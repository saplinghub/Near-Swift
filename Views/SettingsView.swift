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
    @State private var qWeatherKey: String = ""
    @State private var qWeatherHost: String = ""
    @State private var waqiToken: String = ""
    @State private var isTesting = false
    @State private var testMessage: String?
    @State private var locationSearchQuery: String = ""
    @State private var searchResults: [LocationInfo] = []
    @State private var isSearching = false
    @State private var weatherTestMessage: String?
    @State private var isTestingWeather = false
    @State private var selectedTab: Int = 0 // 0: App, 1: AI, 2: Weather, 3: Pet
    
    // Pet Settings
    @State private var isPetSelfAwarenessEnabled: Bool = true
    @State private var isPetSystemAwarenessEnabled: Bool = true
    @State private var isPetIntentAwarenessEnabled: Bool = true
    @State private var isHealthReminderEnabled: Bool = true
    @State private var isAccessibilityGranted: Bool = false
    
    // Save Feedback
    @State private var saveFeedbackMessage: String? = nil
    
    @State private var showExpandedEditor = false
    @AppStorage("isDebugMode") private var isDebugMode = false
    @State private var devClickCount = 0
    @ObservedObject var logManager = LogManager.shared
    
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

                    // Tab Picker
                    NearTabPicker(items: isDebugMode ? ["通用", "AI 配置", "天气", "桌宠", "日志"] : ["通用", "AI 配置", "天气", "桌宠"], selection: $selectedTab)
                        .padding(.bottom, 10)

                    if selectedTab == 0 {
                        appSettingsSection
                    } else if selectedTab == 1 {
                        aiConfigSection
                    } else if selectedTab == 2 {
                        weatherConfigSection
                    } else if selectedTab == 3 {
                        petSettingsSection
                    } else if isDebugMode && selectedTab == 4 {
                        debugLogSection
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
            
            // Modern Glassmorphism Toast Notification
            if let message = saveFeedbackMessage {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.green.opacity(0.8), .mint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                    }
                    
                    Text(message)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.primary, .primary.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                }
                .overlay {
                    Capsule()
                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.9)).combined(with: .opacity),
                    removal: .opacity.combined(with: .scale(scale: 1.1))
                ))
                .zIndex(200)
                .offset(y: 200) // Lower center for better visibility
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
            
            self.qWeatherKey = storageManager.qWeatherKey
            self.qWeatherHost = storageManager.qWeatherHost
            self.waqiToken = storageManager.waqiToken
            self.isPetSelfAwarenessEnabled = storageManager.isPetSelfAwarenessEnabled
            self.isPetSystemAwarenessEnabled = storageManager.isSystemAwarenessEnabled
            self.isPetIntentAwarenessEnabled = storageManager.isPetIntentAwarenessEnabled
            self.isHealthReminderEnabled = storageManager.isHealthReminderEnabled
            self.checkAccessibilityStatus()
        }
    }
    
    private func checkAccessibilityStatus() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    @EnvironmentObject var weatherService: WeatherService

    func testWeatherConnection() {
        isTestingWeather = true
        weatherTestMessage = nil
        weatherService.testConnection(key: qWeatherKey, host: qWeatherHost)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isTestingWeather = false
                if case .failure(let error) = completion {
                    weatherTestMessage = "测试失败: \(error.localizedDescription)"
                }
            }, receiveValue: { success in
                weatherTestMessage = success ? "Key 有效，测试成功！" : "Key 无效或异常"
            })
            .store(in: &cancellables)
    }

    func searchLocations() {
        guard !locationSearchQuery.isEmpty else { return }
        isSearching = true
        weatherService.searchLocation(query: locationSearchQuery, key: qWeatherKey, host: qWeatherHost)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                isSearching = false
                if case .failure(let error) = completion {
                    self.weatherTestMessage = "搜索失败: \(error.localizedDescription)"
                }
            },
                  receiveValue: { results in
                self.searchResults = results
                if results.isEmpty {
                    self.weatherTestMessage = "未找到相关城市"
                }
            })
            .store(in: &cancellables)
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

    func saveAISettings() {
        let newConfig = AIConfig(baseURL: baseURL, apiKey: apiKey, model: model, systemPrompt: systemPrompt)
        aiService.config = newConfig
        storageManager.aiConfig = newConfig
        storageManager.saveAIConfig()
        showSaveFeedback()
    }
    func savePetSettings() {
        storageManager.savePetSettings(
            isSelfAwareEnabled: isPetSelfAwarenessEnabled,
            isSystemAwareEnabled: isPetSystemAwarenessEnabled,
            isIntentAwareEnabled: isPetIntentAwarenessEnabled,
            isHealthReminderEnabled: isHealthReminderEnabled
        )
        
        storageManager.isPetSelfAwarenessEnabled = isPetSelfAwarenessEnabled
        storageManager.isSystemAwarenessEnabled = isPetSystemAwarenessEnabled
        storageManager.isPetIntentAwarenessEnabled = isPetIntentAwarenessEnabled
        PetManager.shared.model.isHealthReminderEnabled = isHealthReminderEnabled
        showSaveFeedback()
    }

    func saveWeatherSettings() {
        storageManager.qWeatherKey = qWeatherKey
        storageManager.qWeatherHost = qWeatherHost
        storageManager.waqiToken = waqiToken
        storageManager.saveQWeatherKey()
        weatherService.fetchWeather()
        showSaveFeedback()
    }

    private func showSaveFeedback() {
        withAnimation {
            saveFeedbackMessage = "设置已保存"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                saveFeedbackMessage = nil
            }
        }
    }
    
    // MARK: - Sections
    
    private var aiConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.nearPrimary)
                Text("AI 智能化配置")
                    .font(.headline)
                    .foregroundColor(.nearTextPrimary)
            }
            
            VStack(spacing: 12) {
                SettingsInputRow(icon: "link", title: "API 地址", placeholder: "https://api.openai.com/v1", text: $baseURL)
                SettingsInputRow(icon: "key", title: "API 密钥", placeholder: "sk-...", text: $apiKey, isSecure: true)
                SettingsInputRow(icon: "cube", title: "模型名称", placeholder: "gpt-4", text: $model)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("系统提示词")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.nearTextSecondary)
                        Spacer()
                        Button(action: { withAnimation { showExpandedEditor = true } }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12))
                                .foregroundColor(.nearPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    TextEditor(text: $systemPrompt)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(height: 120)
                        .padding(4)
                        .background(Color(hex: "#F8FAFC"))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.nearTextSecondary.opacity(0.1), lineWidth: 1))
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            HStack(spacing: 12) {
                Button(action: testConnection) {
                    HStack {
                        if isTesting { ProgressView().scaleEffect(0.6).frame(width: 16, height: 16) }
                        else { Image(systemName: "network") }
                        Text("测试连接")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.nearTextPrimary)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.nearTextSecondary.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain).disabled(isTesting)
                
                Button(action: saveAISettings) {
                    Text("保存 AI 配置")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(Color.nearPrimary).cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            
            if let message = testMessage {
                Text(message).font(.caption).foregroundColor(message.contains("成功") ? .green : .red)
            }
        }
    }
    
    private var weatherConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.orange)
                Text("天气服务精化")
                    .font(.headline)
                    .foregroundColor(.nearTextPrimary)
            }
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsInputRow(icon: "key", title: "API Key", placeholder: "填入您的 API Key", text: $qWeatherKey, isSecure: true)
                    
                    SettingsInputRow(icon: "globe", title: "API Host", placeholder: "https://devapi.qweather.com/v7", text: $qWeatherHost)
                    
                    SettingsInputRow(icon: "lock.shield", title: "WAQI Token", placeholder: "入您的 WAQI Token", text: $waqiToken, isSecure: true)
                    
                    HStack {
                        Button(action: testWeatherConnection) {
                            HStack {
                                if isTestingWeather { ProgressView().scaleEffect(0.5) }
                                else { Image(systemName: "checkmark.shield") }
                                Text("测试 Key")
                            }
                            .font(.system(size: 12))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(isTestingWeather || qWeatherKey.isEmpty)
                        
                        if let msg = weatherTestMessage {
                            Text(msg)
                                .font(.system(size: 10))
                                .foregroundColor(msg.contains("成功") ? .green : .red)
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("地域维护")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.nearTextSecondary)
                    
                    // Highlighted Current Location
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("当前选定地域")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.8))
                            Text(storageManager.qWeatherLocationName)
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Image(systemName: "location.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [.nearPrimary, .nearPrimary.opacity(0.8)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(12)
                    .shadow(color: Color.nearPrimary.opacity(0.3), radius: 8, x: 0, y: 4)

                    HStack {
                        TextField("搜索城市 (如: 济南)", text: $locationSearchQuery)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(10)
                            .background(Color(hex: "#F1F5F9"))
                            .cornerRadius(8)
                        
                        Button(action: searchLocations) {
                            if isSearching {
                                ProgressView().scaleEffect(0.6).frame(width: 36, height: 36)
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .padding(10)
                                    .background(Color.nearPrimary)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(locationSearchQuery.isEmpty || isSearching)
                    }
                    
                    if let msg = weatherTestMessage {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(msg.contains("成功") ? .green : .red)
                            .padding(.horizontal, 4)
                    }
                    
                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("搜索建议")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            ScrollView {
                                VStack(spacing: 4) {
                                    ForEach(searchResults) { loc in
                                        Button(action: {
                                            storageManager.qWeatherLocationId = loc.id
                                            storageManager.qWeatherLocationName = loc.name
                                            // Save coordinates for minutely API
                                            UserDefaults.standard.set(loc.lon, forKey: "qWeatherLon")
                                            UserDefaults.standard.set(loc.lat, forKey: "qWeatherLat")
                                            
                                            storageManager.saveQWeatherKey()
                                            searchResults = []
                                            locationSearchQuery = ""
                                            weatherService.fetchWeather()
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack(alignment: .firstTextBaseline) {
                                                        Text(loc.name).font(.system(size: 14, weight: .bold))
                                                        Text(loc.type == "city" ? "城市" : loc.type).font(.system(size: 10)).padding(.horizontal, 4).background(Color.blue.opacity(0.1)).cornerRadius(4)
                                                    }
                                                    Text("\(loc.adm2), \(loc.adm1), \(loc.country)").font(.system(size: 11)).foregroundColor(.secondary)
                                                    HStack(spacing: 12) {
                                                        Label("\(loc.lat), \(loc.lon)", systemImage: "mappin.and.ellipse")
                                                        if let tz = loc.tz {
                                                            Label(tz, systemImage: "clock")
                                                        }
                                                    }
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.nearTextLight)
                                                }
                                                Spacer()
                                                if storageManager.qWeatherLocationId == loc.id {
                                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                                }
                                            }
                                            .padding(12)
                                            .background(storageManager.qWeatherLocationId == loc.id ? Color.nearPrimary.opacity(0.05) : Color.white)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(storageManager.qWeatherLocationId == loc.id ? Color.nearPrimary.opacity(0.2) : Color.clear, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(2)
                            }
                            .frame(maxHeight: 280) // Control height to prevent overflow
                            .background(Color(hex: "#F8FAFC"))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            Button(action: saveWeatherSettings) {
                Text("保存天气配置")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(Color.orange).cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
    
    private var petSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(.nearPrimary)
                Text("桌面宠物设置")
                    .font(.headline)
            }
            
            VStack(spacing: 0) {
                Toggle(isOn: $isPetSelfAwarenessEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("自我意识 (随机漫步)")
                            .font(.system(size: 14, weight: .medium))
                        Text("开启后，它会偶尔在桌面自由散步并自言自语。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .nearPrimary))
                .padding(.vertical, 16)
                
                Divider()
                
                Toggle(isOn: $isPetSystemAwarenessEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("系统感知 (负载反馈)")
                            .font(.system(size: 14, weight: .medium))
                        Text("根据 CPU 负载改变光环颜色并给出贴心提醒。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .nearPrimary))
                .padding(.vertical, 16)
                
                Divider()
                
                Toggle(isOn: $isPetIntentAwarenessEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("操作感知 (趣味互动)")
                                .font(.system(size: 14, weight: .medium))
                            Spacer()
                            if isPetIntentAwarenessEnabled {
                                Button(action: {
                                    UserIntentMonitor.shared.openLogFolder()
                                }) {
                                    Label("查看日志", systemImage: "folder")
                                        .font(.system(size: 11))
                                        .foregroundColor(.nearPrimary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("感知应用切换与操作频率，开启拟人化调侃互动。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .nearPrimary))
                .padding(.vertical, 16)
                
                if isPetIntentAwarenessEnabled && !isAccessibilityGranted {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("需要辅助功能权限")
                                .font(.system(size: 11, weight: .bold))
                        }
                        
                        Text("为了统计操作频率以实现更精准的互动，请在系统设置中授予 Near 辅助功能权限。")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            UserIntentMonitor.shared.requestAccessibility()
                        }) {
                            Text("去开启权限")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.nearPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.nearPrimary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.bottom, 16)
                }
                
                Divider()
                
                // 健康提醒设置
                Toggle(isOn: $isHealthReminderEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("健康助手 (饮水/站立)")
                            .font(.system(size: 14, weight: .medium))
                        Text("每隔一小时提醒您喝水或站立，并在 17:30 提供今日健康总结。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .nearPrimary))
                .padding(.vertical, 16)
                
                if isHealthReminderEnabled {
                    HStack(spacing: 12) {
                        Button(action: { PetManager.shared.triggerTestReminder(type: "water") }) {
                            Label("测试喝水提醒", systemImage: "drop.fill")
                                .font(.system(size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                        
                        Button(action: { PetManager.shared.triggerTestReminder(type: "stand") }) {
                            Label("测试站立提醒", systemImage: "figure.stand")
                                .font(.system(size: 10))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.green)
                        
                        Spacer()
                    }
                    .padding(.bottom, 12)
                    .padding(.leading, 4)
                }
            }
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            Button(action: savePetSettings) {
                Text("保存设置")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 40)
                    .background(Color.nearPrimary).cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .onAppear {
            self.checkAccessibilityStatus()
        }
    }
    
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // General Info
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "app.badge.fill")
                        .foregroundColor(.nearPrimary)
                    Text("应用信息")
                        .font(.headline)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("v1.2.0")
                            .foregroundColor(.nearTextSecondary)
                    }
                    Divider()
                    HStack {
                        Text("开发者")
                        Spacer()
                        Text("Near Creative")
                            .foregroundColor(.nearTextSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        devClickCount += 1
                        if devClickCount >= 10 {
                            isDebugMode.toggle()
                            devClickCount = 0
                            // Reset tab if hiding logs
                            if !isDebugMode && selectedTab == 3 {
                                selectedTab = 0
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            
            // Other settings could go here
            VStack(alignment: .leading, spacing: 12) {
                Text("其他说明")
                    .font(.headline)
                Text("Near 是一款致力于通过极简设计提供倒计时与生活资讯的智能桌面助理。")
                    .font(.system(size: 13))
                    .foregroundColor(.nearTextSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.4))
                    .cornerRadius(12)
            }
        }
    }

    private var debugLogSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.nearPrimary)
                Text("运行日志 (Debug)")
                    .font(.headline)
                    .foregroundColor(.nearTextPrimary)
                Spacer()
                
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logManager.logs, forType: .string)
                }) {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.nearPrimary.opacity(0.1))
                .cornerRadius(6)
            }
            
            ScrollView {
                Text(logManager.logs.isEmpty ? "暂无日志数据..." : logManager.logs)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.nearTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
            .frame(height: 350)
            .background(Color(hex: "#F8FAFC"))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.nearTextSecondary.opacity(0.1), lineWidth: 1))
            
            HStack(spacing: 12) {
                Button(action: {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.plainText]
                    panel.nameFieldStringValue = "near_weather_logs.txt"
                    if panel.runModal() == .OK, let url = panel.url {
                        try? logManager.logs.write(to: url, atomically: true, encoding: .utf8)
                    }
                }) {
                    Label("导出日志", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .frame(height: 36)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.nearTextSecondary.opacity(0.2), lineWidth: 1))
                
                Button(action: { logManager.clear() }) {
                    Label("清空日志", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .frame(height: 36)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(8)
            }
        }
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