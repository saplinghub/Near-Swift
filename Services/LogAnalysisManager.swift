import Foundation
import SwiftUI
import Combine

/// 日志分析元数据
struct LogMeta: Codable {
    var isAnalyzed: Bool = false
    var analysisResult: String?
    var analysisDate: Date?
}

/// 日志分析管理器
class LogAnalysisManager: ObservableObject {
    static let shared = LogAnalysisManager()
    
    private let fileManager = FileManager.default
    private var interactionDir: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Near/InteractionLogs")
    }
    private var healthDir: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Near/HealthLogs")
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// 获取未解析的日志列表
    func getUnanalyzedLogs() -> [URL] {
        var unanalyzed: [URL] = []
        let dirs = [interactionDir, healthDir]
        
        for dir in dirs {
            guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            let logFiles = files.filter { $0.pathExtension == "log" || $0.pathExtension == "json" }
            
            for logFile in logFiles {
                let metaURL = logFile.appendingPathExtension("meta")
                if !fileManager.fileExists(atPath: metaURL.path) {
                    unanalyzed.append(logFile)
                } else {
                    if let data = try? Data(contentsOf: metaURL),
                       let meta = try? JSONDecoder().decode(LogMeta.self, from: data),
                       !meta.isAnalyzed {
                        unanalyzed.append(logFile)
                    }
                }
            }
        }
        return unanalyzed
    }
    
    /// 执行 AI 分析并持久化结果
    func analyzeLog(_ url: URL, aiService: AIService) -> AnyPublisher<String, Error> {
        let metaURL = url.appendingPathExtension("meta")
        let content = (try? String(contentsOf: url)) ?? ""
        let logType = url.path.contains("HealthLogs") ? "健康助手" : "操作感知"
        
        return aiService.analyzeLogs(content: content, logType: logType)
            .handleEvents(receiveOutput: { result in
                let meta = LogMeta(isAnalyzed: true, analysisResult: result, analysisDate: Date())
                if let data = try? JSONEncoder().encode(meta) {
                    try? data.write(to: metaURL)
                }
            })
            .eraseToAnyPublisher()
    }
}
