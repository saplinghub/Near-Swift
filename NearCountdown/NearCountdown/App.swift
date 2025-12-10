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

        let storageManager = StorageManager()
        // Note: CountdownManager creates its own StorageManager instance internally. 
        // Ideally we should inject it, but for now we won't touch CountdownManager constructor 
        // to avoid cascading changes unless needed.
        let countdownManager = CountdownManager() 
        let aiService = AIService(storageManager: storageManager)

        statusBarManager = StatusBarManager(
            countdownManager: countdownManager,
            aiService: aiService,
            storageManager: storageManager
        )

        print("AppDelegate setup completed")
    }
}