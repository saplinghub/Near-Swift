import SwiftUI
import UniformTypeIdentifiers

struct DragDropDelegate: DropDelegate {
    let sourceIndex: Int
    let countdownManager: CountdownManager

    func validateDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.data]).first else { return false }
        return item.canLoadObject(ofClass: String.self)
    }

    func dropEntered(info: DropInfo) {
        // 可以在这里添加视觉反馈
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.data]).first else {
            return false
        }

        // Fix: Use loadDataRepresentation(for:completionHandler:) or loadObject(ofClass:completionHandler:)
        // correctly without blocking the main thread.
        
        item.loadObject(ofClass: String.self) { (data, error) in
            // Handle the optional data safely
            if let idString = data as? String,
               let targetId = UUID(uuidString: idString) {
                
                // Perform the UI update on the main thread
                DispatchQueue.main.async {
                    print("Dropping item: \(targetId) to index: \(self.sourceIndex)")
                    self.countdownManager.moveCountdown(from: self.sourceIndex, to: targetId)
                }
            } else {
                print("Failed to load drop item: \(String(describing: error))")
            }
        }
        
        return true
    }
}
