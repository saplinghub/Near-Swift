import Foundation

struct CountdownEvent: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var startDate: Date
    var targetDate: Date
    var icon: IconType
    var isPinned: Bool
    var order: Int

    init(id: UUID = UUID(), name: String, startDate: Date, targetDate: Date, icon: IconType, isPinned: Bool = false, order: Int = 0) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.targetDate = targetDate
        self.icon = icon
        self.isPinned = isPinned
        self.order = order
    }

    var isCompleted: Bool {
        targetDate <= Date()
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day ?? 0
    }

    var hoursRemaining: Int {
        let components = Calendar.current.dateComponents([.hour], from: Date(), to: targetDate)
        return components.hour ?? 0
    }

    var minutesRemaining: Int {
        let components = Calendar.current.dateComponents([.minute], from: Date(), to: targetDate)
        return components.minute ?? 0
    }

    var progress: Double {
        let totalDuration = targetDate.timeIntervalSince(startDate)
        let elapsedDuration = Date().timeIntervalSince(startDate)
        return max(0, min(1, elapsedDuration / totalDuration))
    }

    var timeRemainingString: String {
        if isCompleted {
            return "已结束"
        }

        let days = daysRemaining
        let hours = hoursRemaining
        let minutes = minutesRemaining

        if days > 0 {
            return "\(days)天"
        } else if hours > 0 {
            return "\(hours)小时"
        } else {
            return "\(minutes)分钟"
        }
    }

    var totalDays: Int {
        let components = Calendar.current.dateComponents([.day], from: startDate, to: targetDate)
        // 包含起始天和结束天，通常习惯 +1
        return (components.day ?? 0) + 1
    }

    var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: startDate)) ~ \(formatter.string(from: targetDate))"
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: targetDate)
    }

    static func createDefault() -> CountdownEvent {
        CountdownEvent(
            id: UUID(),
            name: "新倒计时",
            startDate: Date(),
            targetDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            icon: .star,
            isPinned: false,
            order: 0
        )
    }

    var uuidString: String {
        id.uuidString
    }
}