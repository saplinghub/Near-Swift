import Foundation

enum IconType: String, CaseIterable, Codable {
    case rocket = "rocket"
    case palm = "palm"
    case headphones = "headphones"
    case code = "code"
    case gift = "gift"

    var sfSymbol: String {
        switch self {
        case .rocket:
            return "rocket"
        case .palm:
            return "palm.tree.fill"
        case .headphones:
            return "headphones"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .gift:
            return "gift.fill"
        }
    }

    var color: String {
        switch self {
        case .rocket:
            return "#6366F1"  // 与Tauri版本一致
        case .palm:
            return "#10B981"  // 与Tauri版本一致
        case .headphones:
            return "#8B5CF6"  // 与Tauri版本一致
        case .code:
            return "#0EA5E9"  // 与Tauri版本一致
        case .gift:
            return "#F43F5E"  // 与Tauri版本一致
        }
    }

    var backgroundColor: String {
        switch self {
        case .rocket:
            return "#EEF2FF"
        case .palm:
            return "#ECFDF5"
        case .headphones:
            return "#FDF4FF"
        case .code:
            return "#F0F9FF"
        case .gift:
            return "#FFF1F2"
        }
    }
}