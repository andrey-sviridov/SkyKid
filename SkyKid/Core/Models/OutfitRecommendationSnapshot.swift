import Foundation

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
    static let defaultTimeToLive: TimeInterval = 2 * 60 * 60

    let schemaVersion: Int
    let generatedAt: Date
    let expiresAt: Date
    let childName: String
    let childAgeLabel: String
    let cityName: String
    let context: RecommendationSnapshotContext?
    let recommendation: OutfitRecommendation

    init(
        recommendation: OutfitRecommendation,
        childName: String,
        childAgeLabel: String,
        cityName: String,
        context: RecommendationSnapshotContext? = nil,
        generatedAt: Date = Date(),
        timeToLive: TimeInterval = Self.defaultTimeToLive
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.generatedAt = generatedAt
        self.expiresAt = generatedAt.addingTimeInterval(timeToLive)
        self.childName = childName
        self.childAgeLabel = childAgeLabel
        self.cityName = cityName
        self.context = context
        self.recommendation = recommendation
    }

    // MARK: - Freshness

    func isFresh(at date: Date = Date()) -> Bool {
        schemaVersion == Self.currentSchemaVersion
            && generatedAt <= date.addingTimeInterval(60)
            && date < expiresAt
    }
}
