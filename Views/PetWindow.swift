import AppKit
import SwiftUI

class PetWindow: NSPanel {
    private var model: PetModel
    
    init(contentRect: NSRect, model: PetModel) {
        self.model = model
        
        // 强制窗口大小为 60x60
        let fixedRect = NSRect(x: contentRect.origin.x, y: contentRect.origin.y, width: 60, height: 60)
        
        super.init(
            contentRect: fixedRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.level = .floating 
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // 现在整个窗口都是宠物，可以直接允许背景拖拽
        self.isMovableByWindowBackground = true
        
        let petView = PetContentView(model: model)
        let hostingView = NSHostingView(rootView: petView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        self.contentView = hostingView
        
        // 监听移动以同步气泡
        NotificationCenter.default.addObserver(self, selector: #selector(windowMoved), name: NSWindow.didMoveNotification, object: self)
    }
    
    @objc private func windowMoved() {
        PetManager.shared.handleWindowMoved()
    }
    
    // 鼠标抬起时触发吸附检查
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        PetManager.shared.finishDragging()
    }
    
    // 作为一个桌宠，不应该抢夺用户的键盘焦点
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
}
