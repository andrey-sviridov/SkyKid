import Foundation

// MARK: - LegacyWardrobeAutoSelector

/// Старый CLO-подбор используется только вкладкой «Конструктор».
/// Основная рекомендация всегда проходит через OutfitSolver.
enum LegacyWardrobeAutoSelector {
    static func selectItems(
        temperature: Double,
        ageGroup: WardrobeAgeGroup,
        pinnedItemIDs: Set<String> = WardrobePinnedItemsStore.loadIDs()
    ) -> Set<GarmentItem> {
        var selected = Set(GarmentCatalog.all.filter { pinnedItemIDs.contains($0.id) })
        if temperature >= 30 { return selected }

        let orderedIDs = candidateIDs(for: temperature, ageGroup: ageGroup)
        let requiredHeat = requiredHeat(for: temperature, ageGroup: ageGroup)
        var occupiedSlots = Set(selected.flatMap { bodySlots(of: $0) })
        var bestSelection = selected
        var bestDeviation = abs(totalHeat(selected) - requiredHeat)

        for id in orderedIDs {
            guard let item = GarmentCatalog.byID[id] else { continue }
            let candidateSlots = bodySlots(of: item)
            guard candidateSlots.isDisjoint(with: occupiedSlots) else { continue }
            guard canAdd(item, to: selected) else { continue }

            let candidate = selected.union([item])
            let nextRisk = riskLevel(for: candidate, temperature: temperature, requiredHeat: requiredHeat)
            guard nextRisk != .criticalOverheat else { continue }

            let currentRisk = riskLevel(for: selected, temperature: temperature, requiredHeat: requiredHeat)
            let isStillCold = currentRisk == .dangerouslyCold || currentRisk == .cold || currentRisk == .slightlyCold
            if isStillCold && nextRisk == .hot { continue }

            selected = candidate
            occupiedSlots.formUnion(candidateSlots)

            let deviation = abs(totalHeat(selected) - requiredHeat)
            if deviation < bestDeviation {
                bestDeviation = deviation
                bestSelection = selected
            }

            let settledRisk = riskLevel(for: selected, temperature: temperature, requiredHeat: requiredHeat)
            if settledRisk == .hot || settledRisk == .criticalOverheat { break }
        }

        if temperature <= -10, let blanket = GarmentCatalog.byID["warm_blanket"] {
            bestSelection.insert(blanket)
        }
        return applyingMinimumOutdoorCoverage(
            to: bestSelection,
            temperature: temperature,
            ageGroup: ageGroup
        )
    }

    private static func applyingMinimumOutdoorCoverage(
        to items: Set<GarmentItem>,
        temperature: Double,
        ageGroup: WardrobeAgeGroup
    ) -> Set<GarmentItem> {
        guard (24..<30).contains(temperature) else { return items }
        guard !items.contains(where: hasOutdoorBodyCoverage) else { return items }

        var coveredItems = items
        for id in minimumOutdoorCoverageIDs(for: ageGroup) {
            guard let item = GarmentCatalog.byID[id] else { continue }
            guard canAdd(item, to: coveredItems) else { continue }
            coveredItems.insert(item)
            break
        }
        return coveredItems
    }

    private static func hasOutdoorBodyCoverage(_ item: GarmentItem) -> Bool {
        item.id != "diaper" && item.layer.occupiesBody
    }

    private static func minimumOutdoorCoverageIDs(for ageGroup: WardrobeAgeGroup) -> [String] {
        switch ageGroup {
        case .earlyInfant: return ["bodi_km_kr", "slip_thin"]
        case .infant: return ["bodi_short", "pesochnik"]
        case .active: return ["t_shirt", "bodi_short"]
        }
    }

    private static func candidateIDs(for temperature: Double, ageGroup: WardrobeAgeGroup) -> [String] {
        switch (temperature, ageGroup) {
        case (22..., .earlyInfant):
            return ["slip_thin", "thin_socks", "bodi_km_kr", "sun_hat"]
        case (22..., .infant):
            return ["pesochnik", "noski_thin", "shapka_trik", "kofta_cardigan", "bodi_short", "thin_socks"]
        case (22..., .active):
            return ["t_shirt", "shorts_light", "noski_thin", "thin_socks"]

        case (15..<22, .earlyInfant):
            return ["slip_thin", "bodi_km_kr", "thin_socks", "thin_hat", "bodi_km_dr", "slip_thick", "thin_blanket", "fleece_overall"]
        case (15..<22, .infant):
            return ["pesochnik", "bodi_short", "thin_socks", "noski_thin", "thin_hat", "shapka_trik", "kofta_cardigan", "thin_blanket", "slip_open", "slip_closed", "fleece_overall", "knit_overall", "fleece", "sweater"]
        case (15..<22, .active):
            return ["t_shirt", "longsleeve", "thin_socks", "noski_thin", "leggings", "thin_hat", "kofta_cardigan", "thin_blanket", "fleece", "sweater"]

        case (10..<15, .earlyInfant):
            return ["slip_thin", "bodi_km_dr", "thin_socks", "warm_socks", "thin_hat", "slip_thick", "thin_blanket", "fleece_overall", "knit_overall", "booties", "warm_hat", "warm_blanket"]
        case (10..<15, .infant):
            return ["bodi_short", "thin_socks", "noski_thin", "shtany_trik", "kofta_cardigan", "slip_open", "warm_socks", "thin_hat", "shapka_trik", "slip_closed", "bodi_long", "thin_blanket", "fleece_overall", "knit_overall", "booties", "warm_hat", "windbreaker", "warm_blanket"]
        case (10..<15, .active):
            return ["longsleeve", "thin_socks", "noski_thin", "leggings", "thin_hat", "fleece", "pants", "booties", "warm_hat", "windbreaker", "thin_blanket"]

        case (5..<10, .earlyInfant):
            return ["slip_thin", "bodi_km_dr", "warm_socks", "thin_hat", "slip_thick", "fleece_overall", "knit_overall", "booties", "warm_hat", "mittens", "demi_overall", "thin_blanket", "warm_blanket"]
        case (5..<10, .infant):
            return ["slip_closed", "bodi_long", "warm_socks", "thin_hat", "kofta_cardigan", "fleece_overall", "knit_overall", "booties", "warm_hat", "mittens", "demi_overall", "thin_blanket", "warm_blanket"]
        case (5..<10, .active):
            return ["longsleeve", "warm_socks", "thin_hat", "fleece", "leggings", "pants", "booties", "warm_hat", "mittens", "windbreaker", "demi"]

        case (0..<5, .earlyInfant):
            return ["slip_thick", "bodi_km_dr", "warm_socks", "booties", "thin_hat", "fleece_overall", "knit_overall", "warm_hat", "mittens", "thin_blanket", "demi_overall", "warm_blanket"]
        case (0..<5, .infant):
            return ["slip_futer", "bodi_long", "warm_socks", "booties", "thin_hat", "fleece_overall", "knit_overall", "warm_hat", "mittens", "thin_blanket", "demi_overall", "warm_blanket"]
        case (0..<5, .active):
            return ["thermals", "warm_socks", "thin_hat", "fleece", "pants", "booties", "warm_hat", "mittens", "windbreaker", "thin_blanket", "demi"]

        case ((-10)..<0, _) where temperature > -10:
            return ["thermals", "warm_socks", "booties", "fleece_overall", "warm_hat", "mittens", "demi_overall", "demi", "warm_blanket", "winter"]
        default:
            return ["thermals", "warm_socks", "booties", "sweater", "fleece_overall", "warm_hat", "mittens", "winter_overall", "winter", "warm_blanket"]
        }
    }

    private static func requiredHeat(for temperature: Double, ageGroup: WardrobeAgeGroup) -> Double {
        let baseline: Double
        switch ageGroup {
        case .earlyInfant: baseline = 28.0
        case .infant: baseline = 26.0
        case .active: baseline = 24.0
        }
        let base = max(0.0, (baseline - temperature) * 0.5)
        return ageGroup == .active && temperature < 15 ? base * 0.85 : base
    }

    private static func canAdd(_ item: GarmentItem, to selected: Set<GarmentItem>) -> Bool {
        let exclusiveGroups: [Set<String>] = [
            ["thin_socks", "warm_socks", "noski_thin", "noski_thick", "wool_socks"],
            ["thin_hat", "warm_hat", "shapka_trik", "balaclava_hat", "sun_hat"],
            ["thin_blanket", "warm_blanket"]
        ]
        return !exclusiveGroups.contains { group in
            group.contains(item.id) && selected.contains { group.contains($0.id) }
        }
    }

    private static func bodySlots(of item: GarmentItem) -> Set<BodySlot> {
        item.id == "diaper" ? [] : item.layer.bodySlots
    }

    private static func totalHeat(_ items: Set<GarmentItem>) -> Double {
        items.reduce(0.0) { $0 + $1.heatValue }
    }

    private static func riskLevel(
        for items: Set<GarmentItem>,
        temperature: Double,
        requiredHeat: Double
    ) -> ThermalRisk {
        if temperature >= 30 { return .criticalOverheat }
        if temperature <= -10 { return .dangerouslyCold }

        let deviation = totalHeat(items) - requiredHeat
        let zone = temperature >= 22 ? TempZone.hot : (temperature >= 10 ? .mild : .cold)
        let risk = zoneRisk(deviation: deviation, zone: zone)
        guard risk == .optimal else { return risk }
        if deviation > 0.2 { return .warm }
        if deviation < -0.2 { return .slightlyCold }
        return .optimal
    }

    private enum TempZone { case hot, mild, cold }

    private static func zoneRisk(deviation: Double, zone: TempZone) -> ThermalRisk {
        switch zone {
        case .hot:
            if deviation >= 1.5 { return .criticalOverheat }
            if deviation > 0.5 { return .hot }
            return .optimal
        case .mild:
            if deviation >= 3.0 { return .criticalOverheat }
            if deviation >= 1.5 { return .hot }
            if deviation >= -1.0 { return .optimal }
            if deviation >= -2.5 { return .slightlyCold }
            return .cold
        case .cold:
            if deviation >= 5.0 { return .hot }
            if deviation >= 2.0 { return .warm }
            if deviation >= -1.5 { return .optimal }
            if deviation >= -4.0 { return .slightlyCold }
            return .dangerouslyCold
        }
    }
}
