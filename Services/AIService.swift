import Foundation
import Combine

class AIService: ObservableObject {
    @Published var config: AIConfig
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    private var storageManager: StorageManager
    
    // Default System Prompt (Static)
    static let defaultSystemPrompt = """
        你是一个智能倒计时事件解析助手。当前时间：{YEAR}年{MONTH}月{DAY}日。

        规则：
        1. 理解用户意图，自动计算时间并生成合适的事件名称
        2. 返回JSON：{"name":"事件名称","date":"YYYY-MM-DD HH:mm","startDate":"YYYY-MM-DD","icon":"iconKey"}
        3. startDate 是事件开始时间，date 是目标时间
        4. icon 必须从以下列表中选择最匹配的一个（默认为 star）：
           [star, leaf, headphones, code, gift, birthday, travel, work, anniversary, game, sports, study, shopping]
           - 生日/纪念日 -> birthday/anniversary/gift
           - 工作/上线 -> work/code
           - 旅游/假期 -> travel/leaf
           - 学习/考试 -> study/book

        示例：
        - "过年倒计时" → name:"春节倒计时🧧", startDate:现在, date:{NEXT_YEAR}-01-29 00:00, icon:"leaf"
        - "今年的进度" → name:"{YEAR}年进度📊", startDate:{YEAR}-01-01, date:{YEAR}-12-31 23:59, icon:"star"
        - "高考倒计时" → name:"高考加油💪", startDate:现在, date:{YEAR}-06-07 09:00, icon:"study"
        - "下周五下午3点项目上线" → name:"项目上线🚀", startDate:现在, date:计算下周五15:00, icon:"code"
        - "距离生日还有多久" → name:"生日快乐🎂", startDate:现在, date:今年生日或明年生日, icon:"birthday"

        要求：
        - 事件名称简洁有趣，可加emoji
        - 自动推断合理的时间
        - 如果是进度类（如"今年进度"），startDate设为起点时间
        - 如果是倒计时类，startDate设为当前时间
        """
    
    init(storageManager: StorageManager) {
        self.storageManager = storageManager
        self.config = storageManager.aiConfig
    }

    func parseCountdown(input: String) -> AnyPublisher<CountdownEvent?, Error> {
        isLoading = true
        errorMessage = nil

        return Future<CountdownEvent?, Error> { promise in
            guard let url = URL(string: "\(self.config.baseURL)/chat/completions") else {
                self.isLoading = false
                promise(.failure(NSError(domain: "Invalid URL", code: 0)))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(self.config.apiKey)", forHTTPHeaderField: "Authorization")

            let calendar = Calendar.current
            let now = Date()
            let year = String(calendar.component(.year, from: now))
            let month = String(calendar.component(.month, from: now))
            let day = String(calendar.component(.day, from: now))
            let nextYear = String(calendar.component(.year, from: now) + 1)
            
            let systemPrompt: String
            if let custom = self.config.systemPrompt, !custom.isEmpty {
                 systemPrompt = custom
                    .replacingOccurrences(of: "{YEAR}", with: year)
                    .replacingOccurrences(of: "{MONTH}", with: month)
                    .replacingOccurrences(of: "{DAY}", with: day)
                    .replacingOccurrences(of: "{NEXT_YEAR}", with: nextYear)
            } else {
                systemPrompt = AIService.defaultSystemPrompt
                    .replacingOccurrences(of: "{YEAR}", with: year)
                    .replacingOccurrences(of: "{MONTH}", with: month)
                    .replacingOccurrences(of: "{DAY}", with: day)
                    .replacingOccurrences(of: "{NEXT_YEAR}", with: nextYear)
            }
            
            // Build Prompt
            let finalUserPrompt = "解析倒计时事件：\(input)"

            let body: [String: Any] = [
                "model": self.config.model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": finalUserPrompt]
                ],
                "temperature": 0.3
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                self.isLoading = false
                self.errorMessage = "JSON 序列化失败"
                promise(.failure(error))
                return
            }

            URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { data, response -> Data in
                    guard let httpResponse = response as? HTTPURLResponse else {
                         throw URLError(.badServerResponse)
                    }
                    if httpResponse.statusCode != 200 {
                        if let str = String(data: data, encoding: .utf8) {
                            print("API Error: \(str)")
                        }
                         throw URLError(.badServerResponse)
                    }
                    return data
                }
                .decode(type: OpenAIChatResponse.self, decoder: JSONDecoder())
                .tryMap { response -> AIContentResponse in
                    guard let content = response.choices.first?.message.content else {
                         throw NSError(domain: "AI Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
                    }
                    var cleanContent = content
                    if cleanContent.contains("```json") {
                        cleanContent = cleanContent.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                    }
                    
                    guard let data = cleanContent.data(using: .utf8) else {
                        throw NSError(domain: "AI Error", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid string encoding"])
                    }
                    
                    return try JSONDecoder().decode(AIContentResponse.self, from: data)
                }
                .map { $0.toCountdownEvent() }
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            self.errorMessage = "解析失败: \(error.localizedDescription)"
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { countdown in
                        promise(.success(countdown))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }

    func testConnection() -> AnyPublisher<Bool, Never> {
        isLoading = true
        errorMessage = nil

        return Future<Bool, Never> { promise in
            self.parseCountdown(input: "测试倒计时")
                .sink(
                    receiveCompletion: { _ in
                        self.isLoading = false
                    },
                    receiveValue: { _ in
                        promise(.success(true))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Almanac (Huangli)
    func fetchAlmanac(date: Date) -> AnyPublisher<AlmanacResponse, Error> {
        // Cache Key
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        // Return cached if available (avoiding extra AI calls)
        // Note: For now, I'll rely on the caller to handle caching or just always fetch if explicit.
        // User asked for "Refresh" button, so we should support fetch.
        
        isLoading = true
        errorMessage = nil
        
        return Future<AlmanacResponse, Error> { promise in
            guard let url = URL(string: "\(self.config.baseURL)/chat/completions") else {
                self.isLoading = false
                promise(.failure(NSError(domain: "Invalid URL", code: 0)))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(self.config.apiKey)", forHTTPHeaderField: "Authorization")
            
            let systemPrompt = """
            你是一个专业的中国传统黄历和运势助手。今天是 \(dateString)。
            请返回今天的黄历信息，内容要符合中国传统黄历习惯。
            JSON格式：
            {
                "date": "\(dateString)",
                "lunarDate": "农历xx月xx (如：腊月初八)",
                "yi": "宜：嫁娶、出行、祈福、开业等 (4-5项，用顿号分隔)",
                "ji": "忌：动土、安葬、破土、诸事不宜等 (4-5项，用顿号分隔)",
                "fortune": "今日运势详解 (2-3句话，包含事业、感情或健康方面的建议，语气积极温暖)"
            }
            不要包含markdown格式，只返回纯JSON。
            """
            
            let body: [String: Any] = [
                "model": self.config.model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": "请生成今日黄历"]
                ],
                "temperature": 0.7 // Slightly creative for fortune
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                self.isLoading = false
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
                .tryMap { response -> AlmanacResponse in
                    guard let content = response.choices.first?.message.content else {
                         throw NSError(domain: "AI Error", code: -1)
                    }
                    var cleanContent = content
                    if cleanContent.contains("```json") {
                        cleanContent = cleanContent.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                    }
                    
                    guard let data = cleanContent.data(using: .utf8) else {
                        throw NSError(domain: "AI Error", code: -2)
                    }
                    
                    return try JSONDecoder().decode(AlmanacResponse.self, from: data)
                }
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            self.errorMessage = "黄历获取失败: \(error.localizedDescription)"
                            promise(.failure(error))
                        }
                    },
                    receiveValue: { almanac in
                        promise(.success(almanac))
                    }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
}