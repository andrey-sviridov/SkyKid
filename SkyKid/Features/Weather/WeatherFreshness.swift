import Foundation

// MARK: - WeatherFreshness

/// Small, deterministic model for showing whether the weather snapshot is
/// recent enough to use for a walk.
struct WeatherFreshness: Equatable {
    static let defaultStaleAfter: TimeInterval = 2 * 60 * 60

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

    var isStale: Bool {
        guard let age else { return true }
        return age >= staleAfter
    }
}
