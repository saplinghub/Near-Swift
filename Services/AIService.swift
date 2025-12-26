import Foundation
import Combine

class AIService: ObservableObject {
    @Published var config: AIConfig
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var storageManager: StorageManager
    
    static let defaultSystemPrompt = """
        你是一个智能倒计时事件解析助手。当前时间：{YEAR}年{MONTH}月{DAY}日。

        规则：
        1. 理解用户意图，自动计算时间并生成合适的事件名称
        2. 返回JSON：{"name":"事件名称","date":"YYYY-MM-DD HH:mm","startDate":"YYYY-MM-DD","icon":"iconKey"}
        3. startDate 是事件开始时间，date 是目标时间
        4. icon 必须从以下列表中选择最匹配的一个（默认为 star）：
           [star, leaf, headphones, code, gift, birthday, travel, work, anniversary, game, sports, study, shopping]
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

            let calendar = SharedUtils.calendar
            let now = SharedUtils.now
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
            
            let body: [String: Any] = [
                "model": self.config.model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": "解析倒计时事件：\(input)"]
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
                    var cleanContent = content
                    if cleanContent.contains("```json") {
                        cleanContent = cleanContent.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                    }
                    return cleanContent.data(using: .utf8) ?? Data()
                }
                .decode(type: AIContentResponse.self, decoder: JSONDecoder())
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
    
    func analyzeLogs(content: String, logType: String) -> AnyPublisher<String, Error> {
        isLoading = true
        errorMessage = nil
        
        return Future<String, Error> { promise in
            guard let url = URL(string: "\(self.config.baseURL)/chat/completions") else {
                self.isLoading = false
                promise(.failure(NSError(domain: "Invalid URL", code: 0)))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(self.config.apiKey)", forHTTPHeaderField: "Authorization")
            
            let systemPrompt = "你是一个桌宠助手，请分析用户的「\(logType)」日志并给出 30 字以内的毒舌点评。"
            let body: [String: Any] = [
                "model": self.config.model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": "请分析日志：\n\(content.prefix(3000))"]
                ],
                "temperature": 0.5
            ]
            
            do { request.httpBody = try JSONSerialization.data(withJSONObject: body) } catch {
                self.isLoading = false
                promise(.failure(error))
                return
            }
            
            URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { data, _ in data }
                .decode(type: OpenAIChatResponse.self, decoder: JSONDecoder())
                .map { $0.choices.first?.message.content ?? "分析失败" }
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        self.isLoading = false
                        if case .failure(let error) = completion { promise(.failure(error)) }
                    },
                    receiveValue: { result in promise(.success(result)) }
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
    
    func fetchAlmanac(date: Date) -> AnyPublisher<AlmanacResponse, Error> {
        let dateStr = SharedUtils.dateFormatter(format: "yyyy-MM-dd").string(from: date)
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
            
            let systemPrompt = "你是一个专业的中国传统黄历助手。今天是 \(dateStr)。请返回 JSON：{\"date\":\"\(dateStr)\",\"lunarDate\":\"...\",\"yi\":\"...\",\"ji\":\"...\",\"fortune\":\"...\"}"
            let body: [String: Any] = [
                "model": self.config.model,
                "messages": [["role": "system", "content": systemPrompt], ["role": "user", "content": "生成今日黄历"]],
                "temperature": 0.7
            ]
            
            do { request.httpBody = try JSONSerialization.data(withJSONObject: body) } catch {
                self.isLoading = false
                promise(.failure(error))
                return
            }
            
            URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { $0.data }
                .decode(type: OpenAIChatResponse.self, decoder: JSONDecoder())
                .tryMap { response -> Data in
                    let content = response.choices.first?.message.content ?? ""
                    let clean = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                    return clean.data(using: .utf8) ?? Data()
                }
                .decode(type: AlmanacResponse.self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        self.isLoading = false
                        if case .failure(let error) = completion { promise(.failure(error)) }
                    },
                    receiveValue: { promise(.success($0)) }
                )
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
}