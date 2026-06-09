import Foundation
import CoreLocation
import Observation
import WidgetKit

// DIP: ViewModel зависит от WeatherService (абстракция), не от OpenMeteoService.
// Для тестов достаточно создать WeatherViewModel(service: MockWeatherService()).

@MainActor
@Observable
final class WeatherViewModel {
    private var service: any WeatherService
    private(set) var currentProvider: WeatherProvider

    var weather: WeatherData?
    var isLoading = false
    var error: String?

    private var lastCoordinate: CLLocationCoordinate2D?
    private var lastCityName: String = "Моё местоположение"

    init(service: any WeatherService) {
        self.service = service
        let raw = UserDefaults.standard.string(forKey: WeatherProvider.providerKey) ?? ""
        self.currentProvider = WeatherProvider(rawValue: raw) ?? .openMeteo
    }

    func load(coordinate: CLLocationCoordinate2D, cityName: String = "Моё местоположение") async {
        lastCoordinate = coordinate
        lastCityName   = cityName
        AppGroup.saveLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        isLoading = true
        error = nil
        do {
            let data = try await service.fetch(coordinate: coordinate)
            weather = data
            AppGroup.saveWeather(
                temperature:   data.temperature,
                apparentTemp:  data.apparentTemperature,
                weatherCode:   data.weatherCode,
                windSpeed:     data.windSpeed,
                precipitation: data.precipitation,
                cityName:      cityName
            )
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = "Не удалось загрузить погоду"
        }
        isLoading = false
    }

    /// Переключает провайдера, сохраняет API-ключ (если нужен) и перезагружает погоду.
    func switchProvider(_ provider: WeatherProvider, apiKey: String? = nil) {
        if let key = apiKey, !key.isEmpty {
            switch provider {
            case .openWeatherMap: UserDefaults.standard.set(key, forKey: WeatherProvider.owmKeyKey)
            case .weatherAPI:     UserDefaults.standard.set(key, forKey: WeatherProvider.wapiKeyKey)
            case .yandex:         UserDefaults.standard.set(key, forKey: WeatherProvider.yandexKeyKey)
            default: break
            }
        }
        UserDefaults.standard.set(provider.rawValue, forKey: WeatherProvider.providerKey)
        service = WeatherProvider.makeService(for: provider) ?? OpenMeteoService()
        currentProvider = provider
        if let coordinate = lastCoordinate {
            Task { await load(coordinate: coordinate, cityName: lastCityName) }
        }
    }
}
