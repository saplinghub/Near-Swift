import SwiftUI

@main
struct NearCountdownApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarManager: StatusBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("=== App Launching ===")
        Logger.shared.log("Log path: \(Logger.shared.getLogPath())")
        
        NSApp.setActivationPolicy(.accessory)

        Logger.shared.log("Initializing storage and managers...")
        let storageManager = StorageManager()
        let countdownManager = CountdownManager() 
        let aiService = AIService(storageManager: storageManager)
        let systemMonitor = SystemMonitor()

        Logger.shared.log("Setting up StatusBarManager...")
        statusBarManager = StatusBarManager(
            countdownManager: countdownManager,
            aiService: aiService,
            storageManager: storageManager,
            systemMonitor: systemMonitor
        )

        // 启动桌宠
        Logger.shared.log("Enabling/Disabling pet based on settings...")
        PetManager.shared.model.isEnabled = storageManager.isPetEnabled
        if storageManager.isPetEnabled {
            Logger.shared.log("Showing Pet...")
            PetManager.shared.showPet()
        }

        Logger.shared.log("=== App Launch Completed ===")
    }
}