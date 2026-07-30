import Foundation

// MARK: - WalkEventReclassifier
// Позволяет назначить конкретное действие "контрольной точке" постфактум
// (во время прогулки или уже в Истории), сохраняя исходное время события.
// Если новое/старое действие — надел/снял вещь, синхронизирует набор
// одежды (outfitItemIDs) так, будто оно было применено сразу.

enum WalkEventReclassifier {
    static func apply(
        old: WalkEvent,
        newKind: WalkEventKind,
        newGarmentID: String?,
        newNote: String?,
        outfitItemIDs: [String]
    ) -> (event: WalkEvent, outfitItemIDs: [String]) {
        var ids = outfitItemIDs

        // Откатываем эффект старой классификации на набор одежды.
        if old.kind == .addedGarment, let oldID = old.garmentID {
            ids.removeAll { $0 == oldID }
        } else if old.kind == .removedGarment, let oldID = old.garmentID, !ids.contains(oldID) {
            ids.append(oldID)
        }

        // Применяем эффект новой классификации.
        if newKind == .addedGarment, let newID = newGarmentID, !ids.contains(newID) {
            ids.append(newID)
        } else if newKind == .removedGarment, let newID = newGarmentID {
            ids.removeAll { $0 == newID }
        }

        let updated = WalkEvent(
            id: old.id,
            timestamp: old.timestamp,
            kind: newKind,
            garmentID: newKind == .addedGarment || newKind == .removedGarment ? newGarmentID : nil,
            note: newNote
        )
        return (updated, ids)
    }
}
