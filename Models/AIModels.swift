import Foundation

struct AIConfig: Codable {
    var baseURL: String
    var apiKey: String
    var model: String
    var systemPrompt: String? // Added custom system prompt

    static func createDefault() -> AIConfig {
        AIConfig(
            baseURL: "https://x666.me/v1",
            apiKey: "",
            model: "gpt-4.1-mini",
            systemPrompt: nil // Default to nil, will use built-in default if nil
        )
    }

    func isValid() -> Bool {
        !baseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty
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
            yi: "",
            ji: "",
            fortune: ""
        )
    }

    func toCountdownEvent() -> CountdownEvent? {
        let formatter = SharedUtils.dateFormatter(format: "yyyy-MM-dd")
        // Also support ISO format with time if AI provides it
        // For simplicity, sticking to yyyy-MM-dd or yyyy-MM-dd HH:mm 
        
        // Intelligent date parsing (simple version)
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
        
        // Icon parsing
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
    let yi: String // Suitable
    let ji: String // Unsuitable
    let fortune: String // Daily Fortune
}