import SwiftUI
import Lottie
import AppKit

struct LottieView: NSViewRepresentable {
    var animationName: String
    var loopMode: LottieLoopMode = .loop
    var isPaused: Bool = false // 联动播放状态
    
    func makeNSView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        
        animationView.wantsLayer = true
        animationView.layer?.backgroundColor = .clear
        
        // 降低内容权重，服从 SwiftUI 约束
        animationView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        animationView.setContentHuggingPriority(.defaultLow, for: .vertical)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        if let path = Bundle.module.path(forResource: animationName, ofType: "json") {
            animationView.animation = LottieAnimation.filepath(path)
        } else {
            animationView.animation = LottieAnimation.named(animationName, bundle: .module)
        }
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.backgroundBehavior = .pauseAndRestore
        
        // 【关键优化】使用 CoreAnimation 引擎
        animationView.configuration = LottieConfiguration(renderingEngine: .coreAnimation)
        
        if !isPaused {
            animationView.play()
        } else {
            animationView.currentProgress = 0
        }
        
        return animationView
    }
    
    func updateNSView(_ nsView: LottieAnimationView, context: Context) {
        if isPaused {
            // 【优化】用户希望停止：改为“播放一次”模式
            // 这样 Lottie 会自然播放完当前这一轮循环，然后停在结束帧（通常与首帧衔接）
            if nsView.loopMode == .loop {
                nsView.loopMode = .playOnce
            }
        } else {
            // 用户希望激活：恢复“循环”模式并确保正在播放
            if nsView.loopMode == .playOnce {
                nsView.loopMode = .loop
            }
            if !nsView.isAnimationPlaying {
                nsView.play()
            }
        }
    }
}
