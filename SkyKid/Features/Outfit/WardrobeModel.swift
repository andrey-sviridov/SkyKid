import SwiftUI

// MARK: - Legacy WardrobeModel
// SRP: содержит только бизнес-логику выбора одежды.
// View-компоненты живут в ClothingCalculatorView.swift.
// Доменные типы (GarmentItem, ThermalRisk, …) — в GarmentCatalog.swift.
// Не использовать в OutfitView, виджете, Siri или safety-решениях.

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
        if isExtremeHeat { return L10n.text("ОПАСНО: КРИТИЧЕСКИЙ ПЕРЕГРЕВ") }
        if isExtremeCold { return L10n.text("ОПАСНО: РИСК ОБМОРОЖЕНИЯ") }
        switch riskLevel {
        case .dangerouslyCold:  return L10n.text("Опасно холодно!")
        case .cold:             return L10n.text("Холодно")
        case .slightlyCold:     return L10n.text("Прохладно")
        case .optimal:          return L10n.text("Идеально")
        case .warm:             return L10n.text("Тепловато")
        case .hot:
            return tempZone == .cold
                ? L10n.text("Очень жарко")
                : L10n.text("Жарко")
        case .criticalOverheat: return L10n.text("Критический перегрев!")
        }
    }

    var riskDetail: String {
        if isExtremeHeat {
            return L10n.text(
                "Прогулку лучше перенести на более прохладное время. Младенцу предлагайте обычные кормления чаще."
            )
        }
        if isExtremeCold {
            return L10n.text(
                "Прогулку лучше перенести. Одежда не отменяет риск от экстремального холода."
            )
        }
        switch riskLevel {
        case .dangerouslyCold:
            return L10n.text("Риск обморожения и переохлаждения! Срочно занесите малыша в тепло.")
        case .cold:
            return L10n.text("Ребёнку холодно. Добавьте утепляющий слой.")
        case .slightlyCold:
            return L10n.text("Немного прохладно. Рассмотрите ещё один лёгкий слой.")
        case .optimal:
            return L10n.text("Одежда подобрана оптимально для данной температуры.")
        case .warm:
            return L10n.text("Немного тепловато. Снимите один утепляющий слой.")
        case .hot where tempZone == .cold:
            return L10n.text("Малыш сильно вспотеет и может простудиться. Снимите утеплитель.")
        case .hot:
            return L10n.text("Слишком тепло. Срочно снимите лишние слои.")
        case .criticalOverheat where tempZone == .hot:
            return L10n.text("Слишком жарко! Снимите всю лишнюю одежду — минимум: боди и подгузник.")
        case .criticalOverheat:
            return L10n.text("Риск теплового удара — немедленно снимите лишнюю одежду!")
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
        if isExtremeHeat {
            return L10n.format(
                "Минимум одежды при %lld°C",
                Int(temperature.rounded())
            )
        }
        return L10n.format(
            "%lld°C · %@",
            Int(temperature.rounded()),
            ageGroup.displayName
        )
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

    func resetTemperatureAndAutoSelect() {
        let result = LegacyWardrobeAutoSelector.selectItems(
            temperature: weatherTemperature,
            ageGroup: ageGroup,
            pinnedItemIDs: pinnedItemIDs
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            temperature = weatherTemperature
            selectedItems = result
        }
    }

    // ── Автоподбор: жадный поиск к «Идеально» ─────────────────────────────
    func autoSelect() {
        let result = LegacyWardrobeAutoSelector.selectItems(
            temperature: temperature,
            ageGroup: ageGroup,
            pinnedItemIDs: pinnedItemIDs
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            selectedItems = result
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
