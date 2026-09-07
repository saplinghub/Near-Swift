import Foundation

/// AI 接口格式：统一收敛为两大类
enum AIFormat: String, Codable, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"

    var id: String { rawValue }

    /// 兼容历史存储值：
    /// - "OneAPI" 为 OpenAI 兼容网关 → .openAI
    /// - "智谱" 走 Anthropic 兼容接口 → .anthropic
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "OneAPI", "oneAPI", "OpenAI", "openAI", "openai":
            self = .openAI
        case "智谱", "zhipu", "Anthropic", "anthropic":
            self = .anthropic
        default:
            self = .openAI
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// OpenAI 格式下的具体 API 形态
enum OpenAIEndpoint: String, Codable, CaseIterable, Identifiable {
    case chatCompletions = "Chat Completions"
    case responses = "Responses API"

    var id: String { rawValue }
}

struct AIConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var format: AIFormat
    /// OpenAI 格式下选择 Chat Completions 还是 Responses API（仅 format == .openAI 时生效）
    var openAIEndpoint: OpenAIEndpoint
    /// 是否禁用思考（默认 true，即默认关闭思考）
    var disableThinking: Bool
    var baseURL: String
    var apiKey: String
    var model: String
    var systemPrompt: String?

    init(id: UUID = UUID(),
         name: String,
         format: AIFormat,
         openAIEndpoint: OpenAIEndpoint = .chatCompletions,
         disableThinking: Bool = true,
         baseURL: String,
         apiKey: String,
         model: String,
         systemPrompt: String? = nil) {
        self.id = id
        self.name = name
        self.format = format
        self.openAIEndpoint = openAIEndpoint
        self.disableThinking = disableThinking
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.systemPrompt = systemPrompt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, format, openAIEndpoint, disableThinking, baseURL, apiKey, model, systemPrompt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "默认配置"
        self.format = try container.decodeIfPresent(AIFormat.self, forKey: .format) ?? .openAI
        self.openAIEndpoint = try container.decodeIfPresent(OpenAIEndpoint.self, forKey: .openAIEndpoint) ?? .chatCompletions
        self.disableThinking = try container.decodeIfPresent(Bool.self, forKey: .disableThinking) ?? true
        self.baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        self.systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(format, forKey: .format)
        try container.encode(openAIEndpoint, forKey: .openAIEndpoint)
        try container.encode(disableThinking, forKey: .disableThinking)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(apiKey, forKey: .apiKey)
        try container.encode(model, forKey: .model)
        try container.encodeIfPresent(systemPrompt, forKey: .systemPrompt)
    }

    static func createDefault() -> AIConfig {
        AIConfig(
            id: UUID(),
            name: "OpenAI 默认",
            format: .openAI,
            openAIEndpoint: .chatCompletions,
            disableThinking: true,
            baseURL: "",
            apiKey: "",
            model: "",
            systemPrompt: ""
        )
    }

    func isValid() -> Bool {
        !baseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty
    }

    /// 根据格式给出默认 Base URL（用户未填写时使用）
    var defaultBaseURL: String {
        switch format {
        case .anthropic:
            return "https://api.anthropic.com"
        case .openAI:
            return "https://api.openai.com/v1"
        }
    }

    /// 请求路径（不含 host）
    var requestPath: String {
        switch format {
        case .anthropic:
            return "/v1/messages"
        case .openAI:
            return openAIEndpoint == .responses ? "/responses" : "/chat/completions"
        }
    }
}

struct AIStorage: Codable {
    var configs: [AIConfig]
    var activeID: UUID
    
    static func createDefault() -> AIStorage {
        let defaultConfig = AIConfig.createDefault()
        return AIStorage(configs: [defaultConfig], activeID: defaultConfig.id)
    }
}

// Wrapper for OpenAI Chat Completions Response
struct OpenAIChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String?
        }
        let message: Message?
        let delta: Message?
    }
    let choices: [Choice]?

    enum CodingKeys: String, CodingKey {
        case choices
    }

    var extractedText: String? {
        for choice in choices ?? [] {
            if let text = choice.message?.content, !text.isEmpty {
                return text
            }
            if let text = choice.delta?.content, !text.isEmpty {
                return text
            }
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.choices = (try? container.decode([Choice].self, forKey: .choices)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(choices, forKey: .choices)
    }
}

// Wrapper for OpenAI Responses API Response
struct OpenAIResponsesResponse: Codable {
    struct OutputItem: Codable {
        let type: String?
        let role: String?
        let content: [ContentItem]?
    }

    struct ContentItem: Codable {
        let type: String?
        let text: String?

        enum CodingKeys: String, CodingKey {
            case type, text
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Responses API 中正文条目类型为 "output_text"，兼容网关返回的 "text"
            self.type = try container.decodeIfPresent(String.self, forKey: .type)
            self.text = try container.decodeIfPresent(String.self, forKey: .text)
        }
    }

    let output: [OutputItem]?
    let text: String? // 部分网关直接返回顶层 text

    enum CodingKeys: String, CodingKey {
        case output, text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.output = try container.decodeIfPresent([OutputItem].self, forKey: .output)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
    }

    /// 提取首个 message 输出中的文本
    func extractText() -> String? {
        if let text = text, !text.isEmpty { return text }
        guard let output = output else { return nil }
        for item in output {
            guard item.type == "message" || item.role == "assistant" else { continue }
            let parts = (item.content ?? []).compactMap { $0.text }
            let joined = parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { return joined }
        }
        return nil
    }
}

// Wrapper for Anthropic API Response
struct AnthropicChatResponse: Codable {
    struct Content: Codable {
        let text: String
    }

    // Handle content that may be:
    // 1. [{"type": "text", "text": "..."}]
    // 2. [{"type": "thinking", "thinking": "..."}, {"type": "text", "text": "..."}] (MiniMax)
    // 3. [{"type": "text", "text": "..."}] (standard)
    // 4. "direct string"
    let content: [Content]?

    enum CodingKeys: String, CodingKey {
        case content
    }

    enum RawContentItem: Codable {
        case text(String)
        case thinking(String)
        case unknown

        enum CodingKeys: String, CodingKey {
            case type, text, thinking
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decodeIfPresent(String.self, forKey: .type)
            switch type {
            case "text":
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            case "thinking":
                if let thinking = try? container.decode(String.self, forKey: .thinking) {
                    self = .thinking(thinking)
                } else {
                    self = .unknown
                }
            default:
                self = .unknown
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let s):
                try container.encode("text", forKey: .type)
                try container.encode(s, forKey: .text)
            case .thinking(let s):
                try container.encode("thinking", forKey: .type)
                try container.encode(s, forKey: .thinking)
            case .unknown:
                try container.encode("unknown", forKey: .type)
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode as [Content] directly
        if let contentArray = try? container.decode([Content].self, forKey: .content) {
            self.content = contentArray
            return
        }

        // Try: decode as array of raw items and extract text (or thinking as fallback)
        if let rawItems = try? container.decode([RawContentItem].self, forKey: .content) {
            var texts: [Content] = []
            var thinkingTexts: [String] = []
            for item in rawItems {
                switch item {
                case .text(let s):
                    texts.append(Content(text: s))
                case .thinking(let s):
                    thinkingTexts.append(s)
                default:
                    break
                }
            }
            // If no text found but thinking exists, use thinking as fallback
            if texts.isEmpty && !thinkingTexts.isEmpty {
                texts = thinkingTexts.map { Content(text: $0) }
            }
            self.content = texts.isEmpty ? nil : texts
            return
        }

        // Fallback: try to decode as plain string
        if let contentString = try? container.decode(String.self, forKey: .content) {
            self.content = [Content(text: contentString)]
            return
        }

        self.content = nil
    }
}

// The actual content we expect from the AI
struct AIContentResponse: Codable {
    let name: String
    let date: String
    let startDate: String?
    let icon: String? // Added icon suggestion

    func toCountdownEvent() -> CountdownEvent? {
        let formatter = SharedUtils.dateFormatter(format: "yyyy-MM-dd")
        var targetDate = formatter.date(from: date)
        if targetDate == nil {
            targetDate = SharedUtils.dateFormatter(format: "yyyy-MM-dd HH:mm").date(from: date)
        }
        
        guard let finalTargetDate = targetDate else { return nil }

        let startDateValue: Date
        if let startDateStr = startDate {
            if let parsedStartDateWithTime = SharedUtils.dateFormatter(format: "yyyy-MM-dd HH:mm").date(from: startDateStr) {
                startDateValue = parsedStartDateWithTime
            } else if let parsedStartDate = SharedUtils.dateFormatter(format: "yyyy-MM-dd").date(from: startDateStr) {
                startDateValue = parsedStartDate
            } else {
                startDateValue = SharedUtils.now
            }
        } else {
            startDateValue = SharedUtils.now
        }
        
        var iconType: IconType = .star
        if let iconName = icon, let matched = IconType(rawValue: iconName.lowercased()) {
            iconType = matched
        }

        return CountdownEvent(
            id: UUID(),
            name: name,
            startDate: startDateValue,
            targetDate: finalTargetDate,
            icon: iconType,
            isPinned: false,
            order: 0
        )
    }
}

// Almanac Response from AI
struct AlmanacResponse: Codable {
    let date: String
    let lunarDate: String
    let ganZhi: String
    let weekday: String
    let chongSha: String
    let yi: String // Suitable
    let ji: String // Unsuitable
    let jiShen: String
    let xiongSha: String
    let zhiShen: String
    let pengZu: String
    let fortune: String // Daily Fortune
    let luckyColor: String
    let luckyNumber: String
    let luckyDirection: String

    enum CodingKeys: String, CodingKey {
        case date, lunarDate, ganZhi, weekday, chongSha, yi, ji, jiShen, xiongSha, zhiShen, pengZu, fortune, luckyColor, luckyNumber, luckyDirection
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.date = try container.decode(String.self, forKey: .date)
        self.lunarDate = try container.decode(String.self, forKey: .lunarDate)
        self.weekday = try container.decode(String.self, forKey: .weekday)
        self.chongSha = try container.decode(String.self, forKey: .chongSha)
        self.yi = try container.decode(String.self, forKey: .yi)
        self.ji = try container.decode(String.self, forKey: .ji)
        self.jiShen = try container.decode(String.self, forKey: .jiShen)
        self.xiongSha = try container.decode(String.self, forKey: .xiongSha)
        self.zhiShen = try container.decode(String.self, forKey: .zhiShen)
        self.pengZu = try container.decode(String.self, forKey: .pengZu)
        self.fortune = try container.decode(String.self, forKey: .fortune)
        self.luckyColor = try container.decode(String.self, forKey: .luckyColor)
        self.luckyDirection = try container.decode(String.self, forKey: .luckyDirection)

        // Handle luckyNumber (String or Int)
        if let str = try? container.decode(String.self, forKey: .luckyNumber) {
            self.luckyNumber = str
        } else if let num = try? container.decode(Int.self, forKey: .luckyNumber) {
            self.luckyNumber = String(num)
        } else {
            self.luckyNumber = ""
        }

        // Handle ganZhi (String or Object)
        if let str = try? container.decode(String.self, forKey: .ganZhi) {
            self.ganZhi = str
        } else if let obj = try? container.decode([String: String].self, forKey: .ganZhi) {
            let year = obj["year"] ?? ""
            let month = obj["month"] ?? ""
            let day = obj["day"] ?? ""
            self.ganZhi = "\(year)年 \(month)月 \(day)日"
        } else {
            self.ganZhi = ""
        }
    }

    init(date: String, lunarDate: String, ganZhi: String, weekday: String, chongSha: String, yi: String, ji: String, jiShen: String, xiongSha: String, zhiShen: String, pengZu: String, fortune: String, luckyColor: String, luckyNumber: String, luckyDirection: String) {
        self.date = date
        self.lunarDate = lunarDate
        self.ganZhi = ganZhi
        self.weekday = weekday
        self.chongSha = chongSha
        self.yi = yi
        self.ji = ji
        self.jiShen = jiShen
        self.xiongSha = xiongSha
        self.zhiShen = zhiShen
        self.pengZu = pengZu
        self.fortune = fortune
        self.luckyColor = luckyColor
        self.luckyNumber = luckyNumber
        self.luckyDirection = luckyDirection
    }

    static func createEmpty() -> AlmanacResponse {
        let formatter = SharedUtils.dateFormatter(format: "yyyy-MM-dd")
        return AlmanacResponse(
            date: formatter.string(from: Date()),
            lunarDate: "",
            ganZhi: "",
            weekday: "",
            chongSha: "",
            yi: "",
            ji: "",
            jiShen: "",
            xiongSha: "",
            zhiShen: "",
            pengZu: "",
            fortune: "",
            luckyColor: "",
            luckyNumber: "",
            luckyDirection: ""
        )
    }
}
