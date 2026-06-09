import SwiftUI

// MARK: - GarmentLayer

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

// MARK: - WardrobeAgeGroup
// Source: neonatology.pdf с.55 — три физиологических периода:
// 0–3 мес: нет дрожательного термогенеза, только бурый жир
// 3–12 мес: подкожный жир развивается, начало движения
// 1+ лет: ходит, самостоятельно вырабатывает тепло

enum WardrobeAgeGroup: String, CaseIterable, Identifiable {
    case earlyInfant = "0–3 мес"
    case infant      = "3–12 мес"
    case active      = "1+ лет"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .earlyInfant: return "Лежит в коляске — нет мышечного тепла"
        case .infant:      return "В коляске или начинает ползать"
        case .active:      return "Ходит/двигается — генерирует тепло"
        }
    }
}

extension AgeGroup {
    // Fallback-маппинг по AgeGroup (без точного возраста).
    // Для точного маппинга использовать ChildProfile.wardrobeAgeGroup.
    var toWardrobeAgeGroup: WardrobeAgeGroup {
        switch self {
        case .infant:              return .earlyInfant  // консервативно для 0–5 мес
        case .baby:                return .infant        // 6–11 мес
        default:                   return .active
        }
    }
}

extension ChildProfile {
    /// Точный маппинг в группу конструктора по реальному возрасту в месяцах.
    /// Точнее, чем AgeGroup.toWardrobeAgeGroup, т.к. учитывает границу 3 мес.
    var wardrobeAgeGroup: WardrobeAgeGroup {
        let totalMonths = ageYears * 12 + ageMonths
        switch totalMonths {
        case 0..<3:  return .earlyInfant
        case 3..<12: return .infant
        default:     return .active
        }
    }
}

// MARK: - ThermalRisk
// 7 зон — label/detail контекстно-зависимы и вычисляются в WardrobeModel

enum ThermalRisk: Equatable {
    case dangerouslyCold   // Zone C: delta < −4.0
    case cold              // Zone B: delta < −2.5
    case slightlyCold      // слегка прохладно
    case optimal           // в допуске
    case warm              // слегка тепловато
    case hot               // жарко
    case criticalOverheat  // критический перегрев

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

// MARK: - GarmentItem
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

// MARK: - GarmentCatalog
// Единственный источник данных о предметах гардероба.
// Pre-computed lookup tables — O(1) access, no per-frame allocation.

enum GarmentCatalog {
    static let all: [GarmentItem] = [
        // ── Базовый слой ──────────────────────────────────────────────────────
        .init(id: "diaper",       name: "Подгузник",             heatValue: 0.1,  layer: .base,      symbol: "figure.child"),
        .init(id: "slip",         name: "Хлопковый слип / боди", heatValue: 1.5,  layer: .base,      symbol: "tshirt.fill"),
        .init(id: "thermals",     name: "Термобельё",            heatValue: 2.0,  layer: .base,      symbol: "thermometer.medium"),
        .init(id: "thin_socks",   name: "Носочки тонкие",        heatValue: 0.3,  layer: .base,      symbol: "oval.fill"),
        .init(id: "warm_socks",   name: "Носочки тёплые",        heatValue: 0.6,  layer: .base,      symbol: "capsule.fill"),
        .init(id: "scratch",      name: "Царапки",               heatValue: 0.2,  layer: .base,      symbol: "sparkles"),
        // ── Утеплитель ────────────────────────────────────────────────────────
        .init(id: "fleece",       name: "Флисовый комбез",       heatValue: 3.5,  layer: .insulator, symbol: "wind"),
        .init(id: "sweater",      name: "Свитер",                heatValue: 3.0,  layer: .insulator, symbol: "hexagon.fill"),
        .init(id: "pants",        name: "Брюки хлопковые",       heatValue: 1.0,  layer: .insulator, symbol: "rectangle.fill"),
        // ── Верхняя одежда ────────────────────────────────────────────────────
        .init(id: "windbreaker",  name: "Ветровка",              heatValue: 1.5,  layer: .outer,     symbol: "tornado"),
        .init(id: "demi",         name: "Демисезонный комбез",   heatValue: 6.0,  layer: .outer,     symbol: "cloud.fill"),
        .init(id: "winter",       name: "Зимний комбез 250г",    heatValue: 10.0, layer: .outer,     symbol: "snowflake"),
        .init(id: "thin_blanket", name: "Одеялко тонкое",        heatValue: 1.5,  layer: .outer,     symbol: "square.fill"),
        .init(id: "warm_blanket", name: "Одеялко тёплое",        heatValue: 3.0,  layer: .outer,     symbol: "square.grid.2x2.fill"),
        // ── Аксессуары ────────────────────────────────────────────────────────
        .init(id: "thin_hat",     name: "Тонкая шапочка",        heatValue: 0.8,  layer: .accessory, symbol: "moon.fill"),
        .init(id: "warm_hat",     name: "Тёплая шапка",          heatValue: 2.0,  layer: .accessory, symbol: "moon.stars.fill"),
        .init(id: "mittens",      name: "Варежки",               heatValue: 0.5,  layer: .accessory, symbol: "hand.raised.fill"),
        .init(id: "booties",      name: "Пинетки",               heatValue: 1.0,  layer: .accessory, symbol: "diamond.fill"),
        .init(id: "bib",          name: "Слюнявчик",             heatValue: 0.2,  layer: .accessory, symbol: "drop.fill"),
    ]

    static let byID: [String: GarmentItem] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static let byLayer: [GarmentLayer: [GarmentItem]] = {
        var d: [GarmentLayer: [GarmentItem]] = [:]
        GarmentLayer.allCases.forEach { d[$0] = [] }
        all.forEach { d[$0.layer]!.append($0) }
        return d
    }()
}
