import Cocoa
import SwiftUI
import Combine

class StatusBarManager: NSObject, ObservableObject {
    private let statusItem: NSStatusItem
    private let countdownManager: CountdownManager
    private let systemMonitor: SystemMonitor
    private var window: NSWindow?
    private var animationTimer: Timer?
    private var currentFrame = 0
    private var lastFrameTime = Date()
    private var currentFPS: Int = 30
    private var globalEventMonitor: Any?

    @Published var isWindowVisible = false

    private let aiService: AIService
    private let storageManager: StorageManager

    init(countdownManager: CountdownManager, aiService: AIService, storageManager: StorageManager) {
        print("Starting StatusBarManager initialization")
        self.countdownManager = countdownManager
        self.aiService = aiService
        self.storageManager = storageManager
        self.systemMonitor = SystemMonitor()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        super.init()

        print("StatusBarManager initialized")

        if let button = statusItem.button {
            print("Status item button found")
            // 使用系统图标作为默认图标
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Near Countdown")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            print("Status bar button configured with system timer icon")
        } else {
            print("Error: Could not get status item button")
        }

        // 延迟设置 Combine 订阅，避免初始化问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("Setting up subscriptions")
            self.setupSubscriptions()
            self.startAnimation()
            
            // Fix: Show window on launch to ensure user sees the app
            self.showWindow()
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private func setupSubscriptions() {
        // 清理之前的订阅
        cancellables.removeAll()

        countdownManager.$pinnedCountdown
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusBarTitle()
            }
            .store(in: &cancellables)

        systemMonitor.$cpuUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAnimation()
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.removeAll()
        animationTimer?.invalidate()
        animationTimer = nil

        // 清理全局事件监听器
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func statusBarButtonClicked() {
        print("Status bar button clicked")
        toggleWindow()
    }

    func toggleWindow() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        // 获取状态栏图标的位置
        guard let statusButton = statusItem.button else { return }

        let windowWidth: CGFloat = 380
        let windowHeight: CGFloat = 600

        // 获取状态栏图标在屏幕上的位置
        let statusRect = statusButton.window?.frame ?? statusButton.frame
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        
        // Calculate X position (centered below status item, but kept within screen bounds)
        var xPos = statusRect.midX - windowWidth / 2
        
        // Fallback if status rect is invalid (e.g. 0,0) -> Place at top right
        if statusRect.origin.x == 0 && statusRect.origin.y == 0 {
            xPos = screenFrame.maxX - windowWidth - 20
        }
        
        // Ensure window stays within horizontal screen bounds
        xPos = max(screenFrame.minX + 10, min(xPos, screenFrame.maxX - windowWidth - 10))
        
        // Calculate Y position (below status bar)
        // Note: Cocoa coords (0,0) is bottom-left. Status bar is at top.
        // We want top of window to be slightly below status bar.
        var yPos = statusRect.minY - windowHeight - 5
        
        // Fallback or adjustment if calculation places it off-screen
        if yPos < screenFrame.minY {
            yPos = screenFrame.maxY - windowHeight - 10
        }

        let windowRect = NSRect(
            x: xPos,
            y: yPos,
            width: windowWidth,
            height: windowHeight
        )

        if window == nil {
            createWindow(rect: NSRect.zero) // Create with dummy rect, resize later
        }

        // Recalculate position every time to ensure alignment
        if let statusButton = statusItem.button {
            let statusRect = statusButton.window?.frame ?? statusButton.frame
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            
            let windowWidth: CGFloat = 380
            let windowHeight: CGFloat = 600
            
            var xPos = statusRect.midX - windowWidth / 2
            
            // Fallback for launch issue
            if statusRect.origin.x == 0 && statusRect.origin.y == 0 {
                xPos = screenFrame.maxX - windowWidth - 20
            }
            
            // Constrain visibility
            xPos = max(screenFrame.minX + 10, min(xPos, screenFrame.maxX - windowWidth - 10))
            
            // Y position: Strictly below status bar
            let yPos = statusRect.minY - windowHeight - 5
            
            let windowRect = NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight)
            
            window?.setFrame(windowRect, display: true)
        }
        
        window?.makeKeyAndOrderFront(nil)
        window?.orderFront(nil)
        isWindowVisible = true
    }

    private func getCurrentScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation

        // 找到包含鼠标位置的屏幕
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    private func hideWindow() {
        window?.orderOut(nil)
        isWindowVisible = false
    }

    private func createWindow(rect: NSRect) {
        let contentView = ContentView()
            .environmentObject(countdownManager)
            .environmentObject(aiService)
            .environmentObject(storageManager)

        window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window?.title = "Near 倒计时"
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        
        // Refinement: Fixed window, not draggable
        window?.isMovableByWindowBackground = false
        
        window?.hasShadow = true
        window?.level = .floating
        window?.delegate = self
        window?.contentView = NSHostingView(rootView: contentView)

        // 添加点击外部隐藏功能
        window?.acceptsMouseMovedEvents = true

        // 设置全局事件监听器来检测点击外部
        setupGlobalEventMonitor()
    }

    private func setupGlobalEventMonitor() {
        // 清理之前的监听器
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // 监听全局鼠标点击事件
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isWindowVisible else { return }

            // 获取点击位置
            let clickLocation = event.locationInWindow

            // 检查点击是否在窗口外部
            if let window = self.window {
                let windowFrame = window.frame
                let screenClickLocation = NSPoint(
                    x: clickLocation.x,
                    y: NSScreen.main?.frame.height ?? 0 - clickLocation.y
                )

                if !windowFrame.contains(screenClickLocation) {
                    // 点击在窗口外部，隐藏窗口
                    DispatchQueue.main.async {
                        self.hideWindow()
                    }
                }
            }
        }
    }

    private func updateStatusBarTitle() {
        guard let button = statusItem.button else { return }

        if let topText = countdownManager.getTopCountdownText() {
            button.title = topText
            button.imagePosition = .noImage
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            self.updateAnimationFrame()
        }
    }

    private func updateAnimation() {
        let elapsed = Date().timeIntervalSince(lastFrameTime)
        if elapsed > 2.0 {
            lastFrameTime = Date()
            let cpuUsage = systemMonitor.cpuUsage
            let fpsValue = 15 + (cpuUsage * 45 / 100)
            currentFPS = max(15, min(60, Int(fpsValue)))
        }
    }

    private func updateAnimationFrame() {
        let elapsed = Date().timeIntervalSince1970 * 1000
        let frameInterval = 1000 / Double(currentFPS)
        currentFrame = Int((elapsed / frameInterval).truncatingRemainder(dividingBy: 32))

        // 创建风车动画图标
        if let button = statusItem.button {
            let cpuUsage = systemMonitor.cpuUsage

            // 根据CPU使用率创建不同颜色的风车图标
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)

            if cpuUsage > 50 {
                // 高CPU使用率时使用红色警告图标
                if let image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "High CPU Usage") {
                    button.image = image.withSymbolConfiguration(config)
                }
            } else {
                // 正常状态显示风车动画
                let windmillConfig = NSImage.SymbolConfiguration(hierarchicalColor: NSColor(hex: "#6366F1"))
                if let image = NSImage(systemSymbolName: "wind", accessibilityDescription: "CPU Windmill") {
                    button.image = image.withSymbolConfiguration(windmillConfig)
                }
            }
        }
    }
}

extension StatusBarManager: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        // 窗口获得焦点时的处理
        print("Window became key")
    }

    func windowDidResignKey(_ notification: Notification) {
        // 窗口失去焦点时，延迟隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.hideWindow()
        }
    }
}