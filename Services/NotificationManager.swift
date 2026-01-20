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
    let callback: ((String) -> Void)? // 用于返回点击反馈

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

/// 通知管理中心：协调各服务发送通知，由显示者（如 PetManager）进行展示
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published private(set) var currentNotification: NearNotification?
    
    private var dismissTimer: Timer?
    
    private init() {}
    
    /// 发送新通知
    func post(_ notification: NearNotification) {
        DispatchQueue.main.async {
            self.dismissTimer?.invalidate()
            
            // 顶掉旧通知
            self.currentNotification = notification
            
            // 自动消失逻辑
            if let delay = notification.autoDismissDelay {
                self.dismissTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    self?.dismiss()
                }
            }
        }
    }
    
    /// 触发通知动作
    func triggerAction(_ actionId: String) {
        guard let notification = currentNotification else { return }
        
        // 1. 执行 action 自身逻辑
        if let action = notification.actions.first(where: { $0.id == actionId }) {
            action.action?()
        }
        
        // 2. 返回反馈给调用方
        notification.callback?(actionId)
        
        // 3. 点击后通常立即关闭通知
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
