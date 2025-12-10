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
        print("AppDelegate.applicationDidFinishLaunching called")
        NSApp.setActivationPolicy(.accessory)

        let countdownManager = CountdownManager()
        let aiService = AIService()
        let storageManager = StorageManager()

        statusBarManager = StatusBarManager(
            countdownManager: countdownManager,
            aiService: aiService,
            storageManager: storageManager
        )

        print("AppDelegate setup completed")
    }
}