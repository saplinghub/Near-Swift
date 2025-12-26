import Foundation
import AppKit
import Combine

class PowerStateManager: ObservableObject {
    static let shared = PowerStateManager()
    
    @Published var isIdle: Bool = false
    @Published var isSystemSleeping: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var simulationTimer: Timer?
    
    private init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        let workspace = NSWorkspace.shared.notificationCenter
        
        // 1. 系统睡眠/唤醒
        workspace.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in self?.setSystemSleeping(true) }
            .store(in: &cancellables)
            
        workspace.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in 
                self?.setSystemSleeping(false)
                self?.setIdle(false, reason: "System Wakeup")
            }
            .store(in: &cancellables)
            
        // 2. 显示器睡眠/唤醒
        workspace.publisher(for: NSWorkspace.screensDidSleepNotification)
            .sink { [weak self] _ in self?.setIdle(true, reason: "Display Asleep") }
            .store(in: &cancellables)
            
        workspace.publisher(for: NSWorkspace.screensDidWakeNotification)
            .sink { [weak self] _ in self?.setIdle(false, reason: "Display Waked") }
            .store(in: &cancellables)
            
        // 3. 屏幕锁定/解锁
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setIdle(true, reason: "Screen Locked")
        }
        
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setIdle(false, reason: "Screen Unlocked")
        }
    }
    
    func simulateIdle(duration: TimeInterval = 10.0) {
        LogManager.shared.append("[POWER] Simulating Idle State for \(duration)s")
        setIdle(true, reason: "Test Simulation")
        
        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.setIdle(false, reason: "Test Finished")
        }
    }
    
    private func setSystemSleeping(_ sleeping: Bool) {
        isSystemSleeping = sleeping
        if sleeping {
            setIdle(true, reason: "System Sleep")
        }
    }
    
    private func setIdle(_ idle: Bool, reason: String) {
        // 如果系统正在休眠，且试图因为其他原因解除闲置，需拦截逻辑（除非是系统唤醒本身）
        if !idle && isSystemSleeping && reason != "System Wakeup" && reason != "Test Finished" {
            return
        }
        
        guard isIdle != idle else { return }
        
        DispatchQueue.main.async {
            self.isIdle = idle
            let status = idle ? "ENTERED" : "EXITED"
            LogManager.shared.append("[POWER] System \(status) Idle State (\(reason))")
            
            // 发送系统通知供非 Combine 组件监听
            NotificationCenter.default.post(name: NSNotification.Name("PowerStateChanged"), object: nil, userInfo: ["isIdle": idle])
        }
    }
}
