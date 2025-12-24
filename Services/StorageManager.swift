import Foundation

class StorageManager: ObservableObject {
    @Published var countdowns: [CountdownEvent] = []
    @Published var aiConfig: AIConfig = AIConfig.createDefault()
    @Published var qWeatherKey: String = ""
    @Published var qWeatherHost: String = "https://devapi.qweather.com/v7"
    @Published var qWeatherLocationId: String = "101010100" // Default: Beijing
    @Published var qWeatherLocationName: String = "北京"

    private let countdownsKey = "countdowns"
    private let aiConfigKey = "aiConfig"
    private let qWeatherKeyPath = "qWeatherKey"
    private let qWeatherHostPath = "qWeatherHost"
    private let qWeatherLocIdPath = "qWeatherLocId"
    private let qWeatherLocNamePath = "qWeatherLocName"

    init() {
        loadAll()
    }

    private func loadAll() {
        loadCountdowns()
        loadAIConfig()
        loadQWeatherKey()
    }

    private func loadCountdowns() {
        guard let data = UserDefaults.standard.data(forKey: countdownsKey) else { return }

        do {
            countdowns = try JSONDecoder().decode([CountdownEvent].self, from: data)
        } catch {
            print("Error loading countdowns: \(error)")
        }
    }

    private func loadAIConfig() {
        guard let data = UserDefaults.standard.data(forKey: aiConfigKey) else { return }

        do {
            aiConfig = try JSONDecoder().decode(AIConfig.self, from: data)
        } catch {
            print("Error loading AI config: \(error)")
        }
    }

    private func loadQWeatherKey() {
        qWeatherKey = UserDefaults.standard.string(forKey: qWeatherKeyPath) ?? ""
        qWeatherHost = UserDefaults.standard.string(forKey: qWeatherHostPath) ?? "https://devapi.qweather.com/v7"
        qWeatherLocationId = UserDefaults.standard.string(forKey: qWeatherLocIdPath) ?? "101010100"
        qWeatherLocationName = UserDefaults.standard.string(forKey: qWeatherLocNamePath) ?? "北京"
    }

    func saveQWeatherKey() {
        UserDefaults.standard.set(qWeatherKey, forKey: qWeatherKeyPath)
        UserDefaults.standard.set(qWeatherHost, forKey: qWeatherHostPath)
        UserDefaults.standard.set(qWeatherLocationId, forKey: qWeatherLocIdPath)
        UserDefaults.standard.set(qWeatherLocationName, forKey: qWeatherLocNamePath)
    }

    func saveCountdowns() {
        do {
            let data = try JSONEncoder().encode(countdowns)
            UserDefaults.standard.set(data, forKey: countdownsKey)
        } catch {
            print("Error saving countdowns: \(error)")
        }
    }
    
    func syncAll(_ countdowns: [CountdownEvent]) {
        self.countdowns = countdowns
        saveCountdowns()
    }

    func saveAIConfig() {
        do {
            let data = try JSONEncoder().encode(aiConfig)
            UserDefaults.standard.set(data, forKey: aiConfigKey)
        } catch {
            print("Error saving AI config: \(error)")
        }
    }

    func addCountdown(_ countdown: CountdownEvent) {
        countdowns.append(countdown)
        saveCountdowns()
    }

    func updateCountdown(_ countdown: CountdownEvent) {
        if let index = countdowns.firstIndex(where: { $0.id == countdown.id }) {
            countdowns[index] = countdown
            saveCountdowns()
        }
    }

    func deleteCountdown(_ id: UUID) {
        countdowns.removeAll { $0.id == id }
        saveCountdowns()
    }

    func reorderCountdowns(fromOffsets source: IndexSet, toOffset destination: Int) {
        countdowns.move(fromOffsets: source, toOffset: destination)
        for (index, countdown) in countdowns.enumerated() {
            var updated = countdown
            updated.order = index
            countdowns[index] = updated
        }
        saveCountdowns()
    }
}