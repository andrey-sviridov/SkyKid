import Foundation

// MARK: - LayeredOutfit

/// Результат рекомендации: три слоя + аксессуары.
/// Слой равен nil, если при данной погоде он не нужен.
struct LayeredOutfit: Equatable {

    struct Layer: Equatable {
        let name: String
        let systemImage: String
        let reason: String
    }

    /// Расчётная температура ощущений с учётом возраста, активности и предпочтений.
    let effectiveTemp: Double
    /// Базовый слой: нательное бельё / термобельё. Присутствует всегда.
    let baseLayer: Layer?
    /// Средний слой: утеплитель (флис, свитер). nil при тёплой погоде.
    let midLayer: Layer?
    /// Верхний слой: куртка / конверт. nil при жаркой погоде без осадков и ветра.
    let outerLayer: Layer?
    /// Аксессуары: шапка, перчатки, шарф, обувь.
    let accessories: [Layer]

    /// Все ненулевые слои в порядке «от тела наружу».
    var allLayers: [Layer] {
        [baseLayer, midLayer, outerLayer].compactMap { $0 } + accessories
    }
}

// MARK: - LayerStrategy (OCP)
//
// Новая возрастная группа или контекст (бассейн, горы) → новый тип,
// реализующий этот протокол. Существующие стратегии не меняются.

protocol LayerStrategy: Sendable {
    func baseLayer(for effectiveTemp: Double, ageGroup: AgeGroup) -> LayeredOutfit.Layer?
    func midLayer(for effectiveTemp: Double, ageGroup: AgeGroup) -> LayeredOutfit.Layer?
    func outerLayer(for effectiveTemp: Double, ageGroup: AgeGroup, weather: WeatherData) -> LayeredOutfit.Layer?
    func accessories(for effectiveTemp: Double, ageGroup: AgeGroup, weather: WeatherData) -> [LayeredOutfit.Layer]
}

// MARK: - StandardLayerStrategy (дети 1 год и старше)

struct StandardLayerStrategy: LayerStrategy {

    func baseLayer(for t: Double, ageGroup: AgeGroup) -> LayeredOutfit.Layer? {
        switch t {
        case ..<0:
            return .init(name: "Термобельё", systemImage: "thermometer.medium",
                         reason: "Первый слой защиты от мороза")
        case 0..<15:
            return .init(name: "Хлопковое бельё", systemImage: "tshirt.fill",
                         reason: "Дышащий базовый слой")
        case 15..<22:
            return .init(name: "Лёгкая футболка", systemImage: "tshirt.fill",
                         reason: "Комфортная температура")
        default:
            return .init(name: "Минимум одежды", systemImage: "sun.max.fill",
                         reason: "Жара — максимально лёгкая одежда")
        }
    }

    func midLayer(for t: Double, ageGroup: AgeGroup) -> LayeredOutfit.Layer? {
        guard t < 18 else { return nil }
        switch t {
        case 10..<18:
            return .init(name: "Лёгкая кофта", systemImage: "wind",
                         reason: "Прохладно — нужен промежуточный слой")
        case 0..<10:
            return .init(name: "Флисовая кофта", systemImage: "wind",
                         reason: "Флис удерживает тепло тела")
        default:
            return .init(name: "Тёплый свитер / флис", systemImage: "wind",
                         reason: "Мороз — плотный утеплитель обязателен")
        }
    }

    func outerLayer(for t: Double, ageGroup: AgeGroup, weather: WeatherData) -> LayeredOutfit.Layer? {
        let hasRain = (51...82).contains(weather.weatherCode) || weather.precipitation > 0.1
        let hasSnow = (71...77).contains(weather.weatherCode)
        let hasWind = weather.windSpeed > 7

        if hasRain {
            return .init(name: "Дождевик / непромокаемая куртка",
                         systemImage: "cloud.rain.fill",
                         reason: "Идёт дождь — нужна водонепроницаемая защита")
        }
        if hasSnow && t < 5 {
            return .init(name: "Зимний комбинезон", systemImage: "snowflake",
                         reason: "Снег и мороз — максимальная защита")
        }
        switch t {
        case 18...:
            guard hasWind else { return nil }
            return .init(name: "Ветровка", systemImage: "wind",
                         reason: "Сильный ветер \(Int(weather.windSpeed)) м/с")
        case 5..<18:
            return .init(name: "Демисезонная куртка", systemImage: "cloud.fill",
                         reason: t < 10 ? "Холодная погода" : "Прохладная погода")
        case 0..<5:
            return .init(name: "Зимняя куртка", systemImage: "cloud.snow.fill",
                         reason: "Около нуля — зимняя куртка обязательна")
        default:
            return .init(name: "Зимний комбинезон", systemImage: "snowflake",
                         reason: "Сильный мороз — необходима полная защита")
        }
    }

    func accessories(for t: Double, ageGroup: AgeGroup, weather: WeatherData) -> [LayeredOutfit.Layer] {
        var result: [LayeredOutfit.Layer] = []

        // Source: pediatria3.pdf, с. 314-315 — терморегуляторная функция кожи
        // несовершенна у детей 1-3 лет. Тоддлер требует более раннего
        // надевания шапки и варежек, чем дети 3+ лет.
        let hatThreshold:     Double = (ageGroup == .toddler) ? 14.0 : 10.0
        let mittensThreshold: Double = (ageGroup == .toddler) ?  7.0 :  5.0

        // Головной убор
        if t < hatThreshold {
            result.append(.init(
                name: t < 0 ? "Тёплая шапка" : "Лёгкая шапочка",
                systemImage: t < 0 ? "moon.stars.fill" : "moon.fill",
                reason: t < 0 ? "Мороз — шапка обязательна" : "Прохладно — защита головы"
            ))
        } else if t >= 22 {
            result.append(.init(name: "Панамка / кепка",
                                systemImage: "sun.max.fill",
                                reason: "Защита от солнца"))
        }

        // Перчатки / варежки
        if t < mittensThreshold {
            result.append(.init(
                name: t < -5 ? "Варежки" : "Перчатки",
                systemImage: "hand.raised.fill",
                reason: t < -5 ? "Сильный мороз — варежки теплее перчаток" : "Защита рук от холода"
            ))
        }

        // Защита шеи — порог выровнен с варежками (обе дистальные зоны)
        if t < mittensThreshold { result.append(neckLayer(for: ageGroup)) }

        // Обувь
        let hasSnow = (71...77).contains(weather.weatherCode)
        let hasRain = (51...82).contains(weather.weatherCode) || weather.precipitation > 0.1
        if hasSnow {
            result.append(.init(name: "Зимние сапоги", systemImage: "diamond.fill",
                                reason: "Снег на улице"))
        } else if hasRain {
            result.append(.init(name: "Резиновые сапоги", systemImage: "drop.fill",
                                reason: "Мокрые дороги"))
        }

        return result
    }

    private func neckLayer(for ageGroup: AgeGroup) -> LayeredOutfit.Layer {
        switch ageGroup {
        case .infant, .baby, .toddler:
            return .init(name: "Бафф / снуд", systemImage: "circle.fill",
                         reason: "Безопаснее шарфа — не зацепится на площадке")
        case .preschool:
            return .init(name: "Бафф или короткий шарф", systemImage: "circle.fill",
                         reason: "Следите, чтобы не намотался на оборудование")
        case .schoolAge, .teen:
            return .init(name: "Шарф", systemImage: "circle.fill",
                         reason: "Защита шеи и горла от холодного воздуха")
        }
    }
}

// MARK: - InfantLayerStrategy (0–12 месяцев)
//
// Особенности: не двигается / в коляске → не вырабатывает тепло самостоятельно;
// шапка обязательна при любой температуре; конверт вместо куртки.

struct InfantLayerStrategy: LayerStrategy {

    // Source: Алгоритм одевания младенца, стр. 7
    // Малыш в коляске не генерирует тепло движением — ветровой порог
    // в 1.75× ниже, чем для ходячих детей (4 м/с vs 7 м/с).
    private static let windProtectionThreshold: Double = 4.0

    // Source: Алгоритм, стр. 8 — AgeExtrasRule: дистальные конечности;
    // neonatology.pdf, с. 55 — незрелость вегетативного контроля сосудов.
    // Периферийное кровообращение у новорождённых хуже взрослого →
    // варежки нужны раньше, чем при 0°C.
    private static let mittensThreshold: Double = 5.0

    func baseLayer(for t: Double, ageGroup: AgeGroup) -> LayeredOutfit.Layer? {
        if t >= 22 {
            return .init(name: "Хлопковый слип / боди", systemImage: "figure.child",
                         reason: "Только лёгкий хлопок в жару")
        }
        return .init(name: "Боди + тонкие носочки", systemImage: "figure.child",
                     reason: "Малыши мёрзнут быстрее — базовый слой обязателен")
    }

    func midLayer(for t: Double, ageGroup: AgeGroup) -> LayeredOutfit.Layer? {
        guard t < 22 else { return nil }
        return t < 5
            ? .init(name: "Флисовый комбинезон + боди",
                    systemImage: "wind",
                    reason: "Мороз — плотный утеплитель для малыша")
            : .init(name: "Флисовый комбинезон",
                    systemImage: "wind",
                    reason: "Удерживает тепло тела малыша")
    }

    func outerLayer(for t: Double, ageGroup: AgeGroup, weather: WeatherData) -> LayeredOutfit.Layer? {
        let hasWind = weather.windSpeed > Self.windProtectionThreshold
        // Source: Алгоритм, стр. 7 — WindRule для коляски
        if t >= 22 {
            guard hasWind else { return nil }
            return .init(name: "Ветрозащитный чехол на коляску", systemImage: "wind",
                         reason: "Ветер \(Int(weather.windSpeed.rounded())) м/с — малыш не согревается движением")
        }
        let hasRain = (51...82).contains(weather.weatherCode) || weather.precipitation > 0.1
        if hasRain {
            return .init(name: "Непромокаемый конверт / дождевик на коляску",
                         systemImage: "cloud.rain.fill",
                         reason: "Защита от дождя для малыша в коляске")
        }
        switch t {
        case 10..<22:
            return .init(name: "Демисезонный конверт", systemImage: "cloud.fill",
                         reason: "В коляске прохладно")
        case 0..<10:
            return .init(name: "Зимний конверт-мешок", systemImage: "snowflake",
                         reason: "В коляске ребёнок не двигается — нужен тёплый конверт")
        default:
            return .init(name: "Зимний конверт + одеялко", systemImage: "snowflake.circle.fill",
                         reason: "Мороз — максимальная защита для малыша в коляске")
        }
    }

    func accessories(for t: Double, ageGroup: AgeGroup, weather: WeatherData) -> [LayeredOutfit.Layer] {
        var result: [LayeredOutfit.Layer] = []
        // Шапка — всегда, форма зависит от температуры
        result.append(.init(
            name: t < 5 ? "Тёплая шапочка" : (t < 22 ? "Хлопковый чепчик" : "Лёгкий чепчик от солнца"),
            systemImage: "moon.fill",
            reason: "Голова малыша — главная зона теплообмена"
        ))
        if t < Self.mittensThreshold {
            result.append(.init(name: "Варежки-царапки", systemImage: "hand.raised.fill",
                                reason: t < 0 ? "Мороз — защита ручек" : "Периферийное кровообращение малыша слабее взрослого"))
        }
        if t < 5 {
            result.append(.init(name: "Пинетки / тёплые носочки", systemImage: "capsule.fill",
                                reason: "Ножки мёрзнут быстро даже в конверте"))
        }
        let hasSnow = (71...77).contains(weather.weatherCode)
        let hasRain = (51...82).contains(weather.weatherCode) || weather.precipitation > 0.1
        if hasSnow {
            result.append(.init(name: "Зимние сапоги / тёплые ботинки",
                                systemImage: "diamond.fill",
                                reason: "Снег на улице"))
        } else if hasRain {
            result.append(.init(name: "Непромокаемая обувь",
                                systemImage: "drop.fill",
                                reason: "Мокрые дороги"))
        }
        return result
    }
}

// MARK: - ClothingRecommendationEngine

/// Stateless recommendation engine. All inputs are explicit parameters — no hidden globals.
///
/// Typical call site (inside a @MainActor ViewModel):
///
///     let bias  = BiasStore.shared.currentBias(for: profile, feelsLike: weather.apparentTemperature)
///     let outfit = ClothingRecommendationEngine.recommend(weather: weather, profile: profile, learnedBias: bias)
///
/// To record user feedback:
///
///     BiasStore.shared.record(.tooCold, for: profile, feelsLike: weather.apparentTemperature)
enum ClothingRecommendationEngine {

    // MARK: - Public API

    /// Returns layered outfit recommendation.
    ///
    /// - Parameters:
    ///   - weather:     Current weather data (feelsLike is the primary temperature input).
    ///   - profile:     Child profile (age, activity, manual offset).
    ///   - learnedBias: Adaptive bias from `BiasStore` (°C). Default 0 for previews / tests.
    static func recommend(
        weather:     WeatherData,
        profile:     ChildProfile,
        learnedBias: Double = 0
    ) -> LayeredOutfit {
        let t        = effectiveTemperature(weather: weather, profile: profile, learnedBias: learnedBias)
        let strategy = Self.strategy(for: profile)
        let age      = profile.ageGroup
        return LayeredOutfit(
            effectiveTemp: t,
            baseLayer:     strategy.baseLayer(for: t, ageGroup: age),
            midLayer:      strategy.midLayer(for: t, ageGroup: age),
            outerLayer:    strategy.outerLayer(for: t, ageGroup: age, weather: weather),
            accessories:   strategy.accessories(for: t, ageGroup: age, weather: weather)
        )
    }

    // MARK: - Effective temperature formula

    /// EffectiveTemp = FeelsLike + ActivityAdjustment + AgeOffset + WalkType + HealthAdjustment + ManualOffset + LearnedBias + StrollerAdjustment
    ///
    /// Components:
    ///   • `ActivityAdjustment`  : +3°C (high) / 0°C (moderate) / −2°C (low)
    ///   • `AgeOffset`           : −5°C (infant) … 0°C (teen)
    ///   • `WalkTypeAdjustment`  : +1°C (short) / 0°C (regular) / −1°C (park) / −1.5°C (long)
    ///   • `HealthAdjustment`    : сумма поправок от Set<HealthFeature>
    ///   • `ManualOffset`        : постоянная поправка родителя (temperaturePreferenceOffset)
    ///   • `LearnedBias`         : адаптивный bias из BiasStore (ClothingBiasEngine)
    ///   • `StrollerAdjustment`  : +3°C (глубокая зимняя люлька) / 0°C (остальные)
    ///     Source: Алгоритм одевания младенца, стр. 5 — тепловое сопротивление корпуса люльки
    static func effectiveTemperature(
        weather:     WeatherData,
        profile:     ChildProfile,
        learnedBias: Double = 0
    ) -> Double {
        let strollerAdjustment = profile.usesStroller ? profile.strollerType.effectiveTempAdjustment : 0
        // Source: neonatology.pdf — период новорождённости (0-28 дней) = максимальный риск.
        // Нет дрожательного термогенеза, бурый жир истощается при охлаждении за минуты.
        // Дополнительный -1°C сверх возрастного offset -5°C = итого -6°C для новорождённых.
        let newbornOffset: Double = profile.isNewbornPeriod ? -1.0 : 0.0
        return weather.apparentTemperature
            + profile.activityLevel.temperatureAdjustment
            + profile.ageGroup.temperatureOffset
            + profile.walkType.temperatureAdjustment
            + profile.healthTemperatureAdjustment
            + profile.temperaturePreferenceOffset
            + learnedBias
            + strollerAdjustment
            + newbornOffset
    }

    // MARK: - Private

    private static func strategy(for profile: ChildProfile) -> any LayerStrategy {
        // Source: Алгоритм одевания младенца, стр. 3
        // До 44 нед. постконцептуального возраста — консервативный режим.
        // Недоношенный тоддлер (1-3 г.) физиологически ближе к младенцу.
        if profile.healthFeatures.contains(.premature), profile.ageGroup == .toddler {
            return InfantLayerStrategy()
        }
        switch profile.ageGroup {
        case .infant, .baby: return InfantLayerStrategy()
        default:             return StandardLayerStrategy()
        }
    }
}

// MARK: - Identifiable conformance (enables SwiftUI ForEach without index)

extension LayeredOutfit.Layer: Identifiable {
    public var id: String { name + systemImage }
}
