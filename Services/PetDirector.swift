import Foundation
import Combine

/// 单一状态机宿主：把“宠物意图”翻译成语义动画并驱动帧。
///
/// 职责边界：
///  - 输入：业务层（PetManager / 外部命令）调用 `interrupt(semantic:)`、`setBubble` 等
///  - 内部：根据当前模型状态推导语义 → 播放对应雪碧图行（Lottie 宠物走自身播放器，不在此驱动）
///  - 输出：仅写 model 的 `semantic` / `atlasRow` / `atlasCol`（视图消费）
///
/// 设计原则：渲染只看快照；动画抢占 + TTL 回闲；闲置/贴边时停帧省电。
final class PetDirector: ObservableObject {
    weak var model: PetModel?

    /// 当前皮肤是否为雪碧图（决定是否由 director 驱动帧）
    var isAtlasSkin = false
    /// 帧调度缓存：语义 → 当前所在行
    private var activeClip: AtlasClip?
    private var frameTimer: Timer?
    private var ttlTimer: Timer?
    private var frameIndex = 0

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

    private func applySemantic(_ semantic: PetAnimSemantic, reason: String, ttl: TimeInterval? = nil) {
        guard isAtlasSkin, let model = model else {
            currentSemantic = semantic
            model?.semantic = semantic
            return
        }
        currentSemantic = semantic
        model.semantic = semantic

        let clip = semantic.atlasClip(facing: model.facingDirection)
        activeClip = clip

        LogManager.shared.appendPerformance(key: "pet-semantic", interval: 3.0, "[PET] semantic=\(semantic.rawValue) reason=\(reason) row=\(clip.row)")

        // 静态帧（低电量/贴边隐藏态）→ 只显示首帧，不起 timer
        if clip.staticFrame || model.isDocked && !semantic.shouldAnimate {
            stopFrameTimer()
            model.atlasRow = clip.row
            model.atlasCol = 0
            return
        }

        // 呼吸型（idle/贴边）与循环型都起帧调度；一次性（说话/成功/失败）播完回闲置
        frameIndex = entryFrame(for: clip)
        model.atlasRow = clip.row
        model.atlasCol = frameIndex
        scheduleNextFrame()

        // TTL：非闲置语义到点强制回闲置（贴边时保持贴边视觉）
        if let ttl = ttl, ttl > 0 {
            ttlTimer?.invalidate()
            ttlTimer = Timer.scheduledTimer(withTimeInterval: ttl, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.returnToAmbient(reason: "ttl") }
            }
        } else {
            ttlTimer?.invalidate()
        }
    }

    /// 进入闲置（取消 TTL 与帧定时）
    func returnToAmbient(reason: String) {
        guard isAtlasSkin else { return }
        applySemantic(.idle, reason: reason)
    }

    /// 事件源（业务层）主动刷新当前语义（如拖拽结束、行走结束、消息变化后调用）
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
        // 只有“高一层”的语义变化才打断正在播放的一次性动画（说话/成功/失败播完自动回闲置）
        if currentSemantic == semantic { return }
        applySemantic(semantic, reason: reason)
    }

    // MARK: - 帧调度

    private func entryFrame(for clip: AtlasClip) -> Int {
        switch activeClip?.row {
        case 3, 4, 5: // waving/jumping/failed 从第 1 帧起，避免闪
            return min(1, clip.frameCount - 1)
        default:
            return 0
        }
    }

    private func scheduleNextFrame() {
        frameTimer?.invalidate()
        guard let clip = activeClip else { return }
        let ms = clip.durationsMS[min(frameIndex, clip.durationsMS.count - 1)]
        frameTimer = Timer.scheduledTimer(withTimeInterval: Double(ms) / 1000.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.advanceFrame() }
        }
    }

    private func advanceFrame() {
        guard let model = model, let clip = activeClip else { return }
        frameIndex += 1

        if frameIndex >= clip.frameCount {
            if clip.loop {
                frameIndex = 0
            } else {
                // 一次性动画播完 → 回到闲置
                returnToAmbient(reason: "clipFinished")
                return
            }
        }

        model.atlasRow = clip.row
        model.atlasCol = frameIndex
        scheduleNextFrame()
    }

    private func stopFrameTimer() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    /// 停掉所有驱动（闲置/隐藏/销毁时）
    func suspend() {
        frameTimer?.invalidate()
        frameTimer = nil
        ttlTimer?.invalidate()
        ttlTimer = nil
    }

    func resume() {
        guard isAtlasSkin, let model = model, model.isEnabled else { return }
        applySemantic(model.semantic, reason: "resume")
    }
}
