import Cocoa
import SwiftUI
import Combine

class StatusBarManager: NSObject, NSWindowDelegate {
    private var statusItem: NSStatusItem
    private var window: NSWindow?
    private var countdownManager: CountdownManager
    private var aiService: AIService
    private var storageManager: StorageManager
    private var eventMonitor: Any?
    private var isWindowVisible = false
    
    // Animation
    private var fanFrames: [NSImage] = []
    private var currentFrameIndex = 0
    private var animationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(countdownManager: CountdownManager, aiService: AIService, storageManager: StorageManager) {
        self.countdownManager = countdownManager
        self.aiService = aiService
        self.storageManager = storageManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        super.init()
        
        setupStatusItem()
        loadFanFrames()
        startAnimation()
        setupBindings()
        
        // Show window on launch (Visibility Fix)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showWindow()
        }
    }
    
    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(named: "NearIcon") ?? NSImage(systemSymbolName: "fanblades", accessibilityDescription: "Fan")
            button.action = #selector(toggleWindow)
            button.target = self
            button.imagePosition = .imageLeft
        }
    }
    
    private func loadFanFrames() {
        // Load frames fan_00.png to fan_31.png from strictly Resources/icons/fan_frames
        for i in 0...31 {
            let frameName = String(format: "fan_%02d", i)
            
            // Try explicit path in Resources/icons/fan_frames
            if let path = Bundle.main.path(forResource: frameName, ofType: "png", inDirectory: "icons/fan_frames") {
                if let image = NSImage(contentsOfFile: path) {
                    image.isTemplate = true // Adapt to dark/light mode
                    image.size = NSSize(width: 18, height: 18) // Ensure correct size
                    fanFrames.append(image)
                }
            } else {
                print("Warning: Could not find frame \(frameName)")
            }
        }
        print("Loaded \(fanFrames.count) fan frames")
    }
    
    private func startAnimation() {
        guard !fanFrames.isEmpty else { return }
        
        // 30 FPS animation
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            self?.updateFrame()
        }
    }
    
    private func updateFrame() {
        guard !fanFrames.isEmpty, let button = statusItem.button else { return }
        
        currentFrameIndex = (currentFrameIndex + 1) % fanFrames.count
        button.image = fanFrames[currentFrameIndex]
    }
    
    private func setupBindings() {
        // Observe changes to countdowns to update title
        // Since activeCountdowns is @Published in CountdownManager
        countdownManager.objectWillChange
            .sink { [weak self] _ in
                // Delay slightly to let update happen
                DispatchQueue.main.async {
                    self?.updatePinnedTitle()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updatePinnedTitle() {
        guard let button = statusItem.button else { return }
        
        // Find first pinned countdown
        // Prioritize active, then completed? Usually only active matters for "days remaining" usage.
        if let pinned = countdownManager.pinnedCountdown {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: pinned.targetDate).day ?? 0
            // Format: " 5天"
            // Just simple "X天" as per Tauri
            button.title = " \(days)天" 
        } else {
            button.title = ""
        }
    }

    @objc func toggleWindow() {
        if isWindowVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    func showWindow() {
        let windowWidth: CGFloat = 380
        let windowHeight: CGFloat = 600

        if window == nil {
            createWindow(rect: NSRect.zero)
        }

        // Recalculate position every time to ensure alignment
        if let statusButton = statusItem.button {
            let statusRect = statusButton.window?.frame ?? statusButton.frame
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            
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
        NSApp.activate(ignoringOtherApps: true) // Important for focus
        window?.orderFront(nil)
        isWindowVisible = true
        
        setupEventMonitor()
    }

    func hideWindow() {
        window?.orderOut(nil)
        isWindowVisible = false
        stopEventMonitor()
    }

    private func createWindow(rect: NSRect) {
        let contentView = ContentView()
            .environmentObject(countdownManager)
            .environmentObject(aiService)
            .environmentObject(storageManager)

        let hostingController = NSHostingController(rootView: contentView)
        
        let newWindow = CustomWindow(
            contentRect: rect,
            styleMask: [.borderless], // No title bar
            backing: .buffered,
            defer: false
        )
        
        newWindow.contentViewController = hostingController
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.title = "Near 倒计时"
        newWindow.isMovableByWindowBackground = false
        newWindow.hasShadow = true
        newWindow.level = .floating
        newWindow.delegate = self
        
        self.window = newWindow
    }
    
    // MARK: - Auto Hide Logic
    
    private func setupEventMonitor() {
        if eventMonitor != nil { return }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hideWindow()
        }
    }
    
    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    // Auto-hide on focus loss
    func windowDidResignKey(_ notification: Notification) {
        hideWindow()
    }
}

class CustomWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}