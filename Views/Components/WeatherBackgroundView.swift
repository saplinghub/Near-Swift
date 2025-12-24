import SwiftUI

struct WeatherBackgroundView: View {
    @EnvironmentObject var weatherService: WeatherService
    
    var body: some View {
        ZStack {
            // High-fidelity Gradient
            backgroundGradient
                .animation(.easeInOut(duration: 1.5), value: weatherIcon)
            
            // Atmospheric Bloom
            Circle()
                .fill(RadialGradient(colors: [glowColor.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 400))
                .offset(x: -100, y: -150)
                .blur(radius: 60)
            
            // Dynamic Particle System
            weatherEffectLayer
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private var weatherIcon: String {
        weatherService.weather?.current.icon ?? "100"
    }
    
    private var glowColor: Color {
        if weatherIcon.hasPrefix("1") { return .yellow }
        if weatherIcon.hasPrefix("3") { return .blue }
        if weatherIcon.hasPrefix("4") { return .white }
        return .white
    }
    
    private var backgroundGradient: some View {
        let colors: [Color]
        
        // Pastel & Bright Color Palettes (Apple Style)
        switch weatherIcon {
        case "100", "150": // Sunny - Bright Blue to White
            colors = [Color(hex: "#7DD3FC"), Color(hex: "#BAE6FD"), Color(hex: "#F0F9FF")]
        case "101"..."104", "151"..."154": // Cloudy - Soft Grey/White
            colors = [Color(hex: "#E5E7EB"), Color(hex: "#F3F4F6"), Color(hex: "#FFFFFF")]
        case "300"..."399": // Rain - Clean Blue-Grey
            colors = [Color(hex: "#94A3B8"), Color(hex: "#CBD5E1"), Color(hex: "#E2E8F0")]
        case "400"..."499": // Snow - Pure Frosty White
            colors = [Color(hex: "#F1F5F9"), Color(hex: "#FFFFFF"), Color(hex: "#E2E8F0")]
        default:
            colors = [Color(hex: "#F3F4F6"), Color(hex: "#FFFFFF")]
        }
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    @ViewBuilder
    private var weatherEffectLayer: some View {
        if weatherIcon.hasPrefix("3") {
            RainEffectView()
        } else if weatherIcon.hasPrefix("4") {
            SnowEffectView()
        } else if weatherIcon == "100" || weatherIcon == "150" {
            SunnyEffectView()
        } else {
            CloudyEffectView()
        }
    }
}

// MARK: - Specialized Effects

struct RainEffectView: View {
    var body: some View {
        ZStack {
            ForEach(0..<40) { _ in
                Raindrop()
            }
        }
    }
}

struct Raindrop: View {
    @State private var position: CGPoint = .zero
    let speed = CGFloat.random(in: 400...700)
    let size = CGFloat.random(in: 10...20)
    
    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
            .frame(width: 1, height: size)
            .position(position)
            .onAppear {
                reset()
                fall()
            }
    }
    
    private func reset() {
        position = CGPoint(x: CGFloat.random(in: 0...400), y: CGFloat.random(in: -100...0))
    }
    
    private func fall() {
        let duration = (600 - position.y) / speed
        withAnimation(.linear(duration: Double(duration))) {
            position.y = 650
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration)) {
            reset()
            fall()
        }
    }
}

struct SnowEffectView: View {
    var body: some View {
        ZStack {
            ForEach(0..<50) { _ in
                Snowflake()
            }
        }
    }
}

struct Snowflake: View {
    @State private var position: CGPoint = .zero
    @State private var rotation: Double = 0
    let speed = CGFloat.random(in: 100...200)
    let size = CGFloat.random(in: 3...7)
    
    var body: some View {
        Image(systemName: "snowflake")
            .font(.system(size: size))
            .foregroundColor(.white.opacity(0.4))
            .rotationEffect(.degrees(rotation))
            .position(position)
            .onAppear {
                reset()
                fall()
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
    
    private func reset() {
        position = CGPoint(x: CGFloat.random(in: 0...400), y: CGFloat.random(in: -100...0))
    }
    
    private func fall() {
        let duration = (600 - position.y) / speed
        withAnimation(.linear(duration: Double(duration))) {
            position.y = 650
            position.x += CGFloat.random(in: -20...20)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(duration)) {
            reset()
            fall()
        }
    }
}

struct SunnyEffectView: View {
    @State private var scale = 1.0
    
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [.yellow.opacity(0.1), .clear], center: .center, startRadius: 0, endRadius: 200))
            .frame(width: 400, height: 400)
            .scaleEffect(scale)
            .offset(x: -150, y: -200)
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    scale = 1.2
                }
            }
    }
}

struct CloudyEffectView: View {
    @State private var offset = CGFloat(-200)
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 250, height: 250)
                    .offset(x: offset + CGFloat(i * 100), y: CGFloat(i * 150 - 150))
                    .blur(radius: 40)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                offset = 200
            }
        }
    }
}
