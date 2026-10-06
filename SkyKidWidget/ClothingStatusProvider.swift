import Foundation
import WidgetKit

// MARK: - Timeline Entry

struct ClothingStatusEntry: TimelineEntry {
    let date: Date
    let recommendation: WidgetOutfitRecommendation
    let isPlaceholder: Bool
    let requiresRefresh: Bool
    let lastUpdatedAt: Date?

    static var placeholder: ClothingStatusEntry {
        ClothingStatusEntry(
            date: Date(),
            recommendation: .placeholder,
            isPlaceholder: true,
            requiresRefresh: false,
            lastUpdatedAt: nil
        )
    }

    static func refreshRequired(
        from snapshot: OutfitRecommendationSnapshot?
    ) -> ClothingStatusEntry {
        ClothingStatusEntry(
            date: Date(),
            recommendation: snapshot.map { WidgetOutfitRecommendation(snapshot: $0) } ?? .placeholder,
            isPlaceholder: false,
            requiresRefresh: true,
            lastUpdatedAt: snapshot?.generatedAt
        )
    }
}

// MARK: - Timeline Provider

/// Reads the exact versioned recommendation produced by the main app.
/// The widget never runs a separate clothing algorithm.
struct ClothingStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClothingStatusEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ClothingStatusEntry) -> Void) {
        completion(context.isPreview ? .placeholder : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClothingStatusEntry>) -> Void) {
        let now = Date()
        let snapshot = AppGroupRecommendationSnapshotStore().load()
        let entry = makeEntry(snapshot: snapshot, at: now)
        let regularUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
        let nextUpdate = nextUpdateDate(
            now: now,
            regularUpdate: regularUpdate,
            snapshot: snapshot
        )
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    // MARK: - Entry construction

    private func makeEntry() -> ClothingStatusEntry {
        let now = Date()
        let snapshot = AppGroupRecommendationSnapshotStore().load()
        return makeEntry(snapshot: snapshot, at: now)
    }

    private func makeEntry(
        snapshot: OutfitRecommendationSnapshot?,
        at date: Date
    ) -> ClothingStatusEntry {
        guard let snapshot, snapshot.freshness(at: date) == .fresh else {
            return .refreshRequired(from: snapshot)
        }

        return ClothingStatusEntry(
            date: date,
            recommendation: WidgetOutfitRecommendation(snapshot: snapshot),
            isPlaceholder: false,
            requiresRefresh: false,
            lastUpdatedAt: snapshot.generatedAt
        )
    }

    private func nextUpdateDate(
        now: Date,
        regularUpdate: Date,
        snapshot: OutfitRecommendationSnapshot?
    ) -> Date {
        guard let snapshot, snapshot.freshness(at: now) == .fresh else { return regularUpdate }
        let expiryUpdate = max(snapshot.freshnessExpirationDate, now.addingTimeInterval(1))
        return min(regularUpdate, expiryUpdate)
    }
}
