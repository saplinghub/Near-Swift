import SwiftUI

/// 宠物形象渲染：根据当前皮肤的 manifest 决定走 Lottie 还是雪碧图。
/// 由 PetManager 持有并注入 bundle；PetModel 只是状态快照的载体。
struct PetContentView: View {
    @ObservedObject var model: PetModel
    var bundle: PetBundle?
    @State private var bobOffset: CGFloat = 0

    private var isAtlas: Bool { bundle?.isLottie == false }

    var body: some View {
        Group {
            if isAtlas {
                SpriteAtlasView(model: model, bundle: bundle)
            } else {
                // Lottie 路径：把模型语义映射成播放意图（沿用旧逻辑，Lottie 自带内部动画）
                lottieView
            }
        }
        .frame(width: 60, height: 60)
        .scaleEffect(x: model.facingDirection.scale, y: 1.0)
        .scaleEffect(model.isDocked ? 0.75 : 1.0)
        .offset(y: model.state == .walking ? bobOffset : 0)
        .opacity(model.isDocked ? 0.9 : 1.0)
        .onAppear { updateBob(shouldBob: model.state == .walking) }
        .onChange(of: model.state) { state in
            updateBob(shouldBob: state == .walking)
        }
    }

    /// Lottie 动画：语义 → 播放/停止。当前单文件动画，循环表达已足够。
    private var lottieView: some View {
        let shouldAnimate = PetAnimationResolver.resolve(model: model).playback == .playing
        return LottieView(
            animationName: bundle?.lottieName ?? "guaishou",
            playback: shouldAnimate ? .playing : .stopped
        )
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
