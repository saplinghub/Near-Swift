import SwiftUI

struct CountdownCardView: View {
    @EnvironmentObject var countdownManager: CountdownManager
    let countdown: CountdownEvent
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // 左侧图标 - 匹配Tauri版本样式
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: countdown.icon.backgroundColor))
                    .frame(width: 36, height: 36)

                Image(systemName: countdown.icon.sfSymbol)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: countdown.icon.color))
            }

            // 中间内容区域
            VStack(alignment: .leading, spacing: 4) {
                // 标题和日期行
                HStack {
                    Text(countdown.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.nearTextPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(countdown.dateString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.nearTextSecondary)
                }

                // 时间详情
                HStack(spacing: 3) {
                    Text("\(countdown.daysRemaining)")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.nearTextPrimary)

                    Text("天")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.nearTextSecondary)

                    Text(countdown.timeRemainingString)
                        .font(.system(size: 11))
                        .foregroundColor(.nearTextSecondary)
                        .opacity(0.8)

                    Spacer()
                }

                // 进度条
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.nearBackgroundEnd)
                        .frame(height: 4)
                        .overlay(
                            GeometryReader { geometry in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                .nearPrimary,
                                                .nearSecondary
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * countdown.progress)
                            },
                            alignment: .leading
                        )

                    Text("\(Int(countdown.progress * 100))%")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.nearPrimary)
                        .frame(minWidth: 26, alignment: .trailing)
                }
            }

            // 右侧按钮组
            VStack(spacing: 8) {
                Button(action: {
                    countdownManager.deleteCountdown(countdown.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.nearTextLight)
                }
                .buttonStyle(ActionButtonStyle(hoverColor: .nearHoverRed, hoverBg: .nearHoverRedBg))

                if !countdown.isCompleted {
                    Button(action: {
                        countdownManager.togglePin(countdown.id)
                    }) {
                        Image(systemName: countdown.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 12))
                            .foregroundColor(countdown.isPinned ? .nearPrimary : .nearTextLight)
                    }
                    .buttonStyle(ActionButtonStyle(hoverColor: .nearPrimary, hoverBg: .nearHoverBlueBg))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.05 : 0.02),
                    radius: isHovered ? 8 : 2,
                    x: 0,
                    y: isHovered ? 4 : 1
                )
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// 动作按钮样式
struct ActionButtonStyle: ButtonStyle {
    let hoverColor: Color
    let hoverBg: Color
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? hoverBg : Color.clear)
            )
            .foregroundColor(isHovered ? hoverColor : .nearTextLight)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
    }
}