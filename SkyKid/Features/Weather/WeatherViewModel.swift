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
    private let outfitUseCase: BuildOutfitRecommendationUseCase
    private let nowProvider: @Sendable () -> Date
    private(set) var currentProvider: WeatherProvider

    var weather: NormalizedWeather?
    private(set) var outfitRecommendation: OutfitRecommendation?
    var isLoading = false
    var error: String?
    private(set) var cityName: String = L10n.text("Моё местоположение")
    private(set) var weatherUpdatedAt: Date?

    private var recommendationProfile: ChildThermalProfile?
    private var walkContext: WalkContext?

    private var lastCoordinate: CLLocationCoordinate2D?
    // CLGeocoder ограничивает частоту запросов — геокодируем повторно
    // только если позиция сместилась заметно (> 1 км).
    private var geocodedLocation: CLLocation?

    init(
        service: any WeatherService,
        outfitUseCase: BuildOutfitRecommendationUseCase,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.service = service
        self.outfitUseCase = outfitUseCase
        self.nowProvider = nowProvider
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
            AppGroup.saveWeather(
                temperature:   data.temperature,
                apparentTemp:  data.apparentTemperature,
                weatherCode:   data.weatherCode,
                windSpeed:     data.windSpeed,
                precipitation: data.precipitation,
                cityName:      cityName
            )
            weather = data
            weatherUpdatedAt = nowProvider()
            rebuildOutfitRecommendation()
        } catch {
            self.error = L10n.text("Не удалось загрузить погоду")
        }
        isLoading = false
    }

    /// Принудительно перезагружает погоду для последней координаты,
    /// игнорируя дистанционный guard в ContentView. Вызывается кнопкой обновления.
    func reload() async {
        guard let coordinate = lastCoordinate else { return }
        await load(coordinate: coordinate)
    }

    /// Rebuilds the single recommendation after a profile, wardrobe, or
    /// personalization change without requesting weather again.
    func refreshOutfitRecommendation(
        for profile: ChildProfile?,
        walkContext: WalkContext?
    ) {
        recommendationProfile = profile?.thermalProfile
        self.walkContext = walkContext
        rebuildOutfitRecommendation()
    }

    func refreshLocalization() {
        if geocodedLocation == nil {
            cityName = L10n.text("Моё местоположение")
        }
        if error != nil {
            error = L10n.text("Не удалось загрузить погоду")
        }
        rebuildOutfitRecommendation()
    }

    private func rebuildOutfitRecommendation() {
        guard let profile = recommendationProfile else {
            outfitRecommendation = nil
            outfitUseCase.clearSnapshot()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        guard let walkContext, let weather else {
            // Keep the last valid App Group snapshot while the app is waiting
            // for fresh weather or preparing the in-memory walk context.
            outfitRecommendation = nil
            return
        }

        let output = outfitUseCase.execute(
            weather: weather,
            profile: profile,
            walkContext: walkContext,
            cityName: cityName,
            generatedAt: weatherUpdatedAt ?? nowProvider()
        )
        outfitRecommendation = output.recommendation
        WidgetCenter.shared.reloadAllTimelines()
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
