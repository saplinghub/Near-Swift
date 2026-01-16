import Foundation

class Logger {
    static let shared = Logger()
    private let logFileURL: URL?
    
    private init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentDirectory = urls.first {
            let logDir = documentDirectory.appendingPathComponent("NearLogs", isDirectory: true)
            try? fileManager.createDirectory(at: logDir, withIntermediateDirectories: true)
            logFileURL = logDir.appendingPathComponent("launch.log")
        } else {
            logFileURL = nil
        }
    }
    
    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"
        
        print(logMessage, terminator: "")
        
        guard let url = logFileURL else { return }
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.synchronize() // 关键：确保物理写入磁盘
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    
    func getLogPath() -> String {
        return logFileURL?.path ?? "Unknown"
    }
}
