import SwiftUI
import Lottie
import AppKit

struct LottieView: NSViewRepresentable {
    var animationName: String
    var loopMode: LottieLoopMode = .loop
    var playback: PetAnimationPlayback = .playing

    final class Coordinator {
        var lastAnimationName: String?
        var lastLoopMode: LottieLoopMode?
        var lastPlayback: PetAnimationPlayback?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        
        animationView.wantsLayer = true
        animationView.layer?.backgroundColor = .clear
        
        // 降低内容权重，服从 SwiftUI 约束
        animationView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        animationView.setContentHuggingPriority(.defaultLow, for: .vertical)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        loadAnimation(named: animationName, into: animationView)

        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.backgroundBehavior = .pauseAndRestore

        // 【关键优化】使用 CoreAnimation 引擎
        animationView.configuration = LottieConfiguration(renderingEngine: .coreAnimation)

        context.coordinator.lastAnimationName = animationName
        context.coordinator.lastLoopMode = loopMode
        applyPlayback(playback, to: animationView, coordinator: context.coordinator, force: true)

        return animationView
    }
    
    func updateNSView(_ nsView: LottieAnimationView, context: Context) {
        if context.coordinator.lastAnimationName != animationName {
            nsView.stop()
            loadAnimation(named: animationName, into: nsView)
            nsView.currentProgress = 0
            context.coordinator.lastAnimationName = animationName
            context.coordinator.lastPlayback = nil
        }

        if context.coordinator.lastLoopMode != loopMode {
            nsView.loopMode = loopMode
            context.coordinator.lastLoopMode = loopMode
        }

        applyPlayback(playback, to: nsView, coordinator: context.coordinator)
    }

    private func loadAnimation(named name: String, into animationView: LottieAnimationView) {
        if let path = ResourceBundle.current.path(forResource: name, ofType: "json") {
            animationView.animation = LottieAnimation.filepath(path)
        } else {
            animationView.animation = LottieAnimation.named(name, bundle: ResourceBundle.current)
        }
    }

    private func applyPlayback(_ playback: PetAnimationPlayback, to animationView: LottieAnimationView, coordinator: Coordinator, force: Bool = false) {
        guard force || coordinator.lastPlayback != playback else { return }

        switch playback {
        case .playing:
            animationView.loopMode = loopMode
            if !animationView.isAnimationPlaying {
                animationView.play()
            }
        case .paused:
            if animationView.isAnimationPlaying {
                animationView.pause()
            }
        case .stopped:
            animationView.stop()
            animationView.currentProgress = 0
        }

        coordinator.lastPlayback = playback
    }
}
