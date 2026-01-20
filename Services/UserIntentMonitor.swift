import Foundation
import AppKit
import Combine

class UserIntentMonitor: ObservableObject {
    static let shared = UserIntentMonitor()
    
    @Published var activeApp: String = ""
    @Published var inputFrequency: Int = 0 // 每分钟点击/按键次数
    @Published var isAccessibilityGranted: Bool = false
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: Timer?
    private var counter: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
    // 操作记录日志
    private let logDirectory: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        logDirectory = appSupport.appendingPathComponent("Near/InteractionLogs")
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        checkAccessibility()
        setupAppLevelMonitor()
        startPeriodicCleanup()
    }
    
    func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if isAccessibilityGranted {
            setupEventTap()
        }
    }
    
    private func setupAppLevelMonitor() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.activeApp = app.localizedName ?? "Unknown"
                self?.recordLog(event: "Activated App: \(self?.activeApp ?? "")")
            }
        }
    }
    
    private func setupEventTap() {
        guard eventTap == nil else { return }
        
        let eventMask = (1 << NX_KEYDOWN) | (1 << NX_LMOUSEDOWN) | (1 << NX_RMOUSEDOWN)
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) in
            if let ptr = refcon {
                // 暂时不去记录 inputFrequency 的值
                // let mySelf = Unmanaged<UserIntentMonitor>.fromOpaque(ptr).takeUnretainedValue()
                // mySelf.counter += 1
            }
            return Unmanaged.passRetained(event)
        }
        
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                   place: .headInsertEventTap,
                                   options: .defaultTap,
                                   eventsOfInterest: CGEventMask(eventMask),
                                   callback: callback,
                                   userInfo: refcon)
        
        if let tap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let source = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        
        // 仅在初始启动记录一次，不再每分钟刷新 Timer
        // 改为按需查询或由上层触发清理
    }
    
    /// 由 PetManager 在意图检查周期调用，用于结算频率并重置
    func flushInputFrequency() -> Int {
        let current = counter
        self.inputFrequency = current
        if current > 0 {
            self.recordLog(event: "Input Frequency Settle: \(current) in period")
        }
        self.counter = 0
        return current
    }
    
    private func recordLog(event: String) {
        let date = SharedUtils.now
        let timestamp = SharedUtils.dateFormatter(format: "yyyy-MM-dd HH:mm:ss").string(from: date)
        let logEntry = "[\(timestamp)] \(event)\n"
        
        let fileName = "\(SharedUtils.dateFormatter(format: "yyyy-MM-dd").string(from: date)).log"
        let fileURL = logDirectory.appendingPathComponent(fileName)
        
        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
    
    private func startPeriodicCleanup() {
        // 每小时检查一次，清理 24 小时前的日志
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.cleanupOldLogs()
        }
    }
    
    private func cleanupOldLogs() {
        let now = Date()
        let thirtyDaysAgo = now.addingTimeInterval(-86400 * 30)
        
        let files = try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey], options: [])
        files?.forEach { url in
            if let attr = try? url.resourceValues(forKeys: [.creationDateKey]),
               let creationDate = attr.creationDate,
               creationDate < thirtyDaysAgo {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// 打开存放日志的文件夹
    func openLogFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logDirectory.path)
    }
}
