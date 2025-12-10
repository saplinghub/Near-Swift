import Foundation
import Combine

class AIService: ObservableObject {
    @Published var config: AIConfig
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init(config: AIConfig = AIConfig.createDefault()) {
        self.config = config
    }

    func parseCountdown(input: String) -> AnyPublisher<CountdownEvent?, Error> {
        isLoading = true
        errorMessage = nil

        let prompt = """
        解析倒计时事件：\(input)

        请返回 JSON 格式的响应，包含以下字段：
        - name: 事件名称
        - date: 目标日期 (YYYY-MM-DD)
        - startDate: 开始日期 (YYYY-MM-DD，可选，默认为今天)

        示例响应：
        {"name": "春节", "date": "2025-01-29", "startDate": "2025-01-01"}
        """

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

            let body = [
                "model": self.config.model,
                "messages": [
                    ["role": "user", "content": prompt]
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
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }
                    return data
                }
                .decode(type: AIResponse.self, decoder: JSONDecoder())
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
}