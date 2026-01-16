import AppKit
import SwiftUI

class BubbleWindow: NSPanel {
    private var model: PetModel
    
    init(model: PetModel) {
        self.model = model
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        
        let contentView = BubbleContentView(model: model)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        self.contentView = hostingView
    }
    
    override var canBecomeKey: Bool { return false }
    override var canBecomeMain: Bool { return false }
    
    private var lastUpdate: Date = .distantPast

    /// 当消息可见性改变时，刷新窗口大小并位置
    func updateSizeAndPosition(relativeTo petFrame: NSRect) {
        // 调度到主线程，且确保不在当前的 SwiftUI 布局事务中冲突
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let hostingView = self.contentView as? NSHostingView<BubbleContentView> else { return }
            
            // 节流处理：0.1s 间隔
            let now = Date()
            if now.timeIntervalSince(self.lastUpdate) < 0.1 { return }
            self.lastUpdate = now
            
            // 关键：SwiftUI 需要一个受限的宽度来计算合适的高度
            // 我们通过直接给 hostingView 设定一个临时宽度约束，来获取准确的高度
            let bubbleWidth: CGFloat = 260
            let fittingSize = hostingView.fittingSize // 获取 SwiftUI 视图的自然尺寸
            
            // 过滤：如果高度几乎为 0，说明内容是空或被隐藏
            if fittingSize.height < 10 {
                if self.isVisible { self.orderOut(nil) }
                return
            }
            
            // 增加舍入处理，防止由于像素对齐导致的无限微量抖动（死循环诱因）
            let bubbleHeight = ceil(fittingSize.height)
            
            // 计算位置：居中于宠物上方
            let x = floor(petFrame.midX - bubbleWidth / 2)
            let y = floor(petFrame.maxY + 5)
            
            let targetFrame = NSRect(x: x, y: y, width: bubbleWidth, height: bubbleHeight)
            
            // 只有当 Frame 发生显著改变（超过 0.5 像素）时才更新
            if abs(self.frame.size.height - targetFrame.size.height) > 0.5 || 
               abs(self.frame.origin.x - targetFrame.origin.x) > 0.5 ||
               abs(self.frame.origin.y - targetFrame.origin.y) > 0.5 {
                
                // 【核心修复】移除 hostingView.setFrameSize(targetSize)
                // 在 macOS 中，作为 contentView 的 hostingView 会由 NSWindow 自动管理
                // 手动干预往往是导致 Auto Layout Loop 的元凶
                self.setFrame(targetFrame, display: true, animate: false)
            }
            
            if !self.isVisible {
                self.makeKeyAndOrderFront(nil)
            }
        }
    }
}
