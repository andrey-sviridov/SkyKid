import Foundation
import CoreLocation

struct YandexWeatherService: WeatherService {
    let apiKey: String
    private static let base = "https://api.weather.yandex.ru/v2/forecast"

    func fetch(coordinate: CLLocationCoordinate2D) async throws -> WeatherData {
        var components = URLComponents(string: Self.base)!
        components.queryItems = [
            .init(name: "lat",   value: String(coordinate.latitude)),
            .init(name: "lon",   value: String(coordinate.longitude)),
            .init(name: "limit", value: "1"),
            .init(name: "lang",  value: "ru_RU"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "X-Yandex-API-Key")

        let (data, _) = try await URLSession.shared.data(for: request)
        let root = try JSONDecoder().decode(YandexRoot.self, from: data)
        let fact = root.fact

        return WeatherData(
            temperature:         Double(fact.temp),
            apparentTemperature: Double(fact.feels_like),
            humidity:            fact.humidity,
            windSpeed:           fact.wind_speed,
            windDirection:       windDirDegrees(fact.wind_dir),
            precipitation:       fact.prec_mm ?? 0,
            weatherCode:         wmoCode(fact.condition)
        )
    }

    // MARK: - Helpers

    private func windDirDegrees(_ dir: String) -> Int {
        switch dir {
        case "n":   return 0
        case "ne":  return 45
        case "e":   return 90
        case "se":  return 135
        case "s":   return 180
        case "sw":  return 225
        case "w":   return 270
        case "nw":  return 315
        default:    return 0
        }
    }

    private func wmoCode(_ condition: String) -> Int {
        switch condition {
        case "clear":                    return 0
        case "partly-cloudy":            return 1
        case "cloudy":                   return 2
        case "overcast":                 return 3
        case "drizzle":                  return 51
        case "light-rain":               return 61
        case "rain", "moderate-rain":    return 63
        case "heavy-rain",
             "continuous-heavy-rain":    return 65
        case "showers":                  return 80
        case "wet-snow", "hail":         return 77
        case "light-snow":               return 71
        case "snow":                     return 73
        case "snow-showers":             return 85
        case "thunderstorm",
             "thunderstorm-with-rain":   return 95
        case "thunderstorm-with-hail":   return 99
        default:                         return 3
        }
    }
}

// MARK: - Response models

private struct YandexRoot: Decodable {
    let fact: YandexFact
}

private struct YandexFact: Decodable {
    let temp:       Int
    let feels_like: Int
    let humidity:   Int
    let wind_speed: Double
    let wind_dir:   String
    let condition:  String
    let prec_mm:    Double?
}
