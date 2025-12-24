import Foundation
import Combine

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: String = ""
    
    private let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
    
    private init() {}
    
    func append(_ message: String) {
        let timestamp = formatter.string(from: Date())
        let newEntry = "[\(timestamp)] \(message)\n"
        DispatchQueue.main.async {
            self.logs += newEntry
            // Limit log size to prevent memory issues
            if self.logs.count > 100000 {
                self.logs = String(self.logs.suffix(50000))
            }
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs = ""
        }
    }
    
    func export() -> String {
        return logs
    }
}
