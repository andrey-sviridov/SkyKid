import Foundation

// MARK: - Weather field quality

enum WeatherField: String, CaseIterable, Hashable, Sendable {
    case temperature
    case apparentTemperature
    case humidity
    case windSpeed
    case windGust
    case windDirection
    case precipitation
    case precipitationType
    case weatherCode
    case uvIndex
    case cloudCover
    case hourlyForecast

    var displayName: String {
        switch self {
        case .temperature:         return "температура"
        case .apparentTemperature: return "ощущаемая температура"
        case .humidity:            return "влажность"
        case .windSpeed:           return "ветер"
        case .windGust:            return "порывы ветра"
        case .windDirection:       return "направление ветра"
        case .precipitation:       return "количество осадков"
        case .precipitationType:   return "тип осадков"
        case .weatherCode:         return "условия погоды"
        case .uvIndex:             return "UV-индекс"
        case .cloudCover:          return "облачность"
        case .hourlyForecast:      return "почасовой прогноз"
        }
    }
}

enum WeatherFieldQuality: String, Equatable, Sendable {
    case observed
    case derived
    case estimated
    case unavailable

    var score: Double {
        switch self {
        case .observed:    return 1
        case .derived:     return 0.85
        case .estimated:   return 0.55
        case .unavailable: return 0
        }
    }

    var issuePriority: Int {
        switch self {
        case .unavailable: return 0
        case .estimated:   return 1
        case .derived:     return 2
        case .observed:    return 3
        }
    }
}

enum WeatherValueOrigin: String, Equatable, Sendable {
    case provider
    case derivedFromProvider
    case safetyFallback
}

struct WeatherFieldStatus: Equatable, Sendable {
    let field: WeatherField
    let source: WeatherSource
    let origin: WeatherValueOrigin
    let quality: WeatherFieldQuality
    let note: String?
}

// MARK: - Confidence

enum WeatherConfidenceLevel: String, Equatable, Sendable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high:   return "Высокая уверенность"
        case .medium: return "Средняя уверенность"
        case .low:    return "Низкая уверенность"
        }
    }
}

struct WeatherConfidence: Equatable, Sendable {
    let level: WeatherConfidenceLevel
    let score: Double
    let issues: [WeatherFieldStatus]

    var summary: String {
        guard !issues.isEmpty else {
            return "Все важные поля получены от погодного сервиса."
        }
        let names = issues.prefix(3).map { $0.field.displayName }
        return "Неполные данные: \(names.joined(separator: ", ")). Расчёт использует осторожные замены."
    }
}

// MARK: - NormalizedWeather

struct NormalizedWeather: Equatable, Sendable {
    let source: WeatherSource
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let windDirection: Int
    let precipitation: Double
    let weatherCode: Int
    let windGust: Double
    let uvIndex: Double
    let cloudCover: Double
    let precipType: PrecipType
    let hourly: [HourlyForecast]
    let fieldStatuses: [WeatherField: WeatherFieldStatus]

    var confidence: WeatherConfidence {
        WeatherConfidenceCalculator.calculate(statuses: fieldStatuses)
    }

    func status(for field: WeatherField) -> WeatherFieldStatus {
        fieldStatuses[field] ?? WeatherFieldStatus(
            field: field,
            source: source,
            origin: .safetyFallback,
            quality: .unavailable,
            note: "Нет метаданных"
        )
    }

    var windDirectionLabel: String {
        let directions = ["С", "ССВ", "СВ", "ВСВ", "В", "ВЮВ", "ЮВ", "ЮЮВ",
                          "Ю", "ЮЮЗ", "ЮЗ", "ЗЮЗ", "З", "ЗСЗ", "СЗ", "ССЗ"]
        let index = Int((Double(windDirection) / 22.5).rounded()) % 16
        return directions[index]
    }

    var conditionDescription: String {
        legacyData.conditionDescription
    }

    var conditionIcon: String {
        legacyData.conditionIcon
    }

    var legacyData: WeatherData {
        WeatherData(
            temperature: temperature,
            apparentTemperature: apparentTemperature,
            humidity: humidity,
            windSpeed: windSpeed,
            windDirection: windDirection,
            precipitation: precipitation,
            weatherCode: weatherCode,
            windGust: windGust,
            uvIndex: uvIndex,
            cloudCover: cloudCover,
            precipType: precipType,
            hourly: hourly
        )
    }
}

// MARK: - Manual / test input

extension NormalizedWeather {
    init(
        temperature: Double,
        apparentTemperature: Double,
        humidity: Int,
        windSpeed: Double,
        windDirection: Int,
        precipitation: Double,
        weatherCode: Int,
        windGust: Double = 0,
        uvIndex: Double = 0,
        cloudCover: Double = 50,
        precipType: PrecipType? = nil,
        hourly: [HourlyForecast] = []
    ) {
        let normalizedGust = windGust > 0 ? windGust : windSpeed
        var statuses = Dictionary(uniqueKeysWithValues: WeatherField.allCases.map { field in
            (field, WeatherFieldStatus(
                field: field,
                source: .manual,
                origin: .provider,
                quality: .observed,
                note: nil
            ))
        })
        if windGust <= 0, windSpeed > 0 {
            statuses[.windGust] = WeatherFieldStatus(
                field: .windGust,
                source: .manual,
                origin: .derivedFromProvider,
                quality: .derived,
                note: "Порыв приравнен к устойчивому ветру"
            )
        }
        self.init(
            source: .manual,
            temperature: temperature,
            apparentTemperature: apparentTemperature,
            humidity: humidity,
            windSpeed: windSpeed,
            windDirection: windDirection,
            precipitation: precipitation,
            weatherCode: weatherCode,
            windGust: normalizedGust,
            uvIndex: uvIndex,
            cloudCover: cloudCover,
            precipType: precipType ?? PrecipType(wmoCode: weatherCode),
            hourly: hourly,
            fieldStatuses: statuses
        )
    }
}

// MARK: - Preview mocks

#if DEBUG
extension NormalizedWeather {
    static var mock: NormalizedWeather {
        NormalizedWeather(temperature: 18, apparentTemperature: 16,
                          humidity: 62, windSpeed: 4.5, windDirection: 270,
                          precipitation: 0, weatherCode: 2)
    }

    static var mockRainy: NormalizedWeather {
        NormalizedWeather(temperature: 12, apparentTemperature: 9,
                          humidity: 88, windSpeed: 6, windDirection: 180,
                          precipitation: 2.5, weatherCode: 61)
    }

    static var mockWinter: NormalizedWeather {
        NormalizedWeather(temperature: -8, apparentTemperature: -12,
                          humidity: 75, windSpeed: 5, windDirection: 0,
                          precipitation: 0.5, weatherCode: 73)
    }
}
#endif

// MARK: - Confidence calculation

private enum WeatherConfidenceCalculator {
    private static let weights: [WeatherField: Double] = [
        .temperature: 3,
        .apparentTemperature: 2,
        .humidity: 1.5,
        .windSpeed: 2.5,
        .windGust: 1,
        .windDirection: 0.25,
        .precipitation: 1.5,
        .precipitationType: 1,
        .weatherCode: 1.5,
        .uvIndex: 1,
        .cloudCover: 0.75,
        .hourlyForecast: 0.5,
    ]

    static func calculate(statuses: [WeatherField: WeatherFieldStatus]) -> WeatherConfidence {
        let totalWeight = weights.values.reduce(0, +)
        let earned = weights.reduce(0.0) { partial, entry in
            partial + entry.value * (statuses[entry.key]?.quality.score ?? 0)
        }
        let score = totalWeight > 0 ? earned / totalWeight : 0
        let uvUnavailable = statuses[.uvIndex]?.quality == .unavailable
        let level: WeatherConfidenceLevel
        if score >= 0.9, !uvUnavailable {
            level = .high
        } else if score >= 0.72 {
            level = .medium
        } else {
            level = .low
        }
        let issues = WeatherField.allCases
            .compactMap { field -> WeatherFieldStatus? in
                guard let status = statuses[field], status.quality != .observed else { return nil }
                return status
            }
            .sorted { $0.quality.issuePriority < $1.quality.issuePriority }
        return WeatherConfidence(level: level, score: score, issues: issues)
    }
}
