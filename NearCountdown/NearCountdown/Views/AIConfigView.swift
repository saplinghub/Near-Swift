import SwiftUI

struct AIConfigView: View {
    @ObservedObject var aiService: AIService
    @ObservedObject var storageManager: StorageManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API 配置")) {
                    TextField("API 地址", text: $aiService.config.baseURL)
                        .textFieldStyle(.roundedBorder)

                    SecureField("API 密钥", text: $aiService.config.apiKey)
                        .textFieldStyle(.roundedBorder)

                    TextField("模型名称", text: $aiService.config.model)
                        .textFieldStyle(.roundedBorder)
                }

                Section {
                    Button("保存配置") {
                        storageManager.saveAIConfig()
                        dismiss()
                    }
                    .disabled(!aiService.config.isValid())

                    Button("测试连接") {
                        // TODO: 实现连接测试
                    }
                    .disabled(!aiService.config.isValid())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}