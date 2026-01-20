import Foundation
import AppKit
import SwiftUI
import Combine

class PetManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = PetManager()
    
    @Published var model = PetModel()
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
                // 激活动画：消息显示中
                self?.model.isAnimating = isVisible
                
                if isVisible {
                    if let petFrame = self?.petWindow?.frame {
                        self?.bubbleWindow?.updateSizeAndPosition(relativeTo: petFrame)
                    }
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
                }
                
                let shouldAnimate = self.model.isMessageVisible || self.isDragging
                if self.model.isAnimating != shouldAnimate {
                    self.model.isAnimating = shouldAnimate
                }
            }
            .store(in: &powerCancellables)
    }
    
    private func enterIdleMode() {
        LogManager.shared.append("[PET] Entering Idle Mode: Suspending timers and animations")
        checkTimer?.invalidate()
        walkTimer?.invalidate()
        messageTimer?.invalidate()
        monitor?.stopMonitoring()
        withAnimation { model.isMessageVisible = false }
    }
    
    private func handleIdleExit() {
        LogManager.shared.append("[PET] Detected Idle Exit: Restoring activities")
        monitor?.startMonitoring()
        startMonitoring()
        
        // 延迟 1-3s 触发拟人化唤醒
        let delay = Double.random(in: 1.0...3.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let quotes = ["朕又回来啦！刚才睡得真香~", "呼... 好梦初醒，开始干活！", "捕捉到你的操作啦，我在偷懒的时候你该不会也在摸鱼吧？", "信号恢复！ Near 准备就绪。"]
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
        
        let petWindow = PetWindow(contentRect: initialRect, model: model)
        petWindow.delegate = self
        
        // 创建并绑定气泡窗口
        let bubbleWindow = BubbleWindow(model: model)
        petWindow.addChildWindow(bubbleWindow, ordered: .above)
        
        petWindow.makeKeyAndOrderFront(nil)
        self.petWindow = petWindow
        self.bubbleWindow = bubbleWindow
        
        self.monitor = SystemMonitor() // 初始化监控
        self.intentMonitor = UserIntentMonitor.shared
        
        // 启动时同步持久化设置
        // 静态模式优化：仅在非闲置时启动高频监控（逻辑已在 startMonitoring 中处理）
        
        startMonitoring()
    }
    

    private func startMonitoring() {
        // 大幅降低常驻频率：仅 1.0s 用于基础状态检查
        resetTimer(interval: 1.0)
    }
    
    // 暴露此方法，让 Window 在移动时主动通知
    func handleWindowMoved() {
        // 拖拽中激活动画
        self.isDragging = true
        if !model.isAnimating { model.isAnimating = true }
        
        // 由于使用了 addChildWindow，位移同步由系统处理
        handleDocking(isDragging: true)
    }
    
    func finishDragging() {
        self.isDragging = false
        // 停止拖拽后，如果没有气泡，则停止动画以省电
        if !model.isMessageVisible { model.isAnimating = false }
        
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
                quotes = ["电脑终于凉快下来了，舒服~", "呼，刚才好热呀，现在好多了", "还是这会儿清爽，适合发呆~"]
            case .medium: 
                quotes = ["工作量上来了呢，加油！", "呼，稍微有一点点热了", "我在陪你一起努力呢"]
            case .high: 
                quotes = ["哇！电脑要爆炸啦，快休息下！", "好烫好烫，你在跑仿真吗？", "我的光环都变红了，冷静点！"]
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
    }
    
    // MARK: - 用户意图感知互动 (User Intent Awareness)
    private func updateIntentAwareness() {
        guard model.isIntentAwarenessEnabled, let intent = intentMonitor else { return }
        let now = Date()
        
        // 结算并重置输入频率
        let _ = intent.flushInputFrequency()
        
        // 互动 CD：2 分钟（防止频繁打扰）
        guard now.timeIntervalSince(lastIntentTime) > 120.0 else { return }
        
        // 1. 简单场景：应用切换感知
        if intent.activeApp != lastIntentAppName {
            let app = intent.activeApp.lowercased()
            lastIntentAppName = intent.activeApp
            
            var quote: String? = nil
            
            if app.contains("xcode") || app.contains("vscode") || app.contains("iterm") {
                quote = ["主人加油，代码写累了休息下~", "键盘冒火星啦，代码之神在注视你！", "在敲 Bug 还是在造轮子呀？"].randomElement()
            } else if app.contains("safari") || app.contains("chrome") {
                quote = ["又在查资料（摸鱼）吗？", "浏览器的内容看起来很精彩呢...", "别看太久，记得眨眨眼哦"].randomElement()
            } else if app.contains("bilibili") || app.contains("youtube") {
                quote = ["我也想看这个视频！", "摸鱼时间到！我也来凑热闹", "老板在看你哦...（开玩笑的）"].randomElement()
            } else if app.contains("finder") {
                quote = ["在找什么宝贝？我帮你找找看？", "文件好多呀，该整理一下了呢"].randomElement()
            }
            
            if let q = quote {
                NotificationManager.shared.post(NearNotification(message: q, type: .fun))
                lastIntentTime = now
                return
            }
        }
        
        // 2. 复杂场景：活跃度与停留时间感知
        if intent.inputFrequency > 100 { // 高频输入（奋笔疾书）
            NotificationManager.shared.post(NearNotification(message: ["主人手速惊人！我已经看呆了", "这就是传说中的盲打吗？强！"].randomElement()!, type: .fun))
            lastIntentTime = now
        } else if intent.inputFrequency == 0 && now.timeIntervalSince(lastIntentTime) > 600.0 { // 长时间发呆
             let stayQuote = ["盯——这个页面盯着好久了，是在思考人生吗？", "发呆也是一种修行呢...", "主人掉线了吗？歪？"].randomElement()!
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
        
        // 2. 定时健康提醒 (模拟：每 60 分钟且用户活跃时)
        // 这里为了演示效果，可以缩短间隔，实际建议 1 小时
        let waterInterval: TimeInterval = 3600 // 1 小时
        if now.timeIntervalSince(lastWaterReminderTime) > waterInterval {
            showWaterReminder()
            lastWaterReminderTime = now
        }
    }
    
    private func showWaterReminder() {
        let notification = NearNotification(
            message: "主人忙了好久了，喝杯暖水休息一下吧？💧",
            type: .health,
            actions: [
                NearNotificationAction(id: "water_done", title: "喝水了", color: .blue) {
                    HealthManager.shared.recordActivity(type: "water")
                    NotificationManager.shared.post(NearNotification(message: "好哒！主人真棒，继续保持哦~", type: .health, autoDismissDelay: 3.0))
                },
                NearNotificationAction(id: "water_later", title: "等一下", color: .gray) {
                    NotificationManager.shared.post(NearNotification(message: "那好吧，忙完这阵千万记得喝水呀！", type: .health, autoDismissDelay: 3.0))
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
            model.actions = [
                PetAction(id: "stand_done", title: "站好了", color: .green) { [weak self] in
                    HealthManager.shared.recordActivity(type: "stand")
                    self?.saySomething(text: "活动一下筋骨舒服多了吧！☀️", duration: 3.0)
                    self?.model.actions = []
                },
                PetAction(id: "stand_later", title: "再等会儿", color: .gray) { [weak self] in
                    self?.saySomething(text: "好滴，但别坐太久哦，脊椎在抱怨啦~", duration: 3.0)
                    self?.model.actions = []
                }
            ]
            notify("主人站起来伸个腰吧？久坐对身体不好哦~ 🧘‍♀️", level: .critical, type: .health, duration: 10.0)
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
                    NearNotificationAction(id: "weather_ack", title: "朕知道了", color: .nearPrimary) {
                        self.isWeatherAckedToday = true
                        NotificationManager.shared.post(NearNotification(message: "好哒，那我就不打扰主人啦！", type: .weather, autoDismissDelay: 3.0))
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
                burstMsg = "天色变了呢，现在是「\(weather.text)」啦，主人快看窗外！"
            } else if tempDiff >= 5 {
                burstMsg = "气温突然波动了 \(tempDiff)°C，现在是 \(weather.temp)°C，多保重哦！"
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
        case 0..<5: return "主人这么晚还没睡呀"
        case 5..<9: return "早安主人"
        case 9..<12: return "上午好呀"
        case 12..<14: return "中午好，记得午休下哦"
        case 14..<18: return "下午好，喝杯咖啡吗"
        case 18..<22: return "晚上好，辛苦啦"
        default: return "夜深了，注意休息哦"
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
    
    private let dockQuotes = ["在这儿躲一会儿~", "没人能看见我吧？", "我变小啦！", "嘘...我在潜伏", "贴贴边缘~"]
    private let undockQuotes = ["被抓出来了！", "呼~ 还是中间宽敞", "主人发现我了", "哎呀，别抓我的耳朵~", "我又变大啦！"]
    
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
        let now = Date()
        if model.state == .idle && now.timeIntervalSince(model.lastWalkTime) > 30.0 {
            if Double.random(in: 0...1) < 0.03 {
                startRandomWalk()
            }
        }
    }
    
    private func startRandomWalk() {
        guard let window = petWindow, let screen = window.screen else { return }
        let s = screen.visibleFrame
        let margin: CGFloat = 150.0
        let targetX = CGFloat.random(in: (s.minX + margin)...(s.maxX - margin))
        let targetY = CGFloat.random(in: (s.minY + margin)...(s.maxY - margin))
        let target = CGPoint(x: targetX - window.frame.width/2, y: targetY - window.frame.height/2)
        model.state = .walking
        model.walkTarget = target
        
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
    }
    
    private let randomQuotes = ["今天也要加油呀~", "我在巡逻呢！", "这边的风景不错", "感觉自己萌萌哒", "想喝奶茶了...", "你在忙吗？"]
    
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
    
    func saySomething(text: String, type: PetMessageType = .fun, duration: TimeInterval? = nil, isFromManager: Bool = false) {
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
        checkTimer?.invalidate()
        walkTimer?.invalidate()
        messageTimer?.invalidate()
        monitor?.stopMonitoring()
        bubbleWindow?.orderOut(nil)
        petWindow?.orderOut(nil)
        petWindow = nil
        bubbleWindow = nil
        model.isVisible = false
    }
    
    func windowWillClose(_ notification: Notification) { hidePet() }
}
