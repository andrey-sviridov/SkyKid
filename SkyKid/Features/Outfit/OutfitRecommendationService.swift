import Foundation

// MARK: - OutfitRecommendationService
// Orchestrates the full §2→§3→§4→§5→§6 TOG pipeline.

@MainActor
final class OutfitRecommendationService {

    static let shared = OutfitRecommendationService()

    private init() {}

    func recommend(
        weather: WeatherData,
        profile: ChildProfile,
        gearSetup: GearSetup
    ) -> OutfitRecommendation {

        // §2 Effective Temperature
        let effOutput = EffectiveTemperatureCalculator.calculate(
            .init(weather: weather, gearSetup: gearSetup)
        )

        // §3 Microclimate
        let microOutput = MicroclimateCalculator.calculate(.init(
            T: weather.temperature,
            T_eff: effOutput.T_eff,
            V_calc: effOutput.V_calc,
            gearSetup: gearSetup
        ))

        // §8 Personal TOG offset
        let personalOffset = PersonalOffsetStore.shared.currentOffset(
            for: profile, tMicro: microOutput.T_micro
        )

        // §4 TOG Required
        let togOutput = TOGCalculator.calculate(.init(
            T_micro: microOutput.T_micro,
            profile: profile,
            personalOffset: personalOffset
        ))

        // §5 Outfit Solver
        let solverOutput = OutfitSolver.solve(.init(
            TOG_required: togOutput.TOG_required,
            T_micro: microOutput.T_micro,
            T_hi: effOutput.T_hi,
            uvIndex: weather.uvIndex,
            carrierUnderJacket: microOutput.carrierUnderJacket,
            profile: profile,
            gearSetup: gearSetup,
            weather: weather,
            precipFlags: effOutput.precipFlags,
            ownedGarmentIDs: UserWardrobeStore.shared.ownedIDs
        ))

        // §6 Safety Rules
        let safetyOutput = SafetyRulesEngine.evaluate(.init(
            T_eff: effOutput.T_eff,
            T_hi: effOutput.T_hi,
            T_micro: microOutput.T_micro,
            V_calc: effOutput.V_calc,
            TOG_required: togOutput.TOG_required,
            TOG_base: togOutput.TOG_base,
            strollerAdvice: microOutput.strollerAdvice,
            precipFlags: effOutput.precipFlags,
            weather: weather,
            profile: profile,
            gearSetup: gearSetup
        ))

        var allWarnings = safetyOutput.warnings
        if let gap = solverOutput.wardrobeGap {
            allWarnings.append(SafetyWarning(
                code: .wardrobeGap,
                severity: .info,
                message: gap,
                systemImage: "bag.badge.questionmark"
            ))
        }

        let allSteps = effOutput.steps + microOutput.steps + togOutput.steps + solverOutput.steps

        return OutfitRecommendation(
            layers: solverOutput.layers,
            accessories: solverOutput.accessories,
            strollerSetup: microOutput.strollerAdvice ?? StrollerAdvice(
                recommendation: "Поднимите капюшон при ветре или осадках",
                isSafetyWarning: false
            ),
            totalTOG: solverOutput.totalTOG,
            targetTOG: togOutput.TOG_required,
            warnings: allWarnings,
            checkHint: safetyOutput.checkHint,
            walkWindow: safetyOutput.walkWindow,
            explanation: allSteps
        )
    }
}
