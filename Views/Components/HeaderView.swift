import SwiftUI

struct HeaderView: View {
    @Binding var showingSettingsSheet: Bool
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            // Left: Title
            Text("NEAR")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .italic()
                .tracking(2)
                .foregroundColor(.nearTextPrimary)
                .padding(.leading, 20)

            Spacer()

            // Right: Tabs + Settings
            HStack(spacing: 8) {
                // Custom Tab Switcher
                HStack(spacing: 0) {
                    TabButton(title: "进行中", isSelected: selectedTab == 0) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = 0
                        }
                    }
                    
                    TabButton(title: "已结束", isSelected: selectedTab == 1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = 1
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(8)
                .padding(2)
                .background(Color.white.opacity(0.5)) // Outer border/glow potential
                .cornerRadius(10)

                // Settings Button
                Button(action: {
                    showingSettingsSheet = true
                }) {
                    Image(systemName: "gearshape.fill") // Using sun.max or gear based on image, image looks like a sun/gear hybrid or just settings. Keeping gear for now but styling it simpler.
                    // Actually image shows a "Sun" icon maybe? Or a valid settings icon.
                    // Let's stick to gear but make it look like the square button in the image.
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.nearTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .padding(.trailing, 20)
        }
        .padding(.top, 16) // Increased top padding
        .padding(.bottom, 12)
        // Background handled by ContentView ZStack or VisualEffect
    }
}

// Local helper for the pill-shaped tabs inside the header
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                .foregroundColor(isSelected ? .nearPrimary : .nearTextSecondary)
                .frame(height: 28)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.nearHoverBlueBg : Color.clear) // Light blue bg for selected
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
