import SwiftUI

// MARK: - Статус теплового комфорта (виджет-версия)

enum ClothingWidgetStatus: String, Codable, CaseIterable, Sendable {
    case extremeHeat    // ≥ 30 °C эффективная температура для ребёнка
    case hot            // 22–30 °C
    case warm           // 18–22 °C
    case ideal          // 8–18 °C
    case slightlyCold   // 0–8 °C
    case cold           // −10…0 °C
    case extremeCold    // ≤ −10 °C

    var label: String {
        switch self {
        case .extremeHeat:  return "ОПАСНО: ПЕРЕГРЕВ"
        case .hot:          return "Жарко"
        case .warm:         return "Тепловато"
        case .ideal:        return "Идеально"
        case .slightlyCold: return "Прохладно"
        case .cold:         return "Холодно"
        case .extremeCold:  return "ОПАСНО: МОРОЗ"
        }
    }

    var color: Color {
        switch self {
        case .extremeHeat:  return Color.red
        case .hot:          return Color.orange
        case .warm:         return Color(red: 0.95, green: 0.78, blue: 0.0)
        case .ideal:        return Color.green
        case .slightlyCold: return Color(red: 0.3,  green: 0.65, blue: 1.0)
        case .cold:         return Color.blue
        case .extremeCold:  return Color(red: 0.0,  green: 0.1,  blue: 0.75)
        }
    }

    var systemImage: String {
        switch self {
        case .extremeHeat:  return "exclamationmark.triangle.fill"
        case .hot:          return "sun.max.fill"
        case .warm:         return "thermometer.medium"
        case .ideal:        return "checkmark.seal.fill"
        case .slightlyCold: return "cloud.fill"
        case .cold:         return "snowflake"
        case .extremeCold:  return "snowflake.circle.fill"
        }
    }

    var emoji: String {
        switch self {
        case .extremeHeat:  return "🔥"
        case .hot:          return "☀️"
        case .warm:         return "😅"
        case .ideal:        return "😊"
        case .slightlyCold: return "😐"
        case .cold:         return "🥶"
        case .extremeCold:  return "❄️"
        }
    }

    /// Предупреждение безопасности — только для крайних состояний.
    var safetyWarning: String? {
        switch self {
        case .extremeHeat: return "Не выходить в пиковые часы"
        case .extremeCold: return "Прогулка: 15-20 мин максимум"
        default:           return nil
        }
    }
}

// MARK: - Рекомендация для виджета

struct WidgetOutfitRecommendation: Sendable {
    let temperature: Double          // реальная температура
    let apparentTemperature: Double  // ощущаемая
    let effectiveChildTemp: Double   // ощущаемая с поправкой на возраст
    let cityName: String
    let status: ClothingWidgetStatus
    let outfitItems: [String]        // упорядоченный список (от важного к менее важному)
    let ageLabel: String             // «3 года» / «8 месяцев»
    let updatedAt: Date

    /// Три главных элемента одежды одной строкой: «Куртка · Шапка · Перчатки»
    var topItemsSummary: String {
        outfitItems.prefix(3).joined(separator: " · ")
    }
}

// MARK: - Вычислитель рекомендаций виджета

struct WidgetClothingCalculator {

    // MARK: Определение статуса по эффективной температуре ребёнка

    static func status(for effectiveTemp: Double) -> ClothingWidgetStatus {
        switch effectiveTemp {
        case 30...:    return .extremeHeat
        case 22..<30:  return .hot
        case 18..<22:  return .warm
        case 8..<18:   return .ideal
        case 0..<8:    return .slightlyCold
        case -10..<0:  return .cold
        default:       return .extremeCold   // ≤ −10
        }
    }

    // MARK: Список рекомендованных вещей

    static func outfitItems(
        effectiveTemp t: Double,
        weatherCode: Int,
        windSpeed: Double,
        precipitation: Double
    ) -> [String] {
        let isSnowing = (71...77).contains(weatherCode)
        let isRaining = (51...82).contains(weatherCode) || precipitation > 0.1
        let isWindy   = windSpeed > 7

        var items: [String]
        switch t {
        case ..<(-10): items = ["Зимний комбез", "Термобельё", "Варежки", "Зимняя шапка"]
        case -10..<0:  items = ["Зимняя куртка", "Перчатки", "Шапка"]
        case 0..<5:    items = ["Тёплая куртка", "Перчатки", "Шапка"]
        case 5..<15:   items = ["Куртка", "Кофта"]
        case 15..<22:  items = ["Лёгкая куртка", "Футболка"]
        default:       items = ["Лёгкая одежда", "Панамка"]
        }

        if isWindy              { items.insert("Ветровка", at: min(1, items.count)) }
        if isSnowing            { items.append("Зимние сапоги") }
        else if isRaining       { items.append("Дождевик") }

        return items
    }

    // MARK: Главный метод: из кеша + профиля → готовая рекомендация
    // Реплицирует ClothingRecommendationEngine.effectiveTemperature — те же 8 компонент.

    static func recommend(
        weather: CachedWeather,
        profile: ChildProfile?
    ) -> WidgetOutfitRecommendation {
        var effectiveTemp = weather.apparentTemperature
        if let p = profile {
            effectiveTemp += p.ageGroup.temperatureOffset
            effectiveTemp += p.activityLevel.temperatureAdjustment
            effectiveTemp += p.walkType.temperatureAdjustment
            effectiveTemp += p.healthTemperatureAdjustment
            effectiveTemp += p.temperaturePreferenceOffset
            if p.usesStroller {
                effectiveTemp += p.strollerType.effectiveTempAdjustment
            }
            if p.isNewbornPeriod {
                effectiveTemp -= 1.0
            }
        }
        let items = outfitItems(
            effectiveTemp: effectiveTemp,
            weatherCode:   weather.weatherCode,
            windSpeed:     weather.windSpeed,
            precipitation: weather.precipitation
        )
        return WidgetOutfitRecommendation(
            temperature:          weather.temperature,
            apparentTemperature:  weather.apparentTemperature,
            effectiveChildTemp:   effectiveTemp,
            cityName:             weather.cityName,
            status:               status(for: effectiveTemp),
            outfitItems:          items,
            ageLabel:             profile?.ageLabel ?? "малыша",
            updatedAt:            weather.updatedAt
        )
    }

    // MARK: Заглушка — когда данных ещё нет

    static var placeholder: WidgetOutfitRecommendation {
        WidgetOutfitRecommendation(
            temperature:         12.0,
            apparentTemperature: 10.0,
            effectiveChildTemp:  7.0,
            cityName:            "—",
            status:              .slightlyCold,
            outfitItems:         ["Куртка", "Кофта", "Шапка"],
            ageLabel:            "малыша",
            updatedAt:           Date()
        )
    }
}
