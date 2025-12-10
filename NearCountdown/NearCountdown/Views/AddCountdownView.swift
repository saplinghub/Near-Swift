import SwiftUI

struct AddCountdownView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var countdownManager: CountdownManager
    @State private var aiService = AIService()

    @State private var countdown = CountdownEvent.createDefault()
    @State private var showingIconPicker = false
    @State private var showingAIParser = false
    @State private var aiInput = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("事件名称", text: $countdown.name)

                    DatePicker("开始时间", selection: $countdown.startDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)

                    DatePicker("目标时间", selection: $countdown.targetDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }

                Section(header: Text("图标")) {
                    HStack {
                        Image(systemName: countdown.icon.sfSymbol)
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: countdown.icon.color))

                        Text(countdown.icon.rawValue)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button("选择") {
                            showingIconPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Section(header: Text("AI 智能解析")) {
                    HStack {
                        TextField("输入自然语言，如：春节倒计时", text: $aiInput)
                            .textFieldStyle(.roundedBorder)

                        Button("解析") {
                            showingAIParser = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(aiInput.isEmpty)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $countdown.icon)
            }
            .sheet(isPresented: $showingAIParser) {
                AIParserView(
                    input: $aiInput,
                    countdown: $countdown,
                    aiService: aiService,
                    onDismiss: {
                        showingAIParser = false
                        aiInput = ""
                    }
                )
            }
        }
    }
}