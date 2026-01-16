import Foundation

enum AIFormat: String, Codable, CaseIterable {
    case groq = "Groq"
    case oneAPI = "OneAPI"
}

struct AIConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var format: AIFormat
    var baseURL: String
    var apiKey: String
    var model: String
    var systemPrompt: String?

    init(id: UUID = UUID(), name: String, format: AIFormat, baseURL: String, apiKey: String, model: String, systemPrompt: String? = nil) {
        self.id = id
        self.name = name
        self.format = format
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.systemPrompt = systemPrompt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, format, baseURL, apiKey, model, systemPrompt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "默认配置"
        self.format = try container.decodeIfPresent(AIFormat.self, forKey: .format) ?? .groq
        self.baseURL = try container.decode(String.self, forKey: .baseURL)
        self.apiKey = try container.decode(String.self, forKey: .apiKey)
        self.model = try container.decode(String.self, forKey: .model)
        self.systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt)
    }

    static func createDefault() -> AIConfig {
        AIConfig(
            id: UUID(),
            name: "Groq 默认",
            format: .groq,
            baseURL: "https://api.groq.com/openai/v1",
            apiKey: "",
            model: "llama-3.3-70b-versatile",
            systemPrompt: ""
        )
    }

    func isValid() -> Bool {
        !baseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty
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

// Wrapper for OpenAI API Response
struct OpenAIChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

// The actual content we expect from the AI
struct AIContentResponse: Codable {
    let name: String
    let date: String
    let startDate: String?
    let icon: String? // Added icon suggestion

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

    func toCountdownEvent() -> CountdownEvent? {
        let formatter = SharedUtils.dateFormatter(format: "yyyy-MM-dd")
        var targetDate = formatter.date(from: date)
        if targetDate == nil {
            targetDate = SharedUtils.dateFormatter(format: "yyyy-MM-dd HH:mm").date(from: date)
        }
        
        guard let finalTargetDate = targetDate else { return nil }

        let startDateValue: Date
        if let startDateStr = startDate, let parsedStartDate = SharedUtils.dateFormatter(format: "yyyy-MM-dd").date(from: startDateStr) {
            startDateValue = parsedStartDate
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