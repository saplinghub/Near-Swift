import Foundation

class Logger {
    static let shared = Logger()
    
    private init() {}
    
    func log(_ message: String) {
        LogManager.shared.append(message)
    }
    
    func getLogPath() -> String {
        return "LogManager managed"
    }
}
