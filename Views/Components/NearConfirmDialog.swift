import SwiftUI

struct NearConfirmDialog: View {
    let title: String
    let message: String?
    let confirmTitle: String
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var animateIn = false
    
    var body: some View {
        ZStack {
            // High-end Background Blur
            Color.black.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onCancel()
                }
            
            VStack(spacing: 0) {
                // Header with Gradient Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.red.opacity(0.1), .pink.opacity(0.05)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 54, height: 54)
                    
                    Circle()
                        .stroke(LinearGradient(colors: [.red.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: "trash.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "#FF4D4D"), Color(hex: "#FF3366")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: Color(hex: "#FF3366").opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 24)
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.nearTextPrimary)
                    
                    if let message = message {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(.nearTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .lineSpacing(2)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                // Modern Capsule Buttons
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text(cancelTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.nearTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(colors: [Color(hex: "#FF4D4D"), Color(hex: "#FF3366")], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(12)
                            .shadow(color: Color(hex: "#FF3366").opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 280)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 30, x: 0, y: 15)
            .scaleEffect(animateIn ? 1.0 : 0.8)
            .opacity(animateIn ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                animateIn = true
            }
        }
    }
}
