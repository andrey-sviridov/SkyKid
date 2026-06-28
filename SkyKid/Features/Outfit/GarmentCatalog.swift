import SwiftUI

// MARK: - GarmentLayer (анатомическая топология слоёв)

enum GarmentLayer: String, CaseIterable, Identifiable {
    case baseFull    = "Базовый — комбинезон"   // на всё тело: слипы, ромперы, термобельё
    case baseTop     = "Базовый — верх"          // боди, футболки, распашонки
    case baseBottom  = "Базовый — низ"           // ползунки, шорты, легинсы
    case midFull     = "Утеплитель — комбинезон" // флисовые/вязаные комбезы
    case midTop      = "Утеплитель — верх"       // свитшоты, кофты, лонгсливы-утеплители
    case midBottom   = "Утеплитель — низ"        // джинсы, плотные штаны
    case outerwear   = "Верхняя одежда"          // куртки, демисезон/зимние комбезы
    case accessory   = "Аксессуары"              // шапки, носки, варежки, пинетки
    case sleepwear   = "Для сна"                 // спальные мешки, пелёнки, одеяла

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .baseFull:   return "figure.child"
        case .baseTop:    return "tshirt.fill"
        case .baseBottom: return "rectangle.fill"
        case .midFull:    return "wind"
        case .midTop:     return "hexagon.fill"
        case .midBottom:  return "rectangle.portrait.fill"
        case .outerwear:  return "cloud.fill"
        case .accessory:  return "sparkles"
        case .sleepwear:  return "moon.zzz.fill"
        }
    }

    /// Слоты «виртуального манекена», которые занимает слой.
    /// «Комбинезон» (full) занимает и верх, и низ своего яруса — поэтому
    /// несовместим с раздельными верх/низ того же яруса (нельзя надеть два боди).
    var bodySlots: Set<BodySlot> {
        switch self {
        case .baseFull:   return [.baseTop, .baseBottom]
        case .baseTop:    return [.baseTop]
        case .baseBottom: return [.baseBottom]
        case .midFull:    return [.midTop, .midBottom]
        case .midTop:     return [.midTop]
        case .midBottom:  return [.midBottom]
        case .outerwear:  return [.outer]
        case .accessory:  return []
        case .sleepwear:  return []
        }
    }

    /// Участвует ли слой в подборе прогулочного лука (тело), а не аксессуар/сон.
    var occupiesBody: Bool { !bodySlots.isEmpty }
}

// MARK: - BodySlot

/// Анатомический слот для проверки несовместимости слоёв в солвере.
/// «Манекен» имеет верх/низ на двух ярусах (база, утеплитель) + верхнюю одежду.
enum BodySlot: Hashable {
    case baseTop, baseBottom
    case midTop, midBottom
    case outer
}

// MARK: - CatalogAgeGroup

enum CatalogAgeGroup: String, CaseIterable, Identifiable {
    case zeroToThree   = "0–3 мес"
    case threeToSix    = "3–6 мес"
    case threeToTwelve = "3–12 мес"
    case sixToTwelve   = "6–12 мес"
    case universal     = "Универсальное"

    var id: String { rawValue }

    func matches(_ group: WardrobeAgeGroup) -> Bool {
        switch group {
        case .earlyInfant: return self == .zeroToThree || self == .universal
        case .infant:      return self == .threeToTwelve || self == .universal
        case .active:      return self == .threeToTwelve || self == .sixToTwelve || self == .universal
        }
    }
}

// MARK: - WardrobeAgeGroup

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
    var toWardrobeAgeGroup: WardrobeAgeGroup {
        switch self {
        case .infant:  return .earlyInfant
        case .baby:    return .infant
        default:       return .active
        }
    }
}

extension ChildProfile {
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

enum ThermalRisk: Equatable {
    case dangerouslyCold
    case cold
    case slightlyCold
    case optimal
    case warm
    case hot
    case criticalOverheat

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

struct GarmentItem: Identifiable, Hashable {
    let id: String
    let name: String
    let heatValue: Double          // CLO-analogue (WardrobeModel)
    let tog: Double                // TOG value (OutfitSolver §5.1)
    let layer: GarmentLayer
    let symbol: String
    var catalogAgeGroup: CatalogAgeGroup? = nil   // nil = legacy OutfitSolver item
    var features: [String] = []

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: - GarmentCatalog

enum GarmentCatalog {

    static let all: [GarmentItem] = legacyItems + catalogItems

    // ── Старые предметы (используются OutfitSolver §5.1) ─────────────────────
    // catalogAgeGroup == nil → не отображаются в пользовательском каталоге
    static let legacyItems: [GarmentItem] = [
        .init(id: "diaper",      name: "Подгузник",             heatValue: 0.2,  tog: 0.10, layer: .baseFull,  symbol: "figure.child"),
        .init(id: "slip",        name: "Хлопковый слип / боди", heatValue: 1.5,  tog: 0.60, layer: .baseFull,  symbol: "tshirt.fill"),
        .init(id: "thermals",    name: "Термобельё",            heatValue: 2.0,  tog: 0.80, layer: .baseFull,  symbol: "thermometer.medium"),
        .init(id: "thin_socks",  name: "Носочки тонкие",        heatValue: 0.3,  tog: 0.15, layer: .accessory, symbol: "oval.fill"),
        .init(id: "warm_socks",  name: "Носочки тёплые",        heatValue: 0.6,  tog: 0.30, layer: .accessory, symbol: "capsule.fill"),
        .init(id: "scratch",     name: "Царапки",               heatValue: 0.2,  tog: 0.10, layer: .accessory, symbol: "sparkles"),
        .init(id: "fleece",      name: "Флисовый комбез",       heatValue: 3.5,  tog: 1.20, layer: .midFull,   symbol: "wind"),
        .init(id: "sweater",     name: "Свитер",                heatValue: 3.0,  tog: 0.80, layer: .midTop,    symbol: "hexagon.fill"),
        .init(id: "pants",       name: "Брюки хлопковые",       heatValue: 1.0,  tog: 0.40, layer: .midBottom, symbol: "rectangle.fill"),
        .init(id: "windbreaker", name: "Ветровка",              heatValue: 1.5,  tog: 0.50, layer: .outerwear, symbol: "tornado"),
        .init(id: "demi",        name: "Демисезонный комбез",   heatValue: 6.0,  tog: 2.25, layer: .outerwear, symbol: "cloud.fill"),
        .init(id: "winter",      name: "Зимний комбез 250г",    heatValue: 10.0, tog: 3.50, layer: .outerwear, symbol: "snowflake"),
        .init(id: "thin_hat",    name: "Тонкая шапочка",        heatValue: 0.8,  tog: 0.20, layer: .accessory, symbol: "moon.fill"),
        .init(id: "warm_hat",    name: "Тёплая шапка",          heatValue: 2.0,  tog: 0.50, layer: .accessory, symbol: "moon.stars.fill"),
        .init(id: "mittens",     name: "Варежки",               heatValue: 0.5,  tog: 0.30, layer: .accessory, symbol: "hand.raised.fill"),
        .init(id: "booties",     name: "Пинетки",               heatValue: 1.0,  tog: 0.40, layer: .accessory, symbol: "diamond.fill"),
        .init(id: "bib",         name: "Слюнявчик",             heatValue: 0.0,  tog: 0.00, layer: .accessory, symbol: "drop.fill"),
    ]

    // ── Пользовательский каталог (отображается в Конструкторе) ───────────────
    static let catalogItems: [GarmentItem] = [

        // 0–3 мес ─────────────────────────────────────────────────────────────
        .init(id: "bodi_km_kr", name: "Боди-кимоно (кор. рукав)",
              heatValue: 0.41, tog: 0.28, layer: .baseTop, symbol: "tshirt",
              catalogAgeGroup: .zeroToThree,
              features: ["полный запах", "без штанин", "швы наружу"]),

        .init(id: "bodi_km_dr", name: "Боди-кимоно (дл. рукав)",
              heatValue: 0.60, tog: 0.40, layer: .baseTop, symbol: "tshirt.fill",
              catalogAgeGroup: .zeroToThree,
              features: ["полный запах", "встроенные царапки"]),

        .init(id: "slip_thin", name: "Слип тонкий (кулирка)",
              heatValue: 0.86, tog: 0.58, layer: .baseFull, symbol: "figure.child",
              catalogAgeGroup: .zeroToThree,
              features: ["закрытый след", "швы наружу"]),

        .init(id: "slip_thick", name: "Слип плотный (интерлок)",
              heatValue: 1.13, tog: 0.75, layer: .baseFull, symbol: "figure.child",
              catalogAgeGroup: .zeroToThree,
              features: ["закрытый след"]),

        .init(id: "raspashonka", name: "Распашонка тонкая",
              heatValue: 0.34, tog: 0.23, layer: .baseTop, symbol: "tshirt",
              catalogAgeGroup: .zeroToThree,
              features: ["без кнопок снизу", "швы наружу"]),

        .init(id: "polzunki_ez", name: "Ползунки (еврорезинка)",
              heatValue: 0.53, tog: 0.35, layer: .baseBottom, symbol: "oval.fill",
              catalogAgeGroup: .zeroToThree,
              features: ["закрытый след", "широкая резинка"]),

        .init(id: "polzunki_lyam", name: "Ползунки на лямках",
              heatValue: 0.71, tog: 0.48, layer: .baseBottom, symbol: "oval.fill",
              catalogAgeGroup: .zeroToThree,
              features: ["закрытый след", "закрывают грудь"]),

        // 3–12 мес ────────────────────────────────────────────────────────────
        .init(id: "bodi_short", name: "Боди, короткий рукав",
              heatValue: 0.38, tog: 0.26, layer: .baseTop, symbol: "tshirt",
              catalogAgeGroup: .threeToTwelve,
              features: ["кор. рукав", "кнопки снизу"]),

        .init(id: "bodi_long", name: "Боди, длинный рукав",
              heatValue: 0.56, tog: 0.38, layer: .baseTop, symbol: "tshirt.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["дл. рукав", "кнопки снизу"]),

        .init(id: "pesochnik", name: "Песочник / Ромпер летний",
              heatValue: 0.64, tog: 0.43, layer: .baseFull, symbol: "figure.child",
              catalogAgeGroup: .threeToTwelve,
              features: ["кор. рукав", "короткие шорты"]),

        .init(id: "slip_open", name: "Слип с открытыми ножками",
              heatValue: 0.98, tog: 0.65, layer: .baseFull, symbol: "figure.child",
              catalogAgeGroup: .threeToTwelve,
              features: ["манжеты на лодыжках", "под носки"]),

        .init(id: "slip_closed", name: "Слип тонкий (закрытые ножки)",
              heatValue: 0.90, tog: 0.60, layer: .baseFull, symbol: "figure.child",
              catalogAgeGroup: .threeToTwelve,
              features: ["закрытый след", "кулирка"]),

        .init(id: "slip_futer", name: "Слип утепленный (футер)",
              heatValue: 1.58, tog: 1.05, layer: .midFull, symbol: "figure.child",
              catalogAgeGroup: .threeToTwelve,
              features: ["второй слой", "начёс внутри"]),

        .init(id: "shtany_trik", name: "Штанишки трикотажные",
              heatValue: 0.45, tog: 0.30, layer: .baseBottom, symbol: "rectangle.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["открытый низ", "под носки"]),

        .init(id: "kofta_cardigan", name: "Кофточка / Кардиган лёгкий",
              heatValue: 0.71, tog: 0.48, layer: .midTop, symbol: "hexagon.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["на кнопках"]),

        .init(id: "noski_thin", name: "Носочки тонкие",
              heatValue: 0.12, tog: 0.08, layer: .accessory, symbol: "oval.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["на стопу"]),

        .init(id: "shapka_trik", name: "Шапочка трикотажная",
              heatValue: 0.23, tog: 0.15, layer: .accessory, symbol: "moon.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["без завязок"]),

        .init(id: "t_shirt", name: "Футболка",
              heatValue: 0.32, tog: 0.22, layer: .baseTop, symbol: "tshirt",
              catalogAgeGroup: .threeToTwelve,
              features: ["кор. рукав"]),

        .init(id: "longsleeve", name: "Лонгслив (тонкая кофта)",
              heatValue: 0.49, tog: 0.33, layer: .baseTop, symbol: "tshirt.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["дл. рукав"]),

        .init(id: "hoodie_thick", name: "Худи / Свитшот с начёсом",
              heatValue: 1.16, tog: 0.78, layer: .midTop, symbol: "hexagon.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["флис или футер 3-нитка"]),

        .init(id: "shorts_light", name: "Шорты лёгкие",
              heatValue: 0.23, tog: 0.15, layer: .baseBottom, symbol: "rectangle",
              catalogAgeGroup: .threeToTwelve,
              features: ["открытый низ"]),

        .init(id: "leggings", name: "Легинсы / Колготки",
              heatValue: 0.53, tog: 0.35, layer: .baseBottom, symbol: "rectangle.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["облегающие"]),

        .init(id: "jeans", name: "Джинсы / Брюки из денима",
              heatValue: 0.75, tog: 0.50, layer: .midBottom, symbol: "rectangle.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["плотная ткань", "защита коленей"]),

        .init(id: "softshell", name: "Комбинезон Softshell",
              heatValue: 1.31, tog: 0.88, layer: .outerwear, symbol: "cloud.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["без подклада", "защита от ветра"]),

        .init(id: "noski_thick", name: "Носки махровые / плотные",
              heatValue: 0.23, tog: 0.15, layer: .accessory, symbol: "capsule.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["утепленные"]),

        .init(id: "pinetki_warm", name: "Пинетки утеплённые",
              heatValue: 0.56, tog: 0.38, layer: .accessory, symbol: "diamond.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["для коляски", "замена обуви"]),

        // Универсальное ───────────────────────────────────────────────────────
        .init(id: "fleece_overall", name: "Флисовый комбинезон (поддёва)",
              heatValue: 1.65, tog: 1.10, layer: .midFull, symbol: "wind",
              catalogAgeGroup: .universal,
              features: ["флис", "под демисезон/зиму"]),

        .init(id: "knit_overall", name: "Вязаный комбинезон",
              heatValue: 1.80, tog: 1.20, layer: .midFull, symbol: "circle.grid.3x3.fill",
              catalogAgeGroup: .universal,
              features: ["шерсть или акрил"]),

        .init(id: "demi_overall", name: "Демисезонный комбез (80–120г)",
              heatValue: 3.08, tog: 2.05, layer: .outerwear, symbol: "cloud.fill",
              catalogAgeGroup: .universal,
              features: ["утеплитель", "от +5 до +15°C"]),

        .init(id: "winter_overall", name: "Зимний конверт / комбез (250–300г)",
              heatValue: 7.13, tog: 4.75, layer: .outerwear, symbol: "snowflake",
              catalogAgeGroup: .universal,
              features: ["мех/пух/тинсулейт", "ниже 0°C"]),

        .init(id: "fur_footmuff", name: "Меховой конверт в коляску (овчина/пух)",
              heatValue: 6.00, tog: 4.00, layer: .outerwear, symbol: "cloud.fill",
              catalogAgeGroup: .universal,
              features: ["для коляски", "сильный мороз"]),

        .init(id: "windbreaker_overall", name: "Ветровочный комбез (без подклада)",
              heatValue: 0.75, tog: 0.50, layer: .outerwear, symbol: "tornado",
              catalogAgeGroup: .universal,
              features: ["защита от ветра", "межсезонье"]),

        .init(id: "balaclava_hat", name: "Шапка-шлем (зимняя)",
              heatValue: 1.20, tog: 0.80, layer: .accessory, symbol: "moon.stars.fill",
              catalogAgeGroup: .universal,
              features: ["закрывает шею и уши"]),

        .init(id: "snood", name: "Манишка / Снуд флисовый",
              heatValue: 0.45, tog: 0.30, layer: .accessory, symbol: "oval.fill",
              catalogAgeGroup: .universal,
              features: ["защита шеи и груди"]),

        .init(id: "wool_socks", name: "Шерстяные носки",
              heatValue: 0.75, tog: 0.50, layer: .accessory, symbol: "capsule.fill",
              catalogAgeGroup: .universal,
              features: ["мериносовая шерсть"]),

        .init(id: "sun_hat", name: "Панамка / Кепка",
              heatValue: 0.15, tog: 0.10, layer: .accessory, symbol: "sun.max.fill",
              catalogAgeGroup: .universal,
              features: ["защита от солнца"]),

        // Для сна ───────────────────────────────────────────────────────────
        .init(id: "pelenka_thin", name: "Пелёнка тонкая (муслин)",
              heatValue: 0.71, tog: 0.48, layer: .sleepwear, symbol: "square.fill",
              catalogAgeGroup: .zeroToThree,
              features: ["свободное пеленание"]),

        .init(id: "pelenka_kokon", name: "Пелёнка-кокон (молния)",
              heatValue: 1.28, tog: 0.85, layer: .sleepwear, symbol: "square.fill",
              catalogAgeGroup: .zeroToThree,
              features: ["трикотаж на молнии"]),

        .init(id: "pelenka_kokon_open", name: "Пелёнка-кокон (открытые руки)",
              heatValue: 0.75, tog: 0.50, layer: .sleepwear, symbol: "square.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["руки свободны", "молния"]),

        .init(id: "sleeping_bag_05tog", name: "Спальный мешок летний (муслин, 0.5 TOG)",
              heatValue: 0.75, tog: 0.50, layer: .sleepwear, symbol: "moon.zzz.fill",
              catalogAgeGroup: .universal,
              features: ["домашний сон", "24–27°C"]),

        .init(id: "sleeping_bag_1tog", name: "Спальный мешок (демисезон, 1.0 TOG)",
              heatValue: 1.50, tog: 1.00, layer: .sleepwear, symbol: "moon.zzz.fill",
              catalogAgeGroup: .universal,
              features: ["домашний сон", "20–24°C"]),

        .init(id: "sleeping_bag_25tog", name: "Спальный мешок (тёплый, 2.5 TOG)",
              heatValue: 3.75, tog: 2.50, layer: .sleepwear, symbol: "moon.zzz.fill",
              catalogAgeGroup: .universal,
              features: ["домашний сон", "16–20°C"]),

        .init(id: "thin_blanket", name: "Одеялко тонкое",
              heatValue: 1.5, tog: 0.80, layer: .sleepwear, symbol: "square.fill",
              catalogAgeGroup: .universal,
              features: ["коляска", "прохладно"]),

        .init(id: "warm_blanket", name: "Одеялко тёплое",
              heatValue: 3.0, tog: 1.50, layer: .sleepwear, symbol: "square.grid.2x2.fill",
              catalogAgeGroup: .universal,
              features: ["коляска", "холодно"]),
    ]

    static func canonicalID(for id: String) -> String {
        switch id {
        case "bodi_st_kr", "bodi_kr": return "bodi_short"
        case "bodi_st_dr", "bodi_dr": return "bodi_long"
        default: return id
        }
    }

    // MARK: - Lookup tables

    static let byID: [String: GarmentItem] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static let byLayer: [GarmentLayer: [GarmentItem]] = {
        var d: [GarmentLayer: [GarmentItem]] = [:]
        GarmentLayer.allCases.forEach { d[$0] = [] }
        all.forEach { d[$0.layer]!.append($0) }
        return d
    }()

    /// Предметы для отображения в Конструкторе, отфильтрованные по возрасту
    static func displayItems(for ageGroup: WardrobeAgeGroup) -> [GarmentLayer: [GarmentItem]] {
        let filtered = catalogItems.filter { $0.catalogAgeGroup?.matches(ageGroup) == true }
        var d: [GarmentLayer: [GarmentItem]] = [:]
        GarmentLayer.allCases.forEach { d[$0] = [] }
        filtered.forEach { d[$0.layer]!.append($0) }
        return d
    }
}
