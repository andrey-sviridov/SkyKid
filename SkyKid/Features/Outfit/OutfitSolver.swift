import Foundation

// MARK: - OutfitSolver §5

enum OutfitSolver {

    struct Input: Sendable {
        let TOG_required: Double
        let T_micro: Double
        let accessoryTemperature: Double
        let T_hi: Double
        let uvIndex: Double
        let carrierUnderJacket: Bool
        let profile: ChildThermalProfile
        let gearSetup: GearSetup
        let weather: NormalizedWeather
        let precipFlags: EffectiveTemperatureCalculator.PrecipFlags
        var ownedGarmentIDs: Set<String>?

        init(
            TOG_required: Double,
            T_micro: Double,
            accessoryTemperature: Double? = nil,
            T_hi: Double,
            uvIndex: Double,
            carrierUnderJacket: Bool,
            profile: ChildThermalProfile,
            gearSetup: GearSetup,
            weather: NormalizedWeather,
            precipFlags: EffectiveTemperatureCalculator.PrecipFlags,
            ownedGarmentIDs: Set<String>? = nil
        ) {
            self.TOG_required = TOG_required
            self.T_micro = T_micro
            self.accessoryTemperature = accessoryTemperature ?? T_micro
            self.T_hi = T_hi
            self.uvIndex = uvIndex
            self.carrierUnderJacket = carrierUnderJacket
            self.profile = profile
            self.gearSetup = gearSetup
            self.weather = weather
            self.precipFlags = precipFlags
            self.ownedGarmentIDs = ownedGarmentIDs
        }

        init(
            TOG_required: Double,
            T_micro: Double,
            accessoryTemperature: Double? = nil,
            T_hi: Double,
            uvIndex: Double,
            carrierUnderJacket: Bool,
            profile: ChildProfile,
            gearSetup: GearSetup,
            weather: NormalizedWeather,
            precipFlags: EffectiveTemperatureCalculator.PrecipFlags,
            ownedGarmentIDs: Set<String>? = nil
        ) {
            self.init(
                TOG_required: TOG_required,
                T_micro: T_micro,
                accessoryTemperature: accessoryTemperature,
                T_hi: T_hi,
                uvIndex: uvIndex,
                carrierUnderJacket: carrierUnderJacket,
                profile: profile.thermalProfile,
                gearSetup: gearSetup,
                weather: weather,
                precipFlags: precipFlags,
                ownedGarmentIDs: ownedGarmentIDs
            )
        }
    }

    struct Output: Sendable {
        let layers: [RecommendedLayer]
        let accessories: [RecommendedLayer]
        let missingGarments: [RecommendedLayer]
        let totalTOG: Double
        let fit: OutfitFit?
        let wardrobeGap: String?
        let overheatWarning: SafetyWarning?
        let steps: [CalcStep]
    }

    static func solve(_ input: Input) -> Output {
        var steps: [CalcStep] = []
        let accessoryPair = resolveAccessories(input: input)

        if input.carrierUnderJacket {
            steps.append(CalcStep(
                label: "Слинг под курткой (§5)",
                value: 0,
                unit: "TOG",
                note: "Корпус согревают родитель и верхняя одежда; отдельно проверяйте открытые зоны"
            ))
            return Output(
                layers: [],
                accessories: accessoryPair.actual,
                missingGarments: accessoryPair.missing,
                totalTOG: 0,
                fit: nil,
                wardrobeGap: missingMessage(for: accessoryPair.missing, achieved: 0, target: 0),
                overheatWarning: nil,
                steps: steps
            )
        }

        let gearTOG = supportedGearTOG(input)
        if gearTOG > 0 {
            steps.append(CalcStep(
                label: "Конверт / плед (§5.0)",
                value: gearTOG,
                unit: "TOG",
                note: "Вычтено из потребности в одежде"
            ))
        }

        let clothingTarget = max(OutfitConfig.TOG.minTOG, input.TOG_required - gearTOG)
        let actual = solveBodyLayers(
            targetTOG: clothingTarget,
            input: input,
            availableIDs: input.ownedGarmentIDs
        )
        let ideal = solveBodyLayers(
            targetTOG: clothingTarget,
            input: input,
            availableIDs: nil
        )

        let rawLayers = recommendedLayers(from: actual.items, temperature: input.T_micro)
        let guardResult = overheatGuard(
            layers: rawLayers,
            gearSetup: input.gearSetup,
            supportsGearLayers: supportsGearLayers(input.gearSetup.transportMode)
        )
        let clothingTOG = guardResult.layers.reduce(0) { $0 + $1.tog }

        let bodySelectionIsAdequate = actual.missingBaseSlots.isEmpty
            && abs(actual.totalTOG - clothingTarget) <= OutfitConfig.Solver.togAccuracyTolerance
        let missingBody = bodySelectionIsAdequate
            ? []
            : missingRecommendations(
                ideal: ideal.items,
                actual: actual.items,
                temperature: input.T_micro
            )
        let missing = deduplicated(missingBody + accessoryPair.missing)

        steps.append(CalcStep(
            label: "Подбор слоёв (§5.2)",
            value: clothingTOG,
            unit: "TOG",
            note: "цель одежда: \(String(format: "%.1f", clothingTarget)) TOG"
        ))
        if guardResult.warning != nil {
            steps.append(CalcStep(
                label: "Двойное утепление (§5.6)",
                value: clothingTOG + gearTOG,
                unit: "TOG",
                note: "Снят конфликтующий верхний слой"
            ))
        }

        let dryTotalTOG = clothingTOG + gearTOG
        let moistureFactor = input.precipFlags.needsRainCover
            ? OutfitConfig.Solver.wetClothingRetentionFactor
            : 1.0
        let effectiveTOG = dryTotalTOG * moistureFactor

        if moistureFactor < 1 {
            steps.append(CalcStep(
                label: "Мокрая одежда (§5.5)",
                value: effectiveTOG,
                unit: "TOG",
                note: String(
                    format: "Без дождевика: %.1f → %.1f TOG",
                    dryTotalTOG,
                    effectiveTOG
                )
            ))
        }

        let hasCoverage = actual.missingBaseSlots.isEmpty
        let accessoriesCovered = accessoryPair.actualMissingZones.isEmpty
        let fit = makeFit(
            targetTOG: input.TOG_required,
            effectiveTOG: effectiveTOG,
            hasCoverage: hasCoverage,
            accessoriesCovered: accessoriesCovered
        )
        let gap = gapMessage(
            missing: missing,
            fit: fit,
            moistureLoss: moistureFactor < 1
        )

        if let gap {
            steps.append(CalcStep(
                label: "Ограничение подбора (§5.2)",
                value: fit.deltaTOG,
                unit: "TOG",
                note: gap
            ))
        }

        return Output(
            layers: guardResult.layers,
            accessories: accessoryPair.actual,
            missingGarments: missing,
            totalTOG: dryTotalTOG,
            fit: fit,
            wardrobeGap: gap,
            overheatWarning: guardResult.warning,
            steps: steps
        )
    }

    // MARK: - Body layers

    private static func solveBodyLayers(
        targetTOG: Double,
        input: Input,
        availableIDs: Set<String>?
    ) -> OutfitCombinationSolver.Result {
        OutfitCombinationSolver.solve(.init(
            targetTOG: targetTOG,
            temperature: input.T_micro,
            profile: input.profile,
            transportMode: input.gearSetup.transportMode,
            availableGarmentIDs: availableIDs
        ))
    }

    private static func recommendedLayers(
        from items: [GarmentItem],
        temperature: Double
    ) -> [RecommendedLayer] {
        items.map { item in
            RecommendedLayer(
                id: item.id,
                name: item.name,
                systemImage: item.symbol,
                reason: layerReason(item: item, temperature: temperature),
                tog: item.tog
            )
        }
    }

    private static func missingRecommendations(
        ideal: [GarmentItem],
        actual: [GarmentItem],
        temperature: Double
    ) -> [RecommendedLayer] {
        let actualIDs = Set(actual.map(\.id))
        return recommendedLayers(
            from: ideal.filter { $0.id != "diaper" && !actualIDs.contains($0.id) },
            temperature: temperature
        )
    }

    // MARK: - Accessories

    private struct AccessoryPair {
        let actual: [RecommendedLayer]
        let missing: [RecommendedLayer]
        let actualMissingZones: Set<BodyZone>
    }

    private static func resolveAccessories(input: Input) -> AccessoryPair {
        let request = OutfitAccessoryResolver.Request(
            temperature: input.accessoryTemperature,
            heatIndex: input.T_hi,
            uvIndex: input.uvIndex,
            correctedAgeWeeks: input.profile.correctedAgeWeeks,
            ageGroup: input.profile.wardrobeAgeGroup,
            availableGarmentIDs: input.ownedGarmentIDs
        )
        let actual = OutfitAccessoryResolver.resolve(request)
        let ideal = OutfitAccessoryResolver.resolve(.init(
            temperature: request.temperature,
            heatIndex: request.heatIndex,
            uvIndex: request.uvIndex,
            correctedAgeWeeks: request.correctedAgeWeeks,
            ageGroup: request.ageGroup,
            availableGarmentIDs: nil
        ))

        let actualLayers = actual.selections.map(recommendedAccessory)
        let missing = ideal.selections
            .filter { idealSelection in
                !actual.selections.contains { actualSelection in
                    !idealSelection.item.coveredZones.isDisjoint(
                        with: actualSelection.item.coveredZones
                    )
                }
            }
            .map(recommendedAccessory)

        return AccessoryPair(
            actual: actualLayers,
            missing: missing,
            actualMissingZones: actual.missingZones
        )
    }

    private static func recommendedAccessory(
        _ selection: OutfitAccessoryResolver.Selection
    ) -> RecommendedLayer {
        RecommendedLayer(
            id: selection.item.id,
            name: selection.item.name,
            systemImage: selection.item.symbol,
            reason: selection.reason,
            tog: selection.item.tog
        )
    }

    // MARK: - Fit and gaps

    private static func makeFit(
        targetTOG: Double,
        effectiveTOG: Double,
        hasCoverage: Bool,
        accessoriesCovered: Bool
    ) -> OutfitFit {
        let delta = effectiveTOG - targetTOG
        let confidence: OutfitFit.Confidence
        if hasCoverage,
           accessoriesCovered,
           abs(delta) <= OutfitConfig.Solver.togAccuracyTolerance {
            confidence = .high
        } else if hasCoverage,
                  abs(delta) <= OutfitConfig.Solver.mediumConfidenceTolerance {
            confidence = .medium
        } else {
            confidence = .low
        }
        return OutfitFit(
            targetTOG: targetTOG,
            effectiveTOG: effectiveTOG,
            deltaTOG: delta,
            confidence: confidence,
            hasRequiredBodyCoverage: hasCoverage
        )
    }

    private static func gapMessage(
        missing: [RecommendedLayer],
        fit: OutfitFit,
        moistureLoss: Bool
    ) -> String? {
        var parts: [String] = []
        if !missing.isEmpty {
            let names = missing.map { $0.name.lowercased() }.joined(separator: ", ")
            parts.append("В гардеробе не хватает: \(names).")
        }
        if fit.confidence != .high {
            parts.append(String(
                format: "Цель %.1f TOG, доступный комплект даёт %.1f TOG.",
                fit.targetTOG,
                fit.effectiveTOG
            ))
        }
        if moistureLoss {
            parts.append("Без дождевика промокание снижает теплоизоляцию одежды.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private static func missingMessage(
        for missing: [RecommendedLayer],
        achieved: Double,
        target: Double
    ) -> String? {
        guard !missing.isEmpty else { return nil }
        let names = missing.map { $0.name.lowercased() }.joined(separator: ", ")
        return "В гардеробе не хватает: \(names). Подобрано \(achieved) из \(target) TOG."
    }

    private static func deduplicated(_ layers: [RecommendedLayer]) -> [RecommendedLayer] {
        var seen: Set<String> = []
        return layers.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Gear and overheat

    private static func supportedGearTOG(_ input: Input) -> Double {
        guard supportsGearLayers(input.gearSetup.transportMode) else { return 0 }
        return (input.gearSetup.strollerConvertTOG ?? 0)
            + (input.gearSetup.blanketTOG ?? 0)
    }

    private static func supportsGearLayers(_ mode: TransportMode) -> Bool {
        mode == .pramBassinette || mode == .pushchairSeat
    }

    private static func overheatGuard(
        layers: [RecommendedLayer],
        gearSetup: GearSetup,
        supportsGearLayers: Bool
    ) -> (layers: [RecommendedLayer], warning: SafetyWarning?) {
        let outerwear = layers.filter { GarmentCatalog.byID[$0.id]?.layer == .outerwear }
        let hasHeavySuit = outerwear.contains {
            $0.tog >= OutfitConfig.Solver.heavyOuterTOGThreshold
        }
        guard hasHeavySuit else { return (layers, nil) }

        let convertTOG = supportsGearLayers ? (gearSetup.strollerConvertTOG ?? 0) : 0
        guard outerwear.count + (convertTOG > 0 ? 1 : 0) >= 2 else {
            return (layers, nil)
        }

        var capped = layers
        if outerwear.count >= 2,
           let lightest = outerwear.min(by: { $0.tog < $1.tog }) {
            capped.removeAll { $0.id == lightest.id }
        }

        return (capped, SafetyWarning(
            code: .overheatPriority,
            severity: .danger,
            message: "Тёплый зимний комбез вместе с меховым конвертом или вторым верхним слоем создаёт двойное утепление. Оставьте что-то одно.",
            systemImage: "thermometer.sun.fill"
        ))
    }

    // MARK: - Copy

    private static func layerReason(item: GarmentItem, temperature: Double) -> String {
        switch item.layer {
        case .baseFull, .baseTop, .baseBottom:
            return temperature >= 24 ? "Лёгкий базовый слой" : "Базовый слой у кожи"
        case .midFull, .midTop, .midBottom:
            return "Утепляющий средний слой"
        case .outerwear:
            return "Защита от холода и ветра"
        case .accessory:
            return "Защита открытой зоны"
        case .sleepwear:
            return item.name
        }
    }
}
