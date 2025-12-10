import SwiftUI
import Combine

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: IconType

    var body: some View {
        VStack(spacing: 20) {
            Text("选择图标")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(IconType.allCases, id: \.self) { iconType in
                    Button(action: {
                        selectedIcon = iconType
                        dismiss()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: iconType.sfSymbol)
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: iconType.color))

                            Text(iconType.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: iconType.color).opacity(0.1))
                        )
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}