import Foundation

struct WeatherData: Equatable {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let windDirection: Int
    let precipitation: Double
    let weatherCode: Int

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

struct RadarFrame: Identifiable {
    let id   = UUID()
    let time: Date
    let path: String
    let host: String  // из API-ответа, не хардкодить
}
