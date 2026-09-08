import SwiftUI

// MARK: - 气泡消息类型（中文风格，沿用现有 PetMessageType 的展示）
enum PetMessageType: String, Codable {
    case system = "系统状态"
    case health = "健康提醒"
    case power = "能源状态"
    case fun = "日常互动"
    case weather = "天气提醒"

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .system: return "cpu"
        case .health: return "heart.fill"
        case .power: return "bolt.fill"
        case .fun: return "face.smiling"
        case .weather: return "cloud.sun.fill"
        }
    }
}

/// 任务/消息气泡的“状态驱动动画”
enum BubbleStatus: String, Codable {
    case waiting = "待命"
    case working = "进行中"
    case review = "待评审"
    case done = "完成"
    case failed = "失败"
    case info = "信息"

    var semantic: PetAnimSemantic {
        switch self {
        case .waiting: return .waiting
        case .working: return .working
        case .review: return .review
        case .done: return .success
        case .failed: return .failure
        case .info: return .speaking
        }
    }
}

/// 气泡动作按钮
struct PetAction: Identifiable {
    let id: String
    let title: String
    let color: Color
    var action: (() -> Void)?
}

/// 一条气泡（threadId 用于原地更新同一任务）
struct PetBubble: Identifiable, Equatable {
    let id = UUID()
    let threadId: String
    var text: String
    var type: PetMessageType
    var status: BubbleStatus
    var actions: [PetAction]
    var createdAt: Date = Date()

    static func == (lhs: PetBubble, rhs: PetBubble) -> Bool {
        lhs.threadId == rhs.threadId && lhs.text == rhs.text
    }
}

// MARK: - 便捷扩展
extension String {
    /// 空白/空串 → nil，方便“空则用默认”链式
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
