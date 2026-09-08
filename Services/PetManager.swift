import Foundation
import AppKit
import SwiftUI
import Combine

class PetManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = PetManager()
    
    @Published var model = PetModel()
    private(set) var petBundle: PetBundle? = nil
    /// 雪碧图皮肤时的帧驱动器
    private var director: PetDirector?
    private var petWindow: PetWindow?
    private var bubbleWindow: BubbleWindow?
    private var checkTimer: Timer?
    private var walkTimer: Timer?
    private var messageTimer: Timer?
    private var monitor: SystemMonitor?
    private var intentMonitor: UserIntentMonitor?
    private var isDragging: Bool = false
    
    // 操作意图追踪
    private var lastIntentAppName: String = ""
    private var lastIntentTime: Date = .distantPast
    
    // 系统感知：负载稳定性追踪
    private var pendingLevel: PetModel.LoadLevel = .low
    private var lastNotifiedLevel: PetModel.LoadLevel = .low
    private var levelStableStartTime: Date = .distantPast
    
    // 健康助手状态
    private var lastWaterReminderTime: Date = .distantPast
    private var lastStandReminderTime: Date = .distantPast
    private var isDailySummaryShown: Bool = false
    
    // 天气感知状态
    private var lastWeatherPromptDate: String = "" // YYYY-MM-DD
    private var lastWeatherAckTime: Date = .distantPast
    private var isWeatherAckedToday: Bool = false
    private var lastWeatherConditions: (temp: Int, text: String)? = nil
    
    // 通知计时器：用于频率控制
    private var lastNotificationTimes: [String: Date] = [:]
    private var lastDeepCheckTime: Date = .distantPast
    
    // 【新增】分层调度时间戳
    private var lastWeatherCheckTime: Date = .distantPast
    private var lastHealthCheckTime: Date = .distantPast
    private var lastIntentCheckTime: Date = .distantPast
    
    // 通知等级定义
    enum NotificationLevel: Int {
        case critical = 1 // 健康提醒、气象灾害
        case important = 2 // 每日天气、固定日程
        case normal = 3 // 自由交互、系统负载
    }
    
    enum NotificationType: String {
        case health, interaction, fun, system, weather, power
    }
    
    private var powerCancellables = Set<AnyCancellable>()
    private var notificationCancellable: AnyCancellable?

    /// 旧 Lottie 时代的动画状态刷新入口。纯雪碧图时代统一由 PetDirector 驱动，
    /// 这里保留为对 director 的 reconcile 转发，供既有事件调用点使用。
    private func refreshAnimationState(reason: String) {
        director?.reconcile(reason: reason)
    }

    override private init() {
        super.init()
        setupPowerObservation()
        setupNotificationObservation()
    }
    
    private func setupNotificationObservation() {
        NotificationManager.shared.$currentNotification
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let notification = notification {
                    self?.displayNotification(notification)
                } else {
                    self?.model.isMessageVisible = false
                }
            }
            .store(in: &powerCancellables)
    }
    
    private func displayNotification(_ notification: NearNotification) {
        // 1. 设置动作按钮
        self.model.actions = notification.actions.map { action in
            PetAction(id: action.id, title: action.title, color: action.color) {
                NotificationManager.shared.triggerAction(action.id)
            }
        }
        
        // 2. 映射通知类型
        let msgType: PetMessageType
        switch notification.type {
        case .system: msgType = .system
        case .health: msgType = .health
        case .power: msgType = .power
        case .fun: msgType = .fun
        case .weather: msgType = .weather
        case .countdown: msgType = .health // 倒计时暂时映射至健康提醒风格
        }
        
        // 3. 显示消息
        saySomething(text: notification.message, type: msgType, isFromManager: true)
    }
    
    private func setupPowerObservation() {
        PowerStateManager.shared.$isIdle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isIdle in
                self?.model.isIdle = isIdle
                if isIdle {
                    self?.enterIdleMode()
                } else {
                    self?.handleIdleExit()
                }
            }
            .store(in: &powerCancellables)
            
        // 监听开启/关闭状态
        model.$isEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                if isEnabled {
                    self?.showPet()
                } else {
                    self?.hidePet()
                }
            }
            .store(in: &powerCancellables)
            
        // 【新增】监听消息可见性，主动更新气泡位置与宠物动画状态
        model.$isMessageVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                // 消息可见性变化后统一解析动画状态，避免覆盖 walking/dragging 等动画。
                self?.refreshAnimationState(reason: "messageVisibleChanged")

                // 气泡更新：立即更新，使用手动计算的高度
                if let petFrame = self?.petWindow?.frame {
                    self?.bubbleWindow?.updateSizeAndPosition(relativeTo: petFrame)
                }
            }
            .store(in: &powerCancellables)
            
        // 【关键修复】建立 0.5s 的低频自检，确保 isAnimating 状态最终一致性
        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                // 物理兜底：如果 self.isDragging 为 true 但鼠标实际并未按下（AppKit 漏掉了 mouseUp）
                // 则强制修正 isDragging 状态
                if self.isDragging && NSEvent.pressedMouseButtons == 0 {
                    self.isDragging = false
                    self.model.isDragging = false
                }

                if self.model.isDragging != self.isDragging {
                    self.model.isDragging = self.isDragging
                }
                self.refreshAnimationState(reason: "dragFallbackTimer")
            }
            .store(in: &powerCancellables)
    }
    
    private func enterIdleMode() {
        LogManager.shared.append("[PET] Entering Idle Mode: Suspending timers and animations")
        invalidateAllTimers()
        director?.suspend()
        monitor?.stopMonitoring()
        withAnimation { model.isMessageVisible = false }
        model.isDragging = false
        model.state = .idle
        refreshAnimationState(reason: "enterIdleMode")
    }

    /// 统一清理所有 Timer，防止资源泄漏
    private func invalidateAllTimers() {
        checkTimer?.invalidate()
        checkTimer = nil
        walkTimer?.invalidate()
        walkTimer = nil
        messageTimer?.invalidate()
        messageTimer = nil
    }
    
    private func handleIdleExit() {
        LogManager.shared.append("[PET] Detected Idle Exit: Restoring activities")
        monitor?.startMonitoring()
        director?.resume()
        startMonitoring()
        refreshAnimationState(reason: "idleExit")

        // 延迟 1-3s 触发拟人化唤醒
        let delay = Double.random(in: 1.0...3.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let quotes = ["奴才回来啦！刚才打了个盹~", "陛下驾到！奴才听候差遣！", "睡醒了陛下！奴才精神抖擞！", "陛下醒了？奴才也刚睡醒~", "奴才充好电啦，继续伺候陛下！", "呼...奴才满血复活！"]
            let notification = NearNotification(
                message: quotes.randomElement() ?? "我回来啦！",
                type: .power,
                autoDismissDelay: 5.0
            )
            NotificationManager.shared.post(notification)
        }
    }
    
    func showPet() {
        guard petWindow == nil else { return }
        
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let initialRect = NSRect(x: screenFrame.midX - 30, y: screenFrame.midY - 30, width: 60, height: 60)
        
        // 依据当前皮肤 id 解析形象（社区雪碧图）
        self.petBundle = PetLibrary.resolveBundle(petID: model.petSkinID)
        model.semantic = .idle
        model.atlasRow = 0
        model.atlasCol = 0

        let petWindow = PetWindow(contentRect: initialRect, model: model, bundle: petBundle)
        petWindow.delegate = self
        
        // 创建并绑定气泡窗口
        let bubbleWindow = BubbleWindow(model: model)
        petWindow.addChildWindow(bubbleWindow, ordered: .above)
        
        petWindow.makeKeyAndOrderFront(nil)
        self.petWindow = petWindow
        self.bubbleWindow = bubbleWindow
        
        self.monitor = SystemMonitor() // 初始化监控
        self.intentMonitor = UserIntentMonitor.shared
        
        // 雪碧图皮肤：由 director 驱动帧
        let director = PetDirector(model: model)
        self.director = director
        director.attachAtlas()
        director.interrupt(.idle, reason: "showPet")
        
        // 启动本地命令通道（供 PI Hook / 脚本调用）
        startCommandServer()
        
        // 启动时同步持久化设置
        // 静态模式优化：仅在非闲置时启动高频监控（逻辑已在 startMonitoring 中处理）
        
        startMonitoring()
    }

    /// 启动宠物命令通道：接收外部 JSON 命令（如 PI Hook 报告成功/失败）。
    private func startCommandServer() {
        PetCommandServer.shared.onCommand = { [weak self] command in
            guard let self = self else { return }
            guard self.petWindow != nil else { return } // 宠物未显示则忽略

            // 1) 表达性动作到达时，若正在随机散步先停下，避免画面/动作打架
            if command.semantic != .idle && self.model.state == .walking {
                self.stopWalking()
            }

            // 2) 先播动作（给足展示时长）；3) 台词仅作为气泡文字，不打断动作
            switch command.semantic {
            case .idle:
                self.director?.returnToAmbient(reason: "remote")
                if let msg = command.message, !msg.isEmpty {
                    self.saySomething(text: msg, type: self.petMessageType(for: .idle), preserveAction: true)
                }
            case .working, .waiting, .review:
                // 持续性状态：动作循环展示，直到下一条命令/事件改变
                self.director?.interrupt(command.semantic, reason: "remote")
                let msg = command.message?.nilIfEmpty ?? self.petLine(for: command.semantic)
                if let msg = msg {
                    self.saySomething(text: msg, type: self.petMessageType(for: command.semantic), preserveAction: true)
                }
            case .success, .failure:
                // 一次性表达动作：播放完整一遍（约 2.5s），台词并行显示
                self.director?.interrupt(command.semantic, reason: "remote", ttl: 3.0)
                let msg = command.message?.nilIfEmpty ?? self.petLine(for: command.semantic)
                if let msg = msg {
                    self.saySomething(text: msg, type: self.petMessageType(for: command.semantic), preserveAction: true)
                }
            case .speaking:
                self.director?.interrupt(.speaking, reason: "remote", ttl: 3.0)
                if let msg = command.message, !msg.isEmpty {
                    self.saySomething(text: msg, type: .fun, preserveAction: true)
                }
            default:
                // 闲置/贴边/低电量/行走/拖拽等：仅当有台词时说话
                if let msg = command.message, !msg.isEmpty {
                    self.saySomething(text: msg, type: self.petMessageType(for: command.semantic))
                } else {
                    self.director?.returnToAmbient(reason: "remote")
                }
            }
        }
        PetCommandServer.shared.start()
    }

    /// 远程命令未带文案时，按语义生成拟人化台词
    private func petLine(for semantic: PetAnimSemantic) -> String? {
        switch semantic {
        case .working:
            return ["奴才这就开工，陛下稍候~", "收到！奴才麻溜儿地干起来", "开工开工，键盘要冒烟啦"].randomElement()
        case .success:
            return ["成了成了！奴才给您贺喜~🎉", "完美收工！奴才都替陛下高兴", "搞定！陛下的吩咐奴才从不含糊"].randomElement()
        case .failure:
            return ["哎哟喂，出岔子了…奴才再琢磨琢磨", "大意了……陛下容奴才重新来过", "这次没成，奴才不认输！"].randomElement()
        case .waiting:
            return ["奴才候着呢，陛下慢慢来~"].randomElement()
        case .review:
            return ["让奴才端详端详……嗯，有几分门道"].randomElement()
        case .speaking:
            return ["奴才在呢，陛下请讲~"].randomElement()
        case .idle:
            return ["奴才随时听候差遣"].randomElement()
        default:
            return nil
        }
    }

    /// 语义 → 气泡文案风格（供远程命令附带台词时使用）
    private func petMessageType(for semantic: PetAnimSemantic) -> PetMessageType {
        switch semantic {
        case .success: return .fun
        case .failure: return .system
        case .working, .waiting, .review: return .system
        case .speaking, .idle, .docked, .lowPower, .walking, .dragging: return .fun
        }
    }

    /// 切换宠物皮肤（外部/设置页调用）。返回是否成功。
    @discardableResult
    func setSkin(id: String) -> Bool {
        UserDefaults.standard.set(id, forKey: "petSkinID")
        guard petWindow == nil else {
            // 运行中切换：先隐藏再以新皮肤重建
            hidePet()
            model.petSkinID = id
            if model.isEnabled { showPet() }
            return true
        }
        model.petSkinID = id
        return true
    }

    /// 启动时恢复上次皮肤
    func loadStoredSkin() {
        let stored = UserDefaults.standard.string(forKey: "petSkinID") ?? "starcorn"
        model.petSkinID = stored
    }
    

    private func startMonitoring() {
        // 大幅降低常驻频率：仅 1.0s 用于基础状态检查
        resetTimer(interval: 1.0)
    }
    
    // 暴露此方法，让 Window 在移动时主动通知
    func handleWindowMoved() {
        // 拖拽中激活动画
        self.isDragging = true
        model.isDragging = true
        director?.interrupt(.dragging, reason: "draggingStarted")
        refreshAnimationState(reason: "draggingStarted")

        // 由于使用了 addChildWindow，位移同步由系统处理
        handleDocking(isDragging: true)
    }
    
    func finishDragging() {
        self.isDragging = false
        model.isDragging = false
        director?.reconcile(reason: "draggingFinished")
        refreshAnimationState(reason: "draggingFinished")

        handleDocking(isDragging: false)
        // 停止拖拽后，强制校验一次气泡位置
        if let petFrame = petWindow?.frame {
            bubbleWindow?.updateSizeAndPosition(relativeTo: petFrame)
        }
    }

    private func resetTimer(interval: TimeInterval) {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateState()
        }
    }
    
    private func updateState() {
        let now = Date()
        
        // 1. 实时级 (1.0s): 自我意识感知（随机散步逻辑）
        handleSelfAwareness() 
        
        // 2. 动态级 (30.0s): 系统负载检查
        if now.timeIntervalSince(lastDeepCheckTime) >= 30.0 {
            updateSystemAwareness() 
            lastDeepCheckTime = now
        }
        
        // 3. 意图级 (60.0s): 用户意图、应用切换感知
        if now.timeIntervalSince(lastIntentCheckTime) >= 60.0 {
            updateIntentAwareness()
            lastIntentCheckTime = now
        }
        
        // 4. 业务级 - 健康提醒 (600.0s / 10min)
        if now.timeIntervalSince(lastHealthCheckTime) >= 600.0 {
            updateHealthReminders()
            lastHealthCheckTime = now
        }
        
        // 5. 业务级 - 天气感知 (1800.0s / 30min)
        if now.timeIntervalSince(lastWeatherCheckTime) >= 1800.0 {
            updateWeatherInsights()
            lastWeatherCheckTime = now
        }
    }
    
    private func updateSystemAwareness() {
        guard model.isSystemAwarenessEnabled, let monitor = monitor else { return }
        
        let cpu = monitor.cpuUsage * 100.0
        let currentLevel: PetModel.LoadLevel
        
        // 1. 负载分级与 UI 颜色同步
        if cpu < 15.0 { currentLevel = .low }
        else if cpu < 50.0 { currentLevel = .medium }
        else { currentLevel = .high }
        
        if model.cpuLoadLevel != currentLevel {
            DispatchQueue.main.async {
                withAnimation { self.model.cpuLoadLevel = currentLevel }
            }
        }


        // 2. 拟人化气泡逻辑：稳定性过滤
        let now = Date()
        
        // 如果等级发生变化，开始计时
        if currentLevel != pendingLevel {
            pendingLevel = currentLevel
            levelStableStartTime = now
        }
        
        // 判定条件：
        // a. 等级稳定超过 4 秒 (避开瞬时波峰)
        // b. 该等级尚未提醒过 (记忆功能)
        // c. 距离上次任意提醒至少 5 秒 (最小间隔)
        if currentLevel != lastNotifiedLevel && 
           now.timeIntervalSince(levelStableStartTime) >= 4.0 &&
           now.timeIntervalSince(model.lastSystemQuoteTime) >= 5.0 {
            
            let quotes: [String]
            switch currentLevel {
            case .low:
                quotes = ["电脑凉快了~奴才也舒服多了！", "呼——温度降下来了，舒服呀！", "这会儿凉爽，奴才也精神~"]
            case .medium:
                quotes = ["陛下的电脑有点热呢！", "奴才陪着陛下一起努力！", "工作量上来了，加油陛下！"]
            case .high:
                quotes = ["陛下！电脑发烫啦！要炸了！", "好烫好烫！电脑在燃烧！", "奴才的毛都热炸了，快看看！"]
            }
            
            let notification = NearNotification(
                message: quotes.randomElement()!,
                type: .system,
                autoDismissDelay: 5.0
            )
            NotificationManager.shared.post(notification)
            lastNotifiedLevel = currentLevel
            model.lastSystemQuoteTime = now
        }

        // 【新增】高负载 → “忙碌/原地跑”动作（starcorn 行7 running / 忙碌）
        // 复用上面的稳定性窗口：稳定 4s 后进入忙碌动画，负载回落回闲置。
        // 仅在空闲/忙碌循环态切换，不打断拖拽/说话/行走/贴边等更高优先级状态。
        let isHighStable = currentLevel == .high &&
            now.timeIntervalSince(levelStableStartTime) >= 4.0 &&
            !model.isDragging && !model.isMessageVisible &&
            model.state != .walking && !model.isDocked
        let isWorking = model.semantic == .working
        if isHighStable && !isWorking {
            director?.interrupt(.working, reason: "cpuHighStable")
        } else if currentLevel != .high && isWorking {
            director?.returnToAmbient(reason: "cpuLoadDown")
        }
    }
    
    // MARK: - 用户意图感知互动 (User Intent Awareness)
    private func updateIntentAwareness() {
        guard model.isIntentAwarenessEnabled, let intent = intentMonitor else { return }
        let now = Date()

        // 结算并重置输入频率（先获取值，再重置）
        let frequency = intent.flushInputFrequency()

        // 互动 CD：2 分钟（防止频繁打扰）
        guard now.timeIntervalSince(lastIntentTime) > 120.0 else { return }

        // 1. 简单场景：应用切换感知
        if intent.activeApp != lastIntentAppName {
            let app = intent.activeApp.lowercased()
            lastIntentAppName = intent.activeApp

            var quote: String? = nil

            if app.contains("xcode") || app.contains("vscode") || app.contains("iterm") {
                quote = ["陛下写代码的样子好帅！", "奴才看不懂但奴才大受震撼！", "键盘要冒烟啦陛下！", "Bug 是什么？能吃吗？", "陛下继续，奴才给您加油~"].randomElement()
            } else if app.contains("safari") || app.contains("chrome") {
                quote = ["陛下在冲浪吗？奴才也想看~", "浏览器里有什么好东西呀？", "陛下眼睛要休息一下吗？", "奴才陪陛下一一起看~"].randomElement()
            } else if app.contains("bilibili") || app.contains("youtube") {
                quote = ["陛下在娱乐呢？奴才也想看！", "摸鱼时间到！奴才陪陛下一起摸~", "这视频有意思吗？", "陛下快乐吗？奴才也想要快乐！"].randomElement()
            } else if app.contains("finder") {
                quote = ["陛下在找什么宝贝呀？", "奴才帮陛下一起找！", "文件好多呐，要奴才帮忙整理吗？"].randomElement()
            }

            if let q = quote {
                NotificationManager.shared.post(NearNotification(message: q, type: .fun))
                lastIntentTime = now
                return
            }
        }

        // 2. 复杂场景：活跃度与停留时间感知
        if frequency > 100 { // 高频输入（奋笔疾书）
            NotificationManager.shared.post(NearNotification(message: ["陛下手速惊人！奴才佩服！", "这就是传说中的盲打吗？太强了陛下！", "奴才只看到一道影子闪过！"].randomElement()!, type: .fun))
            lastIntentTime = now
        } else if frequency == 0 && now.timeIntervalSince(lastIntentTime) > 600.0 { // 长时间发呆
             let stayQuote = ["陛下盯着屏幕发什么呆呢~", "奴才都无聊到睡着了...", "陛下是在想奴才吗？嘿嘿", "这屏幕有奴才好看吗？", "陛下呆住了！要不要奴才表演个节目？"].randomElement()!
             NotificationManager.shared.post(NearNotification(message: stayQuote, type: .fun))
             lastIntentTime = now
        }
    }
    
    // MARK: - 健康助手集成

    private func updateHealthReminders() {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        // 1. 每日总结触发 (17:30 左右)
        if hour == 17 && minute >= 30 && minute <= 35 {
            if !isDailySummaryShown {
                let summary = HealthManager.shared.generateDailySummary()
                let notification = NearNotification(
                    message: summary,
                    type: .health,
                    autoDismissDelay: 15.0
                )
                NotificationManager.shared.post(notification)
                isDailySummaryShown = true
            }
        } else if hour == 0 {
            // 凌晨重置总结标记与天气标记
            isDailySummaryShown = false
        }

        // 2. 定时健康提醒：喝水（每 60 分钟）
        let waterInterval: TimeInterval = 3600 // 1 小时
        if now.timeIntervalSince(lastWaterReminderTime) > waterInterval {
            showWaterReminder()
            lastWaterReminderTime = now
        }

        // 3. 定时健康提醒：站立（每 45 分钟，与喝水错开）
        let standInterval: TimeInterval = 2700 // 45 分钟
        if now.timeIntervalSince(lastStandReminderTime) > standInterval {
            showStandReminder()
            lastStandReminderTime = now
        }
    }

    private func showWaterReminder() {
        let notification = NearNotification(
            message: "陛下久坐伤身呐！奴才端杯茶来？💧",
            type: .health,
            actions: [
                NearNotificationAction(id: "water_done", title: "喝水了", color: .blue) {
                    HealthManager.shared.recordActivity(type: "water")
                    NotificationManager.shared.post(NearNotification(message: "陛下龙体健康！奴才这就退下~", type: .health, autoDismissDelay: 3.0))
                },
                NearNotificationAction(id: "water_later", title: "等一下", color: .gray) {
                    NotificationManager.shared.post(NearNotification(message: "那奴才先候着，陛下记得喝水呀！", type: .health, autoDismissDelay: 3.0))
                }
            ],
            autoDismissDelay: 10.0
        )
        NotificationManager.shared.post(notification)
    }

    private func showStandReminder() {
        let notification = NearNotification(
            message: "陛下龙体要紧！站起来活动活动吧~ 🧘‍♀️",
            type: .health,
            actions: [
                NearNotificationAction(id: "stand_done", title: "站好了", color: .green) {
                    HealthManager.shared.recordActivity(type: "stand")
                    NotificationManager.shared.post(NearNotification(message: "陛下英武！龙体康健！☀️", type: .health, autoDismissDelay: 3.0))
                },
                NearNotificationAction(id: "stand_later", title: "再等会儿", color: .gray) {
                    NotificationManager.shared.post(NearNotification(message: "那奴才陪陛下一起久坐~开玩笑的！", type: .health, autoDismissDelay: 3.0))
                }
            ],
            autoDismissDelay: 10.0
        )
        NotificationManager.shared.post(notification)
    }

    /// 调试接口：手动触发健康提醒测试
    func triggerTestReminder(type: String) {
        if type == "water" {
            showWaterReminder()
        } else if type == "stand" {
            showStandReminder()
        }
    }
    
    // MARK: - 天气感知交互
    
    private func updateWeatherInsights() {
        guard let weather = WeatherService.shared.weather?.current else { return }
        let now = Date()
        let todayStr = SharedUtils.dateFormatter(format: "yyyy-MM-dd").string(from: now)
        
        // 1. 每日首次使用电脑时的天气提醒 (带按钮)
        let isNewDay = lastWeatherPromptDate != todayStr
        let cooldown: TimeInterval = 1800 // 30分钟重新提醒
        
        if isNewDay || (!isWeatherAckedToday && now.timeIntervalSince(lastWeatherAckTime) > cooldown) {
            if isNewDay { isWeatherAckedToday = false }
            
            let greeting = getTimeAwareGreeting()
            var advice = "记得添衣或是带伞哦~" // 兜底
            
            // 使用生活指数提供更人性化的建议
            if let weatherData = WeatherService.shared.weather {
                let indices = weatherData.indices
                // type 1: 穿衣, 3: 紫外线, 8: 舒适度
                if let cloth = indices.first(where: { $0.type == "1" }) {
                    advice = cloth.text.replacingOccurrences(of: "建议", with: "听说今日")
                } else if let comf = indices.first(where: { $0.type == "8" }) {
                    advice = "外面\(comf.category)，\(comf.text)"
                }
            }
            
            let info = "\(greeting)！今天天气「\(weather.text)」，\(advice) ☁️"
            let notification = NearNotification(
                message: info,
                type: .weather,
                actions: [
                    NearNotificationAction(id: "weather_ack", title: "知道了陛下", color: .nearPrimary) {
                        self.isWeatherAckedToday = true
                        NotificationManager.shared.post(NearNotification(message: "奴才告退~陛下保重身体！", type: .weather, autoDismissDelay: 3.0))
                    }
                ],
                autoDismissDelay: 15.0
            )
            NotificationManager.shared.post(notification)
            lastWeatherAckTime = now
            lastWeatherPromptDate = todayStr
        }
        
        // 2. 天气剧变监测 (无按钮)
        if let last = lastWeatherConditions {
            let tempDiff = abs((Int(weather.temp) ?? 0) - last.temp)
            let isConditionChanged = last.text != weather.text
            
            var burstMsg: String? = nil
            if isConditionChanged {
                burstMsg = "陛下！天色变了，现在是「\(weather.text)」啦，快看窗外！"
            } else if tempDiff >= 5 {
                burstMsg = "陛下注意！气温突变 \(tempDiff)°C，现在 \(weather.temp)°C 了！"
            }
            
            if let msg = burstMsg {
                NotificationManager.shared.post(NearNotification(message: msg, type: .weather, autoDismissDelay: 5.0))
            }
        }
        
        // 更新记录快照
        lastWeatherConditions = (temp: Int(weather.temp) ?? 0, text: weather.text)
    }
    
    private func getTimeAwareGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<5: return "陛下龙体要紧，早点休息呀！"
        case 5..<9: return "陛下早安！奴才给您请安了~"
        case 9..<12: return "陛下上午好！奴才随时待命~"
        case 12..<14: return "陛下午安！记得用膳休息哦"
        case 14..<18: return "陛下下午好！奴才给您扇扇风~"
        case 18..<22: return "陛下晚安！奴才守夜值班~"
        default: return "陛下更晚了，早些歇息吧！"
        }
    }
    
    
    private func getOptimalDockEdge(centerX: CGFloat, centerY: CGFloat, screen: NSScreen) -> (edge: DockEdge, rect: NSRect) {
        let fullFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let hasDockBottom = visibleFrame.minY > fullFrame.minY
        let hasDockLeft = visibleFrame.minX > fullFrame.minX
        let hasDockRight = visibleFrame.maxX < fullFrame.maxX
        
        let dockThreshold: CGFloat = 80.0
        var bestEdge: DockEdge = .none
        let distL = centerX - fullFrame.minX
        let distR = fullFrame.maxX - centerX
        let distB = centerY - fullFrame.minY
        let distT = fullFrame.maxY - centerY
        
        let distances: [(DockEdge, CGFloat, Bool)] = [
            (.left, distL, hasDockLeft),
            (.right, distR, hasDockRight),
            (.bottom, distB, hasDockBottom),
            (.top, distT, false)
        ]
        
        let validEdges = distances.filter { !$0.2 && $0.1 < dockThreshold }
        if let closest = validEdges.min(by: { $0.1 < $1.1 }) {
            bestEdge = closest.0
        }
        return (bestEdge, visibleFrame)
    }
    
    private func handleDocking(isDragging: Bool) {
        guard let window = petWindow else { return }
        let frame = window.frame
        let centerX = frame.origin.x + frame.width / 2
        let centerY = frame.origin.y + frame.height / 2
        
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let (newEdge, visibleFrame) = getOptimalDockEdge(centerX: centerX, centerY: centerY, screen: screen)
        
        let shouldDock = newEdge != .none
        let wasAlreadyDocked = model.isDocked
        
        if model.isDocked != shouldDock || model.dockEdge != newEdge {
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self.model.isDocked = shouldDock
                    self.model.dockEdge = newEdge
                    if shouldDock { self.model.state = .docked }
                    else if self.model.state == .docked { self.model.state = .idle }
                }
                self.refreshAnimationState(reason: "dockingChanged")
                self.director?.reconcile(reason: "dockingChanged")

                if wasAlreadyDocked && !shouldDock {
                    self.saySomething(text: self.undockQuotes.randomElement() ?? "呼~ 被抓出来了")
                }
            }
        }
        
        if shouldDock && !isDragging {
            autoSnapToEdge(edge: newEdge, screen: screen.frame)
            if !wasAlreadyDocked {
                saySomething(text: dockQuotes.randomElement() ?? "在这儿歇会儿~")
            }
        }
        
        if isDragging && !visibleFrame.contains(CGPoint(x: centerX, y: centerY)) {
            if let window = petWindow {
                pushBackToVisible(window: window, visibleFrame: visibleFrame)
            }
        }
    }
    
    private let dockQuotes = ["陛下看不见奴才~", "奴才躲一躲...", "嘘！奴才在装死", "缩成一团~", "躲好了陛下！", "奴才藏好啦~"]
    private let undockQuotes = ["陛下找到奴才了！", "被发现了嘿嘿~", "奴才无处可藏！", "好吧奴才出来了~", "陛下眼睛真尖！", "奴才投降！"]
    
    private func pushBackToVisible(window: NSWindow, visibleFrame: NSRect) {
        var origin = window.frame.origin
        let centerX = origin.x + window.frame.width / 2
        let centerY = origin.y + window.frame.height / 2
        if centerX < visibleFrame.minX { origin.x = visibleFrame.minX - window.frame.width / 2 + 10 }
        if centerX > visibleFrame.maxX { origin.x = visibleFrame.maxX - window.frame.width / 2 - 10 }
        if centerY < visibleFrame.minY { origin.y = visibleFrame.minY - window.frame.height / 2 + 10 }
        if origin != window.frame.origin { window.setFrameOrigin(origin) }
    }
    
    private func autoSnapToEdge(edge: DockEdge, screen: NSRect) {
        guard let window = petWindow else { return }
        var origin = window.frame.origin
        let w = window.frame.width
        let h = window.frame.height
        switch edge {
        case .left: origin.x = screen.minX - w/2 + 10 // 静态化后边缘保留更少，使其更“贴”
        case .right: origin.x = screen.maxX - w/2 - 10
        case .bottom: origin.y = screen.minY - h/2 + 20
        case .top: origin.y = screen.maxY - h/2 - 20
        case .none: break
        }
        if abs(window.frame.origin.x - origin.x) > 1 || abs(window.frame.origin.y - origin.y) > 1 {
            window.setFrameOrigin(origin)
        }
    }
    
    private func handleSelfAwareness() {
        guard model.isSelfAwarenessEnabled else { return } // 开关检查
        guard model.state == .idle || model.state == .walking else { return }
        // 表达性动作（忙碌/成功/失败等）展示期间不随机散步，避免打断
        if isExpressiveSemantic(model.semantic) { return }
        let now = Date()
        if model.state == .idle && now.timeIntervalSince(model.lastWalkTime) > 30.0 {
            if Double.random(in: 0...1) < 0.03 {
                startRandomWalk()
            }
        }
    }

    /// 是否属于“表达性动作”（展示期间应避免被低频 ambient 打断）
    private func isExpressiveSemantic(_ semantic: PetAnimSemantic) -> Bool {
        switch semantic {
        case .working, .waiting, .review, .success, .failure, .speaking: return true
        case .idle, .walking, .dragging, .docked, .lowPower: return false
        }
    }
    
    private func startRandomWalk() {
        guard let window = petWindow, let screen = window.screen else { return }
        let s = screen.visibleFrame
        let margin: CGFloat = 150.0
        let targetX = CGFloat.random(in: (s.minX + margin)...(s.maxX - margin))
        let targetY = CGFloat.random(in: (s.minY + margin)...(s.maxY - margin))
        let target = CGPoint(x: targetX - window.frame.width/2, y: targetY - window.frame.height/2)
        let dx = target.x - window.frame.origin.x
        model.facingDirection = dx < 0 ? .left : .right
        model.state = .walking
        model.walkTarget = target
        director?.interrupt(.walking, reason: "walkStarted")
        refreshAnimationState(reason: "walkStarted")

        // 彻底废弃 Timer 步进，改用 Core Animation (NSAnimationContext) 驱动
        NSAnimationContext.runAnimationGroup({ context in
            let dx = target.x - window.frame.origin.x
            let dy = target.y - window.frame.origin.y
            let dist = hypot(dx, dy)
            
            // 保持约 10-20 pts/s 的优雅速度
            context.duration = dist / 15.0
            context.timingFunction = CAMediaTimingFunction(name: .linear)
            
            window.animator().setFrameOrigin(target)
        }, completionHandler: { [weak self] in
            // 动画结束后校验是否由于“抓取”导致的已停止
            guard self?.model.state == .walking else { return }
            self?.stopWalking()
            if Double.random(in: 0...1) > 0.6 {
                self?.notify(self?.randomQuotes.randomElement() ?? "散步真开心~", level: .normal, type: .fun)
            }
        })
    }
    
    private func stopWalking() {
        walkTimer?.invalidate()
        walkTimer = nil
        model.state = .idle
        model.lastWalkTime = Date()
        model.walkTarget = nil
        director?.returnToAmbient(reason: "walkStopped")
        refreshAnimationState(reason: "walkStopped")
    }
    
    private let randomQuotes = ["奴才出来溜达溜达~", "陛下在忙吗？奴才来转转", "这空气真好！", "奴才巡视一下领地~", "好无聊啊陛下...", "奴才想玩！", "趴在地上好凉快~", "陛下需要奴才陪吗？", "奴才走累了..."]
    
    func notify(_ text: String, level: NotificationLevel = .normal, type: NotificationType = .interaction, duration: TimeInterval? = nil) {
        let now = Date()
        let typeKey = type.rawValue
        let lastTime = lastNotificationTimes[typeKey] ?? .distantPast
        
        // 基础冷却时间 (秒)
        var baseCD: TimeInterval = 0
        switch level {
        case .critical:  baseCD = 5.0   // 一级通知几乎无抑制
        case .important: baseCD = 300.0 // 二级通知 5 分钟
        case .normal:    baseCD = 600.0 // 三级通知 10 分钟
        }
        
        // 贴边缩起抑制逻辑
        if model.isDocked && level.rawValue > 1 {
            // 贴边时，非紧急通知冷却时间延长 3-5 倍
            let multiplier: Double = level == .important ? 3.0 : 5.0
            baseCD *= multiplier
        }
        
        // 冷却检查
        // 豁免逻辑：如果是系统电源/唤醒通知，则不进行 CD 抑制，确保用户感知
        if type != .power {
            guard now.timeIntervalSince(lastTime) >= baseCD else { return }
        }
        
        // 类型映射
        let msgType: PetMessageType
        switch type {
        case .system: msgType = .system
        case .health: msgType = .health
        case .power: msgType = .power
        case .fun: msgType = .fun
        case .weather: msgType = .weather
        case .interaction: msgType = .fun // 互动消息映射到日常互动
        }
        
        // 执行提醒
        LogManager.shared.append("[PET-NOTIFY] Type: \(typeKey), Level: \(level.rawValue), Text: \(text)")
        saySomething(text: text, type: msgType, duration: duration)
        lastNotificationTimes[typeKey] = now
    }
    
    func saySomething(text: String, type: PetMessageType = .fun, duration: TimeInterval? = nil, isFromManager: Bool = false, preserveAction: Bool = false) {
        // 如果不是来自 NotificationManager，且没有显式的 isFromManager，则需要清空按钮
        // 这通常是内部拟人化短句（如散步后的感慨）
        if !isFromManager {
            model.actions = []
        }
        
        LogManager.shared.append("[PET-SAY] Text: \(text), Type: \(type.rawValue)")
        
        // 设置消息类型
        model.messageType = type
        
        // 顶掉逻辑
        if model.isMessageVisible {
            model.oldMessage = model.message
            model.oldMessageId = model.messageId
        } else {
            model.oldMessage = ""
            model.oldMessageId = nil
        }
        
        model.message = text
        model.messageId = UUID()
        
        withAnimation { model.isMessageVisible = true }
        // preserveAction：仅显示气泡，不把当前动作（如成功跳跃/失败沮丧）切成"说话/挥手"
        if !preserveAction {
            director?.interrupt(.speaking, reason: "say", ttl: 3.0)
        }
        
        // 注意：如果是通过 NotificationManager 来的，自动消失由其管理，这里不启动自身的 timer
        if !isFromManager {
            let baseDuration = 1.5 + Double(text.count) * 0.1
            let displayDuration = duration ?? min(5.0, baseDuration)
            
            messageTimer?.invalidate()
            messageTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
                withAnimation { self?.model.isMessageVisible = false }
            }
        }
    }
    
    func hidePet() {
        invalidateAllTimers()
        director?.suspend()
        director = nil
        PetCommandServer.shared.onCommand = nil
        PetCommandServer.shared.stop()
        monitor?.stopMonitoring()
        bubbleWindow?.orderOut(nil)
        petWindow?.orderOut(nil)
        petWindow = nil
        bubbleWindow = nil
        model.isVisible = false
    }
    
    func windowWillClose(_ notification: Notification) { hidePet() }
}
