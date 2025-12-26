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
    @Published var opacity: Double = PetConfig.defaultOpacity
    
    @Published var mood: Double = 1.0 // 0.0 ~ 1.0
    
    /// 当前气泡附带的交互动作
    @Published var actions: [PetAction] = []
    
    /// 是否处于贴边缩起状态
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
    @Published var isMessageVisible: Bool = false
    
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
