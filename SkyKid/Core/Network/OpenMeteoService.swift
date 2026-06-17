import Foundation
import CoreLocation

// DIP: конформанс к WeatherService позволяет подменять реализацию в ViewModel.

struct OpenMeteoService: WeatherService {
    private static let base = "https://api.open-meteo.com/v1/forecast"

    func fetch(coordinate: CLLocationCoordinate2D) async throws -> WeatherData {
        var components = URLComponents(string: Self.base)!
        components.queryItems = [
            .init(name: "latitude",        value: String(coordinate.latitude)),
            .init(name: "longitude",       value: String(coordinate.longitude)),
            .init(name: "current",         value: [
                "temperature_2m", "apparent_temperature",
                "relative_humidity_2m", "wind_speed_10m",
                "wind_direction_10m", "weather_code", "precipitation",
                "wind_gusts_10m", "uv_index", "cloud_cover"
            ].joined(separator: ",")),
            .init(name: "hourly",          value: [
                "temperature_2m", "apparent_temperature", "precipitation_probability"
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

        return WeatherData(
            temperature:         c.temperature_2m,
            apparentTemperature: c.apparent_temperature,
            humidity:            c.relative_humidity_2m,
            windSpeed:           c.wind_speed_10m,
            windDirection:       c.wind_direction_10m,
            precipitation:       c.precipitation,
            weatherCode:         c.weather_code,
            windGust:            c.wind_gusts_10m ?? 0.0,
            uvIndex:             c.uv_index ?? 0.0,
            cloudCover:          c.cloud_cover.map(Double.init) ?? 50.0,
            precipType:          PrecipType(wmoCode: c.weather_code),
            hourly:              hourly
        )
    }

    private static func hourlyForecasts(from h: OMHourly?) -> [HourlyForecast] {
        guard let h else { return [] }
        return h.time.indices.compactMap { i in
            guard let t = h.temperature_2m[safe: i] ?? nil,
                  let at = h.apparent_temperature[safe: i] ?? nil else { return nil }
            return HourlyForecast(
                time: Date(timeIntervalSince1970: TimeInterval(h.time[i])),
                temperature: t,
                apparentTemperature: at,
                precipProbability: h.precipitation_probability?[safe: i].flatMap { $0 } ?? 0
            )
        }
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
}

private struct OMCurrent: Decodable {
    let temperature_2m: Double
    let apparent_temperature: Double
    let relative_humidity_2m: Int
    let wind_speed_10m: Double
    let wind_direction_10m: Int
    let precipitation: Double
    let weather_code: Int
    let wind_gusts_10m: Double?
    let uv_index: Double?
    let cloud_cover: Int?
}
