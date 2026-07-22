import Foundation

// MARK: - OutdoorSafetyLimits

/// Product guardrails used to decide whether SkyKid should suppress an outfit
/// scenario. These are conservative application limits, not clinical cutoffs.
struct OutdoorSafetyLimits: Equatable, Sendable {
    let coldBelow: Double
    let hotAbove: Double
    let usesAdditionalMedicalCaution: Bool
}

// MARK: - SafetyAssessmentContext

/// Immutable input shared by the independent safety policies.
struct SafetyAssessmentContext: Sendable {
    let effectiveTemperature: Double
    let heatIndexTemperature: Double
    let microclimateTemperature: Double
    let calculatedWindKmh: Double
    let precipitation: EffectiveTemperatureCalculator.PrecipFlags
    let weather: NormalizedWeather
    let profile: ChildThermalProfile
    let walkContext: WalkContext

    var gearSetup: GearSetup {
        walkContext.gearSetup
    }
}

// MARK: - WeatherSafetyAssessment

struct WeatherSafetyAssessment: Sendable {
    let warnings: [SafetyWarning]
    let nextSaferWindow: DateInterval?
}
