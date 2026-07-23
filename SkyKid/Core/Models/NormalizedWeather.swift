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
        case .temperature:         return L10n.text("температура")
        case .apparentTemperature: return L10n.text("ощущаемая температура")
        case .humidity:            return L10n.text("влажность")
        case .windSpeed:           return L10n.text("ветер")
        case .windGust:            return L10n.text("порывы ветра")
        case .windDirection:       return L10n.text("направление ветра")
        case .precipitation:       return L10n.text("количество осадков")
        case .precipitationType:   return L10n.text("тип осадков")
        case .weatherCode:         return L10n.text("условия погоды")
        case .uvIndex:             return L10n.text("UV-индекс")
        case .cloudCover:          return L10n.text("облачность")
        case .hourlyForecast:      return L10n.text("почасовой прогноз")
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
        case .high:   return L10n.text("Высокая уверенность")
        case .medium: return L10n.text("Средняя уверенность")
        case .low:    return L10n.text("Низкая уверенность")
        }
    }
}

struct WeatherConfidence: Equatable, Sendable {
    let level: WeatherConfidenceLevel
    let score: Double
    let issues: [WeatherFieldStatus]

    var summary: String {
        guard !issues.isEmpty else {
            return L10n.text("Все важные поля получены от погодного сервиса.")
        }
        let names = issues.prefix(3).map { $0.field.displayName }
        return L10n.format(
            "Неполные данные: %@. Расчёт использует осторожные замены.",
            names.joined(separator: ", ")
        )
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
            note: L10n.text("Нет метаданных")
        )
    }

    var windDirectionLabel: String {
        let directions = L10n.text("С,ССВ,СВ,ВСВ,В,ВЮВ,ЮВ,ЮЮВ,Ю,ЮЮЗ,ЮЗ,ЗЮЗ,З,ЗСЗ,СЗ,ССЗ")
            .split(separator: ",")
            .map(String.init)
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
                note: L10n.text("Порыв приравнен к устойчивому ветру")
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
