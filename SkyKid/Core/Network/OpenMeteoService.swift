import Foundation
import CoreLocation

struct OpenMeteoService {
    private static let base = "https://api.open-meteo.com/v1/forecast"

    static func fetch(coordinate: CLLocationCoordinate2D) async throws -> WeatherData {
        var components = URLComponents(string: base)!
        components.queryItems = [
            .init(name: "latitude", value: String(coordinate.latitude)),
            .init(name: "longitude", value: String(coordinate.longitude)),
            .init(name: "current", value: [
                "temperature_2m", "apparent_temperature",
                "relative_humidity_2m", "wind_speed_10m",
                "wind_direction_10m", "weather_code", "precipitation"
            ].joined(separator: ",")),
            .init(name: "wind_speed_unit", value: "ms"),
            .init(name: "timezone", value: "auto")
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let root = try JSONDecoder().decode(OMRoot.self, from: data)
        let c = root.current

        return WeatherData(
            temperature: c.temperature_2m,
            apparentTemperature: c.apparent_temperature,
            humidity: c.relative_humidity_2m,
            windSpeed: c.wind_speed_10m,
            windDirection: c.wind_direction_10m,
            precipitation: c.precipitation,
            weatherCode: c.weather_code
        )
    }
}

// MARK: - Response models

private struct OMRoot: Decodable {
    let current: OMCurrent
}

private struct OMCurrent: Decodable {
    let temperature_2m: Double
    let apparent_temperature: Double
    let relative_humidity_2m: Int
    let wind_speed_10m: Double
    let wind_direction_10m: Int
    let precipitation: Double
    let weather_code: Int
}
