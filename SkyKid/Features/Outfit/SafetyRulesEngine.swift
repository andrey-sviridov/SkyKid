import Foundation

// MARK: - SafetyRulesEngine §6

/// Orchestrates independent safety policies without owning their rules.
enum SafetyRulesEngine {

    struct Output: Sendable {
        let warnings: [SafetyWarning]
        let walkWindow: DateInterval?
        let checkHint: String
    }

    static func evaluate(_ context: SafetyAssessmentContext) -> Output {
        let ageLimits = AgeSafetyPolicy.limits(for: context.profile)
        let medical = MedicalSafetyPolicy.evaluate(
            context,
            ageLimits: ageLimits
        )
        let weather = WeatherSafetyPolicy.evaluate(
            context,
            limits: medical.exposureLimits
        )
        let transportWarnings = TransportSafetyPolicy.evaluate(context)

        let warnings = sortedWarnings(
            medical.warnings + weather.warnings + transportWarnings
        )
        let walkWindow = medical.blocksWalk
            ? nil
            : weather.nextSaferWindow

        return Output(
            warnings: warnings,
            walkWindow: walkWindow,
            checkHint: ThermalComfortCheckPolicy.instruction
        )
    }
}

// MARK: - Warning priority

private extension SafetyRulesEngine {
    static func sortedWarnings(
        _ warnings: [SafetyWarning]
    ) -> [SafetyWarning] {
        SafetyWarning.orderedForPresentation(warnings)
    }
}
