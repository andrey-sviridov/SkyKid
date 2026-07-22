import Foundation

// MARK: - WeatherSource

enum WeatherSource: String, CaseIterable, Equatable, Sendable {
    case openMeteo
    case weatherKit
    case openWeatherMap
    case weatherAPI
    case yandex
    case manual

    var displayName: String {
        switch self {
        case .openMeteo:      return "Open-Meteo"
        case .weatherKit:     return "Apple WeatherKit"
        case .openWeatherMap: return "OpenWeatherMap"
        case .weatherAPI:     return "WeatherAPI.com"
        case .yandex:         return "Яндекс Погода"
        case .manual:         return "Тестовые данные"
        }
    }

    var systemImage: String {
        switch self {
        case .openMeteo:      return "globe"
        case .weatherKit:     return "apple.logo"
        case .openWeatherMap: return "cloud.sun.fill"
        case .weatherAPI:     return "antenna.radiowaves.left.and.right"
        case .yandex:         return "y.circle.fill"
        case .manual:         return "hammer.fill"
        }
    }
}

// MARK: - RawWeatherObservation

/// Provider-facing transport model. Optional values preserve the distinction
/// between a real zero and a field that the provider did not return.
struct RawWeatherObservation: Equatable, Sendable {
    let source: WeatherSource
    let temperature: Double?
    let apparentTemperature: Double?
    let humidity: Int?
    let windSpeed: Double?
    let windDirection: Int?
    let precipitation: Double?
    let weatherCode: Int?
    let windGust: Double?
    let uvIndex: Double?
    let cloudCover: Double?
    let hourly: [HourlyForecast]
    let qualityOverrides: [WeatherField: WeatherFieldQuality]
    let notes: [WeatherField: String]

    init(
        source: WeatherSource,
        temperature: Double?,
        apparentTemperature: Double? = nil,
        humidity: Int? = nil,
        windSpeed: Double? = nil,
        windDirection: Int? = nil,
        precipitation: Double? = nil,
        weatherCode: Int? = nil,
        windGust: Double? = nil,
        uvIndex: Double? = nil,
        cloudCover: Double? = nil,
        hourly: [HourlyForecast] = [],
        qualityOverrides: [WeatherField: WeatherFieldQuality] = [:],
        notes: [WeatherField: String] = [:]
    ) {
        self.source = source
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.precipitation = precipitation
        self.weatherCode = weatherCode
        self.windGust = windGust
        self.uvIndex = uvIndex
        self.cloudCover = cloudCover
        self.hourly = hourly
        self.qualityOverrides = qualityOverrides
        self.notes = notes
    }
}
