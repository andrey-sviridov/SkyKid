// ClothingCalculatorView.swift
// Performance-optimised baby clothing constructor
// ─────────────────────────────────────────────────────────────────────────
// KEY DESIGN DECISION FOR PERF:
//   ClothingConstructorSection receives `selectedItems: Set<GarmentItem>`
//   as an EXPLICIT VALUE parameter — not a model reference.
//   This means the 20-item LazyVGrid is NOT re-rendered when temperature
//   changes on the slider (only when the user taps a clothing item).
// ─────────────────────────────────────────────────────────────────────────

import SwiftUI

// MARK: – Enums ───────────────────────────────────────────────────────────

enum GarmentLayer: String, CaseIterable, Identifiable {
    case base      = "Базовый слой"
    case insulator = "Утеплитель"
    case outer     = "Верхняя одежда"
    case accessory = "Аксессуары"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .base:      return "tshirt.fill"
        case .insulator: return "wind"
        case .outer:     return "cloud.fill"
        case .accessory: return "sparkles"
        }
    }
}

enum WardrobeAgeGroup: String, CaseIterable, Identifiable {
    case newborn = "0–5 мес"
    case active  = "6–12 мес"
    var id: String { rawValue }
    var subtitle: String {
        self == .newborn ? "Лежит / в коляске — нужен доп. слой" : "Активный / ходит — генерирует тепло"
    }
}

// 7 зон — label/detail намеренно УБРАНЫ из enum.
// Они контекстно-зависимы (разные сообщения при одном riskLevel в разных temp-зонах)
// и вычисляются в WardrobeModel.riskLabel / WardrobeModel.riskDetail.
enum ThermalRisk: Equatable {
    case dangerouslyCold   // Zone C: delta < −4.0 — риск обморожения
    case cold              // Zone B: delta < −2.5
    case slightlyCold      // Zone B: [−2.5,−1.0) / Zone C: [−4.0,−1.5)
    case optimal           // все зоны: в допуске
    case warm              // Zone C: [2.0, 5.0)
    case hot               // Zone A: (0.5,1.5) / Zone B: [1.5,3.0) / Zone C: ≥5.0
    case criticalOverheat  // Zone A: ≥1.5 / Zone B: ≥3.0

    var color: Color {
        switch self {
        case .dangerouslyCold:  return Color(red: 0.0,  green: 0.1,  blue: 0.75)
        case .cold:             return .blue
        case .slightlyCold:     return Color(red: 0.3,  green: 0.65, blue: 1.0)
        case .optimal:          return .green
        case .warm:             return Color(red: 0.95, green: 0.8,  blue: 0.0)
        case .hot:              return .orange
        case .criticalOverheat: return .red
        }
    }

    var symbol: String {
        switch self {
        case .dangerouslyCold:  return "snowflake.circle.fill"
        case .cold:             return "snowflake"
        case .slightlyCold:     return "cloud.snow.fill"
        case .optimal:          return "checkmark.seal.fill"
        case .warm:             return "thermometer.medium"
        case .hot:              return "flame.fill"
        case .criticalOverheat: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: – GarmentItem ─────────────────────────────────────────────────────
// String id (not UUID) → stable across frames → LazyVGrid won't re-create cells

struct GarmentItem: Identifiable, Hashable {
    let id: String
    let name: String
    let heatValue: Double   // CLO-analogue index
    let layer: GarmentLayer
    let symbol: String

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: – Static Catalog (20 items) ───────────────────────────────────────

private let catalog: [GarmentItem] = [
    // ── Базовый слой ──────────────────────────────────────────────────────
    .init(id: "diaper",       name: "Подгузник",             heatValue: 0.1, layer: .base,      symbol: "figure.child"),
    .init(id: "slip",         name: "Хлопковый слип / боди", heatValue: 1.5, layer: .base,      symbol: "tshirt.fill"),
    .init(id: "thermals",     name: "Термобельё",            heatValue: 2.0, layer: .base,      symbol: "thermometer.medium"),
    .init(id: "thin_socks",   name: "Носочки тонкие",        heatValue: 0.3, layer: .base,      symbol: "oval.fill"),
    .init(id: "warm_socks",   name: "Носочки тёплые",        heatValue: 0.6, layer: .base,      symbol: "capsule.fill"),
    .init(id: "scratch",      name: "Царапки",               heatValue: 0.2, layer: .base,      symbol: "sparkles"),

    // ── Утеплитель ────────────────────────────────────────────────────────
    .init(id: "fleece",       name: "Флисовый комбез",       heatValue: 3.5, layer: .insulator, symbol: "wind"),
    .init(id: "sweater",      name: "Свитер",                heatValue: 3.0, layer: .insulator, symbol: "hexagon.fill"),
    .init(id: "pants",        name: "Брюки хлопковые",       heatValue: 1.0, layer: .insulator, symbol: "rectangle.fill"),

    // ── Верхняя одежда ────────────────────────────────────────────────────
    .init(id: "windbreaker",  name: "Ветровка",              heatValue: 1.5, layer: .outer,     symbol: "tornado"),
    .init(id: "demi",         name: "Демисезонный комбез",   heatValue: 6.0, layer: .outer,     symbol: "cloud.fill"),
    .init(id: "winter",       name: "Зимний комбез 250г",    heatValue:10.0, layer: .outer,     symbol: "snowflake"),
    .init(id: "thin_blanket", name: "Одеялко тонкое",        heatValue: 1.5, layer: .outer,     symbol: "square.fill"),
    .init(id: "warm_blanket", name: "Одеялко тёплое",        heatValue: 3.0, layer: .outer,     symbol: "square.grid.2x2.fill"),

    // ── Аксессуары ────────────────────────────────────────────────────────
    .init(id: "thin_hat",     name: "Тонкая шапочка",        heatValue: 0.8, layer: .accessory, symbol: "moon.fill"),
    .init(id: "warm_hat",     name: "Тёплая шапка",          heatValue: 2.0, layer: .accessory, symbol: "moon.stars.fill"),
    .init(id: "mittens",      name: "Варежки",               heatValue: 0.5, layer: .accessory, symbol: "hand.raised.fill"),
    .init(id: "booties",      name: "Пинетки",               heatValue: 1.0, layer: .accessory, symbol: "diamond.fill"),
    .init(id: "bib",          name: "Слюнявчик",             heatValue: 0.2, layer: .accessory, symbol: "drop.fill"),
]

// Pre-computed lookup tables — O(1) access, no per-frame allocation
private let catalogByID: [String: GarmentItem] =
    Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

private let catalogByLayer: [GarmentLayer: [GarmentItem]] = {
    var d: [GarmentLayer: [GarmentItem]] = [:]
    GarmentLayer.allCases.forEach { d[$0] = [] }
    catalog.forEach { d[$0.layer]!.append($0) }
    return d
}()

// MARK: – Observable ViewModel ────────────────────────────────────────────

@MainActor
@Observable
final class WardrobeModel {

    // ── Inputs (drive all derived values) ─────────────────────────────────
    var temperature: Double = 12.0
    var ageGroup: WardrobeAgeGroup = .newborn
    var selectedItems: Set<GarmentItem> = []

    // ── Derived — all O(1) or O(n) where n ≤ 20; safe to call every frame ─

    // ── Температурная зона (задаёт допуски риска) ────────────────────────
    private enum TempZone { case hot, mild, cold }
    private var tempZone: TempZone {
        if temperature >= 22 { return .hot  }
        if temperature >= 10 { return .mild }
        return .cold
    }

    // ── Формула потребности в тепле ──────────────────────────────────────
    // +35°C → 0 CLO | +24°C → 0 CLO | 0°C → 12 CLO | −20°C → 22 CLO
    var requiredHeat: Double {
        let base = max(0.0, (24.0 - temperature) * 0.5)
        // Активные дети (6–12 мес) вырабатывают тепло движением — нужно на 15% меньше
        return (ageGroup == .active && temperature < 15) ? base * 0.85 : base
    }

    var currentHeat: Double { selectedItems.reduce(0) { $0 + $1.heatValue } }

    /// +ve = перегрев, −ve = недостаточно тепла
    var heatDeviation: Double { currentHeat - requiredHeat }

    // ── Абсолютные порги безопасности ────────────────────────────────────
    var isExtremeHeat: Bool { temperature >= 30 }
    var isExtremeCold: Bool { temperature <= -10 }

    // ── Зональная оценка риска ────────────────────────────────────────────
    // КРИТИЧЕСКИ: допуски разные в каждой зоне.
    // delta +3 при −10°C — «тепловато». Та же delta при +35°C — критический перегрев за минуты.
    var riskLevel: ThermalRisk {
        if isExtremeHeat { return .criticalOverheat }
        if isExtremeCold { return .dangerouslyCold }
        let d = heatDeviation
        let base = zoneRisk(deviation: d)
        // Rule 3 — Ideal range tuning: «Идеально» только при delta ∈ (−0.2, +0.2)
        guard base == .optimal else { return base }
        if d > 0.2  { return .warm }
        if d < -0.2 { return .slightlyCold }
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

    // ── Контекстно-зависимые сообщения ───────────────────────────────────
    // ЕДИНСТВЕННЫЙ источник истины — согласован с riskLevel.
    // Метр и текст всегда показывают одно и то же состояние.
    var riskLabel: String {
        if isExtremeHeat { return "ОПАСНО: КРИТИЧЕСКИЙ ПЕРЕГРЕВ" }
        if isExtremeCold { return "ОПАСНО: РИСК ОБМОРОЖЕНИЯ" }
        switch riskLevel {
        case .dangerouslyCold:  return "⚠️ Опасно холодно!"
        case .cold:             return "Холодно"
        case .slightlyCold:     return "Прохладно"
        case .optimal:          return "Идеально 👍"
        case .warm:             return "Тепловато"
        case .hot:              return tempZone == .cold ? "Очень жарко" : "Жарко"
        case .criticalOverheat: return "⚠️ Критический перегрев!"
        }
    }

    var riskDetail: String {
        if isExtremeHeat { return "Не выходите на улицу в пиковые часы. Только подгузник, прохладный душ, частое прикладывание к груди/воде." }
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
            return "Опасно для жизни! Ребёнок перегреется за минуты. Оставьте только подгузник!"
        case .criticalOverheat:
            return "Риск теплового удара — немедленно снимите лишнюю одежду!"
        default:
            return ""
        }
    }

    // ── Прогресс метра — контекстный, масштабируется по зоне ─────────────
    // Критические пороги каждой зоны попадают на края шкалы (≈0.9–1.0 и 0.0–0.1)
    var meterProgress: Double {
        let d = heatDeviation
        let hotScale: Double   // делитель горячей стороны
        let coldScale: Double  // делитель холодной стороны
        switch tempZone {
        case .hot:  hotScale = 2.0; coldScale = 1.0
        case .mild: hotScale = 4.0; coldScale = 3.5
        case .cold: hotScale = 6.0; coldScale = 5.0
        }
        if d >= 0 { return 0.5 + min(0.5, d / hotScale * 0.5) }
        else       { return max(0.0, 0.5 - abs(d) / coldScale * 0.5) }
    }

    // Баннер — строго от riskLevel (согласован с метром)
    var showHeatAlert: Bool { isExtremeHeat }
    var showColdAlert: Bool { isExtremeCold }

    var autoSelectLabel: String {
        if isExtremeHeat { return "Только подгузник при \(Int(temperature.rounded()))°C" }
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
        withAnimation(.spring(response: 0.35)) { selectedItems = [] }
    }

    // ── Вспомогательный вычислитель риска для произвольного набора ────────
    // Зеркало riskLevel, но не трогает self.selectedItems.
    // Позволяет autoSelect() симулировать добавление предметов до установки.
    private func computeRisk(for items: Set<GarmentItem>) -> ThermalRisk {
        let heat = items.reduce(0.0) { $0 + $1.heatValue }
        let d    = heat - requiredHeat
        let base = zoneRisk(deviation: d)
        guard base == .optimal else { return base }
        if d > 0.2  { return .warm }
        if d < -0.2 { return .slightlyCold }
        return .optimal
    }

    // ── Автоподбор: жадный поиск к «Идеально» ────────────────────────────
    // Алгоритм:
    //   1. Начинаем с подгузника
    //   2. Перебираем предметы в порядке приоритета (от лёгких к тяжёлым)
    //   3. Добавляем предмет, если он не вызовет criticalOverheat
    //   4. Останавливаемся, когда достигнуто .optimal или .warm
    //   5. НИКОГДА не останавливаемся на .slightlyCold — продолжаем добавлять
    func autoSelect() {
        // Rule 1: extreme heat — only a diaper, no other layers
        if isExtremeHeat {
            var result: Set<GarmentItem> = []
            if let diaper = catalogByID["diaper"] { result.insert(diaper) }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { selectedItems = result }
            return
        }

        var result: Set<GarmentItem> = []

        func add(_ id: String) { if let g = catalogByID[id] { result.insert(g) } }
        add("diaper")  // всегда

        // Ранний выход: жаркий день — одного подгузника достаточно
        guard computeRisk(for: result) != .optimal else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { selectedItems = result }
            return
        }

        let t = temperature
        let isNewborn = (ageGroup == .newborn)

        // Упорядоченные кандидаты: самые «базовые» первыми, тяжёлые — в конце.
        // Жадный цикл добавляет по одному, пока не будет достигнут оптимум.
        let orderedIDs: [String]
        switch t {
        case 22...:
            orderedIDs = []   // подгузник уже покрыл потребность

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
                   "thin_blanket", "demi", "warm_blanket"]  // thin_blanket bridges t=0 gap
                : ["thermals", "warm_socks", "thin_hat", "fleece",
                   "pants", "booties", "warm_hat", "mittens",
                   "windbreaker", "thin_blanket", "demi"]

        case (-10)..<0:
            orderedIDs = ["thermals", "warm_socks", "booties",
                          "fleece", "warm_hat", "mittens",
                          "demi", "warm_blanket", "winter"]

        default: // ≤ −10
            orderedIDs = ["thermals", "warm_socks", "booties",
                          "sweater", "fleece", "warm_hat", "mittens",
                          "winter", "warm_blanket"]
        }

        let heavyOuterIDs: Set<String> = ["demi", "winter"]

        // Жадный цикл: добавляем по одному, пока не «Идеально» или «Тепловато»
        for id in orderedIDs {
            guard let item = catalogByID[id] else { continue }
            // Rule 4: never stack two heavy outer shells (demi + winter)
            if heavyOuterIDs.contains(id) && result.contains(where: { heavyOuterIDs.contains($0.id) }) { continue }
            let rAfterAdd = computeRisk(for: result.union([item]))
            // Пропустить: добавление вызовет критический перегрев
            if rAfterAdd == .criticalOverheat { continue }
            // Пропустить: перескок через оптимум — холодная сторона → жарко без остановки на «Идеально»
            // (В Zone C прыжок в .warm — допустимо и является точкой остановки)
            let currRisk = computeRisk(for: result)
            let isOnColdSide = currRisk == .dangerouslyCold
                            || currRisk == .cold
                            || currRisk == .slightlyCold
            if isOnColdSide && rAfterAdd == .hot { continue }
            result.insert(item)
            let r = computeRisk(for: result)
            if r == .optimal || r == .warm { break }
        }

        // Rule 2: extreme cold — force stroller warmer regardless of greedy result
        if isExtremeCold { add("warm_blanket") }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            selectedItems = result
        }
    }
}

// MARK: – Root View ───────────────────────────────────────────────────────

struct ClothingCalculatorView: View {
    @State private var model = WardrobeModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Reads: temperature, ageGroup, weatherIcon, tempColor
                WeatherControlsCard(model: model)

                // Reads: riskLevel, meterProgress, currentHeat, requiredHeat, deviation
                // Passed as value types → isolated render
                RiskMeterCard(
                    riskLevel:     model.riskLevel,
                    meterProgress: model.meterProgress,
                    currentHeat:   model.currentHeat,
                    requiredHeat:  model.requiredHeat,
                    deviation:     model.heatDeviation,
                    riskLabel:     model.riskLabel,
                    riskDetail:    model.riskDetail
                )

                // Alert banners
                if model.showHeatAlert {
                    AlertCard(icon: "exclamationmark.triangle.fill", color: .red,
                              title: "Не выходите в пиковые часы",
                              message: "Только подгузник, прохладный душ, частое прикладывание к груди/воде.")
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if model.showColdAlert {
                    AlertCard(icon: "snowflake.circle.fill", color: .blue,
                              title: "Экстремальный холод",
                              message: "Ограничьте прогулку до 15-20 минут. Следите за открытыми участками кожи.")
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Auto-select button (reads temp + ageGroup for label text)
                AutoSelectButton(
                    tempLabel: model.autoSelectLabel,
                    action: { model.autoSelect() }
                )

                PediatricNoteCard()

                // ⚡ PERF: only receives `selectedItems` — will NOT re-render when
                //   temperature or ageGroup changes, only when items are toggled.
                ClothingConstructorSection(
                    selectedItems: model.selectedItems,
                    onToggle: { item in
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.65)) {
                            model.toggle(item)
                        }
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Конструктор одежды")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.25), value: model.showHeatAlert)
        .animation(.easeInOut(duration: 0.25), value: model.showColdAlert)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Сбросить") { model.resetAll() }
                    .tint(.secondary)
                    .disabled(model.selectedItems.isEmpty)
            }
        }
    }
}

// MARK: – WeatherControlsCard ─────────────────────────────────────────────
// Uses @Bindable to create $model.temperature / $model.ageGroup bindings

struct WeatherControlsCard: View {
    @Bindable var model: WardrobeModel

    var body: some View {
        VStack(spacing: 16) {

            // Big temperature display
            HStack(spacing: 14) {
                Image(systemName: model.weatherIcon)
                    .font(.system(size: 46))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 58)
                    .animation(.spring(response: 0.4), value: model.weatherIcon)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(model.temperature.rounded()))°C")
                        .font(.system(size: 50, weight: .thin, design: .rounded))
                        .foregroundStyle(model.tempColor)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25), value: model.temperature)
                    Text("Температура на улице")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Slider — .transaction disables spring during drag for instant tracking
            VStack(spacing: 5) {
                Slider(value: $model.temperature, in: -25...35, step: 1)
                    .tint(model.tempColor)
                    .transaction { t in t.animation = nil }
                HStack {
                    Text("−25°")
                    Spacer()
                    Text("0°")
                    Spacer()
                    Text("+35°")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Divider()

            // Age / activity picker
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.child")
                        .foregroundStyle(.secondary)
                    Text("Возраст / активность")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Picker("Возраст", selection: $model.ageGroup) {
                    ForEach(WardrobeAgeGroup.allCases) { g in Text(g.rawValue).tag(g) }
                }
                .pickerStyle(.segmented)

                Text(model.ageGroup.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: model.ageGroup)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: – RiskMeterCard ───────────────────────────────────────────────────
// Receives ONLY value types — view identity stays stable regardless of model changes

struct RiskMeterCard: View {
    let riskLevel: ThermalRisk
    let meterProgress: Double
    let currentHeat: Double
    let requiredHeat: Double
    let deviation: Double
    let riskLabel: String    // контекстная строка от модели (зависит от зоны)
    let riskDetail: String   // контекстное объяснение от модели

    var body: some View {
        VStack(spacing: 14) {

            // Status row
            HStack(spacing: 12) {
                Image(systemName: riskLevel.symbol)
                    .font(.title)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(riskLevel.color)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(riskLabel)
                        .font(.headline)
                        .foregroundStyle(riskLevel.color)
                    Text(riskDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 0.2), value: riskLevel)

            RiskMeterBar(progress: meterProgress)

            Divider()

            // Three stats
            HStack(spacing: 0) {
                heatStat(value: currentHeat,  label: "Текущее\nтепло",  color: riskLevel.color)
                Divider().frame(height: 46)
                heatStat(value: requiredHeat, label: "Нужно\nтепла",   color: .primary)
                Divider().frame(height: 46)
                heatStat(value: deviation,    label: "Разница",         color: deviationColor, sign: true)
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    // Цвет разницы согласован с riskLevel — не своя логика
    private var deviationColor: Color { riskLevel.color }

    @ViewBuilder
    private func heatStat(value: Double, label: String, color: Color, sign: Bool = false) -> some View {
        VStack(spacing: 3) {
            let prefix = sign && value > 0 ? "+" : ""
            Text("\(prefix)\(value, specifier: "%.1f")")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText(countsDown: value < 0))
                .animation(.spring(response: 0.28), value: value)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – RiskMeterBar ────────────────────────────────────────────────────

struct RiskMeterBar: View {
    let progress: Double   // 0 = extreme cold · 0.5 = optimal · 1 = extreme heat

    // Static gradient — created once, not per frame
    private static let gradient = LinearGradient(
        colors: [.blue, Color(red: 0.3, green: 0.7, blue: 1), .green, .yellow, .orange, .red],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let p = max(0, min(1, progress))
                let D: CGFloat = 28
                let thumbX = (geo.size.width - D) * CGFloat(p)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Self.gradient)
                        .frame(height: 14)
                        .padding(.horizontal, D / 2)

                    Circle()
                        .fill(.white)
                        .frame(width: D, height: D)
                        .overlay(Circle().strokeBorder(thumbColor(p), lineWidth: 3))
                        .shadow(color: .black.opacity(0.14), radius: 3, x: 0, y: 2)
                        .offset(x: thumbX)
                        // Spring animation only on value change — smooth on item-toggle, instant on slider drag
                        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: progress)
                }
            }
            .frame(height: 28)

            HStack {
                Label("Холодно", systemImage: "snowflake")
                Spacer()
                Text("Ок")
                Spacer()
                Label("Жарко", systemImage: "flame.fill")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func thumbColor(_ p: Double) -> Color {
        switch p {
        case ..<0.25:      return .blue
        case 0.25..<0.45:  return Color(red: 0.3, green: 0.7, blue: 1)
        case 0.45..<0.55:  return .green
        case 0.55..<0.75:  return .orange
        default:           return .red
        }
    }
}

// MARK: – AlertCard ───────────────────────────────────────────────────────

struct AlertCard: View {
    let icon: String
    let color: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(color)
                Text(message).font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.24), lineWidth: 1))
    }
}

// MARK: – AutoSelectButton ────────────────────────────────────────────────
// Receives only primitive tempLabel string — minimal re-render surface

struct AutoSelectButton: View {
    let tempLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Автоподбор одежды")
                        .font(.headline)
                    Text("Оптимально для \(tempLabel)")
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .opacity(0.6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.32, blue: 0.96),
                             Color(red: 0.44, green: 0.14, blue: 0.86)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: – PediatricNoteCard ───────────────────────────────────────────────

struct PediatricNoteCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 3) {
                Text("Совет педиатра")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
                Text("Холодные ручки и носик — это нормально. Проверяйте температуру по задней части шеи малыша.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: – ClothingConstructorSection ─────────────────────────────────────
// ⚡ PERF: `selectedItems` is a VALUE (Set<GarmentItem>).
//   SwiftUI compares it via Equatable before deciding to re-render.
//   Changing `temperature` in the parent does NOT change `selectedItems`
//   → this entire section skips body re-computation on slider drags.

struct ClothingConstructorSection: View {
    let selectedItems: Set<GarmentItem>
    let onToggle: (GarmentItem) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(GarmentLayer.allCases) { layer in
                let items = catalogByLayer[layer] ?? []
                let selCount = items.filter { selectedItems.contains($0) }.count

                VStack(alignment: .leading, spacing: 10) {
                    // Category header
                    HStack(spacing: 6) {
                        Image(systemName: layer.icon).font(.caption)
                        Text(layer.rawValue).font(.subheadline.weight(.semibold))
                        Spacer()
                        if selCount > 0 {
                            Text("\(selCount) выбрано")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.blue.opacity(0.1), in: Capsule())
                        }
                    }
                    .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(items) { item in
                            GarmentCard(
                                item: item,
                                isSelected: selectedItems.contains(item),
                                onTap: { onToggle(item) }
                            )
                        }
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: – GarmentCard ─────────────────────────────────────────────────────
// ⚡ PERF: only `isSelected: Bool` and `item: GarmentItem` (value types).
//   SwiftUI skips body if neither changes between frames.

struct GarmentCard: View {
    let item: GarmentItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.13) : Color(.secondarySystemBackground))
                        .frame(width: 54, height: 54)

                    Image(systemName: item.symbol)
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .frame(width: 54, height: 54)

                    if isSelected {
                        Circle()
                            .fill(.blue)
                            .frame(width: 19, height: 19)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 4, y: -4)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }

                Text(item.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .blue : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("+\(item.heatValue, specifier: "%.1f") CLO")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                isSelected ? Color.blue.opacity(0.07) : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.0 : 0.97)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.68), value: isSelected)
    }
}

// MARK: – Preview ─────────────────────────────────────────────────────────

#Preview {
    NavigationStack {
        ClothingCalculatorView()
    }
}
