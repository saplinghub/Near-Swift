import AppKit
import SwiftUI

class PetWindow: NSPanel {
    private var model: PetModel
    
    init(contentRect: NSRect, model: PetModel) {
        self.model = model
        super.init(
            contentRect: contentRect,
            // 保持 borderless，确保没有系统边框和阴影
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.level = .floating 
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // 关键：我们要自己实现拖拽，所以关闭背景拖拽
        self.isMovableByWindowBackground = false
        
        let petView = PetView(model: model)
        let hostingView = NSHostingView(rootView: petView)
        // 确保 NSHostingView 也是透明的
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView
    }
    
    // 重写点击事件，只有点中小人身子（中心区域）才允许拖拽
    override func mouseDown(with event: NSEvent) {
        // macOS 窗口坐标：左下角为 (0,0)
        let location = event.locationInWindow
        
        // 如果缩放了，点击区域也应该缩小
        let scale: CGFloat = model.isDocked ? 0.5 : 1.0
        let w: CGFloat = 80 * scale
        let h: CGFloat = 120 * scale
        
        let petBodyRect = NSRect(
            x: (self.frame.width - w) / 2,
            y: (self.frame.height - h) / 2,
            width: w,
            height: h
        )
        
        if petBodyRect.contains(location) {
            // 直接触发系统级窗口拖拽，非常丝滑
            self.performDrag(with: event)
        } else {
            // 不响应，让点击事件穿透到下层桌面
            // 注意：不调用 super 才能真正让穿透生效
            return
        }
    }
    
    // 作为一个桌宠，不应该抢夺用户的键盘焦点
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
}
