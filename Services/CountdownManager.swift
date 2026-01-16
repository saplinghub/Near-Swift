import Foundation
import Combine

class CountdownManager: ObservableObject {
    @Published var countdowns: [CountdownEvent] = []
    @Published var pinnedCountdown: CountdownEvent?
    @Published var activeCountdowns: [CountdownEvent] = []
    @Published var completedCountdowns: [CountdownEvent] = []

    private var storageManager: StorageManager
    private var timer: Timer?
    private var lastSortClickTime: Date?
    private var backupCountdowns: [CountdownEvent]?
    private var cancellables = Set<AnyCancellable>()

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
        self.countdowns = storageManager.countdowns
        updateFilteredCountdowns()
        startTimer()
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe sort mode changes
        storageManager.$countdownSortMode
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateFilteredCountdowns()
                }
            }
            .store(in: &cancellables)
    }

    private func addSampleData() {
        let sampleCountdowns = [
            CountdownEvent(
                id: UUID(),
                name: "春节假期",
                startDate: Date(),
                targetDate: Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date(),
                icon: .star,
                isPinned: true,
                order: 0
            ),
            CountdownEvent(
                id: UUID(),
                name: "项目截止日期",
                startDate: Date(),
                targetDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()) ?? Date(),
                icon: .code,
                isPinned: false,
                order: 1
            ),
            CountdownEvent(
                id: UUID(),
                name: "生日聚会",
                startDate: Date(),
                targetDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                icon: .gift,
                isPinned: false,
                order: 2
            )
        ]

        countdowns = sampleCountdowns
        storageManager.saveCountdowns()
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.updateFilteredCountdowns()
        }
    }

    private func updateFilteredCountdowns() {
        var allCountdowns = countdowns
        
        switch storageManager.countdownSortMode {
        case .manual:
            allCountdowns.sort { $0.order < $1.order }
        case .timeAsc:
            allCountdowns.sort { $0.targetDate < $1.targetDate }
        case .timeDesc:
            allCountdowns.sort { $0.targetDate > $1.targetDate }
        }

        pinnedCountdown = allCountdowns.first { $0.isPinned }
        activeCountdowns = allCountdowns.filter { !$0.isCompleted && !$0.isPinned }
        completedCountdowns = allCountdowns.filter { $0.isCompleted && !$0.isPinned }
    }

    func addCountdown(_ countdown: CountdownEvent) {
        // Breaking sort mode to ensure "New at top" is visible immediately in manual order
        if storageManager.countdownSortMode != .manual {
            storageManager.saveSortMode(.manual)
        }
        countdowns.insert(countdown, at: 0)
        reindexCountdowns()
    }

    func updateCountdown(_ countdown: CountdownEvent) {
        if let index = countdowns.firstIndex(where: { $0.id == countdown.id }) {
            countdowns[index] = countdown
            syncAndSave()
        }
    }

    func deleteCountdown(_ id: UUID) {
        countdowns.removeAll { $0.id == id }
        syncAndSave()
    }

    func togglePin(_ id: UUID) {
        if let index = countdowns.firstIndex(where: { $0.id == id }) {
            let wasPinned = countdowns[index].isPinned
            
            // Unpin all first
            for i in 0..<countdowns.count {
                countdowns[i].isPinned = false
            }
            
            // If it wasn't pinned before, pin it now
            if !wasPinned {
                countdowns[index].isPinned = true
            }
            
            syncAndSave()
        }
    }

    func unpinIfExpired(id: UUID) {
        if let index = countdowns.firstIndex(where: { $0.id == id }) {
            if countdowns[index].isCompleted && countdowns[index].isPinned {
                var updated = countdowns[index]
                updated.isPinned = false
                countdowns[index] = updated
                syncAndSave()
            }
        }
    }
    
    private func syncAndSave() {
        storageManager.countdowns = self.countdowns
        storageManager.saveCountdowns()
        updateFilteredCountdowns()
    }

    func reorderCountdowns(fromOffsets source: IndexSet, toOffset destination: Int) {
        countdowns.move(fromOffsets: source, toOffset: destination)
        reindexCountdowns()
    }

    func getTopCountdownText() -> String? {
        guard let pinned = pinnedCountdown else { return nil }
        return "\(pinned.name): \(pinned.timeRemainingString)"
    }

    func moveActiveCountdowns(from source: IndexSet, to destination: Int) {
        if storageManager.countdownSortMode != .manual {
            storageManager.saveSortMode(.manual)
        }
        var activeItems = activeCountdowns
        activeItems.move(fromOffsets: source, toOffset: destination)

        // 更新主数组中的顺序
        let allItems = countdowns
        let pinnedItems = allItems.filter { $0.isPinned }
        let completedItems = allItems.filter { $0.isCompleted && !$0.isPinned }

        // 重新组合数组 (Ensures pinned stays top, active moved, completed stays bottom)
        self.countdowns = pinnedItems + activeItems + completedItems
        self.reindexCountdowns()
    }

    func moveCompletedCountdowns(from source: IndexSet, to destination: Int) {
        if storageManager.countdownSortMode != .manual {
            storageManager.saveSortMode(.manual)
        }
        var completedItems = completedCountdowns
        completedItems.move(fromOffsets: source, toOffset: destination)

        // 更新主数组中的顺序
        let allItems = countdowns
        let pinnedItems = allItems.filter { $0.isPinned }
        let activeItems = allItems.filter { !$0.isCompleted && !$0.isPinned }

        // 重新组合数组
        self.countdowns = pinnedItems + activeItems + completedItems
        self.reindexCountdowns()
    }

    func moveCountdown(sourceId: UUID, destinationId: UUID) {
        // Find indices
        guard let sourceIndex = countdowns.firstIndex(where: { $0.id == sourceId }),
              let destinationIndex = countdowns.firstIndex(where: { $0.id == destinationId }) else {
            return
        }
        
        // Don't move if same
        if sourceIndex == destinationIndex { return }

        // Perform move
        let item = countdowns.remove(at: sourceIndex)
        countdowns.insert(item, at: destinationIndex)

        // Update orders
        self.reindexCountdowns()
    }
    
    func moveCountdownToEnd(sourceId: UUID) {
         guard let sourceIndex = countdowns.firstIndex(where: { $0.id == sourceId }) else { return }
         
         let item = countdowns.remove(at: sourceIndex)
         countdowns.append(item)
         
         self.reindexCountdowns()
    }
    
    private func reindexCountdowns() {
        for (index, countdown) in countdowns.enumerated() {
            var updated = countdown
            updated.order = index
            countdowns[index] = updated
        }
        
        // Ensure StorageManager is in sync before saving
        storageManager.countdowns = self.countdowns
        storageManager.saveCountdowns()
        updateFilteredCountdowns()
    }
    
    func toggleSortMode() {
        let now = Date()
        let interval = now.timeIntervalSince(lastSortClickTime ?? Date.distantPast)
        
        if interval > 3.0 {
            // Start of a new cycle: Backup currently "visible/manual" order
            backupCountdowns = self.countdowns
            applySort(.timeAsc)
        } else {
            // Within 3s cycle: Asc -> Desc -> Restore (Manual)
            switch storageManager.countdownSortMode {
            case .timeAsc:
                applySort(.timeDesc)
            case .timeDesc:
                restoreOriginal()
            case .manual:
                // If they were already in manual, maybe they just want to start the cycle
                backupCountdowns = self.countdowns
                applySort(.timeAsc)
            }
        }
        lastSortClickTime = now
    }
    
    private func applySort(_ mode: SortMode) {
        storageManager.saveSortMode(mode)
        switch mode {
        case .timeAsc:
            countdowns.sort { $0.targetDate < $1.targetDate }
        case .timeDesc:
            countdowns.sort { $0.targetDate > $1.targetDate }
        case .manual:
            break
        }
        reindexCountdowns()
    }
    
    private func restoreOriginal() {
        if let backup = backupCountdowns {
            self.countdowns = backup
            storageManager.saveSortMode(.manual)
            reindexCountdowns()
        }
        // Cleanup after restore
        backupCountdowns = nil
    }
}