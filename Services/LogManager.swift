import Foundation
import Combine

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logs: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    private var logDirectory: URL {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = urls.first!.appendingPathComponent("Near-Swift")
        let dir = appSupportDir.appendingPathComponent("Logs")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private init() {
        cleanupOldLogs()
    }
    
    func append(_ message: String) {
        let timestamp = SharedUtils.dateFormatter(format: "yyyy-MM-dd HH:mm:ss.SSS").string(from: Date())
        let newEntry = "[\(timestamp)] \(message)\n"
        
        // 1. Memory Log (Debug UI) - Keep only last 100 lines
        DispatchQueue.main.async {
            let currentLogs = self.logs.components(separatedBy: .newlines).filter { !$0.isEmpty }
            var updatedLogs = currentLogs
            updatedLogs.append(newEntry.trimmingCharacters(in: .newlines))
            
            if updatedLogs.count > 100 {
                updatedLogs = Array(updatedLogs.suffix(100))
            }
            self.logs = updatedLogs.joined(separator: "\n") + "\n"
        }
        
        // 2. Console Print
        #if DEBUG
        print(newEntry.trimmingCharacters(in: .newlines))
        #endif
        
        // 3. File Log
        logToFile(newEntry)
    }
    
    private func logToFile(_ entry: String) {
        let fileName = "\(SharedUtils.dateFormatter(format: "yyyy-MM-dd").string(from: Date())).log"
        let fileURL = logDirectory.appendingPathComponent(fileName)
        
        if let data = entry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.synchronize() // 关键：确保物理落盘
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
    
    private func cleanupOldLogs() {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        
        for file in files where file.pathExtension == "log" {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let creationDate = attrs[.creationDate] as? Date {
                if creationDate < sevenDaysAgo {
                    try? FileManager.default.removeItem(at: file)
                    print("[LOG] Cleaned up old log file: \(file.lastPathComponent)")
                }
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
