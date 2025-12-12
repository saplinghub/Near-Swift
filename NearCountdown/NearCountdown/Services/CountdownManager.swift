import Foundation
import Combine

class CountdownManager: ObservableObject {
    @Published var countdowns: [CountdownEvent] = []
    @Published var pinnedCountdown: CountdownEvent?
    @Published var activeCountdowns: [CountdownEvent] = []
    @Published var completedCountdowns: [CountdownEvent] = []

    private var storageManager = StorageManager()
    private var timer: Timer?

    init() {
        countdowns = storageManager.countdowns
        updateFilteredCountdowns()
        startTimer()
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
        let allCountdowns = countdowns.sorted { $0.order < $1.order }

        pinnedCountdown = allCountdowns.first { $0.isPinned }
        activeCountdowns = allCountdowns.filter { !$0.isCompleted && !$0.isPinned }
        completedCountdowns = allCountdowns.filter { $0.isCompleted && !$0.isPinned }
    }

    func addCountdown(_ countdown: CountdownEvent) {
        countdowns.append(countdown)
        storageManager.addCountdown(countdown)
        updateFilteredCountdowns()
    }

    func updateCountdown(_ countdown: CountdownEvent) {
        if let index = countdowns.firstIndex(where: { $0.id == countdown.id }) {
            countdowns[index] = countdown
            storageManager.updateCountdown(countdown)
            updateFilteredCountdowns()
        }
    }

    func deleteCountdown(_ id: UUID) {
        countdowns.removeAll { $0.id == id }
        storageManager.deleteCountdown(id)
        updateFilteredCountdowns()
    }

    func togglePin(_ id: UUID) {
        if let index = countdowns.firstIndex(where: { $0.id == id }) {
            let wasPinned = countdowns[index].isPinned
            
            // Unpin all first
            for i in 0..<countdowns.count {
                countdowns[i].isPinned = false
            }
            
            // If it wasn't pinned before, pin it now (if it was pinned, we just unpinned it above, effectively toggling off)
            if !wasPinned {
                countdowns[index].isPinned = true
            }
            
            storageManager.syncAll(countdowns)
            updateFilteredCountdowns()
        }
    }

    func reorderCountdowns(fromOffsets source: IndexSet, toOffset destination: Int) {
        countdowns.move(fromOffsets: source, toOffset: destination)
        for (index, countdown) in countdowns.enumerated() {
            var updated = countdown
            updated.order = index
            countdowns[index] = updated
        }
        storageManager.saveCountdowns()
        updateFilteredCountdowns()
    }

    func getTopCountdownText() -> String? {
        guard let pinned = pinnedCountdown else { return nil }
        return "\(pinned.name): \(pinned.timeRemainingString)"
    }

    // 拖拽排序功能
    func moveActiveCountdowns(from source: IndexSet, to destination: Int) {
        var activeItems = activeCountdowns
        activeItems.move(fromOffsets: source, toOffset: destination)

        // 更新主数组中的顺序
        var allItems = countdowns
        let pinnedItems = allItems.filter { $0.isPinned }
        let completedItems = allItems.filter { $0.isCompleted && !$0.isPinned }

        // 重新组合数组
        allItems = pinnedItems + activeItems + completedItems

        // 更新order字段
        for (index, item) in allItems.enumerated() {
            var updated = item
            updated.order = index
            allItems[index] = updated
        }

        countdowns = allItems
        storageManager.saveCountdowns()
        updateFilteredCountdowns()
    }

    func moveCompletedCountdowns(from source: IndexSet, to destination: Int) {
        var completedItems = completedCountdowns
        completedItems.move(fromOffsets: source, toOffset: destination)

        // 更新主数组中的顺序
        var allItems = countdowns
        let pinnedItems = allItems.filter { $0.isPinned }
        let activeItems = allItems.filter { !$0.isCompleted && !$0.isPinned }

        // 重新组合数组
        allItems = pinnedItems + activeItems + completedItems

        // 更新order字段
        for (index, item) in allItems.enumerated() {
            var updated = item
            updated.order = index
            allItems[index] = updated
        }

        countdowns = allItems
        storageManager.saveCountdowns()
        updateFilteredCountdowns()
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
        
        storageManager.saveCountdowns()
        updateFilteredCountdowns()
    }
}