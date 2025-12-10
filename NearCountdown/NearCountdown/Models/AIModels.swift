import Foundation

struct AIConfig: Codable {
    var baseURL: String
    var apiKey: String
    var model: String

    static func createDefault() -> AIConfig {
        AIConfig(
            baseURL: "https://api.openai.com/v1",
            apiKey: "",
            model: "gpt-3.5-turbo"
        )
    }

    func isValid() -> Bool {
        !baseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty
    }
}

struct AIResponse: Codable {
    let name: String
    let date: String
    let startDate: String?

    func toCountdownEvent() -> CountdownEvent? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let targetDate = formatter.date(from: date) else { return nil }

        let startDateValue: Date
        if let startDateStr = startDate, let parsedStartDate = formatter.date(from: startDateStr) {
            startDateValue = parsedStartDate
        } else {
            startDateValue = Date()
        }

        return CountdownEvent(
            id: UUID(),
            name: name,
            startDate: startDateValue,
            targetDate: targetDate,
            icon: .rocket,
            isPinned: false,
            order: 0
        )
    }
}