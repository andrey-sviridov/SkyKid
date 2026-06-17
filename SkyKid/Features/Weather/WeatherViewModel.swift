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
    private(set) var cityName: String = "Моё местоположение"

    private var lastCoordinate: CLLocationCoordinate2D?
    // CLGeocoder ограничивает частоту запросов — геокодируем повторно
    // только если позиция сместилась заметно (> 1 км).
    private var geocodedLocation: CLLocation?

    init(service: any WeatherService) {
        self.service = service
        let raw = UserDefaults.standard.string(forKey: WeatherProvider.providerKey) ?? ""
        self.currentProvider = WeatherProvider(rawValue: raw) ?? .openMeteo
    }

    func load(coordinate: CLLocationCoordinate2D) async {
        lastCoordinate = coordinate
        AppGroup.saveLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        isLoading = true
        error = nil
        await resolveCityName(for: coordinate)
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
            // Кешируем TOG-рекомендацию для виджета и Siri до reloadAllTimelines().
            if let profile = AppGroup.loadProfile() {
                let gear = GearSetup.from(profile: profile)
                let rec  = OutfitRecommendationService.shared.recommend(
                    weather: data, profile: profile, gearSetup: gear
                )
                let effectiveTemp = rec.explanation.first(where: { $0.unit == "°C" })?.value
                    ?? data.apparentTemperature
                AppGroup.saveTOGOutfit(CachedTOGOutfit(
                    layers: rec.allDisplayLayers.map {
                        CachedTOGOutfit.Layer(name: $0.name, systemImage: $0.systemImage, reason: $0.reason)
                    },
                    effectiveChildTemp: effectiveTemp,
                    updatedAt: Date()
                ))
            }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = "Не удалось загрузить погоду"
        }
        isLoading = false
    }

    /// Принудительно перезагружает погоду для последней координаты,
    /// игнорируя дистанционный guard в ContentView. Вызывается кнопкой обновления.
    func reload() async {
        guard let coordinate = lastCoordinate else { return }
        await load(coordinate: coordinate)
    }

    // P1-2: обратное геокодирование — реальное название города вместо заглушки.
    private func resolveCityName(for coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let prev = geocodedLocation, location.distance(from: prev) < 1_000 { return }
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let locality = placemarks.first?.locality {
                cityName = locality
                geocodedLocation = location
            }
        } catch {
            // оставляем прежнее название; geocodedLocation не обновляем —
            // следующая загрузка попробует снова
        }
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
            Task { await load(coordinate: coordinate) }
        }
    }
}
