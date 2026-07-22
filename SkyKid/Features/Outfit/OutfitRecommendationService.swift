import Foundation

// MARK: - OutfitRecommendationService
// Orchestrates the full §2→§3→§4→§5→§6 TOG pipeline.

@MainActor
final class OutfitRecommendationService {

    static let shared = OutfitRecommendationService()

    private init() {}

    func recommend(
        weather: NormalizedWeather,
        profile: ChildThermalProfile,
        walkContext: WalkContext
    ) -> OutfitRecommendation {
        let gearSetup = walkContext.gearSetup

        // §2 Effective Temperature
        let effOutput = EffectiveTemperatureCalculator.calculate(
            .init(weather: weather)
        )

        // §3 Microclimate
        let microOutput = MicroclimateCalculator.calculate(.init(
            environment: effOutput,
            gearSetup: gearSetup
        ))

        // §8 Personal TOG offset
        let personalOffset = PersonalOffsetStore.shared.currentOffset(
            for: profile,
            tMicro: microOutput.T_micro,
            walkContext: walkContext
        )

        // §4 TOG Required
        let togOutput = TOGCalculator.calculate(.init(
            T_micro: microOutput.T_micro,
            profile: profile,
            walkContext: walkContext,
            personalOffset: personalOffset
        ))

        // §5 Outfit Solver — выбирает только из реального гардероба и отдельно
        // возвращает безопасный идеальный вариант, если вещей не хватает.
        let solverOutput = OutfitSolver.solve(.init(
            TOG_required: togOutput.TOG_required,
            T_micro: microOutput.T_micro,
            accessoryTemperature: microOutput.accessoryTemperature,
            T_hi: effOutput.T_hi,
            uvIndex: weather.uvIndex,
            carrierUnderJacket: microOutput.carrierUnderJacket,
            profile: profile,
            gearSetup: gearSetup,
            weather: weather,
            precipFlags: effOutput.precipFlags,
            ownedGarmentIDs: walkContext.availableGarmentIDs
        ))

        // §6 Safety Rules
        let safetyOutput = SafetyRulesEngine.evaluate(SafetyAssessmentContext(
            effectiveTemperature: effOutput.T_eff,
            heatIndexTemperature: effOutput.T_hi,
            microclimateTemperature: microOutput.T_micro,
            calculatedWindKmh: effOutput.V_calc,
            precipitation: effOutput.precipFlags,
            weather: weather,
            profile: profile,
            walkContext: walkContext
        ))

        var allWarnings = safetyOutput.warnings
        // §5.6 Перегрев от двойного утепления верхним слоем (комбез + конверт)
        if let overheat = solverOutput.overheatWarning {
            allWarnings.insert(overheat, at: 0)
        }
        if let qualityWarning = weatherQualityWarning(for: weather) {
            allWarnings.append(qualityWarning)
        }

        if let wardrobeGap = solverOutput.wardrobeGap {
            let isColdDeficit = (solverOutput.fit?.deltaTOG ?? 0) < -OutfitConfig.Solver.togAccuracyTolerance
            let hasMissingGarments = !solverOutput.missingGarments.isEmpty
            allWarnings.append(SafetyWarning(
                code: hasMissingGarments ? .wardrobeGap : .outfitFitUncertain,
                severity: isColdDeficit ? .danger : .caution,
                message: wardrobeGap,
                systemImage: hasMissingGarments
                    ? "bag.badge.questionmark"
                    : "scope"
            ))
        }

        let allSteps = effOutput.steps + microOutput.steps + togOutput.steps + solverOutput.steps

        return OutfitRecommendation(
            temperatures: OutfitTemperatures(
                outside: weather.temperature,
                apparent: weather.apparentTemperature,
                effective: effOutput.T_eff,
                microclimate: microOutput.T_micro
            ),
            layers: solverOutput.layers,
            accessories: solverOutput.accessories,
            strollerSetup: microOutput.strollerAdvice ?? StrollerAdvice(
                recommendation: "Поднимите капюшон при ветре или осадках",
                isSafetyWarning: false
            ),
            totalTOG: solverOutput.totalTOG,
            targetTOG: togOutput.TOG_required,
            fit: solverOutput.fit,
            missingGarments: solverOutput.missingGarments,
            warnings: SafetyWarning.orderedForPresentation(allWarnings),
            checkHint: safetyOutput.checkHint,
            walkWindow: safetyOutput.walkWindow,
            explanation: allSteps
        )
    }

    // MARK: - Weather quality

    private func weatherQualityWarning(
        for weather: NormalizedWeather
    ) -> SafetyWarning? {
        guard weather.confidence.level != .high else { return nil }
        let severity: SafetyWarning.Severity = weather.confidence.level == .low
            ? .caution
            : .info
        return SafetyWarning(
            code: .weatherDataQuality,
            severity: severity,
            message: "\(weather.confidence.summary) Проверьте ребёнка через 15–20 минут.",
            systemImage: "exclamationmark.circle.fill"
        )
    }

    // MARK: - Legacy compatibility

    /// Keeps previews and isolated legacy tests source-compatible. Main app
    /// code must pass an explicit `WalkContext` instead.
    func recommend(
        weather: NormalizedWeather,
        profile: ChildProfile,
        gearSetup: GearSetup
    ) -> OutfitRecommendation {
        recommend(
            weather: weather,
            profile: profile.thermalProfile,
            walkContext: .migrated(
                from: profile,
                gearSetup: gearSetup,
                availableGarmentIDs: UserWardrobeStore.shared.ownedIDs
            )
        )
    }

}
