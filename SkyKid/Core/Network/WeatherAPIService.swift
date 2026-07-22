import Foundation
import CoreLocation

// WeatherAPI.com — https://www.weatherapi.com/docs/
// Free tier: 1 000 000 calls/month, no credit card required.
// Get key at: https://www.weatherapi.com/signup.aspx

struct WeatherAPIService: WeatherService {
    let apiKey: String
    private static let base = "https://api.weatherapi.com/v1/current.json"

    func fetch(coordinate: CLLocationCoordinate2D) async throws -> NormalizedWeather {
        var comps = URLComponents(string: Self.base)!
        comps.queryItems = [
            .init(name: "key",  value: apiKey),
            .init(name: "q",    value: "\(coordinate.latitude),\(coordinate.longitude)"),
            .init(name: "lang", value: "ru"),
            .init(name: "aqi",  value: "no"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let root = try JSONDecoder().decode(WAPIRoot.self, from: data)
        let c = root.current
        return try WeatherNormalizer.normalize(RawWeatherObservation(
            source: .weatherAPI,
            temperature: c.temp_c,
            apparentTemperature: c.feelslike_c,
            humidity: c.humidity,
            windSpeed: c.wind_kph.map { $0 / 3.6 },
            windDirection: c.wind_degree,
            precipitation: c.precip_mm,
            weatherCode: c.condition.map { Self.mapCode($0.code) },
            windGust: c.gust_kph.map { $0 / 3.6 },
            uvIndex: c.uv,
            cloudCover: c.cloud.map(Double.init)
        ))
    }

    // MARK: - Condition code → WMO code
    // WeatherAPI condition codes: https://www.weatherapi.com/docs/conditions.json

    private static func mapCode(_ code: Int) -> Int {
        switch code {
        case 1000:             return 0   // Sunny / Clear
        case 1003:             return 1   // Partly cloudy
        case 1006:             return 2   // Cloudy
        case 1009:             return 3   // Overcast
        case 1030, 1135, 1147: return 45  // Mist / Fog
        case 1063, 1150, 1153: return 51  // Patchy / light drizzle
        case 1180, 1183:       return 61  // Patchy / light rain
        case 1186, 1189:       return 63  // Moderate rain
        case 1192, 1195:       return 65  // Heavy rain
        case 1198, 1201:       return 67  // Freezing rain
        case 1072, 1168, 1171: return 56  // Freezing drizzle
        case 1066, 1210, 1213: return 71  // Light snow
        case 1114, 1216, 1219: return 73  // Moderate snow
        case 1117, 1222, 1225: return 75  // Heavy snow
        case 1069, 1204, 1207, 1249, 1252: return 77  // Sleet / ice pellets
        case 1237, 1261, 1264: return 77  // Hail
        case 1240, 1243:       return 80  // Light / moderate showers
        case 1246:             return 82  // Heavy showers
        case 1255, 1258:       return 85  // Light / moderate snow showers
        case 1087, 1273, 1276, 1279, 1282: return 95  // Thunder
        default:               return 3
        }
    }
}

// MARK: - Response models

private struct WAPIRoot: Decodable { let current: WAPICurrent }

private struct WAPICurrent: Decodable {
    let temp_c:      Double?
    let feelslike_c: Double?
    let humidity:    Int?
    let wind_kph:    Double?
    let wind_degree: Int?
    let precip_mm:   Double?
    let gust_kph:    Double?
    let uv:          Double?
    let cloud:       Int?
    let condition:   WAPICondition?
}

private struct WAPICondition: Decodable { let code: Int }
