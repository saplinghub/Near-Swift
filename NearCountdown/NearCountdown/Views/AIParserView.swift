import SwiftUI

struct AIParserView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var input: String
    @Binding var countdown: CountdownEvent
    @ObservedObject var aiService: AIService
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if aiService.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                        .padding()
                } else if let errorMessage = aiService.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text("解析失败")
                            .font(.headline)

                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: countdown.icon.sfSymbol)
                                .font(.system(size: 32))
                                .foregroundColor(Color(hex: countdown.icon.color))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(countdown.name)
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text(countdown.dateString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                        ProgressView(value: countdown.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: countdown.icon.color)))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.1))
                    )
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            aiService.parseCountdown(input: input)
        }
    }
}