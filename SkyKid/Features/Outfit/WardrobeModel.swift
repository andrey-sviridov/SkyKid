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

    /// Температура из погодной вкладки — база для сброса.
    var weatherTemperature: Double

    init(temperature: Double = 12.0, ageGroup: WardrobeAgeGroup = .earlyInfant) {
        self.temperature        = temperature
        self.weatherTemperature = temperature
        self.ageGroup           = ageGroup
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
        if selectedItems.contains(item) { selectedItems.remove(item) }
        else { selectedItems.insert(item) }
    }

    func resetAll() {
        withAnimation(.spring(response: 0.35)) {
            temperature   = weatherTemperature
            selectedItems = []
        }
    }

    // ── Вспомогательный вычислитель риска для произвольного набора ─────────
    private func computeRisk(for items: Set<GarmentItem>) -> ThermalRisk {
        let heat = items.reduce(0.0) { $0 + $1.heatValue }
        let d    = heat - requiredHeat
        let base = zoneRisk(deviation: d)
        guard base == .optimal else { return base }
        if d >  Self.idealBandCLO { return .warm }
        if d < -Self.idealBandCLO { return .slightlyCold }
        return .optimal
    }

    // ── Автоподбор: жадный поиск к «Идеально» ─────────────────────────────
    func autoSelect() {
        var result: Set<GarmentItem> = []

        func add(_ id: String) { if let g = GarmentCatalog.byID[id] { result.insert(g) } }
        // Diaper + slip are the minimum regardless of temperature
        add("diaper")
        add("slip")

        // Rule 1: extreme heat — only minimum base layer
        if isExtremeHeat {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { selectedItems = result }
            return
        }

        guard computeRisk(for: result) != .optimal else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { selectedItems = result }
            return
        }

        let t = temperature
        // earlyInfant и infant — оба в коляске, используют "стационарный" маршрут одевания
        let isNewborn = (ageGroup == .earlyInfant || ageGroup == .infant)

        let orderedIDs: [String]
        switch t {
        case 22...:
            // При 22–29°C нужно немного одежды; алгоритм остановится сам, когда достигнет «Идеально».
            // Пустой список здесь давал баг: только подгузник при +22°C = «Прохладно».
            orderedIDs = isNewborn
                ? ["slip", "thin_socks", "scratch", "bib"]
                : ["slip", "thin_socks"]

        case 15..<22:
            orderedIDs = ["slip", "thin_socks", "thin_hat",
                          "scratch", "bib", "warm_socks", "fleece", "sweater"]

        case 10..<15:
            orderedIDs = isNewborn
                ? ["slip", "warm_socks", "thin_hat", "bib",
                   "fleece", "booties", "warm_hat", "thin_blanket",
                   "pants", "windbreaker", "warm_blanket"]
                : ["slip", "warm_socks", "thin_hat", "fleece",
                   "pants", "booties", "warm_hat", "windbreaker", "thin_blanket"]

        case 5..<10:
            orderedIDs = isNewborn
                ? ["slip", "warm_socks", "thin_hat", "fleece",
                   "booties", "warm_hat", "mittens", "demi",
                   "thin_blanket", "warm_blanket"]
                : ["slip", "warm_socks", "thin_hat", "fleece",
                   "pants", "booties", "warm_hat", "mittens",
                   "windbreaker", "demi"]

        case 0..<5:
            orderedIDs = isNewborn
                ? ["thermals", "warm_socks", "booties", "thin_hat",
                   "fleece", "warm_hat", "mittens",
                   "thin_blanket", "demi", "warm_blanket"]
                : ["thermals", "warm_socks", "thin_hat", "fleece",
                   "pants", "booties", "warm_hat", "mittens",
                   "windbreaker", "thin_blanket", "demi"]

        case (-10)..<0 where t > -10:  // строго (-10, 0) — исключаем -10.0
            orderedIDs = ["thermals", "warm_socks", "booties",
                          "fleece", "warm_hat", "mittens",
                          "demi", "warm_blanket", "winter"]

        default: // ≤ −10 (включая ровно -10.0)
            orderedIDs = ["thermals", "warm_socks", "booties",
                          "sweater", "fleece", "warm_hat", "mittens",
                          "winter", "warm_blanket"]
        }

        let heavyOuterIDs: Set<String> = ["demi", "winter"]
        // Носки взаимоисключающие: надевают либо тонкие, либо тёплые — не оба.
        let sockIDs: Set<String> = ["thin_socks", "warm_socks"]

        for id in orderedIDs {
            guard let item = GarmentCatalog.byID[id] else { continue }
            // Rule 4: never stack two heavy outer shells
            if heavyOuterIDs.contains(id) && result.contains(where: { heavyOuterIDs.contains($0.id) }) { continue }
            // Rule 5: only one sock type at a time
            if sockIDs.contains(id) && result.contains(where: { sockIDs.contains($0.id) }) { continue }
            let rAfterAdd = computeRisk(for: result.union([item]))
            if rAfterAdd == .criticalOverheat { continue }
            let currRisk = computeRisk(for: result)
            let isOnColdSide = currRisk == .dangerouslyCold || currRisk == .cold || currRisk == .slightlyCold
            if isOnColdSide && rAfterAdd == .hot { continue }
            result.insert(item)
            let r = computeRisk(for: result)
            if r == .optimal || r == .warm { break }
        }

        // Rule 2: extreme cold — force stroller warmer
        if isExtremeCold { add("warm_blanket") }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            selectedItems = result
        }
    }
}
