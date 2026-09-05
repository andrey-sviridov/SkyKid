import Foundation

// MARK: - WalkEventUndo

/// Purely reverses the most recent live-walk event. Keeping this separate from
/// the store makes the edge cases easy to verify without persistence or Live
/// Activity side effects.
enum WalkEventUndo {
    static func apply(to walk: ActiveWalk, eventID: UUID? = nil) -> ActiveWalk? {
        let index: Int?
        if let eventID {
            index = walk.events.firstIndex { $0.id == eventID }
        } else {
            index = latestEventIndex(in: walk.events)
        }
        guard let index else { return nil }

        var updated = walk
        let event = updated.events.remove(at: index)

        switch event.kind {
        case .addedGarment:
            if let garmentID = event.garmentID {
                updated.outfitItemIDs.removeAll { $0 == garmentID }
            }
        case .removedGarment:
            if let garmentID = event.garmentID, !updated.outfitItemIDs.contains(garmentID) {
                updated.outfitItemIDs.append(garmentID)
            }
        case .openedBassinette, .closedBassinette, .sleep, .wake, .checkpoint:
            break
        }

        return updated
    }

    private static func latestEventIndex(in events: [WalkEvent]) -> Int? {
        guard !events.isEmpty else { return nil }

        return events.indices.max { lhs, rhs in
            let leftDate = events[lhs].timestamp
            let rightDate = events[rhs].timestamp
            if leftDate == rightDate { return lhs < rhs }
            return leftDate < rightDate
        }
    }
}
