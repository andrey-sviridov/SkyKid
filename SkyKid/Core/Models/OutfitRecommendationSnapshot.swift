import Foundation

// MARK: - Recommendation algorithm version

/// Semantic version of the deterministic recommendation behavior.
///
/// This is intentionally separate from storage schema versions and app
/// marketing versions. Increment it only when recommendation behavior
/// changes; legacy payloads keep a nil value to make their provenance
/// explicitly unknown.
enum RecommendationAlgorithmVersion {
    static let current = 1
}

// MARK: - Recommendation freshness

enum RecommendationFreshnessState: Equatable, Sendable {
    case fresh
    case stale
    case unavailable
}

/// Shared, clock-injected policy used by the app, widget, and Siri snapshot.
/// The policy never reads the wall clock itself; callers provide the instant
/// they want to classify.
struct RecommendationFreshnessPolicy: Equatable, Sendable {
    static let defaultStaleAfter: TimeInterval = 2 * 60 * 60

    let now: Date
    let staleAfter: TimeInterval

    init(
        now: Date,
        staleAfter: TimeInterval = Self.defaultStaleAfter
    ) {
        self.now = now
        self.staleAfter = staleAfter
    }

    func state(for updatedAt: Date?) -> RecommendationFreshnessState {
        guard let updatedAt else { return .unavailable }
        guard updatedAt <= now else { return .unavailable }
        let age = now.timeIntervalSince(updatedAt)
        return age < staleAfter ? .fresh : .stale
    }

    func timeUntilStale(from updatedAt: Date?) -> TimeInterval? {
        guard let updatedAt else { return nil }
        guard updatedAt <= now else { return nil }
        let age = now.timeIntervalSince(updatedAt)
        return max(0, staleAfter - age)
    }
}

// MARK: - RecommendationSnapshotContext

/// Human-readable conditions captured together with the immutable result.
/// Strings are persisted intentionally: widget and Siri can explain the
/// context without importing weather or walk-calculation models.
struct RecommendationSnapshotContext: Codable, Equatable, Sendable {
    let weatherCondition: String
    let weatherSource: String
    let weatherConfidence: String
    let transport: String
    let activity: String
    let walkType: String

    var shortSummary: String {
        [weatherCondition, transport]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    var fullSummary: String {
        [weatherCondition, transport, activity, walkType]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

// MARK: - OutfitRecommendationSnapshot

/// Versioned, immutable result shared by the app, widget, and Siri.
/// Consumers display this exact recommendation and never run a fallback
/// clothing algorithm of their own.
struct OutfitRecommendationSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2
    static let currentAlgorithmVersion = RecommendationAlgorithmVersion.current
    static let defaultTimeToLive: TimeInterval = RecommendationFreshnessPolicy.defaultStaleAfter

    let schemaVersion: Int
    /// Nil means that the snapshot predates algorithm versioning (legacy/unknown).
    let algorithmVersion: Int?
    let generatedAt: Date
    let expiresAt: Date
    let childName: String
    let childAgeLabel: String
    /// Optional for backward compatibility. A snapshot without the birthday
    /// cannot prove that it is still inside the supported age scope.
    let childBirthday: Date?
    let cityName: String
    let context: RecommendationSnapshotContext?
    let recommendation: OutfitRecommendation

    init(
        recommendation: OutfitRecommendation,
        childName: String,
        childAgeLabel: String,
        childBirthday: Date? = nil,
        cityName: String,
        context: RecommendationSnapshotContext? = nil,
        algorithmVersion: Int? = Self.currentAlgorithmVersion,
        generatedAt: Date = Date(),
        timeToLive: TimeInterval = Self.defaultTimeToLive
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.algorithmVersion = algorithmVersion
        self.generatedAt = generatedAt
        self.expiresAt = generatedAt.addingTimeInterval(timeToLive)
        self.childName = childName
        self.childAgeLabel = childAgeLabel
        self.childBirthday = childBirthday
        self.cityName = cityName
        self.context = context
        self.recommendation = recommendation
    }

    // MARK: - Freshness

    var freshnessExpirationDate: Date {
        min(
            expiresAt,
            generatedAt.addingTimeInterval(RecommendationFreshnessPolicy.defaultStaleAfter)
        )
    }

    func freshness(at date: Date = Date()) -> RecommendationFreshnessState {
        guard schemaVersion == Self.currentSchemaVersion else { return .unavailable }

        let state = RecommendationFreshnessPolicy(now: date).state(for: generatedAt)
        guard state == .fresh else { return state }
        return date < expiresAt ? .fresh : .stale
    }

    func isFresh(at date: Date = Date()) -> Bool {
        freshness(at: date) == .fresh
    }

    /// A cached recommendation is usable only while its child remains in the
    /// reviewed age scope. Missing legacy age evidence is deliberately not
    /// treated as supported.
    func isSupportedForChildAge(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let childBirthday else { return false }
        return ChildThermalProfile.supportedAgeScope(
            for: childBirthday,
            now: date,
            calendar: calendar
        ).isSupported
    }
}
