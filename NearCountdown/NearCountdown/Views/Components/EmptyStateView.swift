import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.nearTextSecondary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.nearTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
