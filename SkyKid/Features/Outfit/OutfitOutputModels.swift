import Foundation

// MARK: - OutfitRecommendation §7

struct OutfitRecommendation: Sendable {
    let layers: [RecommendedLayer]          // innermost → outermost
    let accessories: [RecommendedLayer]
    let strollerSetup: StrollerAdvice
    let totalTOG: Double
    let targetTOG: Double
    let warnings: [SafetyWarning]
    let checkHint: String
    let walkWindow: DateInterval?           // nil = no restriction
    let explanation: [CalcStep]             // full §2→§3→§4→§5→§6 trace

    var allDisplayLayers: [RecommendedLayer] { layers + accessories }
}

// MARK: - RecommendedLayer

struct RecommendedLayer: Identifiable, Sendable {
    let id: String           // matches GarmentItem.id
    let name: String
    let systemImage: String
    let reason: String
    let tog: Double
}

// MARK: - CalcStep §7

struct CalcStep: Sendable {
    let label: String        // e.g. "Wind chill (§2.1)"
    let value: Double
    let unit: String         // "°C" or "TOG"
    let note: String?
}

// MARK: - SafetyWarning §6

struct SafetyWarning: Sendable {

    enum Severity: Sendable {
        case info
        case caution
        case danger
    }

    enum Code: String, Sendable {
        case noWalkRecommended
        case shortWalkWarning
        case needsRainCover
        case rainCoverVentilation
        case rainCoverGreenhouse
        case uvWarning
        case walkTimeWarning
        case windWarning
        case carSeatBulkyCoatWarning
        case wardrobeGap
        case overheatPriority
        case feverShortWalk
        case wetClothingTOGLoss      // мокрая одежда теряет TOG
        case longWalkBorderlineTemp  // длинная прогулка + граничная температура
    }

    let code: Code
    let severity: Severity
    let message: String
    let systemImage: String
}

// MARK: - StrollerAdvice §7

struct StrollerAdvice: Sendable {
    let recommendation: String
    let isSafetyWarning: Bool
}
