import Foundation

/// 共享性能工具类：复用高开销的格式化器与日历实例，避免 ICU 库频繁重载。
enum SharedUtils {
    static let calendar: Calendar = {
        var cal = Calendar.current
        return cal
    }()
    
    private static var formatters: [String: DateFormatter] = [:]
    private static let lock = NSLock()
    
    // 全局时间缓存：避免在同一秒/同一渲染循环内多次创建 Date() 或计算组件
    private static var lastNow: Date = Date()
    private static var lastMinuteKey: String = ""
    
    /// 获取当前的“快照时间”，在同一极短时间内多次调用将返回相同实例，减少 Date() 内存分配
    static var now: Date {
        lock.lock()
        defer { lock.unlock() }
        let current = Date()
        // 如果间隔小于 0.1s，视为同一帧/循环，复用旧实例 (极致性能)
        if current.timeIntervalSince(lastNow) < 0.1 {
            return lastNow
        }
        lastNow = current
        return current
    }
    
    /// 获取分钟级别的缓存 Key，用于缓存那些按分钟更新的字符串
    static var minuteKey: String {
        lock.lock()
        defer { lock.unlock() }
        let currentNow = now
        let minute = calendar.component(.minute, from: currentNow)
        let hour = calendar.component(.hour, from: currentNow)
        let day = calendar.component(.day, from: currentNow)
        let key = "\(day)-\(hour)-\(minute)"
        
        if key != lastMinuteKey {
            lastMinuteKey = key
        }
        return key
    }
    
    /// 获取指定格式的 DateFormatter，自动复用缓存实例
    static func dateFormatter(format: String) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }
        
        if let existing = formatters[format] {
            return existing
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatters[format] = formatter
        return formatter
    }
}
