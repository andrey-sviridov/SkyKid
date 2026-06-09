import Foundation

// MARK: - WeatherProvider

enum WeatherProvider: String, CaseIterable, Identifiable {
    case openMeteo      = "open_meteo"
    case weatherKit     = "weatherkit"
    case openWeatherMap = "openweathermap"
    case weatherAPI     = "weatherapi"
    case gismeteo       = "gismeteo"
    case yandex         = "yandex"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openMeteo:      return "Open-Meteo"
        case .weatherKit:     return "Apple WeatherKit"
        case .openWeatherMap: return "OpenWeatherMap"
        case .weatherAPI:     return "WeatherAPI.com"
        case .gismeteo:       return "Gismeteo"
        case .yandex:         return "Яндекс Погода"
        }
    }

    var iconName: String {
        switch self {
        case .openMeteo:      return "globe"
        case .weatherKit:     return "apple.logo"
        case .openWeatherMap: return "cloud.sun.fill"
        case .weatherAPI:     return "antenna.radiowaves.left.and.right"
        case .gismeteo:       return "map.fill"
        case .yandex:         return "y.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .openMeteo:
            return "Бесплатно, без ключа. Модель ECMWF высокого разрешения."
        case .weatherKit:
            return "Тот же источник, что в «Погоде» на iPhone. Бесплатно до 500K запросов/мес. Ключ не нужен — достаточно App ID."
        case .openWeatherMap:
            return "Бесплатный API-ключ. Глобальное покрытие, стандарт индустрии."
        case .weatherAPI:
            return "Бесплатный ключ (1M запросов/мес). Точный feelsLike и мгновенные осадки."
        case .gismeteo:
            return "Российский сервис. Требует коммерческий API-ключ: partner.gismeteo.ru"
        case .yandex:
            return "Яндекс Погода. Требует API-ключ тарифа «Погода»: developer.tech.yandex.ru"
        }
    }

    /// Whether an API key must be supplied before use.
    var requiresKey: Bool {
        switch self {
        case .openMeteo, .weatherKit: return false
        default:                      return true
        }
    }

    /// Whether the provider has a working integration in this app.
    var isIntegrated: Bool {
        switch self {
        case .openMeteo, .weatherKit, .openWeatherMap, .weatherAPI, .yandex: return true
        case .gismeteo:                                                       return false
        }
    }

    // MARK: - UserDefaults keys

    static let providerKey    = "weatherProvider"
    static let owmKeyKey      = "owmApiKey"        // OpenWeatherMap
    static let wapiKeyKey     = "wapiApiKey"        // WeatherAPI.com
    static let yandexKeyKey   = "yandexApiKey"      // Яндекс Погода

    // MARK: - Factory

    /// Creates a WeatherService for the given provider.
    /// Returns nil if the provider needs an API key that has not been set,
    /// or if the provider's integration is unavailable.
    static func makeService(for provider: WeatherProvider) -> (any WeatherService)? {
        switch provider {
        case .openMeteo:
            return OpenMeteoService()

        case .weatherKit:
            return WeatherKitService()

        case .openWeatherMap:
            let key = UserDefaults.standard.string(forKey: owmKeyKey) ?? ""
            guard !key.isEmpty else { return nil }
            return OpenWeatherMapService(apiKey: key)

        case .weatherAPI:
            let key = UserDefaults.standard.string(forKey: wapiKeyKey) ?? ""
            guard !key.isEmpty else { return nil }
            return WeatherAPIService(apiKey: key)

        case .yandex:
            let key = UserDefaults.standard.string(forKey: yandexKeyKey) ?? ""
            guard !key.isEmpty else { return nil }
            return YandexWeatherService(apiKey: key)

        case .gismeteo:
            return nil
        }
    }

    /// The service currently selected in Settings. Falls back to Open-Meteo
    /// if the active provider is misconfigured (e.g. missing API key).
    static var activeService: any WeatherService {
        let raw      = UserDefaults.standard.string(forKey: providerKey) ?? ""
        let provider = WeatherProvider(rawValue: raw) ?? .openMeteo
        return makeService(for: provider) ?? OpenMeteoService()
    }
}
