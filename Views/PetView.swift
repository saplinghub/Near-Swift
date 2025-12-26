import SwiftUI

struct PetView: View {
    @ObservedObject var model: PetModel
    @State private var bounce: Bool = false
    
    // 追踪旧气泡的淡出动效
    @State private var shatteringId: UUID? = nil
    
    var body: some View {
        ZStack {
            // 背景气场 (颜色随负载变化)
            Circle()
                .fill(auraColor.opacity(0.15))
                .frame(width: 80, height: 80)
                .scaleEffect(bounce ? 1.1 : 0.9)
                .blur(radius: model.isDocked ? 5 : 0)
                .animation(.easeInOut(duration: 1.0), value: model.cpuLoadLevel)
            
            // 宠物主体
            VStack(spacing: -8) {
                HStack(spacing: 15) {
                    Circle().fill(Color.white).frame(width: 6, height: 6)
                    Circle().fill(Color.white).frame(width: 6, height: 6)
                }
                .offset(y: bounce ? -2 : 2)
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                    .frame(width: 50, height: 70)
                    .shadow(radius: 3)
            }
            .rotationEffect(.degrees(model.state == .walking ? (bounce ? 5 : -5) : 0))
            
            // 旧气泡粉碎效果
            if let oldId = model.oldMessageId, shatteringId == oldId {
                bubbleContent(text: model.oldMessage)
                    .offset(bubbleOffset)
                    .scaleEffect(1.2)
                    .opacity(0)
                    .blur(radius: 10)
                    .animation(.easeOut(duration: 0.4), value: shatteringId)
            }
            
            // 当前消息气泡
            if model.isMessageVisible {
                bubbleContent(text: model.message)
                    .id(model.messageId)
                    .offset(bubbleOffset)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.9))
                    ))
            }
        }
        .scaleEffect(model.isDocked ? 0.75 : 1.0, anchor: scaleAnchor)
        .opacity(model.isDocked ? 0.9 : 1.0)
        .offset(visualOffset)
        .frame(width: 400, height: 300)
        .onChange(of: model.messageId) { newId in
            if let oldId = model.oldMessageId {
                shatteringId = oldId
                // 自动清理粉碎记录
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if shatteringId == oldId { shatteringId = nil }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
    
    @ViewBuilder
    private func bubbleContent(text: String) -> some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                
                // 渲染动作按钮组
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
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
    }
    
    private var scaleAnchor: UnitPoint {
        switch model.dockEdge {
        case .left:   return .leading
        case .right:  return .trailing
        case .top:    return .top
        case .bottom: return .bottom
        case .none:   return .center
        }
    }
    
    private var visualOffset: CGSize {
        guard model.isDocked else { return .zero }
        let offset: CGFloat = 15.0 
        switch model.dockEdge {
        case .left:   return CGSize(width: -offset, height: 0)
        case .right:  return CGSize(width: offset, height: 0)
        case .top:    return CGSize(width: 0, height: -offset)
        case .bottom: return CGSize(width: 0, height: offset)
        case .none:   return .zero
        }
    }
    
    private var bubbleOffset: CGSize {
        var baseOffset = CGSize(width: 0, height: -90)
        guard model.isDocked else { return baseOffset }
        let shift: CGFloat = 40.0
        switch model.dockEdge {
        case .left:   baseOffset.width += shift
        case .right:  baseOffset.width -= shift
        case .top:    baseOffset.height += shift + 20
        case .bottom: baseOffset.height -= shift
        case .none:   break
        }
        return baseOffset
    }

    private var auraColor: Color {
        guard model.isSystemAwarenessEnabled else { return .blue }
        switch model.cpuLoadLevel {
        case .low:    return .blue
        case .medium: return .yellow
        case .high:   return .red
        }
    }
}
