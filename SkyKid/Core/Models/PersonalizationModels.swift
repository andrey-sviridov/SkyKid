import Foundation

// MARK: - Personalization context

enum PersonalizationScenario: String, Codable, Equatable, Sendable {
    case resting
    case active

    init(activityLevel: BabyActivityLevel, transportMode: TransportMode) {
        if activityLevel == .walkingCrawling || transportMode == .walking {
            self = .active
        } else {
            self = .resting
        }
    }
}

enum PersonalizationFeedbackSource: String, Codable, Equatable, Sendable {
    case outfitScreen
    case walkLog
    case compatibilityAPI
}

struct PersonalizationContext: Codable, Equatable, Sendable {
    let microclimateTemperature: Double
    let temperatureBand: TempBand
    let scenario: PersonalizationScenario
    let transportMode: TransportMode
    let activityLevel: BabyActivityLevel
    let walkType: WalkType
    let outfitItemIDs: [String]
    let targetTOG: Double?
    let effectiveOutfitTOG: Double?
    let durationMinutes: Int?

    init(
        microclimateTemperature: Double,
        transportMode: TransportMode,
        activityLevel: BabyActivityLevel,
        walkType: WalkType,
        outfitItemIDs: [String] = [],
        targetTOG: Double? = nil,
        effectiveOutfitTOG: Double? = nil,
        durationMinutes: Int? = nil
    ) {
        self.microclimateTemperature = microclimateTemperature
        self.temperatureBand = TempBand(tMicro: microclimateTemperature)
        self.scenario = PersonalizationScenario(
            activityLevel: activityLevel,
            transportMode: transportMode
        )
        self.transportMode = transportMode
        self.activityLevel = activityLevel
        self.walkType = walkType
        self.outfitItemIDs = outfitItemIDs.sorted()
        self.targetTOG = targetTOG
        self.effectiveOutfitTOG = effectiveOutfitTOG
        self.durationMinutes = durationMinutes
    }
}

// MARK: - Stored observations

struct PersonalizationObservation: Codable, Equatable, Identifiable, Sendable {
    let sourceID: UUID
    let recordedAt: Date
    let feedback: UserFeedback
    let source: PersonalizationFeedbackSource
    let context: PersonalizationContext

    var id: UUID { sourceID }
}

struct PersonalizationProfileState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int = currentSchemaVersion
    var legacyOffsetsByBand: [String: Double] = [:]
    var observations: [PersonalizationObservation] = []
}

// MARK: - Public result models

struct PersonalizationSummary: Equatable, Sendable {
    let temperatureBand: TempBand
    let scenario: PersonalizationScenario
    let appliedOffset: Double
    let independentDirectionalCount: Int
    let netDirectionalScore: Int
    let comfortableConfirmationCount: Int
    let totalProfileObservationCount: Int
    let hasLegacyBaseline: Bool

    var hasAnyData: Bool {
        totalProfileObservationCount > 0 || hasLegacyBaseline
    }

    var evidenceTowardAdjustment: Int {
        min(abs(netDirectionalScore), PersonalizationPolicy.minimumConsistentSignals)
    }
}

struct PersonalizationUpdate: Equatable, Sendable {
    let previousOffset: Double
    let currentOffset: Double
    let summary: PersonalizationSummary

    var didChangeOffset: Bool {
        abs(currentOffset - previousOffset) > 0.000_1
    }
}

// MARK: - Context factories

extension PersonalizationContext {
    static func recommendation(
        _ recommendation: OutfitRecommendation,
        walkContext: WalkContext,
        durationMinutes: Int? = nil
    ) -> PersonalizationContext {
        PersonalizationContext(
            microclimateTemperature: recommendation.temperatures.microclimate,
            transportMode: walkContext.transportMode,
            activityLevel: walkContext.activityLevel,
            walkType: walkContext.walkType,
            outfitItemIDs: recommendation.allDisplayLayers.map(\.id),
            targetTOG: recommendation.targetTOG,
            effectiveOutfitTOG: recommendation.fit?.effectiveTOG ?? recommendation.totalTOG,
            durationMinutes: durationMinutes
        )
    }

    static func compatibility(tMicro: Double) -> PersonalizationContext {
        PersonalizationContext(
            microclimateTemperature: tMicro,
            transportMode: .pushchairSeat,
            activityLevel: .calmAwake,
            walkType: .regular
        )
    }
}
