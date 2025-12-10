import SwiftUI
import Combine

struct SettingsView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var aiService: AIService
    @EnvironmentObject var storageManager: StorageManager
    
    @State private var baseURL: String = ""
    @State private var apiKey: String = ""
    @State private var model: String = ""
    @State private var systemPrompt: String = ""
    @State private var isTesting = false
    @State private var testMessage: String?
    
    @State private var showExpandedEditor = false
    
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack { // 1. Main ZStack
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Text("设置")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.nearTextPrimary)
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color.gray.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 10)

                    // AI Configuration Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.nearPrimary)
                            Text("AI 配置")
                                .font(.headline)
                                .foregroundColor(.nearTextPrimary)
                        }
                        
                        VStack(spacing: 12) {
                            SettingsInputRow(icon: "link", title: "API 地址", placeholder: "https://api.openai.com/v1", text: $baseURL)
                            SettingsInputRow(icon: "key", title: "API 密钥", placeholder: "sk-...", text: $apiKey, isSecure: true)
                            SettingsInputRow(icon: "cube", title: "模型名称", placeholder: "gpt-3.5-turbo", text: $model)
                            
                            // System Prompt Editor
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("自定义系统提示词")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.nearTextSecondary)
                                    Spacer()
                                    Button(action: { withAnimation { showExpandedEditor = true } }) { // Animate
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.nearPrimary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                ZStack(alignment: .topLeading) {
                                    if systemPrompt.isEmpty {
                                        Text("使用默认配置...")
                                            .foregroundColor(.gray.opacity(0.5))
                                            .font(.system(size: 12))
                                            .padding(12)
                                    }
                                    TextEditor(text: $systemPrompt)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(height: 100)
                                        .padding(4)
                                        .background(Color(hex: "#F8FAFC"))
                                        .cornerRadius(8)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.nearTextSecondary.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // Actions
                        HStack(spacing: 12) {
                            Button(action: testConnection) {
                                HStack {
                                    if isTesting {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "network")
                                    }
                                    Text("测试连接")
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.nearTextPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.nearTextSecondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isTesting)
                            
                            Button(action: saveSettings) {
                                Text("保存配置")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(LinearGradient(gradient: Gradient(colors: [.nearPrimary, .nearHoverBlueBg]), startPoint: .leading, endPoint: .trailing))
                                    .cornerRadius(10)
                                    .shadow(color: .nearPrimary.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if let message = testMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(message.contains("成功") ? .green : .red)
                                .padding(.top, 4)
                                .transition(.opacity)
                        }
                    }
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.nearSecondary)
                            Text("关于")
                                .font(.headline)
                                .foregroundColor(.nearTextPrimary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("版本")
                                .foregroundColor(.nearTextSecondary)
                                Spacer()
                                Text("v1.0.0")
                                    .fontWeight(.medium)
                                    .foregroundColor(.nearTextPrimary)
                            }
                            Divider()
                            HStack {
                                Text("开发者")
                                    .foregroundColor(.nearTextSecondary)
                                Spacer()
                                Text("Near Countdown Team")
                                    .fontWeight(.medium)
                                    .foregroundColor(.nearTextPrimary)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                }
                .padding(24)
            }
            .blur(radius: showExpandedEditor ? 4 : 0) // Blur background when overlay is on
            
            // Expanded Editor Overlay
            if showExpandedEditor {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation { showExpandedEditor = false }
                    }
                
                ExpandedTextEditorView(text: $systemPrompt, isPresented: $showExpandedEditor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .padding(.horizontal, 24)
                    .background(Color.clear)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .onAppear {
            self.baseURL = aiService.config.baseURL
            self.apiKey = aiService.config.apiKey
            self.model = aiService.config.model
            
            if let custom = aiService.config.systemPrompt, !custom.isEmpty {
                 self.systemPrompt = custom
            } else {
                 self.systemPrompt = AIService.defaultSystemPrompt
            }
        }
    }
    
    func testConnection() {
        isTesting = true
        testMessage = nil
        
        let tempConfig = AIConfig(baseURL: baseURL, apiKey: apiKey, model: model, systemPrompt: systemPrompt)
        let previousConfig = aiService.config
        aiService.config = tempConfig
        
        aiService.testConnection()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isTesting = false
                    if case .failure(let error) = completion {
                        testMessage = "连接失败: \(error.localizedDescription)"
                    }
                    aiService.config = previousConfig
                },
                receiveValue: { success in
                    testMessage = success ? "连接成功！" : "连接失败"
                    aiService.config = previousConfig
                }
            )
            .store(in: &cancellables)
    }

    func saveSettings() {
        let newConfig = AIConfig(baseURL: baseURL, apiKey: apiKey, model: model, systemPrompt: systemPrompt)
        aiService.config = newConfig
        storageManager.aiConfig = newConfig
        storageManager.saveAIConfig()
        isPresented = false
    }
}

struct SettingsInputRow: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.nearTextSecondary)
            
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.nearTextLight)
                    .frame(width: 20)
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(PlainTextFieldStyle())
                }
            }
            .padding(10)
            .background(Color(hex: "#F8FAFC"))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.nearTextSecondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct ExpandedTextEditorView: View {
    @Binding var text: String
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("编辑提示词")
                    .font(.headline)
                Spacer()
                Button("完成") {
                    isPresented = false
                }
                .font(.system(size: 14, weight: .bold))
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .padding()
                .background(Color.white)
        }
        // Removed fixed frame from here, controlled by parent
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}