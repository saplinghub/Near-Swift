import Foundation

enum SortMode: String, Codable, CaseIterable {
    case manual = "手动"
    case timeAsc = "时间最近"
    case timeDesc = "时间最远"
}

struct CountdownEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var startDate: Date {
        didSet { updateStaticStrings() }
    }
    var targetDate: Date {
        didSet { updateStaticStrings() }
    }
    var icon: IconType
    var isPinned: Bool
    var order: Int
    var isNotified: Bool
    
    // 存储属性以避免在 body 中重复执行昂贵的 DateFormatter (ICU) 计算
    private(set) var dateString: String = ""
    private(set) var dateRangeString: String = ""

    init(id: UUID = UUID(), name: String, startDate: Date, targetDate: Date, icon: IconType, isPinned: Bool = false, order: Int = 0, isNotified: Bool = false) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.targetDate = targetDate
        self.icon = icon
        self.isPinned = isPinned
        self.order = order
        self.isNotified = false
        updateStaticStrings()
    }
    
    // 自定义解码以初始化存储属性
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDate = try container.decode(Date.self, forKey: .startDate)
        targetDate = try container.decode(Date.self, forKey: .targetDate)
        icon = try container.decode(IconType.self, forKey: .icon)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        order = try container.decode(Int.self, forKey: .order)
        isNotified = try container.decodeIfPresent(Bool.self, forKey: .isNotified) ?? false
        updateStaticStrings()
    }

    private mutating func updateStaticStrings() {
        self.dateString = SharedUtils.dateFormatter(format: "yyyy-MM-dd").string(from: targetDate)
        let formatter = SharedUtils.dateFormatter(format: "M月d日")
        self.dateRangeString = "\(formatter.string(from: startDate)) ~ \(formatter.string(from: targetDate))"
    }

    var isCompleted: Bool {
        targetDate <= SharedUtils.now
    }

    var daysRemaining: Int {
        SharedUtils.calendar.dateComponents([.day], from: SharedUtils.now, to: targetDate).day ?? 0
    }

    var hoursRemaining: Int {
        let components = SharedUtils.calendar.dateComponents([.hour], from: SharedUtils.now, to: targetDate)
        return components.hour ?? 0
    }

    var minutesRemaining: Int {
        let components = SharedUtils.calendar.dateComponents([.minute], from: SharedUtils.now, to: targetDate)
        return components.minute ?? 0
    }

    var progress: Double {
        let totalDuration = targetDate.timeIntervalSince(startDate)
        let elapsedDuration = SharedUtils.now.timeIntervalSince(startDate)
        return max(0, min(1, elapsedDuration / totalDuration))
    }

    var timeRemainingString: String {
        if isCompleted {
            return "已结束"
        }

        let days = daysRemaining
        if days > 0 {
            return "\(days)天"
        } else {
            let hours = hoursRemaining
            if hours > 0 {
                return "\(hours)小时"
            } else {
                return "\(minutesRemaining)分钟"
            }
        }
    }

    var totalDays: Int {
        let components = SharedUtils.calendar.dateComponents([.day], from: startDate, to: targetDate)
        // 包含起始天和结束天，通常习惯 +1
        return (components.day ?? 0) + 1
    }

    static func createDefault() -> CountdownEvent {
        CountdownEvent(
            id: UUID(),
            name: "新倒计时",
            startDate: Date(),
            targetDate: SharedUtils.calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            icon: .star,
            isPinned: false,
            order: 0,
            isNotified: false
        )
    }

    var uuidString: String {
        id.uuidString
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, startDate, targetDate, icon, isPinned, order, isNotified
    }
}