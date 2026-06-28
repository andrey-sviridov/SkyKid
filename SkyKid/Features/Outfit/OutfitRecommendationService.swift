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

        // §5 Outfit Solver — всегда полный каталог; wardrobe check после.
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
            ownedGarmentIDs: nil
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
        // §5.6 Перегрев от двойного утепления верхним слоем (комбез + конверт)
        if let overheat = solverOutput.overheatWarning {
            allWarnings.insert(overheat, at: 0)
        }

        let displayOutfit = displayOutfit(
            weather: weather,
            profile: profile,
            solverOutput: solverOutput,
            carrierUnderJacket: microOutput.carrierUnderJacket
        )
        let displayLayers = displayOutfit.layers
        let displayAccessories = displayOutfit.accessories

        // Wardrobe check: какие вещи из рекомендации не куплены.
        // Не блокирует рекомендацию — всегда показывается полный оптимальный лук.
        let ownedIDs = UserWardrobeStore.shared.ownedIDs
        let missingNames = (displayLayers + displayAccessories)
            .filter { $0.id != "diaper" && !ownedIDs.contains($0.id) }
            .compactMap { GarmentCatalog.byID[$0.id]?.name }
        if !missingNames.isEmpty {
            allWarnings.append(SafetyWarning(
                code: .wardrobeGap,
                severity: .info,
                message: "Нет в гардеробе: \(missingNames.map { $0.lowercased() }.joined(separator: ", ")). Добавьте в «Мой гардероб».",
                systemImage: "bag.badge.questionmark"
            ))
        }

        let allSteps = effOutput.steps + microOutput.steps + togOutput.steps + solverOutput.steps + displayOutfit.steps
        let displayTOG = microOutput.carrierUnderJacket
            ? solverOutput.totalTOG
            : (displayLayers + displayAccessories).reduce(0) { $0 + $1.tog }

        return OutfitRecommendation(
            layers: displayLayers,
            accessories: displayAccessories,
            strollerSetup: microOutput.strollerAdvice ?? StrollerAdvice(
                recommendation: "Поднимите капюшон при ветре или осадках",
                isSafetyWarning: false
            ),
            totalTOG: displayTOG,
            targetTOG: togOutput.TOG_required,
            warnings: allWarnings,
            checkHint: safetyOutput.checkHint,
            walkWindow: safetyOutput.walkWindow,
            explanation: allSteps
        )
    }

    private func displayOutfit(
        weather: WeatherData,
        profile: ChildProfile,
        solverOutput: OutfitSolver.Output,
        carrierUnderJacket: Bool
    ) -> (layers: [RecommendedLayer], accessories: [RecommendedLayer], steps: [CalcStep]) {
        if carrierUnderJacket {
            return (solverOutput.layers, solverOutput.accessories, [])
        }

        let selectedItems = WardrobeAutoSelector.selectItems(
            temperature: weather.apparentTemperature,
            ageGroup: profile.wardrobeAgeGroup
        )
        let recommendedItems = selectedItems.sorted(by: sortForDisplay)
        let recommendedLayers = recommendedItems.map { item in
            RecommendedLayer(
                id: item.id,
                name: item.name,
                systemImage: item.symbol,
                reason: outfitReason(for: item, temperature: weather.apparentTemperature),
                tog: item.tog
            )
        }

        let bodyLayers = recommendedLayers.filter { layer in
            GarmentCatalog.byID[layer.id]?.layer != .accessory
        }
        let accessories = recommendedLayers.filter { layer in
            GarmentCatalog.byID[layer.id]?.layer == .accessory
        }
        let totalTOG = recommendedLayers.reduce(0) { $0 + $1.tog }
        let steps = [CalcStep(
            label: "Автоподбор гардероба",
            value: totalTOG,
            unit: "TOG",
            note: "По конструктору: \(Int(weather.apparentTemperature.rounded()))°C"
        )]
        return (bodyLayers, accessories, steps)
    }

    private func sortForDisplay(_ lhs: GarmentItem, _ rhs: GarmentItem) -> Bool {
        let leftRank = displayRank(for: lhs.layer)
        let rightRank = displayRank(for: rhs.layer)
        if leftRank != rightRank { return leftRank < rightRank }
        if lhs.heatValue != rhs.heatValue { return lhs.heatValue < rhs.heatValue }
        return lhs.name < rhs.name
    }

    private func displayRank(for layer: GarmentLayer) -> Int {
        switch layer {
        case .baseFull, .baseTop, .baseBottom: return 0
        case .midFull, .midTop, .midBottom: return 1
        case .outerwear: return 2
        case .accessory: return 3
        case .sleepwear: return 4
        }
    }

    private func outfitReason(for item: GarmentItem, temperature: Double) -> String {
        if item.id == "diaper" { return "Базовый слой" }
        if item.layer == .accessory { return "Аксессуар по погоде" }
        if temperature >= 30 { return "Минимум одежды при жаре" }
        if temperature >= 22 { return "Лёгкий слой для тёплой погоды" }
        if temperature >= 15 { return "Подобрано для мягкой погоды" }
        if temperature >= 5 { return "Дополнительный слой для прохлады" }
        return "Тёплый слой для холода"
    }

}
