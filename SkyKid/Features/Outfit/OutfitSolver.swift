import Foundation

// MARK: - OutfitSolver §5

enum OutfitSolver {

    struct Input: Sendable {
        let TOG_required: Double
        let T_micro: Double
        let T_hi: Double              // heat index for UV/walk-time accessories
        let uvIndex: Double
        let carrierUnderJacket: Bool  // if true, skip torso layers; accessories only
        let profile: ChildProfile
        let gearSetup: GearSetup
        let weather: WeatherData
        let precipFlags: EffectiveTemperatureCalculator.PrecipFlags
    }

    struct Output: Sendable {
        let layers: [RecommendedLayer]
        let accessories: [RecommendedLayer]
        let totalTOG: Double
        let wardrobeGap: String?      // nil = TOG achieved within tolerance
        let steps: [CalcStep]
    }

    static func solve(_ input: Input) -> Output {
        var steps: [CalcStep] = []

        let accessories = resolveAccessories(input: input)

        if input.carrierUnderJacket {
            // Torso is warm under parent's jacket — only accessories for head/feet
            steps.append(CalcStep(label: "Слинг под курткой (§5)",
                                   value: 0, unit: "TOG",
                                   note: "Утепление корпуса не требуется"))
            return Output(layers: [], accessories: accessories,
                          totalTOG: 0, wardrobeGap: nil, steps: steps)
        }

        let (layers, totalTOG, gap) = selectLayers(TOG_required: input.TOG_required,
                                                     T_micro: input.T_micro,
                                                     profile: input.profile,
                                                     gearSetup: input.gearSetup)

        steps.append(CalcStep(label: "Подбор слоёв (§5.2)",
                               value: totalTOG, unit: "TOG",
                               note: "цель: \(String(format:"%.1f", input.TOG_required)) TOG"))
        if let gap {
            steps.append(CalcStep(label: "Нехватка гардероба (§5.2)",
                                   value: input.TOG_required - totalTOG, unit: "TOG",
                                   note: gap))
        }

        return Output(layers: layers, accessories: accessories,
                      totalTOG: totalTOG, wardrobeGap: gap, steps: steps)
    }

    // MARK: - §5.2 Layer solver (skeleton-template approach)

    private static func selectLayers(
        TOG_required: Double,
        T_micro: Double,
        profile: ChildProfile,
        gearSetup: GearSetup
    ) -> (layers: [RecommendedLayer], totalTOG: Double, gap: String?) {

        let isAtopic = profile.healthConditions.contains(.atopicDermatitis)
        let isCarSeat = gearSetup.transportMode == .carSeat
        let target = TOG_required

        // §5.2: Select skeleton template IDs based on TOG range
        // Then greedily adjust using remaining catalog items
        let skeletonIDs = skeletonTemplate(for: target, isAtopic: isAtopic)
        let skeleton = skeletonIDs.compactMap { GarmentCatalog.byID[$0] }

        // Start with skeleton, then trim items that cause over-budget
        var selected = skeleton
        var achieved = selected.reduce(0) { $0 + $1.tog }

        // §6.2: round down when ambiguous — trim outermost excess first
        // Remove last item if we overshoot and it brings us closer to target
        while achieved > target + OutfitConfig.Solver.togAccuracyTolerance,
              let last = selected.last {
            if abs((achieved - last.tog) - target) < abs(achieved - target) {
                selected.removeLast()
                achieved -= last.tog
            } else {
                break
            }
        }

        // Try to add remaining non-skeleton items to fill any remaining gap
        let used = Set(selected.map(\.id))
        let extras = GarmentCatalog.all.filter { $0.layer != .accessory && !used.contains($0.id) }
        for item in extras {
            guard selected.count < OutfitConfig.Solver.maxBodyLayers else { break }
            guard achieved < target - 0.1 else { break }

            let hasHeavyOuter = selected.contains { $0.id == "demi" || $0.id == "winter" }
            if (item.id == "demi" || item.id == "winter") && hasHeavyOuter { continue }

            let hasSocks = selected.contains { $0.id == "thin_socks" || $0.id == "warm_socks" }
            if (item.id == "thin_socks" || item.id == "warm_socks") && hasSocks { continue }

            if isCarSeat && item.layer != .outer {
                let underHarnessTOG = selected.filter { $0.layer != .outer }.reduce(0) { $0 + $1.tog }
                if underHarnessTOG + item.tog > OutfitConfig.Solver.carSeatMaxHarnessLayerTOG { continue }
            }

            if isAtopic && item.id == "fleece" && selected.isEmpty { continue }

            let newAchieved = achieved + item.tog
            if newAchieved <= target + OutfitConfig.Solver.togAccuracyTolerance {
                selected.append(item)
                achieved = newAchieved
            }
        }

        let layers = selected.map { item in
            RecommendedLayer(
                id: item.id,
                name: item.name,
                systemImage: item.symbol,
                reason: layerReason(item: item, T_micro: T_micro),
                tog: item.tog
            )
        }

        let gap: String?
        if abs(achieved - target) > OutfitConfig.Solver.togAccuracyTolerance {
            gap = "Нужно ≈ \(String(format:"%.1f", target)) TOG, подобрано \(String(format:"%.1f", achieved)) TOG. Добавьте: \(suggestMissingGarment(target: target, achieved: achieved))"
        } else {
            gap = nil
        }

        return (layers, achieved, gap)
    }

    // MARK: - §5.1 Skeleton templates (ordered innermost → outermost)

    private static func skeletonTemplate(for target: Double, isAtopic: Bool) -> [String] {
        switch target {
        case ..<0.8:
            // 0.2–0.7: sleeveless bodysuit only
            return ["diaper"]

        case 0.8..<1.8:
            // 0.8–1.7: LS bodysuit + cotton onesie + leggings (spec §5.1)
            // Pants prevent extras-loop from picking thermals at mild temps (e.g. +19°C)
            return ["diaper", "slip", "pants"]

        case 1.8..<3.1:
            // 1.8–3.0: LS bodysuit + onesie + mid-season all-in-one
            if isAtopic {
                return ["diaper", "slip", "demi"]
            }
            return ["diaper", "slip", "demi"]

        case 3.1..<5.1:
            // 3.1–5.0: LS bodysuit + fleece onesie + winter all-in-one/footmuff
            if isAtopic {
                return ["diaper", "slip", "fleece", "winter"]
            }
            return ["diaper", "slip", "fleece", "winter"]

        default:
            // 5.1+: LS bodysuit + thermal + fleece onesie + winter all-in-one + blanket
            if isAtopic {
                return ["diaper", "slip", "thermals", "fleece", "winter", "warm_blanket"]
            }
            return ["diaper", "slip", "thermals", "fleece", "winter", "warm_blanket"]
        }
    }

    // MARK: - §5.3 Accessories (rule-based, independent of TOG budget)

    private static func resolveAccessories(input: Input) -> [RecommendedLayer] {
        var result: [RecommendedLayer] = []
        let T = input.T_micro
        let corrWeeks = input.profile.correctedAgeWeeks

        // Hat
        if T < 20 || corrWeeks < 4 {
            if T < 10 {
                result.append(accessory("warm_hat", name: "Тёплая шапка (закрывает уши)",
                                         reason: "T_micro < 10°C — тёплая шапка обязательна"))
            } else {
                result.append(accessory("thin_hat", name: "Тонкая шапочка",
                                         reason: T < 20 ? "Прохладно — защита головы" : "До 1 мес — шапочка всегда"))
            }
        }

        // Mittens and warm booties
        if T < 5 {
            result.append(accessory("mittens", name: "Варежки",
                                     reason: "T_micro < 5°C — защита ручек"))
            result.append(accessory("booties", name: "Тёплые пинетки / носочки",
                                     reason: "T_micro < 5°C — ножки мёрзнут"))
        }

        // Balaclava hint below −5 (no catalog item — note only)
        // UV sun hat (no dedicated catalog item — skip for now)

        return result
    }

    private static func accessory(_ id: String, name: String, reason: String) -> RecommendedLayer {
        let item = GarmentCatalog.byID[id]
        return RecommendedLayer(id: id, name: name,
                                systemImage: item?.symbol ?? "sparkles",
                                reason: reason,
                                tog: item?.tog ?? 0)
    }

    // MARK: - Helpers

    private static func layerReason(item: GarmentItem, T_micro: Double) -> String {
        switch item.id {
        case "diaper":       return "Базовый слой"
        case "slip":         return "Первый слой утепления (1.0 TOG)"
        case "thermals":     return T_micro < -5 ? "Термобельё — первый слой при морозе" : "Тёплое термобельё — базовый утепляющий слой"
        case "thin_socks":   return "Носочки"
        case "warm_socks":   return "Тёплые носочки"
        case "scratch":      return "Царапки — защита кожи"
        case "fleece":       return "Флисовый комбез — удерживает тепло"
        case "sweater":      return "Утепляющий слой"
        case "pants":        return "Ползунки"
        case "windbreaker":  return "Ветрозащита"
        case "demi":         return "Демисезонный комбез"
        case "winter":       return "Зимний комбез 3.5 TOG"
        case "thin_blanket": return "Тонкое одеялко"
        case "warm_blanket": return "Тёплое одеялко"
        default:             return item.name
        }
    }

    private static func suggestMissingGarment(target: Double, achieved: Double) -> String {
        let gap = target - achieved
        switch gap {
        case 3.0...: return "зимний комбез (3.5 TOG)"
        case 2.0..<3.0: return "демисезонный комбез (2.25 TOG)"
        case 1.5..<2.0: return "флисовый комбез (1.75 TOG)"
        case 0.8..<1.5: return "хлопковый слип (1.0 TOG)"
        default: return "лёгкий свитер (0.8 TOG)"
        }
    }
}
