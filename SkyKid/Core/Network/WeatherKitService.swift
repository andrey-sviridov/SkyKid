import Foundation
import CoreLocation

// WeatherKit временно отключён — требует активного entitlement в Apple Developer Portal.
// Чтобы включить:
//   1. developer.apple.com → App ID «com.skykid.app» → WeatherKit ✓
//   2. Xcode → SkyKid target → Signing & Capabilities → + WeatherKit
//   3. Раскомментировать import WeatherKit и тело fetch() ниже.

struct WeatherKitService: WeatherService {
    func fetch(coordinate: CLLocationCoordinate2D) async throws -> WeatherData {
        // Fallback на Open-Meteo пока WeatherKit не активирован в Dev Portal
        return try await OpenMeteoService().fetch(coordinate: coordinate)
    }
}

/*
import WeatherKit

struct WeatherKitService: WeatherService {

    func fetch(coordinate: CLLocationCoordinate2D) async throws -> WeatherData {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let current = try await WeatherKit.WeatherService.shared
            .weather(for: location, including: .current)

        return WeatherData(
            temperature:         current.temperature.converted(to: .celsius).value,
            apparentTemperature: current.apparentTemperature.converted(to: .celsius).value,
            humidity:            Int((current.humidity * 100).rounded()),
            windSpeed:           current.wind.speed.converted(to: .metersPerSecond).value,
            windDirection:       Int(current.wind.direction.value),
            precipitation:       current.precipitationIntensity.converted(to: .metersPerSecond).value * 3_600_000,
            weatherCode:         Self.wmoCode(for: current.condition)
        )
    }

    private static func wmoCode(for condition: WeatherCondition) -> Int {
        switch condition {
        case .clear, .hot, .frigid:            return 0
        case .mostlyClear:                     return 1
        case .partlyCloudy, .breezy:           return 2
        case .mostlyCloudy, .cloudy, .windy, .blowingDust: return 3
        case .foggy, .haze, .smoky:            return 45
        case .drizzle:                         return 51
        case .sunShowers:                      return 80
        case .rain:                            return 61
        case .heavyRain:                       return 65
        case .freezingDrizzle:                 return 56
        case .freezingRain:                    return 67
        case .sleet, .wintryMix:               return 77
        case .snow, .flurries, .sunFlurries:   return 71
        case .blowingSnow:                     return 73
        case .heavySnow, .blizzard:            return 75
        case .hail, .strongStorms:             return 99
        case .isolatedThunderstorms, .scatteredThunderstorms,
             .thunderstorms, .tropicalStorm, .hurricane: return 95
        @unknown default:                      return 3
        }
    }
}
*/
