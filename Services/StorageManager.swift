import Foundation

class StorageManager: ObservableObject {
    @Published var countdowns: [CountdownEvent] = []
    @Published var aiStorage: AIStorage = AIStorage.createDefault()
    @Published var qWeatherKey: String = ""
    @Published var qWeatherHost: String = "https://devapi.qweather.com/v7"
    @Published var qWeatherLocationId: String = "101010100" // Default: Beijing
    @Published var qWeatherLocationName: String = "北京"
    @Published var waqiToken: String = ""
    @Published var isPetSelfAwarenessEnabled: Bool = true
    @Published var isSystemAwarenessEnabled: Bool = true // Renamed from isPetSystemAwarenessEnabled
    @Published var isPetIntentAwarenessEnabled: Bool = true
    @Published var isHealthReminderEnabled: Bool = true
    @Published var isPetEnabled: Bool = true
    @Published var isWindmillEnabled: Bool = true
    @Published var countdownSortMode: SortMode = .manual

    private let countdownsKey = "countdowns"
    private let aiStorageKey = "aiStorage"
    private let legacyAIConfigKey = "aiConfig"
    private let qWeatherKeyPath = "qWeatherKey"
    private let qWeatherHostPath = "qWeatherHost"
    private let qWeatherLocIdPath = "qWeatherLocId"
    private let qWeatherLocNamePath = "qWeatherLocName"
    private let waqiTokenPath = "waqiToken"
    private let isPetSelfAwarenessKey = "isPetSelfAwarenessEnabled"
    private let isSystemAwarenessKey = "isSystemAwarenessEnabled" // Renamed from isPetSystemAwarenessKey
    private let isPetIntentAwarenessKey = "isPetIntentAwarenessEnabled"
    private let isHealthReminderKey = "isHealthReminderEnabled"
    private let isPetEnabledKey = "isPetEnabled"
    private let countdownSortModeKey = "countdownSortMode"

    init() {
        loadAll()
    }

    private func loadAll() {
        loadCountdowns()
        loadAIStorage()
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

    private func loadAIStorage() {
        // 1. Try to load AIStorage (Multi-config)
        if let data = UserDefaults.standard.data(forKey: aiStorageKey) {
            do {
                aiStorage = try JSONDecoder().decode(AIStorage.self, from: data)
                return
            } catch {
                print("Error loading AI storage: \(error)")
            }
        }
        
        // 2. Migration: Try to load legacy AIConfig
        if let data = UserDefaults.standard.data(forKey: legacyAIConfigKey) {
            do {
                let legacyConfig = try JSONDecoder().decode(AIConfig.self, from: data)
                var migratedConfig = legacyConfig
                migratedConfig.name = "默认配置"
                aiStorage = AIStorage(configs: [migratedConfig], activeID: migratedConfig.id)
                saveAIStorage()
                // Optional: remove legacy key
                // UserDefaults.standard.removeObject(forKey: legacyAIConfigKey)
                return
            } catch {
                print("Error migrating legacy AI config: \(error)")
            }
        }
        
        // 3. Fallback to default
        aiStorage = AIStorage.createDefault()
    }

    private func loadQWeatherKey() {
        qWeatherKey = UserDefaults.standard.string(forKey: qWeatherKeyPath) ?? ""
        qWeatherHost = UserDefaults.standard.string(forKey: qWeatherHostPath) ?? "https://devapi.qweather.com/v7"
        qWeatherLocationId = UserDefaults.standard.string(forKey: qWeatherLocIdPath) ?? "101010100"
        qWeatherLocationName = UserDefaults.standard.string(forKey: qWeatherLocNamePath) ?? "北京"
        waqiToken = UserDefaults.standard.string(forKey: waqiTokenPath) ?? ""
        isPetSelfAwarenessEnabled = UserDefaults.standard.object(forKey: isPetSelfAwarenessKey) as? Bool ?? true
        self.isSystemAwarenessEnabled = UserDefaults.standard.object(forKey: isSystemAwarenessKey) as? Bool ?? true
        self.isPetIntentAwarenessEnabled = UserDefaults.standard.object(forKey: isPetIntentAwarenessKey) as? Bool ?? true
        self.isHealthReminderEnabled = UserDefaults.standard.object(forKey: isHealthReminderKey) as? Bool ?? true
        self.isPetEnabled = UserDefaults.standard.object(forKey: isPetEnabledKey) as? Bool ?? true
        self.isWindmillEnabled = UserDefaults.standard.object(forKey: "isWindmillEnabled") as? Bool ?? true
        if let modeString = UserDefaults.standard.string(forKey: countdownSortModeKey), let mode = SortMode(rawValue: modeString) {
            self.countdownSortMode = mode
        }
    }

    func saveQWeatherKey() {
        UserDefaults.standard.set(qWeatherKey, forKey: qWeatherKeyPath)
        UserDefaults.standard.set(qWeatherHost, forKey: qWeatherHostPath)
        UserDefaults.standard.set(qWeatherLocationId, forKey: qWeatherLocIdPath)
        UserDefaults.standard.set(qWeatherLocationName, forKey: qWeatherLocNamePath)
        UserDefaults.standard.set(waqiToken, forKey: waqiTokenPath)
    }

    func savePetSettings(isEnabled: Bool, isSelfAwareEnabled: Bool, isSystemAwareEnabled: Bool, isIntentAwareEnabled: Bool, isHealthReminderEnabled: Bool) {
        self.isPetEnabled = isEnabled
        self.isPetSelfAwarenessEnabled = isSelfAwareEnabled
        self.isSystemAwarenessEnabled = isSystemAwareEnabled
        self.isPetIntentAwarenessEnabled = isIntentAwareEnabled
        self.isHealthReminderEnabled = isHealthReminderEnabled
        
        UserDefaults.standard.set(isEnabled, forKey: isPetEnabledKey)
        UserDefaults.standard.set(isSelfAwareEnabled, forKey: isPetSelfAwarenessKey)
        UserDefaults.standard.set(isSystemAwareEnabled, forKey: isSystemAwarenessKey)
        UserDefaults.standard.set(isIntentAwareEnabled, forKey: isPetIntentAwarenessKey)
        UserDefaults.standard.set(isHealthReminderEnabled, forKey: isHealthReminderKey)
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

    func saveAIStorage() {
        do {
            let data = try JSONEncoder().encode(aiStorage)
            UserDefaults.standard.set(data, forKey: aiStorageKey)
        } catch {
            print("Error saving AI storage: \(error)")
        }
    }
    
    var activeAIConfig: AIConfig {
        if let active = aiStorage.configs.first(where: { $0.id == aiStorage.activeID }) {
            return active
        }
        return aiStorage.configs.first ?? AIConfig.createDefault()
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
    
    func saveGeneralSettings(isWindmillEnabled: Bool) {
        self.isWindmillEnabled = isWindmillEnabled
        UserDefaults.standard.set(isWindmillEnabled, forKey: "isWindmillEnabled")
    }
    
    func saveSortMode(_ mode: SortMode) {
        self.countdownSortMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: countdownSortModeKey)
    }
}