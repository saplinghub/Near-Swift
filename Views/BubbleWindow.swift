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
        // 使用屏障（DispatchWorkItem）或简单的 async 确保独立性
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let hostingView = self.contentView as? NSHostingView<BubbleContentView> else { return }
            
            // 节流处理
            if Date().timeIntervalSince(self.lastUpdate) < 0.1 { return }
            self.lastUpdate = Date()

            // 关键：由于在 BubbleContentView 中锁定了宽度为 260，
            // 直接读取 fittingSize 即可获得基于该宽度的稳定高度
            let targetSize = hostingView.fittingSize
            
            // 如果高度太小，说明内容为空或被隐藏
            if targetSize.height < 10 {
                if self.isVisible { self.orderOut(nil) }
                return
            }
            
            let bubbleWidth: CGFloat = 260
            let bubbleHeight = targetSize.height
            
            // 计算位置：居中于宠物上方
            let x = petFrame.midX - bubbleWidth / 2
            let y = petFrame.maxY + 5
            
            let targetFrame = NSRect(x: x, y: y, width: bubbleWidth, height: bubbleHeight)
            
            // 只有当 Frame 发生显著改变（超过 1 像素）时才更新
            if abs(self.frame.height - targetFrame.height) > 1.0 || 
               abs(self.frame.origin.x - targetFrame.origin.x) > 1.0 ||
               abs(self.frame.origin.y - targetFrame.origin.y) > 1.0 {
                
                // 强制同步一次内部布局，防止 setFrame 触发重新测量
                hostingView.setFrameSize(targetSize)
                self.setFrame(targetFrame, display: true)
            }
            
            if !self.isVisible {
                self.makeKeyAndOrderFront(nil)
            }
        }
    }
}
