import Foundation

// MARK: - RecommendationSnapshotStoring

protocol RecommendationSnapshotStoring {
    func save(_ snapshot: OutfitRecommendationSnapshot)
    func load() -> OutfitRecommendationSnapshot?
    func clear()
}

extension RecommendationSnapshotStoring {
    func loadFresh(at date: Date = Date()) -> OutfitRecommendationSnapshot? {
        guard let snapshot = load(), snapshot.isFresh(at: date) else { return nil }
        return snapshot
    }
}

// MARK: - AppGroupRecommendationSnapshotStore

struct AppGroupRecommendationSnapshotStore: RecommendationSnapshotStoring {
    static let storageKey = "outfit_recommendation_snapshot_v2"
    private static let legacyStorageKey = "cached_tog_outfit_v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    func save(_ snapshot: OutfitRecommendationSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.legacyStorageKey)
    }

    func load() -> OutfitRecommendationSnapshot? {
        guard let data = defaults.data(forKey: Self.storageKey),
              let snapshot = try? JSONDecoder().decode(OutfitRecommendationSnapshot.self, from: data),
              snapshot.schemaVersion == OutfitRecommendationSnapshot.currentSchemaVersion
        else { return nil }
        return snapshot
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.legacyStorageKey)
    }
}
