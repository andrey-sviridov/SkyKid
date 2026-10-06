import Foundation

// MARK: - WeatherFreshness

/// Small, deterministic model for showing whether the weather snapshot is
/// recent enough to use for a walk.
struct WeatherFreshness: Equatable {
    static let defaultStaleAfter: TimeInterval = RecommendationFreshnessPolicy.defaultStaleAfter

    let updatedAt: Date?
    let now: Date
    let staleAfter: TimeInterval

    init(
        updatedAt: Date?,
        now: Date = .now,
        staleAfter: TimeInterval = Self.defaultStaleAfter
    ) {
        self.updatedAt = updatedAt
        self.now = now
        self.staleAfter = staleAfter
    }

    var age: TimeInterval? {
        guard let updatedAt else { return nil }
        return max(0, now.timeIntervalSince(updatedAt))
    }

    var state: RecommendationFreshnessState {
        RecommendationFreshnessPolicy(
            now: now,
            staleAfter: staleAfter
        ).state(for: updatedAt)
    }

    var isStale: Bool {
        state != .fresh
    }
}
