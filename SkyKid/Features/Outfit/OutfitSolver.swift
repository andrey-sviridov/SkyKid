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
        /// Личный гардероб (P1-1): nil = весь каталог в наличии.
        var ownedGarmentIDs: Set<String>? = nil
    }

    struct Output: Sendable {
        let layers: [RecommendedLayer]
        let accessories: [RecommendedLayer]
        let totalTOG: Double
        let wardrobeGap: String?      // nil = TOG achieved within tolerance
        let overheatWarning: SafetyWarning?  // §5.6 двойное утепление верхним слоем
        let steps: [CalcStep]
    }

    static func solve(_ input: Input) -> Output {
        var steps: [CalcStep] = []

        let accessories = resolveAccessories(input: input)

        if input.carrierUnderJacket {
            steps.append(CalcStep(label: "Слинг под курткой (§5)",
                                   value: 0, unit: "TOG",
                                   note: "Утепление корпуса не требуется"))
            return Output(layers: [], accessories: accessories,
                          totalTOG: 0, wardrobeGap: nil,
                          overheatWarning: nil, steps: steps)
        }

        // §5.0 Gear TOG: конверт + плед снижают потребность в одежде
        // Работает только для коляски (не слинг, не автокресло).
        let supportsGearLayers = input.gearSetup.transportMode == .pramBassinette
                              || input.gearSetup.transportMode == .pushchairSeat
        let gearTOG = supportsGearLayers
            ? (input.gearSetup.strollerConvertTOG ?? 0) + (input.gearSetup.blanketTOG ?? 0)
            : 0

        if gearTOG > 0 {
            steps.append(CalcStep(label: "Конверт / плед (§5.0)", value: gearTOG, unit: "TOG",
                                   note: "Вычтено из потребности в одежде"))
        }

        let clothingTarget = max(OutfitConfig.TOG.minTOG, input.TOG_required - gearTOG)

        // При мощном конверте снимаем защиту со слипа — ребёнок тёплый без доп. слоя
        let protectionLevel: FootmuffProtection = gearTOG >= OutfitConfig.Solver.footmuffSlipProtectionThreshold
            ? .diaperOnly
            : .diaperAndSlip

        let (rawLayers, _, clothingGap) = selectLayers(
            TOG_required: clothingTarget,
            T_micro: input.T_micro,
            profile: input.profile,
            gearSetup: input.gearSetup,
            protection: protectionLevel,
            ownedIDs: input.ownedGarmentIDs
        )

        // §5.6 Защита от двойного утепления: тяжёлый комбез + второй верхний
        // слой/меховой конверт → снимаем лишнее и/или предупреждаем о перегреве.
        let (layers, overheatWarning) = overheatGuard(
            layers: rawLayers,
            gearSetup: input.gearSetup,
            supportsGearLayers: supportsGearLayers
        )
        let clothingTOG = layers.reduce(0) { $0 + $1.tog }

        steps.append(CalcStep(label: "Подбор слоёв (§5.2)", value: clothingTOG, unit: "TOG",
                               note: "цель одежда: \(String(format:"%.1f", clothingTarget)) TOG"))
        if overheatWarning != nil {
            steps.append(CalcStep(label: "Двойное утепление (§5.6)", value: clothingTOG + gearTOG, unit: "TOG",
                                   note: "Перегрев: снят лишний верхний слой / нужно убрать конверт"))
        }
        if let g = clothingGap {
            steps.append(CalcStep(label: "Нехватка гардероба (§5.2)",
                                   value: clothingTarget - clothingTOG, unit: "TOG", note: g))
        }

        // §5.5 Мокрая одежда: осадки без дождевика → потеря ~35% TOG
        let isWet = input.precipFlags.needsRainCover
        let moistureFactor = isWet ? OutfitConfig.Solver.wetClothingRetentionFactor : 1.0
        let dryTotalTOG   = clothingTOG + gearTOG
        let effectiveTOG  = dryTotalTOG * moistureFactor

        var gap = clothingGap
        if isWet {
            steps.append(CalcStep(label: "Мокрая одежда (§5.5)", value: effectiveTOG, unit: "TOG",
                                   note: String(format: "×%.2g от осадков: %.1f → %.1f TOG",
                                                moistureFactor, dryTotalTOG, effectiveTOG)))
            if effectiveTOG < input.TOG_required - OutfitConfig.Solver.togAccuracyTolerance {
                let lossMsg = "Мокрая одежда теряет ~35% тепла. Эффективный TOG: \(String(format:"%.1f", effectiveTOG)) из \(String(format:"%.1f", input.TOG_required)). Установите дождевик."
                gap = gap.map { "\($0) \(lossMsg)" } ?? lossMsg
            }
        }

        return Output(layers: layers, accessories: accessories,
                      totalTOG: dryTotalTOG, wardrobeGap: gap,
                      overheatWarning: overheatWarning, steps: steps)
    }

    // MARK: - §5.6 Double-insulation guard

    /// Не даём сложить два тяжёлых верхних слоя: зимний комбез (≥ heavyOuterTOGThreshold)
    /// + ещё один слой верхней одежды или меховой конверт-гир = перегрев в коляске.
    /// Если в одежде два слоя Outerwear — снимаем более лёгкий (оставляем тёплый).
    /// Конверт-гир снять нельзя — только предупреждаем.
    private static func overheatGuard(
        layers: [RecommendedLayer],
        gearSetup: GearSetup,
        supportsGearLayers: Bool
    ) -> (layers: [RecommendedLayer], warning: SafetyWarning?) {

        let outerwear = layers.filter { GarmentCatalog.byID[$0.id]?.layer == .outerwear }
        let hasHeavySuit = outerwear.contains { $0.tog >= OutfitConfig.Solver.heavyOuterTOGThreshold }
        guard hasHeavySuit else { return (layers, nil) }

        // Второй источник утепления: ещё один слой верхней одежды ИЛИ конверт-гир (§5.0)
        let gearConvertTOG = supportsGearLayers ? (gearSetup.strollerConvertTOG ?? 0) : 0
        let outerSources = outerwear.count + (gearConvertTOG > 0 ? 1 : 0)
        guard outerSources >= 2 else { return (layers, nil) }

        // Принудительное ограничение: снимаем самый лёгкий из слоёв верхней одежды
        var capped = layers
        if outerwear.count >= 2, let lightest = outerwear.min(by: { $0.tog < $1.tog }) {
            capped.removeAll { $0.id == lightest.id }
        }

        let warning = SafetyWarning(
            code: .overheatPriority,
            severity: .danger,
            message: "Перегрев: тёплый зимний комбез вместе с меховым конвертом или вторым верхним слоем — это двойное утепление. Оставьте что-то одно, иначе малыш вспотеет и переохладится на ветру.",
            systemImage: "thermometer.sun.fill"
        )
        return (capped, warning)
    }

    // Уровень защиты минимальных слоёв (снижается при тёплом конверте)
    private enum FootmuffProtection {
        case diaperAndSlip  // стандарт: подгузник + слип защищены
        case diaperOnly     // конверт заменяет слип → только подгузник
    }

    // MARK: - §5.2 Layer solver (skeleton-template approach)

    private static func selectLayers(
        TOG_required: Double,
        T_micro: Double,
        profile: ChildProfile,
        gearSetup: GearSetup,
        protection: FootmuffProtection = .diaperAndSlip,
        ownedIDs: Set<String>? = nil
    ) -> (layers: [RecommendedLayer], totalTOG: Double, gap: String?) {

        let isAtopic = profile.healthConditions.contains(.atopicDermatitis)
        let isCarSeat = gearSetup.transportMode == .carSeat
        let isStroller = gearSetup.transportMode == .pramBassinette
                      || gearSetup.transportMode == .pushchairSeat
        let target = TOG_required

        // P1-1: подгузник есть всегда — не даём гардеробу сломать скелет.
        // Остальное: nil = весь каталог; не-nil = только переданный набор.
        let isOwned: (String) -> Bool = { id in
            id == "diaper" || ownedIDs?.contains(id) ?? true
        }

        // §5.2: Select skeleton template IDs based on TOG range
        // Then greedily adjust using remaining catalog items
        let skeletonIDs = skeletonTemplate(for: target, isStroller: isStroller)
        let missingSkeleton = skeletonIDs.filter { !isOwned($0) }
        let skeleton = skeletonIDs.filter(isOwned).compactMap { GarmentCatalog.byID[$0] }

        // Start with skeleton, then trim items that cause over-budget
        var selected = skeleton
        var achieved = selected.reduce(0) { $0 + $1.tog }

        // §6.2: round down when ambiguous — trim outermost excess first.
        // При мощном конверте снимаем защиту слипа — он уже заменён конвертом.
        let protectedIDs: Set<String> = protection == .diaperOnly
            ? ["diaper"]
            : ["diaper", "slip", "thermals"]
        while achieved > target + OutfitConfig.Solver.togAccuracyTolerance,
              let last = selected.last,
              !protectedIDs.contains(last.id) {
            if abs((achieved - last.tog) - target) < abs(achieved - target) {
                selected.removeLast()
                achieved -= last.tog
            } else {
                break
            }
        }

        // Try to add remaining body items to fill any remaining gap.
        // «Виртуальный манекен»: каждый слой занимает анатомические слоты;
        // нельзя надеть два боди (baseTop) или слип + боди (baseFull vs baseTop).
        // Аксессуары и одежда для сна (sleepwear) в подбор лука не входят.
        let used = Set(selected.map(\.id))
        var occupiedSlots: Set<BodySlot> = Set(selected.flatMap { slots(of: $0) })
        // Сортируем по TOG убыванию: жадный алгоритм заполняет бюджет тяжёлыми
        // вещами первыми — лёгкое боди не блокирует слот нужного свитера/флиса.
        let extras = GarmentCatalog.all.filter {
            $0.layer.occupiesBody && !used.contains($0.id) && isOwned($0.id)
        }.sorted { $0.tog > $1.tog }
        for item in extras {
            guard selected.count < OutfitConfig.Solver.maxBodyLayers else { break }
            guard achieved < target - 0.1 else { break }

            // Слот-конфликт: анатомический слот уже занят несовместимым слоем
            let candidateSlots = slots(of: item)
            if !candidateSlots.isDisjoint(with: occupiedSlots) { continue }

            if isCarSeat && item.layer != .outerwear {
                let underHarnessTOG = selected.filter { $0.layer != .outerwear }.reduce(0) { $0 + $1.tog }
                if underHarnessTOG + item.tog > OutfitConfig.Solver.carSeatMaxHarnessLayerTOG { continue }
            }

            if isAtopic && item.id == "fleece" && selected.isEmpty { continue }

            let newAchieved = achieved + item.tog
            if newAchieved <= target + OutfitConfig.Solver.togAccuracyTolerance {
                selected.append(item)
                achieved = newAchieved
                occupiedSlots.formUnion(candidateSlots)
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
            let missingNames = missingSkeleton.compactMap { GarmentCatalog.byID[$0]?.name }
            if missingNames.isEmpty {
                gap = "Нужно ≈ \(String(format:"%.1f", target)) TOG, подобрано \(String(format:"%.1f", achieved)) TOG. Добавьте: \(suggestMissingGarment(target: target, achieved: achieved))"
            } else {
                gap = "В вашем гардеробе нет: \(missingNames.joined(separator: ", ").lowercased()). Без этого набирается \(String(format:"%.1f", achieved)) TOG из ≈ \(String(format:"%.1f", target))."
            }
        } else {
            gap = nil
        }

        return (layers, achieved, gap)
    }

    // MARK: - §5.1 Skeleton templates (ordered innermost → outermost)
    // Каждый шаблон слот-валиден: один base-full, один mid-full, один outer.
    // Одеяла/конверты — это гир (§5.0), а не слой одежды, поэтому в шаблонах нет.

    private static func skeletonTemplate(for target: Double, isStroller: Bool) -> [String] {
        switch target {
        case ..<0.8:
            return ["diaper", "slip"]

        case 0.8..<1.8:
            // 0.8–1.7: слип (baseFull); пешком/автокресло добавляем штаны (midBottom),
            // в коляске тепло догоняет плед-гир (§5.0)
            return isStroller
                ? ["diaper", "slip"]
                : ["diaper", "slip", "pants"]

        case 1.8..<3.1:
            // 1.8–3.0: слип (baseFull) + демисезонный комбез (outer)
            return ["diaper", "slip", "demi"]

        case 3.1..<5.1:
            // 3.1–5.0: слип (baseFull) + флис (midFull) + зимний комбез (outer)
            return ["diaper", "slip", "fleece", "winter"]

        default:
            // 5.1+: термобельё (baseFull) + флис (midFull) + зимний комбез (outer)
            return ["diaper", "thermals", "fleece", "winter"]
        }
    }

    /// Слоты предмета. Подгузник — нательное бельё, не занимает слотов
    /// (иначе нельзя было бы надеть боди/слип поверх).
    private static func slots(of item: GarmentItem) -> Set<BodySlot> {
        item.id == "diaper" ? [] : item.layer.bodySlots
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
        case "slip":         return "Базовый слой (боди/слип)"
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
        case 1.5..<2.0: return "флисовый комбез (1.2 TOG)"
        case 0.8..<1.5: return "хлопковый слип (0.6 TOG)"
        default: return "лёгкий свитер (0.8 TOG)"
        }
    }
}
