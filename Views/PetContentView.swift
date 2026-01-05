import SwiftUI

/// 专门负责渲染宠物内容的视图，不包含气泡
struct PetContentView: View {
    @ObservedObject var model: PetModel
    
    var body: some View {
        // 宠物核心渲染器：使用 Lottie 动画
        LottieView(
            animationName: "guaishou",
            isPaused: !model.isAnimating // 仅在 isAnimating 为 true 时播放
        )
        .frame(width: 60, height: 60)
        .scaleEffect(model.isDocked ? 0.75 : 1.0)
        .opacity(model.isDocked ? 0.9 : 1.0)
    }
}
