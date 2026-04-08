import Foundation
import SwiftUI
import Combine

/// 通知类型定义
enum NearNotificationType: String, Codable {
    case system    // 系统状态
    case health    // 健康提醒
    case power     // 能源状态
    case fun       // 日常互动
    case weather   // 天气提醒
    case countdown // 倒计时提醒

    /// 优先级：数值越小优先级越高
    var priority: Int {
        switch self {
        case .power: return 0      // 电源状态最高
        case .health: return 1     // 健康提醒次之
        case .weather: return 2    // 天气提醒
        case .countdown: return 3  // 倒计时
        case .system: return 4     // 系统状态
        case .fun: return 5        // 日常互动最低
        }
    }
}

/// 发送方反馈
struct NearNotificationAction: Identifiable {
    let id: String
    let title: String
    let color: Color
    var action: (() -> Void)?
}

/// 通用通知模型
struct NearNotification: Identifiable {
    let id: UUID = UUID()
    let message: String
    let type: NearNotificationType
    let actions: [NearNotificationAction]
    let autoDismissDelay: TimeInterval?
    let callback: ((String) -> Void)?

    init(
        message: String,
        type: NearNotificationType = .fun,
        actions: [NearNotificationAction] = [],
        autoDismissDelay: TimeInterval? = 5.0,
        callback: ((String) -> Void)? = nil
    ) {
        self.message = message
        self.type = type
        self.actions = actions
        self.autoDismissDelay = autoDismissDelay
        self.callback = callback
    }
}

/// 通知管理中心：直接显示通知，高优先级可打断低优先级
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var currentNotification: NearNotification?

    private var dismissTimer: Timer?

    private init() {}

    /// 发送新通知
    func post(_ notification: NearNotification) {
        DispatchQueue.main.async {
            self.dismissTimer?.invalidate()

            // 如果当前有通知，低优先级的通知直接丢弃
            if let current = self.currentNotification {
                if notification.type.priority > current.type.priority {
                    // 新通知优先级更低，丢弃
                    return
                }
            }

            // 显示新通知（顶替旧通知）
            self.currentNotification = notification
            self.startDismissTimer()
        }
    }

    /// 启动自动消失计时器
    private func startDismissTimer() {
        guard let notification = currentNotification, let delay = notification.autoDismissDelay else {
            return
        }
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }

    /// 触发通知动作
    func triggerAction(_ actionId: String) {
        guard let notification = currentNotification else { return }

        if let action = notification.actions.first(where: { $0.id == actionId }) {
            action.action?()
        }

        notification.callback?(actionId)
        dismiss()
    }

    /// 手动关闭通知
    func dismiss() {
        DispatchQueue.main.async {
            self.currentNotification = nil
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
        }
    }
}
