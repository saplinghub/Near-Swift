import Foundation
import SwiftUI
import Combine

/// 健康行为日志条目
struct HealthLog: Codable {
    let type: String // "water", "stand"
    let timestamp: Date
}

/// 健康助手管理服务
class HealthManager: ObservableObject {
    static let shared = HealthManager()
    
    private let fileManager = FileManager.default
    private var healthDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Near/HealthLogs")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private var currentLogFile: URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return healthDirectory.appendingPathComponent("\(formatter.string(from: Date())).json")
    }
    
    @Published var waterCount: Int = 0
    @Published var standCount: Int = 0
    
    private init() {
        loadTodayStats()
    }
    
    /// 加载今日统计数据
    func loadTodayStats() {
        guard let data = try? Data(contentsOf: currentLogFile),
              let logs = try? JSONDecoder().decode([HealthLog].self, from: data) else {
            waterCount = 0
            standCount = 0
            return
        }
        waterCount = logs.filter { $0.type == "water" }.count
        standCount = logs.filter { $0.type == "stand" }.count
    }
    
    /// 记录健康行为
    func recordActivity(type: String) {
        var logs = loadLogs()
        logs.append(HealthLog(type: type, timestamp: Date()))
        saveLogs(logs)
        
        // 更新内存状态
        if type == "water" {
            waterCount += 1
        } else if type == "stand" {
            standCount += 1
        }
    }
    
    private func loadLogs() -> [HealthLog] {
        guard let data = try? Data(contentsOf: currentLogFile),
              let logs = try? JSONDecoder().decode([HealthLog].self, from: data) else {
            return []
        }
        return logs
    }
    
    private func saveLogs(_ logs: [HealthLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            try? data.write(to: currentLogFile)
        }
    }
    
    /// 生成今日简报
    func generateDailySummary() -> String {
        if waterCount == 0 && standCount == 0 {
            return "主人今天似乎太忙了，还没记录任何健康行为哦，记得多喝水、常站立呀！"
        }
        
        let waterMsg = waterCount >= 8 ? "达成了 8 杯水的全满成就！" : "喝了 \(waterCount) 杯水，继续加油~"
        let standMsg = standCount >= 5 ? "站立拉伸了 \(standCount) 次，身体很棒棒！" : "站立了 \(standCount) 次，要记得动一动哦。"
        
        return "✨ 今日健康简报：\n主人今天\(waterMsg)\n\(standMsg)\n明天也要元气满满哦！"
    }
    
    /// 保留所有健康日志（不再自动清理）
    func cleanupOldLogs() {
        // 健康数据价值较高，默认永久保留，不再执行删除操作
    }
}
