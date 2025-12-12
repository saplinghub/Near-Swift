import SwiftUI

struct PageHeader: View {
    let title: String
    @Binding var showingSettingsSheet: Bool
    
    var body: some View {
        HStack {
            // Left: Title
            Text(title)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.nearTextPrimary)
                .padding(.leading, 20)
            
            Spacer()
            
            // Right: Settings Button
            Button(action: {
                showingSettingsSheet = true
            }) {
                Image(systemName: "gearshape.fill")
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
            .padding(.trailing, 20)
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}
