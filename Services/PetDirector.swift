import Foundation
import Combine

/// 单一状态机宿主：把"宠物意图"翻译成语义动画并驱动帧。
///
/// 资源策略（"静默优先"）：
///  - 闲置：播放 1 轮呼吸后**停在静态帧**（不起循环 Timer），每隔数秒偶发一次"微动"再静置。
///  - 忙碌/待命/评审/行走等"有任务"状态：循环播放（需要持续反馈）。
///  - 贴边/低电量：完全静止（停帧）。
final class PetDirector: ObservableObject {
    weak var model: PetModel?

    /// 当前皮肤是否为雪碧图（决定是否由 director 驱动帧）
    var isAtlasSkin = false

    // 帧调度状态
    private var activeClip: AtlasClip?
    private var frameTimer: Timer?
    private var ttlTimer: Timer?
    private var frameIndex = 0
    private var remainingFiniteLoops: Int?

    /// 闲置微动计时（秒）。若怀疑“静止仍在跳”来自微动，可调大/关闭。
    private let idleMicroMotionInterval: TimeInterval = 60.0
    private var idleMicroTimer: Timer?

    // 供视图直接读的状态
    @Published private(set) var currentSemantic: PetAnimSemantic = .idle
    @Published private(set) var atlasRow = 0
    @Published private(set) var atlasCol = 0

    init(model: PetModel) {
        self.model = model
    }

    /// 绑定到雪碧图皮肤后调用（Lottie 皮肤无需）。
    func attachAtlas() {
        isAtlasSkin = true
        applySemantic(.idle, reason: "attachAtlas")
    }

    /// 内部各业务场景统一入口：切换语义动画。
    func interrupt(_ semantic: PetAnimSemantic, reason: String, ttl: TimeInterval? = nil) {
        guard isAtlasSkin, let model = model, model.isEnabled else {
            currentSemantic = semantic
            model?.semantic = semantic
            return
        }
        applySemantic(semantic, reason: reason, ttl: ttl)
    }

    // MARK: - 语义应用

    private func applySemantic(_ semantic: PetAnimSemantic, reason: String, ttl: TimeInterval? = nil) {
        guard isAtlasSkin, let model = model else {
            currentSemantic = semantic
            model?.semantic = semantic
            return
        }

        // 离开闲置/贴边时取消微动计时
        if semantic != .idle {
            idleMicroTimer?.invalidate()
            idleMicroTimer = nil
        }

        currentSemantic = semantic
        model.semantic = semantic

        let clip = semantic.atlasClip(facing: model.facingDirection)
        activeClip = clip

        LogManager.shared.appendPerformance(key: "pet-semantic", interval: 3.0, "[PET] semantic=\(semantic.rawValue) reason=\(reason) row=\(clip.row) loop=\(clip.loop) static=\(clip.staticFrame)")

        // 1) 贴边/低电量/静态帧：完全静止，只显示一帧
        if semantic == .docked || semantic == .lowPower || clip.staticFrame {
            stopAllTimers()
            model.atlasRow = clip.row
            model.atlasCol = 0
            return
        }

        // 2) 闲置：播一轮呼吸 → 静置，然后起微动计时
        if semantic == .idle {
            startIdleBreath(clip: clip)
            return
        }

        // 3) 一次性动画（说话/成功/失败）：播 2 轮后回闲置
        if !clip.loop {
            startFiniteClip(clip)
            applyTTL(semantic, ttl: ttl)
            return
        }

        // 4) 忙碌/待命/评审/行走等：持续循环
        startLoopingClip(clip)
        applyTTL(semantic, ttl: ttl)
    }

    // MARK: - 闲置：呼吸一轮 → 静置 + 偶发微动

    private func startIdleBreath(clip: AtlasClip) {
        frameTimer?.invalidate()
        frameIndex = 0
        stepIdleBreath(clip: clip)
        scheduleIdleMicroMotion()
    }

    private func stepIdleBreath(clip: AtlasClip) {
        guard let model = model else { return }
        model.atlasRow = clip.row
        model.atlasCol = frameIndex
        frameIndex += 1

        guard frameIndex < clip.frameCount else {
            // 一轮播完 → 静置，停在最后一帧
            frameTimer?.invalidate()
            frameTimer = nil
            return
        }
        let ms = clip.durationsMS[min(frameIndex, clip.durationsMS.count - 1)]
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: Double(ms) / 1000.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stepIdleBreath(clip: clip) }
        }
    }

    private func scheduleIdleMicroMotion() {
        idleMicroTimer?.invalidate()
        idleMicroTimer = Timer.scheduledTimer(withTimeInterval: idleMicroMotionInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.doIdleMicroMotion() }
        }
    }

    /// 闲置期偶发"微动"：眨一眼/轻轻动一下，然后继续静置
    private func doIdleMicroMotion() {
        guard let model = model, isAtlasSkin, model.isEnabled,
              currentSemantic == .idle,
              !model.isMessageVisible, !model.isDragging,
              model.state != .walking, !model.isDocked
        else { return }

        let clip = PetAnimSemantic.idle.atlasClip(facing: model.facingDirection)
        frameTimer?.invalidate()

        // 快速切两帧制造"眨眼/微动"：第 0 → 第 1 → 回 0
        model.atlasRow = clip.row
        model.atlasCol = 1
        frameTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let model = self.model,
                      self.currentSemantic == .idle else { return }
                model.atlasCol = 0
            }
        }
    }

    // MARK: - 一次性动画（播 2 轮回闲置）

    private func startFiniteClip(_ clip: AtlasClip) {
        frameTimer?.invalidate()
        frameIndex = entryFrame(for: clip)
        remainingFiniteLoops = 2
        stepFiniteClip(clip: clip)
    }

    private func stepFiniteClip(clip: AtlasClip) {
        guard let model = model else { return }
        frameIndex += 1

        if frameIndex >= clip.frameCount {
            if let remaining = remainingFiniteLoops, remaining > 1 {
                remainingFiniteLoops = remaining - 1
                frameIndex = 0
            } else {
                returnToAmbient(reason: "clipFinished")
                return
            }
        }

        model.atlasRow = clip.row
        model.atlasCol = frameIndex
        let ms = clip.durationsMS[min(frameIndex, clip.durationsMS.count - 1)]
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: Double(ms) / 1000.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stepFiniteClip(clip: clip) }
        }
    }

    // MARK: - 循环动画

    private func startLoopingClip(_ clip: AtlasClip) {
        frameTimer?.invalidate()
        frameIndex = entryFrame(for: clip)
        stepLoopingClip(clip: clip)
    }

    private func stepLoopingClip(clip: AtlasClip) {
        guard let model = model else { return }
        frameIndex += 1
        if frameIndex >= clip.frameCount { frameIndex = 0 }

        model.atlasRow = clip.row
        model.atlasCol = frameIndex
        let ms = clip.durationsMS[min(frameIndex, clip.durationsMS.count - 1)]
        frameTimer?.invalidate()
        frameTimer = Timer.scheduledTimer(withTimeInterval: Double(ms) / 1000.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stepLoopingClip(clip: clip) }
        }
    }

    private func applyTTL(_ semantic: PetAnimSemantic, ttl: TimeInterval?) {
        guard let ttl = ttl, ttl > 0, semantic != .idle else {
            ttlTimer?.invalidate()
            return
        }
        ttlTimer?.invalidate()
        ttlTimer = Timer.scheduledTimer(withTimeInterval: ttl, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.returnToAmbient(reason: "ttl") }
        }
    }

    /// 回到闲置（呼吸一轮后静置）
    func returnToAmbient(reason: String) {
        guard isAtlasSkin else { return }
        applySemantic(.idle, reason: reason)
    }

    /// 事件源（业务层）主动刷新当前语义
    func reconcile(reason: String) {
        guard isAtlasSkin, let model = model else { return }

        let semantic: PetAnimSemantic
        if model.isDocked {
            semantic = .docked
        } else if model.isDragging {
            semantic = .dragging
        } else if model.isMessageVisible {
            semantic = .speaking
        } else if model.state == .walking {
            semantic = .walking
        } else {
            semantic = .idle
        }
        if currentSemantic == semantic { return }
        applySemantic(semantic, reason: reason)
    }

    // MARK: - 帧入口 & 清理

    private func entryFrame(for clip: AtlasClip) -> Int {
        switch activeClip?.row {
        case 3, 4, 5: // waving/jumping/failed 从第 1 帧起，避免闪
            return min(1, clip.frameCount - 1)
        default:
            return 0
        }
    }

    private func stopAllTimers() {
        frameTimer?.invalidate()
        frameTimer = nil
        idleMicroTimer?.invalidate()
        idleMicroTimer = nil
    }

    /// 停掉所有驱动（闲置/隐藏/销毁时）
    func suspend() {
        stopAllTimers()
        ttlTimer?.invalidate()
        ttlTimer = nil
    }

    func resume() {
        guard isAtlasSkin, let model = model, model.isEnabled else { return }
        applySemantic(model.semantic, reason: "resume")
    }
}
