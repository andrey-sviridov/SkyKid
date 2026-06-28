import SwiftUI

// MARK: - WardrobeModel
// SRP: содержит только бизнес-логику выбора одежды.
// View-компоненты живут в ClothingCalculatorView.swift.
// Доменные типы (GarmentItem, ThermalRisk, …) — в GarmentCatalog.swift.

@MainActor
@Observable
final class WardrobeModel {

    // ── Inputs (drive all derived values) ─────────────────────────────────
    var temperature: Double
    var ageGroup: WardrobeAgeGroup
    var selectedItems: Set<GarmentItem> = []

    /// Идентификаторы вещей, которые надеваются всегда (не снимаются при расчёте).
    private(set) var pinnedItemIDs: Set<String> = []

    /// Температура из погодной вкладки — база для сброса.
    var weatherTemperature: Double

    init(temperature: Double = 12.0, ageGroup: WardrobeAgeGroup = .earlyInfant) {
        self.temperature        = temperature
        self.weatherTemperature = temperature
        self.ageGroup           = ageGroup
        let loaded = WardrobePinnedItemsStore.loadIDs()
        self.pinnedItemIDs = loaded
        for id in loaded {
            if let item = GarmentCatalog.byID[id] { selectedItems.insert(item) }
        }
    }

    // ── Закреплённые вещи ─────────────────────────────────────────────────

    func isPinned(_ item: GarmentItem) -> Bool { pinnedItemIDs.contains(item.id) }

    func pin(_ item: GarmentItem) {
        pinnedItemIDs.insert(item.id)
        selectedItems.insert(item)
        WardrobePinnedItemsStore.saveIDs(pinnedItemIDs)
    }

    func unpin(_ item: GarmentItem) {
        pinnedItemIDs.remove(item.id)
        WardrobePinnedItemsStore.saveIDs(pinnedItemIDs)
    }

    // ── Температурная зона (задаёт допуски риска) ─────────────────────────
    private enum TempZone { case hot, mild, cold }
    private var tempZone: TempZone {
        if temperature >= 22 { return .hot  }
        if temperature >= 10 { return .mild }
        return .cold
    }

    // ── Формула потребности в тепле ───────────────────────────────────────
    // +35°C → 0 CLO | baseline → 0 CLO | 0°C → ~12 CLO | −20°C → ~22 CLO
    // Source: neonatology.pdf, с. 55 + Алгоритм одевания, стр. 9
    var requiredHeat: Double {
        let baseline: Double
        switch ageGroup {
        case .earlyInfant: baseline = Self.earlyInfantComfortBaseline
        case .infant:      baseline = Self.newbornComfortBaseline
        case .active:      baseline = Self.defaultComfortBaseline
        }
        let base = max(0.0, (baseline - temperature) * Self.heatSlopePerDegree)
        return (ageGroup == .active && temperature < Self.activeHeatThreshold)
            ? base * Self.activeHeatReduction
            : base
    }

    var currentHeat: Double { selectedItems.reduce(0) { $0 + $1.heatValue } }

    /// +ve = перегрев, −ve = недостаточно тепла
    var heatDeviation: Double { currentHeat - requiredHeat }

    // ── Абсолютные пороги безопасности ────────────────────────────────────
    var isExtremeHeat: Bool { temperature >= 30 }
    var isExtremeCold: Bool { temperature <= -10 }

    // Единственная точка изменения ширины «Идеального» коридора (Rule 3)
    // Source: Алгоритм одевания младенца, стр. 9 — |deviation| ≤ 0.2 CLO = optimal
    private static let idealBandCLO: Double = 0.2

    // Source: neonatology.pdf, с. 55 — три физиологических периода:
    // 0–3 мес: нет дрожательного термогенеза, бурый жир, комфорт 24–28°C
    // 3–12 мес: подкожный жир развивается, комфорт 22–26°C
    // 1+ лет: взрослая норма 20–24°C
    private static let earlyInfantComfortBaseline: Double = 28.0
    private static let newbornComfortBaseline:      Double = 26.0
    private static let defaultComfortBaseline:      Double = 24.0
    // Source: Алгоритм одевания, стр. 9 — коэффициент теплопотребности
    private static let heatSlopePerDegree:  Double = 0.5
    private static let activeHeatReduction: Double = 0.85
    private static let activeHeatThreshold: Double = 15.0

    // ── Зональная оценка риска ────────────────────────────────────────────
    var riskLevel: ThermalRisk {
        if isExtremeHeat { return .criticalOverheat }
        if isExtremeCold { return .dangerouslyCold }
        let d = heatDeviation
        let base = zoneRisk(deviation: d)
        guard base == .optimal else { return base }
        if d >  Self.idealBandCLO { return .warm }
        if d < -Self.idealBandCLO { return .slightlyCold }
        return .optimal
    }

    private func zoneRisk(deviation d: Double) -> ThermalRisk {
        switch tempZone {
        case .hot:
            if d >= 1.5 { return .criticalOverheat }
            if d >  0.5 { return .hot }
            return .optimal
        case .mild:
            if d >= 3.0  { return .criticalOverheat }
            if d >= 1.5  { return .hot }
            if d >= -1.0 { return .optimal }
            if d >= -2.5 { return .slightlyCold }
            return .cold
        case .cold:
            if d >= 5.0  { return .hot }
            if d >= 2.0  { return .warm }
            if d >= -1.5 { return .optimal }
            if d >= -4.0 { return .slightlyCold }
            return .dangerouslyCold
        }
    }

    // ── Контекстно-зависимые сообщения ────────────────────────────────────
    var riskLabel: String {
        if isExtremeHeat { return "ОПАСНО: КРИТИЧЕСКИЙ ПЕРЕГРЕВ" }
        if isExtremeCold { return "ОПАСНО: РИСК ОБМОРОЖЕНИЯ" }
        switch riskLevel {
        case .dangerouslyCold:  return "Опасно холодно!"
        case .cold:             return "Холодно"
        case .slightlyCold:     return "Прохладно"
        case .optimal:          return "Идеально"
        case .warm:             return "Тепловато"
        case .hot:              return tempZone == .cold ? "Очень жарко" : "Жарко"
        case .criticalOverheat: return "Критический перегрев!"
        }
    }

    var riskDetail: String {
        if isExtremeHeat { return "Слишком жарко для прогулки. Оставайтесь дома — прохладный душ, частое прикладывание к груди/воде." }
        if isExtremeCold { return "Ограничьте прогулку до 15-20 минут. Следите за открытыми участками кожи." }
        switch riskLevel {
        case .dangerouslyCold:
            return "Риск обморожения и переохлаждения! Срочно занесите малыша в тепло."
        case .cold:
            return "Ребёнку холодно. Добавьте утепляющий слой."
        case .slightlyCold:
            return "Немного прохладно. Рассмотрите ещё один лёгкий слой."
        case .optimal:
            return "Одежда подобрана оптимально для данной температуры."
        case .warm:
            return "Немного тепловато. Снимите один утепляющий слой."
        case .hot where tempZone == .cold:
            return "Малыш сильно вспотеет и может простудиться. Снимите утеплитель."
        case .hot:
            return "Слишком тепло. Срочно снимите лишние слои."
        case .criticalOverheat where tempZone == .hot:
            return "Слишком жарко! Снимите всю лишнюю одежду — минимум: боди и подгузник."
        case .criticalOverheat:
            return "Риск теплового удара — немедленно снимите лишнюю одежду!"
        }
    }

    // ── Прогресс метра ────────────────────────────────────────────────────
    var meterProgress: Double {
        let d = heatDeviation
        let hotScale: Double
        let coldScale: Double
        switch tempZone {
        case .hot:  hotScale = 2.0; coldScale = 1.0
        case .mild: hotScale = 4.0; coldScale = 3.5
        case .cold: hotScale = 6.0; coldScale = 5.0
        }
        if d >= 0 { return 0.5 + min(0.5, d / hotScale * 0.5) }
        else       { return max(0.0, 0.5 - abs(d) / coldScale * 0.5) }
    }

    var showHeatAlert: Bool { isExtremeHeat }
    var showColdAlert: Bool { isExtremeCold }

    var autoSelectLabel: String {
        if isExtremeHeat { return "Минимум одежды при \(Int(temperature.rounded()))°C" }
        return "\(Int(temperature.rounded()))°C · \(ageGroup.rawValue)"
    }

    var weatherIcon: String {
        switch temperature {
        case ...(-15): return "snowflake.circle.fill"
        case -15..<0:  return "cloud.snow.fill"
        case 0..<10:   return "cloud.fill"
        case 10..<18:  return "cloud.sun.fill"
        case 18..<26:  return "sun.max.fill"
        default:       return "sun.haze.fill"
        }
    }

    var tempColor: Color {
        switch temperature {
        case ...0:    return .blue
        case 0..<15:  return Color(red: 0.2, green: 0.55, blue: 1.0)
        case 15..<22: return .green
        case 22..<28: return .orange
        default:      return .red
        }
    }

    // ── Actions ───────────────────────────────────────────────────────────

    func toggle(_ item: GarmentItem) {
        guard !isPinned(item) else { return }
        if selectedItems.contains(item) { selectedItems.remove(item) }
        else { selectedItems.insert(item) }
    }

    func resetAll() {
        let pinnedItems = Set(GarmentCatalog.all.filter { pinnedItemIDs.contains($0.id) })
        withAnimation(.spring(response: 0.35)) {
            temperature   = weatherTemperature
            selectedItems = pinnedItems
        }
    }

    // ── Автоподбор: жадный поиск к «Идеально» ─────────────────────────────
    func autoSelect() {
        let result = WardrobeAutoSelector.selectItems(
            temperature: temperature,
            ageGroup: ageGroup,
            pinnedItemIDs: pinnedItemIDs
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            selectedItems = result
        }
    }


    /// Применяет TOG-рекомендацию: выбор предметов из пайплайна §2→§6.
    /// Температура слайдера не меняется — пользователь мог её скорректировать вручную.
    func syncWithTOG(_ rec: OutfitRecommendation) {
        let recIDs = Set((rec.layers + rec.accessories).map(\.id))
        let newItems = Set(GarmentCatalog.all.filter { recIDs.contains($0.id) })
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            selectedItems = newItems
        }
    }
}

// MARK: - WardrobePinnedItemsStore

enum WardrobePinnedItemsStore {
    private static let storageKey = "pinned_wardrobe"

    static func loadIDs() -> Set<String> {
        guard let ids = AppGroup.defaults.stringArray(forKey: storageKey) else {
            return ["diaper"]
        }
        return Set(ids.map { GarmentCatalog.canonicalID(for: $0) })
    }

    static func saveIDs(_ ids: Set<String>) {
        AppGroup.defaults.set(Array(ids).sorted(), forKey: storageKey)
    }
}

// MARK: - WardrobeAutoSelector

enum WardrobeAutoSelector {
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
        return bestSelection
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

