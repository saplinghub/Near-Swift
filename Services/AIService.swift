import Foundation
import Combine

class AIService: ObservableObject {
    private let storageManager: StorageManager
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    
    static let defaultSystemPrompt = """
        你是一个智能倒计时事件解析助手。当前时间：{YEAR}年{MONTH}月{DAY}日。
        核心规则：
        1. 意图理解：智能识别事件类型，自动推算目标日期，并润色事件名称。
        2. 数据结构：必须严格返回以下 JSON 格式：
        {
        "name": "事件名称",
        "startDate": "YYYY-MM-DD",
        "date": "YYYY-MM-DD HH:mm",
        "icon": "iconKey"
        }
        3. 时间逻辑：
        - startDate：事件起始锚点。如果是进度类（如“今年进度”），设为起始日；如果是倒计时类，设为当前日期。
        - date：目标截止时间。需根据自然语言（如“下周五”）自动推算准确数值。
        4. 图标规范：必须从以下预设库中选择，禁止自定义：
        - [star, leaf, headphones, code, gift, birthday, travel, work, anniversary, game, sports, study, shopping]

        映射建议：
        - 生日/纪念日 -> birthday/anniversary/gift
        - 工作/上线/开发 -> work/code
        - 旅游/假期/户外 -> travel/leaf
        - 学习/考试/考研 -> study/book

        示例参考：
        - 用户：过年倒计时
        -> {"name":"春节倒计时🧧", "startDate":"2026-01-16", "date":"2027-01-29 00:00", "icon":"leaf"}
        - 用户：下周五下午3点项目上线
        -> {"name":"项目上线🚀", "startDate":"2026-01-16", "date":"2026-01-23 15:00", "icon":"code"}

        输出强制要求 (Strict Constraints)：
        1. 禁止包含 <think> 标签或任何推理过程。
        2. 禁止包含 Markdown 代码块标记（即不要用 ```json 开头）。
        3. 禁止包含 任何正文解释、前言或后记。
        4. 结果必须 是一个合法的、可直接通过 JSON.parse() 解析的纯字符串。
        """
    
    init(storageManager: StorageManager) {
        self.storageManager = storageManager
    }

    // MARK: - Countdown Events
    
    func parseCountdown(input: String) -> AnyPublisher<CountdownEvent?, Error> {
        self.isLoading = true
        errorMessage = nil

        return Future<CountdownEvent?, Error> { [weak self] promise in
            guard let self = self else { return }
            let activeConfig = self.storageManager.activeAIConfig
            let base = activeConfig.baseURL.isEmpty && activeConfig.format == .groq ? "https://api.groq.com/openai/v1" : activeConfig.baseURL
            guard let url = URL(string: "\(base)/chat/completions") else {
                self.isLoading = false
                promise(.failure(NSError(domain: "Invalid URL", code: 0)))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(activeConfig.apiKey)", forHTTPHeaderField: "Authorization")

            let currentYear = SharedUtils.dateFormatter(format: "yyyy").string(from: Date())
            let currentMonth = SharedUtils.dateFormatter(format: "MM").string(from: Date())
            let currentDay = SharedUtils.dateFormatter(format: "dd").string(from: Date())
            let nextYear = String((Int(currentYear) ?? 2024) + 1)
            
            var systemPrompt = activeConfig.systemPrompt ?? AIService.defaultSystemPrompt
            if systemPrompt.isEmpty { systemPrompt = AIService.defaultSystemPrompt }
            
            systemPrompt = systemPrompt
                .replacingOccurrences(of: "{YEAR}", with: currentYear)
                .replacingOccurrences(of: "{MONTH}", with: currentMonth)
                .replacingOccurrences(of: "{DAY}", with: currentDay)
                .replacingOccurrences(of: "{NEXT_YEAR}", with: nextYear)
            
            var body: [String: Any] = [
                "model": activeConfig.model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": "解析倒计时事件：\(input)"]
                ],
                "temperature": 0.3
            ]
            
            if activeConfig.format == .groq {
                body["include_reasoning"] = false
            }
            
            do {
                let bodyData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
                request.httpBody = bodyData
                if let bodyString = String(data: bodyData, encoding: .utf8) {
                    LogManager.shared.append("[AI Request] URL: \(url.absoluteString), Body: \(bodyString)")
                }
            } catch {
                self.isLoading = false
                self.errorMessage = "JSON 序列化失败"
                promise(.failure(error))
                return
            }

            URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { data, response -> Data in
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                         throw URLError(.badServerResponse)
                    }
                    return data
                }
                .decode(type: OpenAIChatResponse.self, decoder: JSONDecoder())
                .tryMap { response -> Data in
                    guard let content = response.choices.first?.message.content else {
                         throw NSError(domain: "AI Error", code: -1)
                    }
                    LogManager.shared.append("[AI Response] Content: \(content)")
                    let cleanedContent = self.cleanAIContent(content)
                    return cleanedContent.data(using: .utf8) ?? Data()
                }
                .decode(type: AIContentResponse.self, decoder: JSONDecoder())
                .map { $0.toCountdownEvent() }
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            LogManager.shared.append("[AI Error] Parse Countdown Failed: \(error.localizedDescription)")
                            self.errorMessage = "解析失败: \(error.localizedDescription)"
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { countdown in
                        LogManager.shared.append("[AI Response] Parse Countdown Success: \(countdown?.name ?? "nil")")
                        promise(.success(countdown))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    func analyzeLogs(content: String, logType: String) -> AnyPublisher<String, Error> {
        self.isLoading = true
        errorMessage = nil
        
        return Future<String, Error> { [weak self] promise in
            guard let self = self else { return }
            let activeConfig = self.storageManager.activeAIConfig
            let base = activeConfig.baseURL.isEmpty && activeConfig.format == .groq ? "https://api.groq.com/openai/v1" : activeConfig.baseURL
            guard let url = URL(string: "\(base)/chat/completions") else {
                self.isLoading = false
                promise(.failure(NSError(domain: "Invalid URL", code: 0)))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(activeConfig.apiKey)", forHTTPHeaderField: "Authorization")
            
            let systemPrompt = "你是一个桌宠助手，请分析用户的「\(logType)」日志并给出 30 字以内的毒舌点评。"
            var body: [String: Any] = [
                "model": activeConfig.model,
                "messages": [
                    ["role": "system", "content": systemPrompt + "\n重要：请直接返回点评内容，不要包含任何思考过程或额外解释。"],
                    ["role": "user", "content": "请分析日志：\n\(content.prefix(3000))"]
                ],
                "temperature": 0.5
            ]
            
            if activeConfig.format == .groq {
                body["include_reasoning"] = false
            }
            
            do { 
                let bodyData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
                request.httpBody = bodyData 
                if let bodyString = String(data: bodyData, encoding: .utf8) {
                    LogManager.shared.append("[AI Request] Log Analyze, Body: \(bodyString)")
                }
            } catch {
                self.isLoading = false
                promise(.failure(error))
                return
            }
            
            URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { data, _ in data }
                .decode(type: OpenAIChatResponse.self, decoder: JSONDecoder())
                .map { response in
                    let content = response.choices.first?.message.content ?? "分析失败"
                    return self.cleanAIContent(content)
                }
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        self.isLoading = false
                        if case .failure(let error) = completion { 
                            LogManager.shared.append("[AI Error] Log Analyze Failed: \(error.localizedDescription)")
                            promise(.failure(error)) 
                        }
                    },
                    receiveValue: { (result: String) in 
                        LogManager.shared.append("[AI Response] Log Analyze Success: \(result)")
                        promise(.success(result)) 
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }

    func testConnection() -> AnyPublisher<Bool, Never> {
        return parseCountdown(input: "测试")
            .map { _ in true }
            .replaceError(with: false)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func fetchAlmanac() -> AnyPublisher<AlmanacResponse, Error> {
        self.isLoading = true
        errorMessage = nil
        
        return Future<AlmanacResponse, Error> { [weak self] promise in
            guard let self = self else { return }
            let activeConfig = self.storageManager.activeAIConfig
            let base = activeConfig.baseURL.isEmpty && activeConfig.format == .groq ? "https://api.groq.com/openai/v1" : activeConfig.baseURL
            guard let url = URL(string: "\(base)/chat/completions") else {
                self.isLoading = false
                promise(.failure(NSError(domain: "Invalid URL", code: 0)))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(activeConfig.apiKey)", forHTTPHeaderField: "Authorization")
            
            let dateStr = SharedUtils.dateFormatter(format: "yyyy年MM月dd日").string(from: Date())
            let systemPrompt = """
            你是一位经验丰富的黄历解说师。今天是\(dateStr)，请以传统钦天监老黄历的风格，生成今日完整黄历，并附上温暖治愈的现代解读。
            
            你必须严格以 JSON 格式返回，且所有值必须为字符串 (String) 格式。包含以下字段：
            - date: 阳历 (yyyy-MM-dd)
            - lunarDate: 准确农历日期
            - ganZhi: 年月日干支 (单行字符串，如：乙亥年 丙子月 丁未日)
            - weekday: 星期X
            - chongSha: 冲XXX煞XXX
            - yi: 宜 (5-8项，用、分隔)
            - ji: 忌 (5-8项，用、分隔)
            - jiShen: 吉神 (2-4个)
            - xiongSha: 凶煞 (2-4个)
            - zhiShen: 值神
            - pengZu: 彭祖百忌
            - fortune: 今日运势箴言 (80-150字，古今结合，温暖治愈)
            - luckyColor: 幸运颜色
            - luckyNumber: 幸运数字 (字符串格式)
            - luckyDirection: 开运方位
            
            重要：直接返回 JSON，禁止包含 <think> 标签、Markdown 代码块或任何额外正文。确保 JSON 结构扁平，不要嵌套对象。
            """
            var body: [String: Any] = [
                "model": activeConfig.model,
                "messages": [["role": "system", "content": systemPrompt], ["role": "user", "content": "生成 \(dateStr) 的完整黄历"]],
                "temperature": 0.7
            ]
            
            if activeConfig.format == .groq {
                body["include_reasoning"] = false
            }
            
            do { 
                let bodyData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
                request.httpBody = bodyData 
                if let bodyString = String(data: bodyData, encoding: .utf8) {
                    LogManager.shared.append("[AI Request] Fetch Almanac, Body: \(bodyString)")
                }
            } catch {
                self.isLoading = false
                promise(.failure(error))
                return
            }
            
            URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { $0.data }
                .decode(type: OpenAIChatResponse.self, decoder: JSONDecoder())
                .tryMap { response -> Data in
                    let content = response.choices.first?.message.content ?? ""
                    LogManager.shared.append("[AI Response] Almanac Content: \(content)")
                    let cleaned = self.cleanAIContent(content)
                    return cleaned.data(using: .utf8) ?? Data()
                }
                .decode(type: AlmanacResponse.self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        self.isLoading = false
                        if case .failure(let error) = completion { 
                            LogManager.shared.append("[AI Error] Fetch Almanac Failed: \(error.localizedDescription)")
                            promise(.failure(error)) 
                        }
                    },
                    receiveValue: { 
                        LogManager.shared.append("[AI Response] Fetch Almanac Success")
                        promise(.success($0)) 
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    private func cleanAIContent(_ content: String) -> String {
        var cleaned = content
        
        // 1. Remove <think>...</think> tags and their content
        if let regex = try? NSRegularExpression(pattern: "<think>[\\s\\S]*?</think>", options: .caseInsensitive) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "")
        }
        
        // 2. Remove markdown code blocks
        if cleaned.contains("```json") {
            cleaned = cleaned.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        } else if cleaned.contains("```") {
            cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}