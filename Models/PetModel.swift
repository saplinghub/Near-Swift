import Foundation
import SwiftUI

/// 宠物的行为状态
enum PetState: String, Codable {
    case idle      // 闲置
    case walking   // 自由行走中
    case interacting // 交互中
    case docked    // 贴边缩起中
}

/// 吸附边缘
enum DockEdge {
    case none, left, right, top, bottom
}

/// 消息类型映射
enum PetMessageType: String, Codable {
    case system, health, power, fun, weather
    
    var displayName: String {
        switch self {
        case .system: return "系统状态"
        case .health: return "健康提醒"
        case .power: return "能源状态"
        case .fun: return "日常互动"
        case .weather: return "天气提醒"
        }
    }
    
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

/// 气泡动作指令
struct PetAction: Identifiable {
    let id: String
    let title: String
    let color: Color
    var action: (() -> Void)?
}

/// 宠物配置
struct PetConfig {
    static let defaultSize: CGFloat = 120
    static let minOpacity: Double = 0.3
    static let defaultOpacity: Double = 1.0
}

/// 宠物数据模型
class PetModel: ObservableObject {
    @Published var state: PetState = .idle
    @Published var position: CGPoint = .zero
    @Published var isVisible: Bool = true
    @Published var isEnabled: Bool = true // 主开关：控制桌宠是否启用
    @Published var opacity: Double = PetConfig.defaultOpacity
    
    @Published var mood: Double = 1.0 // 0.0 ~ 1.0
    
    /// 当前气泡附带的交互动作
    @Published var actions: [PetAction] = []
    
    /// 是否处于贴边缩起状态
    @Published var isIdle: Bool = false
    @Published var isDocked: Bool = false
    @Published var dockEdge: DockEdge = .none
    
    // 自我意识、系统感知与意图感知开关
    @Published var isSelfAwarenessEnabled: Bool = true
    @Published var isSystemAwarenessEnabled: Bool = true
    @Published var isIntentAwarenessEnabled: Bool = true
    @Published var isHealthReminderEnabled: Bool = true
    
    // 系统状态映射
    enum LoadLevel: String {
        case low, medium, high
    }
    @Published var cpuLoadLevel: LoadLevel = .low
    var lastSystemQuoteTime: Date = .distantPast
    
    // 消息管理
    @Published var messageId: UUID = UUID()
    @Published var message: String = ""
    @Published var messageType: PetMessageType = .fun
    @Published var isMessageVisible: Bool = false
    
    /// 是否正处于动画活跃状态（气泡显示或拖拽时）
    @Published var isAnimating: Bool = false
    
    // 自由移动目标
    var walkTarget: CGPoint?
    var lastWalkTime: Date = .distantPast
    
    /// 上一次在屏幕内的安全位置
    var lastSafePosition: CGPoint = .zero
    
    // 用于粉碎效果的旧消息记录
    var oldMessage: String = ""
    var oldMessageId: UUID?
    
    /// 上一次触发回弹的时间（用于防震荡）
    var lastRecoveryTime: Date = .distantPast
}
