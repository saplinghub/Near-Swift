import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var countdownManager: CountdownManager
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var storageManager: StorageManager
    @Environment(\.dismiss) var dismiss

    @State private var showingAIConfig = false
    @State private var testingConnection = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI 配置")) {
                    HStack {
                        Text("当前模型")
                        Spacer()
                        Text(aiService.config.model)
                            .foregroundColor(.secondary)
                    }

                    Button("配置 AI 服务") {
                        showingAIConfig = true
                    }
                }

                Section(header: Text("系统信息")) {
                    HStack {
                        Text("CPU 使用率")
                        Spacer()
                        Text("\(String(format: "%.1f", storageManager.countdowns.first?.progress ?? 0))%")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("内存使用")
                        Spacer()
                        Text("N/A")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("系统温度")
                        Spacer()
                        Text("N/A")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("运行时间")
                        Spacer()
                        Text("N/A")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("数据管理")) {
                    Button("清空所有数据") {
                        // TODO: 实现清空数据功能
                    }
                    .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: $showingAIConfig) {
                AIConfigView(aiService: aiService, storageManager: storageManager)
            }
        }
    }
}