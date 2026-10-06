import Foundation

// MARK: - Walk origin and personalization eligibility

enum WalkOrigin: String, Codable, Equatable, Sendable {
    case tracked
    case manual
}

enum PersonalizationExclusionReason: String, Codable, Equatable, Sendable {
    case manualWalk
    case notLiveTracked
    case missingWeatherSnapshot
    case invalidWeatherSnapshot
    case staleWeatherSnapshot
    case unknownWeatherProvenance
    case missingWalkContext
}

enum PersonalizationEligibility: Equatable, Sendable {
    case eligible
    case excluded(PersonalizationExclusionReason)

    var isEligible: Bool {
        if case .eligible = self { return true }
        return false
    }

    var exclusionReason: PersonalizationExclusionReason? {
        guard case let .excluded(reason) = self else { return nil }
        return reason
    }
}

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

enum PersonalizationWeatherClass: String, Codable, Equatable, Sendable {
    case fair
    case rain
    case snow
    case severe

    init?(weatherCode: Int?) {
        guard let weatherCode else { return nil }
        switch weatherCode {
        case 0...48: self = .fair
        case 51...67, 80...82: self = .rain
        case 71...77, 85...86: self = .snow
        case 95...99: self = .severe
        default: return nil
        }
    }
}

enum PersonalizationAgeBand: String, Codable, Equatable, Sendable {
    case infant
    case baby
    case olderChild

    init(ageGroup: AgeGroup) {
        switch ageGroup {
        case .infant: self = .infant
        case .baby: self = .baby
        case .toddler, .preschool, .schoolAge, .teen: self = .olderChild
        }
    }
}

enum PersonalizationInsulationBand: String, Codable, Equatable, Sendable {
    case light
    case medium
    case warm

    init?(tog: Double?) {
        guard let tog, tog.isFinite else { return nil }
        switch tog {
        case ..<1.0: self = .light
        case 1.0..<2.5: self = .medium
        default: self = .warm
        }
    }
}

enum PersonalizationDurationBand: String, Codable, Equatable, Sendable {
    case short
    case regular
    case long

    init?(minutes: Int?) {
        guard let minutes, minutes >= 0 else { return nil }
        switch minutes {
        case ..<30: self = .short
        case 30..<90: self = .regular
        default: self = .long
        }
    }
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
    let childAgeBand: PersonalizationAgeBand?
    let weatherClass: PersonalizationWeatherClass?
    let insulationBand: PersonalizationInsulationBand?
    let durationBand: PersonalizationDurationBand?
    let clothingAdjustment: ClothingAdjustment?

    init(
        microclimateTemperature: Double,
        transportMode: TransportMode,
        activityLevel: BabyActivityLevel,
        walkType: WalkType,
        outfitItemIDs: [String] = [],
        targetTOG: Double? = nil,
        effectiveOutfitTOG: Double? = nil,
        durationMinutes: Int? = nil,
        childAgeBand: PersonalizationAgeBand? = nil,
        weatherCode: Int? = nil,
        clothingAdjustment: ClothingAdjustment? = nil,
        weatherClass: PersonalizationWeatherClass? = nil,
        insulationBand: PersonalizationInsulationBand? = nil,
        durationBand: PersonalizationDurationBand? = nil
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
        self.childAgeBand = childAgeBand
        self.weatherClass = weatherClass ?? PersonalizationWeatherClass(weatherCode: weatherCode)
        self.insulationBand = insulationBand ?? PersonalizationInsulationBand(tog: effectiveOutfitTOG)
        self.durationBand = durationBand ?? PersonalizationDurationBand(minutes: durationMinutes)
        self.clothingAdjustment = clothingAdjustment
    }

    private enum CodingKeys: String, CodingKey {
        case microclimateTemperature, temperatureBand, scenario, transportMode
        case activityLevel, walkType, outfitItemIDs, targetTOG, effectiveOutfitTOG
        case durationMinutes, childAgeBand, weatherClass, insulationBand
        case durationBand, clothingAdjustment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        microclimateTemperature = try c.decode(Double.self, forKey: .microclimateTemperature)
        temperatureBand = try c.decode(TempBand.self, forKey: .temperatureBand)
        scenario = try c.decode(PersonalizationScenario.self, forKey: .scenario)
        transportMode = try c.decode(TransportMode.self, forKey: .transportMode)
        activityLevel = try c.decode(BabyActivityLevel.self, forKey: .activityLevel)
        walkType = try c.decode(WalkType.self, forKey: .walkType)
        outfitItemIDs = try c.decodeIfPresent([String].self, forKey: .outfitItemIDs) ?? []
        targetTOG = try c.decodeIfPresent(Double.self, forKey: .targetTOG)
        effectiveOutfitTOG = try c.decodeIfPresent(Double.self, forKey: .effectiveOutfitTOG)
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes)
        childAgeBand = try c.decodeIfPresent(PersonalizationAgeBand.self, forKey: .childAgeBand)
        weatherClass = try c.decodeIfPresent(PersonalizationWeatherClass.self, forKey: .weatherClass)
        insulationBand = try c.decodeIfPresent(PersonalizationInsulationBand.self, forKey: .insulationBand)
            ?? PersonalizationInsulationBand(tog: effectiveOutfitTOG)
        durationBand = try c.decodeIfPresent(PersonalizationDurationBand.self, forKey: .durationBand)
            ?? PersonalizationDurationBand(minutes: durationMinutes)
        clothingAdjustment = try c.decodeIfPresent(ClothingAdjustment.self, forKey: .clothingAdjustment)
    }

    func with(childAgeGroup: AgeGroup) -> PersonalizationContext {
        PersonalizationContext(
            microclimateTemperature: microclimateTemperature,
            transportMode: transportMode,
            activityLevel: activityLevel,
            walkType: walkType,
            outfitItemIDs: outfitItemIDs,
            targetTOG: targetTOG,
            effectiveOutfitTOG: effectiveOutfitTOG,
            durationMinutes: durationMinutes,
            childAgeBand: PersonalizationAgeBand(ageGroup: childAgeGroup),
            clothingAdjustment: clothingAdjustment,
            weatherClass: weatherClass,
            insulationBand: insulationBand,
            durationBand: durationBand
        )
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
    let similarObservationCount: Int
    let evidenceContext: PersonalizationEvidenceContext
    let explanation: PersonalizationExplanation

    var hasAnyData: Bool {
        totalProfileObservationCount > 0 || hasLegacyBaseline
    }

    var evidenceTowardAdjustment: Int {
        min(abs(netDirectionalScore), PersonalizationPolicy.minimumConsistentSignals)
    }
}

struct PersonalizationEvidenceContext: Equatable, Sendable {
    let temperatureBand: TempBand
    let transportMode: TransportMode
    let activityLevel: BabyActivityLevel
    let walkType: WalkType
    let childAgeBand: PersonalizationAgeBand?
    let weatherClass: PersonalizationWeatherClass?
    let insulationBand: PersonalizationInsulationBand?
    let durationBand: PersonalizationDurationBand?

    init(context: PersonalizationContext) {
        temperatureBand = context.temperatureBand
        transportMode = context.transportMode
        activityLevel = context.activityLevel
        walkType = context.walkType
        childAgeBand = context.childAgeBand
        weatherClass = context.weatherClass
        insulationBand = context.insulationBand
        durationBand = context.durationBand
    }
}

enum PersonalizationExplanation: Equatable, Sendable {
    case insufficientEvidence(similarWalkCount: Int)
    case prefersWarmer(evidenceCount: Int)
    case prefersLighter(evidenceCount: Int)
    case balanced(evidenceCount: Int)
    case legacyBaseline
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
