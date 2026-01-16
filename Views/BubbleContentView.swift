import SwiftUI

/// 专门负责渲染消息气泡内容的视图
struct BubbleContentView: View {
    @ObservedObject var model: PetModel
    
    var body: some View {
        if model.isMessageVisible {
            bubbleContent(text: model.message)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)),
                    removal: .opacity
                ))
        } else {
            // 使用空视图，配合 BubbleWindow 的 size 检查
            Color.clear.frame(width: 260, height: 0)
        }
    }
    
    @ViewBuilder
    private func bubbleContent(text: String) -> some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                // 头部：类型标识与关闭按钮
                HStack {
                    Label(model.messageType.displayName, systemImage: model.messageType.iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(colorForType(model.messageType))
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation { model.isMessageVisible = false }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                
                // 内容文本
                Text(text)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true) // 允许垂直换行
                    .lineLimit(5)
                    .frame(minHeight: 20)
                
                if !model.actions.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(model.actions) { action in
                            Button(action: {
                                action.action?()
                            }) {
                                Text(action.title)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(action.color.opacity(0.85))
                                    .clipShape(Capsule())
                                    .shadow(color: action.color.opacity(0.3), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                }
            )
            
            // 气泡尖角
            Image(systemName: "triangle.fill")
                .resizable()
                .frame(width: 12, height: 8)
                .rotationEffect(.degrees(180))
                .foregroundStyle(.ultraThinMaterial)
                .offset(y: -1)
                .shadow(color: .black.opacity(0.05), radius: 2, y: 2)
        }
        .frame(width: 260) // 锁定宽度，彻底防止水平方向的布局抖动和死循环
    }

    private func colorForType(_ type: PetMessageType) -> Color {
        switch type {
        case .system: return .blue
        case .health: return .green
        case .power: return .orange
        case .fun: return .purple
        case .weather: return .cyan
        }
    }
}
