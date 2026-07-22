import Foundation

// MARK: - OutfitRecommendation §7

struct OutfitRecommendation: Codable, Equatable, Sendable {
    let temperatures: OutfitTemperatures
    let layers: [RecommendedLayer]          // innermost → outermost
    let accessories: [RecommendedLayer]
    let strollerSetup: StrollerAdvice
    let totalTOG: Double
    let targetTOG: Double
    let fit: OutfitFit?
    let missingGarments: [RecommendedLayer]?
    let warnings: [SafetyWarning]
    let checkHint: String
    let walkWindow: DateInterval?           // nil = no restriction
    let explanation: [CalcStep]             // full §2→§3→§4→§5→§6 trace

    var allDisplayLayers: [RecommendedLayer] { layers + accessories }

    var suggestedAlternatives: [RecommendedLayer] {
        missingGarments ?? []
    }

    var blockingWarning: SafetyWarning? {
        warnings.first(where: \.blocksScenario)
    }

    var primarySafetyWarning: SafetyWarning? {
        warnings.first {
            $0.severity == .blocked || $0.severity == .danger
        }
    }

    init(
        temperatures: OutfitTemperatures,
        layers: [RecommendedLayer],
        accessories: [RecommendedLayer],
        strollerSetup: StrollerAdvice,
        totalTOG: Double,
        targetTOG: Double,
        fit: OutfitFit? = nil,
        missingGarments: [RecommendedLayer] = [],
        warnings: [SafetyWarning],
        checkHint: String,
        walkWindow: DateInterval?,
        explanation: [CalcStep]
    ) {
        self.temperatures = temperatures
        self.layers = layers
        self.accessories = accessories
        self.strollerSetup = strollerSetup
        self.totalTOG = totalTOG
        self.targetTOG = targetTOG
        self.fit = fit
        self.missingGarments = missingGarments
        self.warnings = warnings
        self.checkHint = checkHint
        self.walkWindow = walkWindow
        self.explanation = explanation
    }
}

// MARK: - Outfit fit

struct OutfitFit: Codable, Equatable, Sendable {
    enum Confidence: String, Codable, Sendable {
        case high
        case medium
        case low
    }

    let targetTOG: Double
    let effectiveTOG: Double
    let deltaTOG: Double
    let confidence: Confidence
    let hasRequiredBodyCoverage: Bool

    var absoluteError: Double { abs(deltaTOG) }
}

// MARK: - Temperatures

/// Explicit temperature stages used by the recommendation pipeline.
/// Keeping them as named values prevents UI and extensions from guessing a
/// temperature by scanning the calculation trace.
struct OutfitTemperatures: Codable, Equatable, Sendable {
    let outside: Double
    let apparent: Double
    let effective: Double
    let microclimate: Double
}

// MARK: - RecommendedLayer

struct RecommendedLayer: Identifiable, Codable, Equatable, Sendable {
    let id: String           // matches GarmentItem.id
    let name: String
    let systemImage: String
    let reason: String
    let tog: Double
}

// MARK: - CalcStep §7

struct CalcStep: Codable, Equatable, Sendable {
    let label: String        // e.g. "Wind chill (§2.1)"
    let value: Double
    let unit: String         // "°C" or "TOG"
    let note: String?
}

// MARK: - SafetyWarning §6

struct SafetyWarning: Codable, Equatable, Sendable {

    enum Severity: String, Codable, Sendable {
        case info
        case caution
        case danger
        case blocked
    }

    enum Code: String, Codable, Sendable {
        case noWalkRecommended
        case coldExposureLimit
        case heatExposureLimit
        case shortWalkWarning
        case needsRainCover
        case heavyRainWithoutCover
        case rainCoverVentilation
        case rainCoverGreenhouse
        case uvWarning
        case walkTimeWarning
        case windWarning
        case carSeatBulkyCoatWarning
        case wardrobeGap
        case outfitFitUncertain
        case overheatPriority
        case feverMedicalAttention
        case feverStayHome
        case illnessNeedsCaution
        case medicalPlanPriority
        case faceVentilationRisk
        case wetClothingTOGLoss      // мокрая одежда теряет TOG
        case longWalkBorderlineTemp  // длинная прогулка + граничная температура
        case weatherDataQuality     // неполные поля погодного провайдера
    }

    let code: Code
    let severity: Severity
    let message: String
    let systemImage: String

    var blocksScenario: Bool {
        switch code {
        case .feverMedicalAttention, .feverStayHome:
            return true
        case .noWalkRecommended:
            return severity == .danger || severity == .blocked
        default:
            return severity == .blocked
        }
    }

    var isWeatherExposureBlock: Bool {
        switch code {
        case .coldExposureLimit, .heatExposureLimit:
            return true
        case .noWalkRecommended:
            return systemImage == "snowflake.circle.fill"
                || systemImage == "sun.max.trianglebadge.exclamationmark"
        default:
            return false
        }
    }

    var presentationPriority: Int {
        let severityPriority: Int
        switch severity {
        case .blocked: severityPriority = 400
        case .danger:  severityPriority = 300
        case .caution: severityPriority = 200
        case .info:    severityPriority = 100
        }

        let codePriority: Int
        switch code {
        case .feverMedicalAttention: codePriority = 40
        case .feverStayHome:         codePriority = 35
        case .coldExposureLimit,
             .heatExposureLimit:     codePriority = 30
        case .faceVentilationRisk,
             .rainCoverGreenhouse:   codePriority = 20
        default:                      codePriority = 0
        }

        return severityPriority + codePriority
    }

    static func orderedForPresentation(
        _ warnings: [SafetyWarning]
    ) -> [SafetyWarning] {
        warnings.enumerated()
            .sorted { left, right in
                let leftPriority = left.element.presentationPriority
                let rightPriority = right.element.presentationPriority
                return leftPriority == rightPriority
                    ? left.offset < right.offset
                    : leftPriority > rightPriority
            }
            .map(\.element)
    }
}

// MARK: - StrollerAdvice §7

struct StrollerAdvice: Codable, Equatable, Sendable {
    let recommendation: String
    let isSafetyWarning: Bool
}
