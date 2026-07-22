import Foundation
import CoreLocation

// DIP: конформанс к WeatherService позволяет подменять реализацию в ViewModel.

struct OpenMeteoService: WeatherService {
    private static let base = "https://api.open-meteo.com/v1/forecast"

    func fetch(coordinate: CLLocationCoordinate2D) async throws -> NormalizedWeather {
        var components = URLComponents(string: Self.base)!
        components.queryItems = [
            .init(name: "latitude",        value: String(coordinate.latitude)),
            .init(name: "longitude",       value: String(coordinate.longitude)),
            .init(name: "current",         value: [
                "temperature_2m", "apparent_temperature",
                "relative_humidity_2m", "wind_speed_10m",
                "wind_direction_10m", "weather_code", "precipitation",
                "wind_gusts_10m", "cloud_cover"
            ].joined(separator: ",")),
            .init(name: "hourly",          value: [
                "temperature_2m", "apparent_temperature", "precipitation_probability",
                "weather_code", "uv_index"
            ].joined(separator: ",")),
            .init(name: "forecast_days",   value: "2"),
            // unixtime: hourly.time приходит числом UTC — не парсим локальный ISO
            .init(name: "timeformat",      value: "unixtime"),
            .init(name: "wind_speed_unit", value: "ms"),
            .init(name: "timezone",        value: "auto"),
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let root = try JSONDecoder().decode(OMRoot.self, from: data)
        let c = root.current
        let hourly = Self.hourlyForecasts(from: root.hourly)
        let currentUV = Self.currentUV(from: root.hourly, currentTime: c.time)
        let hourlyIsComplete = Self.hourlyIsComplete(root.hourly)

        var overrides: [WeatherField: WeatherFieldQuality] = [:]
        var notes: [WeatherField: String] = [:]
        if currentUV != nil {
            overrides[.uvIndex] = .derived
            notes[.uvIndex] = "Взят из ближайшего почасового значения Open-Meteo"
        }
        if !hourly.isEmpty, !hourlyIsComplete {
            overrides[.hourlyForecast] = .estimated
            notes[.hourlyForecast] = "Неполные точки прогноза исключены"
        }

        return try WeatherNormalizer.normalize(RawWeatherObservation(
            source: .openMeteo,
            temperature: c.temperature_2m,
            apparentTemperature: c.apparent_temperature,
            humidity: c.relative_humidity_2m,
            windSpeed: c.wind_speed_10m,
            windDirection: c.wind_direction_10m,
            precipitation: c.precipitation,
            weatherCode: c.weather_code,
            windGust: c.wind_gusts_10m,
            uvIndex: currentUV,
            cloudCover: c.cloud_cover.map(Double.init),
            hourly: hourly,
            qualityOverrides: overrides,
            notes: notes
        ))
    }

    private static func hourlyForecasts(from h: OMHourly?) -> [HourlyForecast] {
        guard let h else { return [] }
        return h.time.indices.compactMap { (i: Int) -> HourlyForecast? in
            guard let t = h.temperature_2m[safe: i] ?? nil,
                  let at = h.apparent_temperature[safe: i] ?? nil else { return nil }
            return HourlyForecast(
                time: Date(timeIntervalSince1970: TimeInterval(h.time[i])),
                temperature: t,
                apparentTemperature: at,
                precipProbability: h.precipitation_probability?[safe: i].flatMap { $0 } ?? 100,
                weatherCode: h.weather_code?[safe: i].flatMap { $0 } ?? -1
            )
        }
    }

    private static func currentUV(from hourly: OMHourly?, currentTime: Int?) -> Double? {
        guard let hourly, let values = hourly.uv_index, !hourly.time.isEmpty else { return nil }
        let target = currentTime ?? Int(Date().timeIntervalSince1970)
        guard let index = hourly.time.indices.min(by: {
            abs(hourly.time[$0] - target) < abs(hourly.time[$1] - target)
        }) else { return nil }
        return values[safe: index].flatMap { $0 }
    }

    private static func hourlyIsComplete(_ hourly: OMHourly?) -> Bool {
        guard let hourly,
              hourly.precipitation_probability != nil,
              hourly.weather_code != nil else { return false }
        return hourly.time.count == hourly.temperature_2m.count
            && hourly.time.count == hourly.apparent_temperature.count
    }
}

// Безопасный доступ к элементу массива из API: индексы строк могут расходиться
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Response models

private struct OMRoot: Decodable {
    let current: OMCurrent
    let hourly: OMHourly?
}

private struct OMHourly: Decodable {
    let time: [Int]                              // unixtime UTC
    let temperature_2m: [Double?]
    let apparent_temperature: [Double?]
    let precipitation_probability: [Double?]?
    let weather_code: [Int?]?
    let uv_index: [Double?]?
}

private struct OMCurrent: Decodable {
    let time: Int?
    let temperature_2m: Double?
    let apparent_temperature: Double?
    let relative_humidity_2m: Int?
    let wind_speed_10m: Double?
    let wind_direction_10m: Int?
    let precipitation: Double?
    let weather_code: Int?
    let wind_gusts_10m: Double?
    let cloud_cover: Int?
}
