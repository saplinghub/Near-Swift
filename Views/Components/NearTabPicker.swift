import SwiftUI

struct NearTabPicker: View {
    let items: [String]
    @Binding var selection: Int
    
    var body: some View {
        GeometryReader { geometry in
            let itemWidth = geometry.size.width / CGFloat(items.count)
            
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                
                // Sliding Indicator
                Capsule()
                    .fill(Color.white)
                    .frame(width: itemWidth - 4, height: geometry.size.height - 4)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .offset(x: CGFloat(selection) * itemWidth + 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)
                
                // Labels
                HStack(spacing: 0) {
                    ForEach(0..<items.count, id: \.self) { index in
                        Text(items[index])
                            .font(.system(size: 13, weight: selection == index ? .semibold : .medium))
                            .foregroundColor(selection == index ? .nearPrimary : .nearTextSecondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selection = index
                            }
                    }
                }
            }
        }
        .frame(height: 32)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(Capsule())
        )
    }
}
