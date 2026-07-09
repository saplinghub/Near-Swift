import SwiftUI

/// 专门负责渲染宠物内容的视图，不包含气泡
struct PetContentView: View {
    @ObservedObject var model: PetModel
    @State private var bobOffset: CGFloat = 0

    var body: some View {
        let descriptor = PetAnimationResolver.resolve(model: model)

        // 宠物核心渲染器：使用 Lottie 动画，额外叠加轻量行走 bob 和方向翻转。
        LottieView(
            animationName: descriptor.animationName,
            playback: descriptor.playback
        )
        .frame(width: 60, height: 60)
        .scaleEffect(x: descriptor.facingDirection.scale, y: 1.0)
        .scaleEffect(descriptor.scale)
        .offset(y: descriptor.shouldBob ? bobOffset : 0)
        .opacity(descriptor.opacity)
        .onAppear { updateBob(shouldBob: descriptor.shouldBob) }
        .onChange(of: descriptor.shouldBob) { shouldBob in
            updateBob(shouldBob: shouldBob)
        }
    }

    private func updateBob(shouldBob: Bool) {
        if shouldBob {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                bobOffset = -3
            }
        } else {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                bobOffset = 0
            }
        }
    }
}
