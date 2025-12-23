import SwiftUI
import UniformTypeIdentifiers

struct DragDropDelegate: DropDelegate {
    let destination: CountdownEvent?
    let countdownManager: CountdownManager

    func validateDrop(info: DropInfo) -> Bool {
        return info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) {
        // Visual feedback if needed
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else {
            return false
        }

        _ = item.loadObject(ofClass: String.self) { (data, error) in
            if let idString = data,
               let sourceId = UUID(uuidString: idString) {
                
                DispatchQueue.main.async {
                    if let dest = self.destination {
                         print("Dropping source: \(sourceId) on destination: \(dest.id)")
                         if sourceId != dest.id {
                             withAnimation {
                                 self.countdownManager.moveCountdown(sourceId: sourceId, destinationId: dest.id)
                             }
                         }
                    } else {
                        print("Dropping source: \(sourceId) to end of list")
                        withAnimation {
                            self.countdownManager.moveCountdownToEnd(sourceId: sourceId)
                        }
                    }
                }
            } else {
                print("Failed to load drop item: \(String(describing: error))")
            }
        }
        
        return true
    }
}
