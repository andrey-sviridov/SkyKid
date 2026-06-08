import Foundation
import CoreLocation

struct OpenWeatherMapService: WeatherService {
    let apiKey: String
    private static let base = "https://api.openweathermap.org/data/2.5/weather"

    func fetch(coordinate: CLLocationCoordinate2D) async throws -> WeatherData {
        var components = URLComponents(string: Self.base)!
        components.queryItems = [
            .init(name: "lat",   value: String(coordinate.latitude)),
            .init(name: "lon",   value: String(coordinate.longitude)),
            .init(name: "appid", value: apiKey),
            .init(name: "units", value: "metric"),
            .init(name: "lang",  value: "ru"),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let root = try JSONDecoder().decode(OWMRoot.self, from: data)
        return WeatherData(
            temperature:         root.main.temp,
            apparentTemperature: root.main.feels_like,
            humidity:            root.main.humidity,
            windSpeed:           root.wind.speed,
            windDirection:       root.wind.deg ?? 0,
            precipitation:       root.rain?.oneHour ?? 0,
            weatherCode:         mapCode(root.weather.first?.id ?? 800)
        )
    }

    private func mapCode(_ id: Int) -> Int {
        switch id {
        case 200...232: return 95
        case 300...321: return 51
        case 500:       return 61
        case 501:       return 63
        case 502...504: return 65
        case 511:       return 77
        case 520, 521:  return 80
        case 522, 531:  return 82
        case 600, 601:  return 71
        case 602:       return 75
        case 611...616: return 77
        case 620...622: return 73
        case 701...762: return 45
        case 771, 781:  return 95
        case 800:       return 0
        case 801:       return 1
        case 802:       return 2
        case 803, 804:  return 3
        default:        return 3
        }
    }
}

private struct OWMRoot: Decodable {
    let main:    OWMMain
    let wind:    OWMWind
    let weather: [OWMWeather]
    let rain:    OWMRain?
}

private struct OWMMain: Decodable {
    let temp: Double
    let feels_like: Double
    let humidity: Int
}

private struct OWMWind: Decodable {
    let speed: Double
    let deg: Int?
}

private struct OWMWeather: Decodable {
    let id: Int
}

private struct OWMRain: Decodable {
    let oneHour: Double?
    enum CodingKeys: String, CodingKey { case oneHour = "1h" }
}
