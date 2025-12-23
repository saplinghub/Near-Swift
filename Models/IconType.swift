import Foundation

enum IconType: String, CaseIterable, Codable {
    case star = "star" // Replaced rocket
    case leaf = "leaf" // Replaced palm
    case headphones = "headphones"
    case code = "code"
    case gift = "gift"
    case birthday = "birthday"
    case travel = "travel"
    case work = "work"
    case anniversary = "anniversary"
    case game = "game"
    case sports = "sports"
    case study = "study"
    case shopping = "shopping"

    var sfSymbol: String {
        switch self {
        case .star: return "star.fill"
        case .leaf: return "leaf.fill"
        case .headphones: return "headphones"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .gift: return "gift.fill"
        case .birthday: return "birthday.cake.fill"
        case .travel: return "airplane"
        case .work: return "briefcase.fill"
        case .anniversary: return "heart.fill"
        case .game: return "gamecontroller.fill"
        case .sports: return "sportscourt.fill"
        case .study: return "book.fill"
        case .shopping: return "cart.fill"
        }
    }

    var color: String {
        switch self {
        case .star: return "#F59E0B" // Amber
        case .leaf: return "#10B981" // Emerald
        case .headphones: return "#8B5CF6"
        case .code: return "#0EA5E9"
        case .gift: return "#F43F5E"
        case .birthday: return "#EC4899"
        case .travel: return "#3B82F6"
        case .work: return "#64748B"
        case .anniversary: return "#EF4444"
        case .game: return "#8B5CF6"
        case .sports: return "#F59E0B"
        case .study: return "#10B981"
        case .shopping: return "#F97316"
        }
    }

    var backgroundColor: String {
        switch self {
        case .star: return "#FFFBEB"
        case .leaf: return "#ECFDF5"
        case .headphones: return "#FDF4FF"
        case .code: return "#F0F9FF"
        case .gift: return "#FFF1F2"
        case .birthday: return "#FDF2F8"
        case .travel: return "#EFF6FF"
        case .work: return "#F1F5F9"
        case .anniversary: return "#FEF2F2"
        case .game: return "#F5F3FF"
        case .sports: return "#FFFBEB"
        case .study: return "#ECFDF5"
        case .shopping: return "#FFF7ED"
        }
    }
}