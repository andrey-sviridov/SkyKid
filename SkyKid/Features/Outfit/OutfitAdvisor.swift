import Foundation

// MARK: - Domain type

struct OutfitItem: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let reason: String
}

// MARK: - OCP: протокол правила
// Новые правила добавляются без изменения существующего кода.
// Создайте conforming type и добавьте его в OutfitAdvisor.rules.

fileprivate protocol OutfitRule: Sendable {
    func apply(effectiveTemp: Double, weather: WeatherData, ageGroup: AgeGroup?) -> [OutfitItem]
}

// MARK: - Конкретные правила

private struct InfantLayeringRule: OutfitRule {
    func apply(effectiveTemp: Double, weather: WeatherData, ageGroup: AgeGroup?) -> [OutfitItem] {
        guard ageGroup == .infant else { return [] }
        return [.init(icon: "🩱", name: "Боди + конверт",
                      reason: "Малышам до 6 мес нужен дополнительный слой")]
    }
}

private struct BaseTemperatureRule: OutfitRule {
    func apply(effectiveTemp t: Double, weather: WeatherData, ageGroup: AgeGroup?) -> [OutfitItem] {
        switch t {
        case ..<(-10):
            return [
                .init(icon: "🧥", name: "Зимний комбинезон",  reason: "Сильный мороз"),
                .init(icon: "🧣", name: "Термобельё",         reason: "Доп. тепло при сильном морозе"),
                .init(icon: "🧤", name: "Варежки",            reason: "Защита от обморожения"),
                .init(icon: "🎿", name: "Зимняя шапка",       reason: "Обязательно в мороз"),
            ]
        case -10..<0:
            return [
                .init(icon: "🧥", name: "Зимняя куртка", reason: "Мороз"),
                .init(icon: "🧤", name: "Перчатки",      reason: "Холодно"),
                .init(icon: "🎿", name: "Шапка",         reason: "Защита головы"),
            ]
        case 0..<5:
            return [
                .init(icon: "🧥", name: "Тёплая куртка", reason: "Около нуля"),
                .init(icon: "🧤", name: "Перчатки",      reason: "Прохладно"),
                .init(icon: "🎿", name: "Шапка",         reason: "Прохладная погода"),
            ]
        case 5..<15:
            return [
                .init(icon: "🧥", name: "Куртка", reason: "Прохладно"),
                .init(icon: "👕", name: "Кофта",  reason: "Переменчивая погода"),
            ]
        case 15..<22:
            return [
                .init(icon: "🧥", name: "Лёгкая куртка",       reason: "Может быть прохладно"),
                .init(icon: "👕", name: "Футболка или кофта",  reason: "Комфортная температура"),
            ]
        default:
            return [
                .init(icon: "👕", name: "Лёгкая одежда",    reason: "Тепло"),
                .init(icon: "🧢", name: "Панамка / кепка",  reason: "Защита от солнца"),
            ]
        }
    }
}

private struct AgeExtrasRule: OutfitRule {
    func apply(effectiveTemp t: Double, weather: WeatherData, ageGroup: AgeGroup?) -> [OutfitItem] {
        guard let group = ageGroup else { return [] }
        switch group {
        case .baby:
            return [.init(icon: "🧦", name: "Тёплые носочки",
                          reason: "Ножки мёрзнут быстрее всего")]
        case .toddler where t < 10:
            return [.init(icon: "🧦", name: "Тёплые носки",
                          reason: "Активно двигается — ножки должны быть в тепле")]
        default:
            return []
        }
    }
}

// Шарф опасен для детей до ~4 лет — риск удушения на площадке
private struct NeckProtectionRule: OutfitRule {
    func apply(effectiveTemp t: Double, weather: WeatherData, ageGroup: AgeGroup?) -> [OutfitItem] {
        guard t < 5, let group = ageGroup else { return [] }
        switch group {
        case .infant, .baby, .toddler:
            return [.init(icon: "🧣", name: "Бафф / снуд",
                          reason: "Безопаснее шарфа: не зацепится на площадке")]
        case .preschool:
            return [.init(icon: "🧣", name: "Бафф или короткий шарф",
                          reason: "Следите, чтобы не намотался на оборудование")]
        case .schoolAge, .teen:
            return [.init(icon: "🧣", name: "Шарф",
                          reason: "Защита шеи и горла от холодного воздуха")]
        }
    }
}

private struct WindRule: OutfitRule {
    func apply(effectiveTemp: Double, weather: WeatherData, ageGroup: AgeGroup?) -> [OutfitItem] {
        guard weather.windSpeed > 7 else { return [] }
        return [.init(icon: "🪬", name: "Ветровка поверх",
                      reason: "Сильный ветер \(Int(weather.windSpeed)) м/с")]
    }
}

private struct PrecipitationRule: OutfitRule {
    func apply(effectiveTemp: Double, weather: WeatherData, ageGroup: AgeGroup?) -> [OutfitItem] {
        let code = weather.weatherCode
        if (71...77).contains(code) {
            return [.init(icon: "👢", name: "Зимние сапоги", reason: "Снег на улице")]
        }
        if (51...82).contains(code) || weather.precipitation > 0.1 {
            return [
                .init(icon: "🌂", name: "Дождевик или зонт", reason: "Идёт дождь"),
                .init(icon: "🥾", name: "Резиновые сапоги",  reason: "Мокрые дороги"),
            ]
        }
        return []
    }
}

// MARK: - Advisor

struct OutfitAdvisor {
    // OCP: добавить новое правило = написать новый тип + вставить сюда.
    // Существующие правила не затрагиваются.
    private static let rules: [any OutfitRule] = [
        InfantLayeringRule(),     // боди+конверт первыми в списке
        BaseTemperatureRule(),
        AgeExtrasRule(),
        NeckProtectionRule(),
        WindRule(),
        PrecipitationRule(),
    ]

    static func recommend(weather: WeatherData, profile: ChildProfile? = nil) -> [OutfitItem] {
        let offset   = profile?.ageGroup.temperatureOffset ?? 0
        let t        = weather.apparentTemperature + offset
        let ageGroup = profile?.ageGroup
        return rules.flatMap { $0.apply(effectiveTemp: t, weather: weather, ageGroup: ageGroup) }
    }
}
