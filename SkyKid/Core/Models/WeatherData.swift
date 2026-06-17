import Foundation

// MARK: - PrecipType §2.4

enum PrecipType: String, Equatable, Sendable {
    case none
    case drizzle
    case lightRain
    case rain
    case snow

    // Все провайдеры приводят свои условия к WMO-кодам, поэтому
    // тип осадков выводится из weatherCode единообразно.
    init(wmoCode: Int) {
        switch wmoCode {
        case 51, 53, 55, 56, 57:             self = .drizzle
        case 61, 80:                         self = .lightRain
        case 63, 65, 66, 67, 81, 82,
             95, 96, 99:                     self = .rain
        case 71, 73, 75, 77, 85, 86:         self = .snow
        default:                             self = .none
        }
    }
}

// MARK: - HourlyForecast (P1-3: walkWindow §6.1)

struct HourlyForecast: Equatable, Sendable {
    let time: Date
    let temperature: Double
    let apparentTemperature: Double
    let precipProbability: Double  // 0–100 %
}

struct WeatherData: Equatable {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double        // m/s
    let windDirection: Int
    let precipitation: Double
    let weatherCode: Int
    // New fields (§2): default values preserve backward compat at all call sites
    let windGust: Double         // m/s; default 0.0
    let uvIndex: Double          // 0–11+; default 0.0
    let cloudCover: Double       // 0–100 %; default 50.0
    let precipType: PrecipType   // default .none
    // Почасовой прогноз (P1-3): пустой у провайдеров без hourly — walkWindow тогда nil
    var hourly: [HourlyForecast] = []

    var windDirectionLabel: String {
        let directions = ["С", "ССВ", "СВ", "ВСВ", "В", "ВЮВ", "ЮВ", "ЮЮВ",
                          "Ю", "ЮЮЗ", "ЮЗ", "ЗЮЗ", "З", "ЗСЗ", "СЗ", "ССЗ"]
        let index = Int((Double(windDirection) / 22.5).rounded()) % 16
        return directions[index]
    }

    var conditionDescription: String {
        switch weatherCode {
        case 0: return "Ясно"
        case 1, 2, 3: return "Облачно"
        case 45, 48: return "Туман"
        case 51, 53, 55: return "Морось"
        case 61, 63, 65: return "Дождь"
        case 71, 73, 75, 77: return "Снег"
        case 80, 81, 82: return "Ливень"
        case 95, 96, 99: return "Гроза"
        default: return "—"
        }
    }

    var conditionIcon: String {
        switch weatherCode {
        case 0: return "sun.max.fill"
        case 1: return "cloud.sun.fill"
        case 2: return "cloud.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75, 77: return "snowflake"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Backward-compatible init (existing call sites pass 7 params)

extension WeatherData {
    init(
        temperature: Double,
        apparentTemperature: Double,
        humidity: Int,
        windSpeed: Double,
        windDirection: Int,
        precipitation: Double,
        weatherCode: Int
    ) {
        self.init(
            temperature: temperature,
            apparentTemperature: apparentTemperature,
            humidity: humidity,
            windSpeed: windSpeed,
            windDirection: windDirection,
            precipitation: precipitation,
            weatherCode: weatherCode,
            windGust: 0.0,
            uvIndex: 0.0,
            cloudCover: 50.0,
            precipType: PrecipType(wmoCode: weatherCode)
        )
    }
}

// MARK: - Preview mocks

#if DEBUG
extension WeatherData {
    static var mock: WeatherData {
        WeatherData(temperature: 18, apparentTemperature: 16,
                    humidity: 62, windSpeed: 4.5, windDirection: 270,
                    precipitation: 0, weatherCode: 2)
    }
    static var mockRainy: WeatherData {
        WeatherData(temperature: 12, apparentTemperature: 9,
                    humidity: 88, windSpeed: 6.0, windDirection: 180,
                    precipitation: 2.5, weatherCode: 61)
    }
    static var mockWinter: WeatherData {
        WeatherData(temperature: -8, apparentTemperature: -12,
                    humidity: 75, windSpeed: 5.0, windDirection: 0,
                    precipitation: 0.5, weatherCode: 73)
    }
}
#endif

struct RadarFrame: Identifiable {
    let id   = UUID()
    let time: Date
    let path: String
    let host: String  // из API-ответа, не хардкодить
}
