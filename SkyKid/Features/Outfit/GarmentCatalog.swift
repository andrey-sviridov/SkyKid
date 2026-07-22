import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum GarmentHaptics {
    @MainActor
    static func previewTriggered() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

// MARK: - GarmentLayer (анатомическая топология слоёв)

enum GarmentLayer: String, CaseIterable, Identifiable, Sendable {
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

    var defaultCoveredZones: Set<BodyZone> {
        switch self {
        case .baseFull, .midFull, .outerwear:
            return [.torso, .arms, .legs]
        case .baseTop, .midTop:
            return [.torso, .arms]
        case .baseBottom, .midBottom:
            return [.legs]
        case .accessory, .sleepwear:
            return []
        }
    }

    var defaultUse: GarmentUse {
        switch self {
        case .accessory: return .accessory
        case .sleepwear: return .sleep
        default: return .outdoorClothing
        }
    }

    var defaultExclusiveGroup: GarmentExclusiveGroup? {
        self == .outerwear ? .outerwear : nil
    }
}

// MARK: - BodySlot

/// Анатомический слот для проверки несовместимости слоёв в солвере.
/// «Манекен» имеет верх/низ на двух ярусах (база, утеплитель) + верхнюю одежду.
enum BodySlot: Hashable, Sendable {
    case baseTop, baseBottom
    case midTop, midBottom
    case outer
}

// MARK: - Garment thermal topology

enum BodyZone: String, CaseIterable, Codable, Hashable, Sendable {
    case torso
    case arms
    case legs
    case head
    case neck
    case hands
    case feet
}

enum GarmentUse: String, Codable, Sendable {
    case outdoorClothing
    case accessory
    case strollerGear
    case sleep
    case utility
}

enum GarmentExclusiveGroup: String, Codable, Hashable, Sendable {
    case outerwear
    case headwear
    case neckwear
    case handwear
    case socks
    case footwear
}

// MARK: - CatalogAgeGroup

enum CatalogAgeGroup: String, CaseIterable, Identifiable, Sendable {
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

enum WardrobeAgeGroup: String, CaseIterable, Identifiable, Sendable {
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

extension ChildThermalProfile {
    var wardrobeAgeGroup: WardrobeAgeGroup {
        switch chronologicalAgeMonths {
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

struct GarmentItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let heatValue: Double          // CLO-analogue (WardrobeModel)
    let tog: Double                // TOG value (OutfitSolver §5.1)
    let layer: GarmentLayer
    let symbol: String
    let catalogAgeGroup: CatalogAgeGroup?
    let features: [String]
    let coveredZones: Set<BodyZone>
    let exclusiveGroup: GarmentExclusiveGroup?
    let use: GarmentUse
    let recommendationAgeGroups: Set<WardrobeAgeGroup>

    init(
        id: String,
        name: String,
        heatValue: Double,
        tog: Double,
        layer: GarmentLayer,
        symbol: String,
        catalogAgeGroup: CatalogAgeGroup? = .universal,
        features: [String] = [],
        coveredZones: Set<BodyZone>? = nil,
        exclusiveGroup: GarmentExclusiveGroup? = nil,
        use: GarmentUse? = nil,
        recommendationAgeGroups: Set<WardrobeAgeGroup> = []
    ) {
        self.id = id
        self.name = name
        self.heatValue = heatValue
        self.tog = tog
        self.layer = layer
        self.symbol = symbol
        self.catalogAgeGroup = catalogAgeGroup
        self.features = features
        self.coveredZones = coveredZones ?? layer.defaultCoveredZones
        self.exclusiveGroup = exclusiveGroup ?? layer.defaultExclusiveGroup
        self.use = use ?? layer.defaultUse
        self.recommendationAgeGroups = recommendationAgeGroups
    }

    var imageAssetName: String { "garment_\(id)" }

    static func == (l: Self, r: Self) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

// MARK: - GarmentIconView

struct GarmentIconView: View {
    enum ContainerShape {
        case circle
        case roundedRectangle(CGFloat)
    }

    let item: GarmentItem
    var isSelected: Bool = false
    var accentColor: Color = .blue
    var size: CGFloat = 40
    var shape: ContainerShape = .circle

    var body: some View {
        ZStack {
            background
            icon
        }
        .frame(width: size, height: size)
        .accessibilityLabel(item.name)
    }

    @ViewBuilder
    private var background: some View {
        let fillColor = isSelected ? accentColor.opacity(0.13) : Color.primary.opacity(0.07)
        switch shape {
        case .circle:
            Circle().fill(fillColor)
        case .roundedRectangle(let radius):
            RoundedRectangle(cornerRadius: radius).fill(fillColor)
        }
    }

    @ViewBuilder
    private var icon: some View {
        #if canImport(UIKit)
        if let image = UIImage(named: item.imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(size * 0.14)
        } else {
            symbolIcon
        }
        #else
        symbolIcon
        #endif
    }

    private var symbolIcon: some View {
        Image(systemName: item.symbol)
            .font(.system(size: max(12, size * 0.42), weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isSelected ? accentColor : .secondary)
    }
}

struct GarmentIconPreviewSheet: View {
    let item: GarmentItem

    var body: some View {
        VStack(spacing: 18) {
            GarmentIconView(item: item, isSelected: true, accentColor: .blue, size: 150)
                .padding(.top, 18)

            VStack(spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text(String(format: "%.2g TOG", item.tog))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !item.features.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(item.features, id: \.self) { feature in
                        Text(feature)
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(360), .medium])
    }
}

struct GarmentPhotoPreviewSheet: View {
    let item: GarmentItem

    var body: some View {
        photo
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
    }

    @ViewBuilder
    private var photo: some View {
        #if canImport(UIKit)
        if let image = UIImage(named: item.imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            fallbackSymbol
        }
        #else
        fallbackSymbol
        #endif
    }

    private var fallbackSymbol: some View {
        Image(systemName: item.symbol)
            .font(.system(size: 140, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white.opacity(0.92))
    }
}

// MARK: - GarmentCatalog

enum GarmentCatalog {

    /// Единственный каталог для решателя, «Моего гардероба» и Конструктора.
    /// В нём нет скрытых дублей, которые пользователь не может отключить.
    static let all: [GarmentItem] = catalogItems

    static let catalogItems: [GarmentItem] = [

        // Базовые и возрастные аксессуары ────────────────────────────────────
        .init(id: "diaper", name: "Подгузник",
              heatValue: 0.20, tog: 0.10, layer: .baseFull, symbol: "figure.child",
              catalogAgeGroup: .universal, coveredZones: [], use: .utility),

        .init(id: "thin_socks", name: "Носочки тонкие",
              heatValue: 0.30, tog: 0.15, layer: .accessory, symbol: "oval.fill",
              catalogAgeGroup: .zeroToThree, coveredZones: [.feet], exclusiveGroup: .socks),

        .init(id: "warm_socks", name: "Носочки тёплые",
              heatValue: 0.60, tog: 0.30, layer: .accessory, symbol: "capsule.fill",
              catalogAgeGroup: .zeroToThree, coveredZones: [.feet], exclusiveGroup: .socks),

        .init(id: "scratch", name: "Царапки",
              heatValue: 0.20, tog: 0.10, layer: .accessory, symbol: "sparkles",
              catalogAgeGroup: .zeroToThree, coveredZones: [.hands], exclusiveGroup: .handwear),

        .init(id: "thin_hat", name: "Тонкая шапочка",
              heatValue: 0.80, tog: 0.20, layer: .accessory, symbol: "moon.fill",
              catalogAgeGroup: .zeroToThree, coveredZones: [.head], exclusiveGroup: .headwear),

        .init(id: "warm_hat", name: "Тёплая шапка",
              heatValue: 2.00, tog: 0.50, layer: .accessory, symbol: "moon.stars.fill",
              catalogAgeGroup: .zeroToThree, coveredZones: [.head], exclusiveGroup: .headwear),

        .init(id: "mittens", name: "Варежки",
              heatValue: 0.50, tog: 0.30, layer: .accessory, symbol: "hand.raised.fill",
              catalogAgeGroup: .universal, coveredZones: [.hands], exclusiveGroup: .handwear),

        .init(id: "booties", name: "Пинетки",
              heatValue: 1.00, tog: 0.40, layer: .accessory, symbol: "diamond.fill",
              catalogAgeGroup: .zeroToThree, coveredZones: [.feet], exclusiveGroup: .footwear),

        .init(id: "bib", name: "Слюнявчик",
              heatValue: 0.00, tog: 0.00, layer: .accessory, symbol: "drop.fill",
              catalogAgeGroup: .universal, coveredZones: [.torso], use: .utility),

        // 0–3 мес ─────────────────────────────────────────────────────────────
        .init(id: "bodi_km_kr", name: "Боди-кимоно (кор. рукав)",
              heatValue: 0.41, tog: 0.28, layer: .baseTop, symbol: "tshirt",
              catalogAgeGroup: .zeroToThree,
              features: ["полный запах", "без штанин", "швы наружу"],
              recommendationAgeGroups: [.earlyInfant]),

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
              features: ["кор. рукав", "кнопки снизу"],
              recommendationAgeGroups: [.infant]),

        .init(id: "bodi_long", name: "Боди, длинный рукав",
              heatValue: 0.56, tog: 0.38, layer: .baseTop, symbol: "tshirt.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["дл. рукав", "кнопки снизу"]),

        .init(id: "pesochnik", name: "Песочник / Ромпер летний",
              heatValue: 0.64, tog: 0.43, layer: .baseFull, symbol: "figure.child",
              catalogAgeGroup: .threeToTwelve,
              features: ["кор. рукав", "короткие шорты"],
              recommendationAgeGroups: [.infant]),

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
              features: ["на стопу"], coveredZones: [.feet], exclusiveGroup: .socks),

        .init(id: "shapka_trik", name: "Шапочка трикотажная",
              heatValue: 0.23, tog: 0.15, layer: .accessory, symbol: "moon.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["без завязок"], coveredZones: [.head], exclusiveGroup: .headwear),

        .init(id: "t_shirt", name: "Футболка",
              heatValue: 0.32, tog: 0.22, layer: .baseTop, symbol: "tshirt",
              catalogAgeGroup: .threeToTwelve,
              features: ["кор. рукав"], recommendationAgeGroups: [.active]),

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
              features: ["утепленные"], coveredZones: [.feet], exclusiveGroup: .socks),

        .init(id: "pinetki_warm", name: "Пинетки утеплённые",
              heatValue: 0.56, tog: 0.38, layer: .accessory, symbol: "diamond.fill",
              catalogAgeGroup: .threeToTwelve,
              features: ["для коляски", "замена обуви"],
              coveredZones: [.feet], exclusiveGroup: .footwear),

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
              features: ["для коляски", "сильный мороз"], use: .strollerGear),

        .init(id: "windbreaker_overall", name: "Ветровочный комбез (без подклада)",
              heatValue: 0.75, tog: 0.50, layer: .outerwear, symbol: "tornado",
              catalogAgeGroup: .universal,
              features: ["защита от ветра", "межсезонье"]),

        .init(id: "balaclava_hat", name: "Шапка-шлем (зимняя)",
              heatValue: 1.20, tog: 0.80, layer: .accessory, symbol: "moon.stars.fill",
              catalogAgeGroup: .universal,
              features: ["закрывает шею и уши"],
              coveredZones: [.head, .neck], exclusiveGroup: .headwear),

        .init(id: "snood", name: "Манишка / Снуд флисовый",
              heatValue: 0.45, tog: 0.30, layer: .accessory, symbol: "oval.fill",
              catalogAgeGroup: .universal,
              features: ["защита шеи и груди"],
              coveredZones: [.neck], exclusiveGroup: .neckwear),

        .init(id: "wool_socks", name: "Шерстяные носки",
              heatValue: 0.75, tog: 0.50, layer: .accessory, symbol: "capsule.fill",
              catalogAgeGroup: .universal,
              features: ["мериносовая шерсть"], coveredZones: [.feet], exclusiveGroup: .socks),

        .init(id: "sun_hat", name: "Панамка / Кепка",
              heatValue: 0.15, tog: 0.10, layer: .accessory, symbol: "sun.max.fill",
              catalogAgeGroup: .universal,
              features: ["защита от солнца"], coveredZones: [.head], exclusiveGroup: .headwear),

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
        case "slip": return "slip_closed"
        case "thermals": return "slip_thick"
        case "fleece": return "fleece_overall"
        case "sweater": return "hoodie_thick"
        case "pants": return "jeans"
        case "windbreaker": return "windbreaker_overall"
        case "demi": return "demi_overall"
        case "winter": return "winter_overall"
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
