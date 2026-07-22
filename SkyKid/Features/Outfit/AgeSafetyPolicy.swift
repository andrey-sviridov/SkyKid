import Foundation

// MARK: - AgeSafetyPolicy

/// Selects conservative outdoor exposure limits from corrected age.
/// It does not diagnose illness or inspect current weather.
enum AgeSafetyPolicy {

    static func limits(for profile: ChildThermalProfile) -> OutdoorSafetyLimits {
        let correctedAgeWeeks = profile.correctedAgeWeeks

        for entry in OutfitConfig.Safety.noWalkThresholds
            where correctedAgeWeeks <= entry.maxCorrWeeks {
            return OutdoorSafetyLimits(
                coldBelow: entry.coldBelow,
                hotAbove: entry.hotAbove,
                usesAdditionalMedicalCaution: false
            )
        }

        let fallback = OutfitConfig.Safety.noWalkThresholds.last
        return OutdoorSafetyLimits(
            coldBelow: fallback?.coldBelow ?? -15,
            hotAbove: fallback?.hotAbove ?? 33,
            usesAdditionalMedicalCaution: false
        )
    }
}
