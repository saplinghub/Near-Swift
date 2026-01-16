import SwiftUI

struct NearPremiumPicker<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let items: [T]
    @Binding var selection: T
    
    @Namespace private var animation
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selection = item
                        }
                    }) {
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: selection == item ? .bold : .medium))
                            .foregroundColor(selection == item ? .white : .nearTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                ZStack {
                                    if selection == item {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [.nearPrimary, .nearSecondary],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .matchedGeometryEffect(id: "pill", in: animation)
                                            .shadow(color: .nearPrimary.opacity(0.3), radius: 5, x: 0, y: 3)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#F8FAFC"))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
                )
        )
    }
}
