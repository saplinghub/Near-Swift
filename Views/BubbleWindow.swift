import AppKit
import SwiftUI

/// 气泡布局常量
enum BubbleLayout {
    static let width: CGFloat = 260
    static let padding: CGFloat = 16
    static let headerHeight: CGFloat = 24  // 类型标签高度
    static let textFontSize: CGFloat = 14
    static let buttonHeight: CGFloat = 32
    static let triangleHeight: CGFloat = 8
    static let baseHeight: CGFloat = 80  // 基础高度（头部+文本最小高度+尖角）
}

/// 手动计算气泡内容高度
func calculateBubbleHeight(text: String, hasActions: Bool, actionCount: Int = 0) -> CGFloat {
    // 计算文本高度
    let textWidth = BubbleLayout.width - BubbleLayout.padding * 2
    let font = NSFont.systemFont(ofSize: BubbleLayout.textFontSize)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let textHeight = (text as NSString).boundingRect(
        with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: attributes
    ).height

    // 文本区域高度（最小20，最多5行约70）
    let textAreaHeight = max(20, min(70, ceil(textHeight)))

    // 按钮区域高度
    var buttonAreaHeight: CGFloat = 0
    if hasActions {
        buttonAreaHeight = BubbleLayout.buttonHeight + 8
    }

    // 总高度 = 基础高度 + 文本高度 + 按钮高度 + padding
    let totalHeight = BubbleLayout.baseHeight + textAreaHeight + buttonAreaHeight

    return ceil(totalHeight)
}

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

    /// 当消息可见性改变时，刷新窗口大小并位置
    func updateSizeAndPosition(relativeTo petFrame: NSRect) {
        guard !model.isMessageVisible else {
            // 显示消息
            showAt(relativeTo: petFrame)
            return
        }

        // 隐藏消息
        if isVisible {
            orderOut(nil)
        }
    }

    private func showAt(relativeTo petFrame: NSRect) {
        let message = model.message
        let hasActions = !model.actions.isEmpty
        let bubbleHeight = calculateBubbleHeight(text: message, hasActions: hasActions)

        let x = floor(petFrame.midX - BubbleLayout.width / 2)
        let y = floor(petFrame.maxY + 5)

        let targetFrame = NSRect(x: x, y: y, width: BubbleLayout.width, height: bubbleHeight)

        setFrame(targetFrame, display: true, animate: false)

        if !isVisible {
            makeKeyAndOrderFront(nil)
        }
    }
}
