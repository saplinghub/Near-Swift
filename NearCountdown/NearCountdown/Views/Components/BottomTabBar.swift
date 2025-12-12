import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: Int
    @State private var isHovering = false
    
    let tabs: [(icon: String, name: String)] = [
        ("list.bullet.rectangle", "事件"),
        ("calendar", "日历"),
        ("cpu", "系统"),
        ("person.crop.circle", "我的")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Visual Layer
            VStack(alignment: .center, spacing: 0) {
                if isHovering {
                    // Expanded Menu
                    HStack(spacing: 0) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Button(action: {
                                selectedTab = index
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: tabs[index].icon)
                                        .font(.system(size: 18, weight: selectedTab == index ? .bold : .medium))
                                        .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                                    
                                    Text(tabs[index].name)
                                        .font(.system(size: 10, weight: selectedTab == index ? .bold : .medium))
                                }
                                .foregroundColor(selectedTab == index ? .nearPrimary : .gray.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottom))) // Snappier transition
                } else {
                    // Minimal "Phantom" View
                    // Widened to match expanded state somewhat
                    HStack(spacing: 8) {
                        ForEach(0..<tabs.count, id: \.self) { index in
                            Capsule()
                                .fill(selectedTab == index ? Color.nearPrimary.opacity(0.6) : Color.gray.opacity(0.3))
                                .frame(height: 6)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 36) // Reduced padding to make it wider (closer to 20)
                    .padding(.bottom, 12)
                    .frame(height: 30, alignment: .bottom) // Height of the visual area
                    .background(Color.clear)
                    .transition(.opacity)
                }
            }
            .allowsHitTesting(isHovering) // Only interactive when expanded? 
            // NO! If we disable hit testing, the Buttons inside won't work even if visible.
            // But we want the "Trigger Zone" to handle the hover for the *container*.
            // Buttons need to receive *clicks*.
            // If `allowsHitTesting(isHovering)` is true only when hovering, that's fine because buttons are only visible when hovering.
            // But when !isHovering, we still need the Trigger Zone to work. Trigger Zone is separate in ZStack.
            // So this modifier applies to the VStack (Visuals).
        }
        .frame(height: 90, alignment: .bottom) // Fixed height trigger container
        .background(Color.black.opacity(0.001)) // Invisible fill to capture hover everywhere in frame
        .onHover { hover in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hover
            }
        }
    }
}
