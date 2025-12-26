import Foundation
import AppKit
import SwiftUI

class PetManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = PetManager()
    
    @Published var model = PetModel()
    private var window: PetWindow?
    private var checkTimer: Timer?
    private var walkTimer: Timer?
    private var messageTimer: Timer?
    private var monitor: SystemMonitor?
    private var intentMonitor: UserIntentMonitor?
    
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
    private var lastWeatherConditions: (temp: Int, text: String)? = nil
    
    override private init() {
        super.init()
    }
    
    func showPet() {
        guard window == nil else { return }
        
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let initialRect = NSRect(x: screenFrame.midX - 200, y: screenFrame.midY - 150, width: 400, height: 300)
        
        let petWindow = PetWindow(contentRect: initialRect, model: model)
        petWindow.delegate = self
        petWindow.makeKeyAndOrderFront(nil)
        self.window = petWindow
        
        self.monitor = SystemMonitor() // 初始化监控
        self.intentMonitor = UserIntentMonitor.shared
        
        // 启动时同步持久化设置
        let defaults = UserDefaults.standard
        model.isSelfAwarenessEnabled = defaults.object(forKey: "isPetSelfAwarenessEnabled") as? Bool ?? true
        model.isSystemAwarenessEnabled = defaults.object(forKey: "isPetSystemAwarenessEnabled") as? Bool ?? true
        model.isIntentAwarenessEnabled = defaults.object(forKey: "isPetIntentAwarenessEnabled") as? Bool ?? true
        
        startMonitoring()
    }
    

    private func startMonitoring() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateState()
        }
    }
    
    private func updateState() {
        let isDragging = NSEvent.pressedMouseButtons != 0
        if isDragging {
            stopWalking() 
            handleDocking(isDragging: true)
        } else {
            handleDocking(isDragging: false)
            
            // 实时同步：如果开关关闭且正在漫步，立即停止
            if !model.isSelfAwarenessEnabled && model.state == .walking {
                stopWalking()
            }
            
            handleSelfAwareness()
            updateSystemAwareness() 
            updateIntentAwareness()
            updateHealthReminders()
            updateWeatherInsights() // 天气感知集成
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
            
            saySomething(quotes.randomElement()!)
            lastNotifiedLevel = currentLevel
            model.lastSystemQuoteTime = now
        }
    }
    
    // MARK: - 用户意图感知互动 (User Intent Awareness)
    private func updateIntentAwareness() {
        guard model.isIntentAwarenessEnabled, let intent = intentMonitor else { return }
        let now = Date()
        
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
                saySomething(q)
                lastIntentTime = now
                return
            }
        }
        
        // 2. 复杂场景：活跃度与停留时间感知
        if intent.inputFrequency > 100 { // 高频输入（奋笔疾书）
            saySomething(["主人手速惊人！我已经看呆了", "这就是传说中的盲打吗？强！"].randomElement()!)
            lastIntentTime = now
        } else if intent.inputFrequency == 0 && now.timeIntervalSince(lastIntentTime) > 600.0 { // 长时间发呆
             // 复杂操作通过 AI 模拟读心（这里模拟 AI 判断）
             let stayQuote = ["盯——这个页面盯着好久了，是在思考人生吗？", "发呆也是一种修行呢...", "主人掉线了吗？歪？"].randomElement()!
             saySomething(stayQuote)
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
                saySomething(summary, duration: 15.0) 
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
            // 检查用户是否在忙 (意图感知有记录且活跃度不为 0)
            if UserIntentMonitor.shared.inputFrequency > 5 {
                showWaterReminder()
                lastWaterReminderTime = now
            }
        }
    }
    
    private func showWaterReminder() {
        model.actions = [
            PetAction(id: "water_done", title: "喝水了", color: .blue) { [weak self] in
                HealthManager.shared.recordActivity(type: "water")
                self?.saySomething("好哒！主人真棒，继续保持哦~", duration: 3.0)
                self?.model.actions = [] // 清空动作
            },
            PetAction(id: "water_later", title: "等一下", color: .gray) { [weak self] in
                self?.saySomething("那好吧，忙完这阵千万记得喝水呀！", duration: 3.0)
                self?.model.actions = []
            }
        ]
        saySomething("主人忙了好久了，喝杯暖水休息一下吧？💧", duration: 10.0)
    }
    
    /// 调试接口：手动触发健康提醒测试
    func triggerTestReminder(type: String) {
        if type == "water" {
            showWaterReminder()
        } else if type == "stand" {
            model.actions = [
                PetAction(id: "stand_done", title: "站好了", color: .green) { [weak self] in
                    HealthManager.shared.recordActivity(type: "stand")
                    self?.saySomething("活动一下筋骨舒服多了吧！☀️", duration: 3.0)
                    self?.model.actions = []
                },
                PetAction(id: "stand_later", title: "再等会儿", color: .gray) { [weak self] in
                    self?.saySomething("好滴，但别坐太久哦，脊椎在抱怨啦~", duration: 3.0)
                    self?.model.actions = []
                }
            ]
            saySomething("主人站起来伸个腰吧？久坐对身体不好哦~ 🧘‍♀️", duration: 10.0)
        }
    }
    
    // MARK: - 天气感知交互
    
    private func updateWeatherInsights() {
        guard let weather = WeatherService.shared.weather?.current else { return }
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: now)
        
        // 1. 每日首次使用电脑时的天气提醒 (带按钮)
        if lastWeatherPromptDate != todayStr {
            let greeting = getTimeAwareGreeting()
            let info = "\(greeting)！今天天气「\(weather.text)」，气温 \(weather.temp)°C。记得添衣或是带伞哦~ ☁️"
            model.actions = [
                PetAction(id: "weather_ack", title: "朕知道了", color: .nearPrimary) { [weak self] in
                    self?.lastWeatherPromptDate = todayStr
                    self?.saySomething("好哒，那我就不打扰主人啦！", duration: 3.0)
                    self?.model.actions = []
                }
            ]
            saySomething(info, duration: 15.0)
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
                saySomething(msg) // 纯提示消息，不带按钮
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
        guard let window = window else { return }
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
                    self.saySomething(self.undockQuotes.randomElement() ?? "呼~ 被抓出来了")
                }
            }
        }
        
        if shouldDock && !isDragging {
            autoSnapToEdge(edge: newEdge, screen: screen.frame)
            if !wasAlreadyDocked {
                saySomething(dockQuotes.randomElement() ?? "在这儿歇会儿~")
            }
        }
        
        if isDragging && !visibleFrame.contains(CGPoint(x: centerX, y: centerY)) {
            pushBackToVisible(window: window, visibleFrame: visibleFrame)
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
        guard let window = window else { return }
        var origin = window.frame.origin
        let w = window.frame.width
        let h = window.frame.height
        switch edge {
        case .left: origin.x = screen.minX - w/2 + 20
        case .right: origin.x = screen.maxX - w/2 - 20
        case .bottom: origin.y = screen.minY - h/2 + 30
        case .top: origin.y = screen.maxY - h/2 - 30
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
        guard let window = window, let screen = window.screen else { return }
        let s = screen.visibleFrame
        let margin: CGFloat = 150.0
        let targetX = CGFloat.random(in: (s.minX + margin)...(s.maxX - margin))
        let targetY = CGFloat.random(in: (s.minY + margin)...(s.maxY - margin))
        let target = CGPoint(x: targetX - window.frame.width/2, y: targetY - window.frame.height/2)
        model.state = .walking
        model.walkTarget = target
        walkTimer?.invalidate()
        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, let win = self.window else { timer.invalidate(); return }
            
            // 二次校验：确保开关关闭时逻辑能彻底停掉
            if !self.model.isSelfAwarenessEnabled {
                self.stopWalking()
                return
            }
            let curr = win.frame.origin
            let dx = target.x - curr.x
            let dy = target.y - curr.y
            let dist = hypot(dx, dy)
            if dist < 2.0 {
                self.stopWalking()
                if Double.random(in: 0...1) > 0.6 {
                    self.saySomething(self.randomQuotes.randomElement() ?? "散步真开心~")
                }
            } else {
                win.setFrameOrigin(CGPoint(x: curr.x + (dx/dist)*1.0, y: curr.y + (dy/dist)*1.0))
            }
        }
    }
    
    private func stopWalking() {
        walkTimer?.invalidate()
        walkTimer = nil
        model.state = .idle
        model.lastWalkTime = Date()
        model.walkTarget = nil
    }
    
    private let randomQuotes = ["今天也要加油呀~", "我在巡逻呢！", "这边的风景不错", "感觉自己萌萌哒", "想喝奶茶了...", "你在忙吗？"]
    
    func saySomething(_ text: String, duration: TimeInterval? = nil) {
        // 默认逻辑：如果不是主动设置了交互 actions，则清空按钮
        // 增加匹配范围：涵盖喝水、站立、天气问候、每日总结等必要交互
        let keywords = ["水", "腰", "站", "早", "午", "晚", "深", "知道了", "总结", "天气"]
        let hasKeywords = keywords.contains { text.contains($0) }
        let isInteractive = !model.actions.isEmpty && hasKeywords
        
        if !isInteractive {
            model.actions = []
        }
        
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
        
        // 根据字数计算时间：每个字 0.1s + 基础 1.5s，最长 5s
        let displayDuration = duration ?? min(5.0, 1.5 + Double(text.count) * 0.15)
        
        withAnimation { model.isMessageVisible = true }
        
        messageTimer?.invalidate()
        messageTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
            withAnimation { self?.model.isMessageVisible = false }
        }
    }
    
    func hidePet() {
        checkTimer?.invalidate()
        walkTimer?.invalidate()
        messageTimer?.invalidate()
        window?.orderOut(nil)
        window = nil
        model.isVisible = false
    }
    
    func windowWillClose(_ notification: Notification) { hidePet() }
}
