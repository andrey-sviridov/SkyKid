import Foundation
import CoreLocation
import Observation
import WidgetKit

// DIP: ViewModel зависит от WeatherService (абстракция), не от OpenMeteoService.
// Для тестов достаточно создать WeatherViewModel(service: MockWeatherService()).

@MainActor
@Observable
final class WeatherViewModel {
    enum ContentState: Equatable {
        case loading
        case fresh(isCached: Bool)
        case cachedStale(updatedAt: Date)
        case unavailable(message: String)
    }

    private var service: any WeatherService
    private let outfitUseCase: BuildOutfitRecommendationUseCase
    private let nowProvider: @Sendable () -> Date
    private let cachedWeatherProvider: @MainActor () -> CachedWeather?
    private(set) var currentProvider: WeatherProvider
    private var freshnessTask: Task<Void, Never>?

    var weather: NormalizedWeather?
    private(set) var outfitRecommendation: OutfitRecommendation?
    private(set) var recommendationAlgorithmVersion: Int?
    var isLoading = false
    var error: String?
    private(set) var contentState: ContentState = .loading
#if DEBUG
    private(set) var diagnosticError: String?
#endif
    private(set) var cityName: String = L10n.text("Моё местоположение")
    private(set) var weatherUpdatedAt: Date?

    private var recommendationProfile: ChildThermalProfile?
    private var walkContext: WalkContext?

    private var lastCoordinate: CLLocationCoordinate2D?
    private var fixedCityName: String?
    // CLGeocoder ограничивает частоту запросов — геокодируем повторно
    // только если позиция сместилась заметно (> 1 км).
    private var geocodedLocation: CLLocation?

    init(
        service: any WeatherService,
        outfitUseCase: BuildOutfitRecommendationUseCase,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        cachedWeatherProvider: @escaping @MainActor () -> CachedWeather? = AppGroup.loadCachedWeatherIgnoringAge,
        lastCoordinateProvider: @escaping @MainActor () -> CLLocationCoordinate2D? = AppGroup.loadLastKnownCoordinate
    ) {
        self.service = service
        self.outfitUseCase = outfitUseCase
        self.nowProvider = nowProvider
        self.cachedWeatherProvider = cachedWeatherProvider
#if DEBUG
        let raw = UserDefaults.standard.string(forKey: WeatherProvider.providerKey) ?? ""
        self.currentProvider = WeatherProvider(rawValue: raw) ?? .openMeteo
#else
        self.currentProvider = .openMeteo
#endif
        lastCoordinate = lastCoordinateProvider()
        hydrateCacheIfAvailable()
    }

    func load(coordinate: CLLocationCoordinate2D, cityName fixedCityName: String? = nil) async {
        lastCoordinate = coordinate
        AppGroup.saveLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        isLoading = true
        error = nil
        contentState = weather == nil ? .loading : classifiedState(isCached: true)
#if DEBUG
        diagnosticError = nil
#endif
        if let fixedCityName {
            cityName = fixedCityName
            self.fixedCityName = fixedCityName
            geocodedLocation = nil
        } else {
            self.fixedCityName = nil
            await resolveCityName(for: coordinate)
        }
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
            contentState = .fresh(isCached: false)
            scheduleFreshnessTransition()
            rebuildOutfitRecommendation()
        } catch {
            self.error = L10n.text("Не удалось загрузить погоду")
#if DEBUG
            diagnosticError = String(describing: error)
#endif
            contentState = classifiedState(isCached: true)
            // A failed refresh must not strand Today in a loading state when
            // a still-fresh cached observation can produce a recommendation.
            rebuildOutfitRecommendation()
        }
        isLoading = false
    }

    /// Принудительно перезагружает погоду для последней координаты,
    /// игнорируя дистанционный guard в ContentView. Вызывается кнопкой обновления.
    func reload() async {
        guard let coordinate = lastCoordinate else { return }
        await load(coordinate: coordinate, cityName: fixedCityName)
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
        if geocodedLocation == nil, fixedCityName == nil {
            cityName = L10n.text("Моё местоположение")
        }
        if error != nil {
            error = L10n.text("Не удалось загрузить погоду")
        }
        rebuildOutfitRecommendation()
    }

    /// Re-evaluates the current weather without fetching. This is used by the
    /// scheduled freshness transition and is also deterministic in tests.
    func refreshFreshness(at date: Date? = nil) {
        guard weatherUpdatedAt != nil else {
            contentState = weather == nil
                ? .unavailable(message: error ?? L10n.text("Погода недоступна"))
                : classifiedState(isCached: true, now: date)
            rebuildOutfitRecommendation()
            return
        }

        let now = date ?? nowProvider()
        guard RecommendationFreshnessPolicy(now: now).state(for: weatherUpdatedAt) == .fresh else {
            contentState = classifiedState(isCached: true, now: now)
            if outfitRecommendation != nil {
                outfitRecommendation = nil
                WidgetCenter.shared.reloadAllTimelines()
            }
            return
        }

        rebuildOutfitRecommendation(at: now)
    }

    private func rebuildOutfitRecommendation() {
        rebuildOutfitRecommendation(at: nowProvider())
    }

    private func rebuildOutfitRecommendation(at now: Date) {
        guard let profile = recommendationProfile else {
            outfitRecommendation = nil
            recommendationAlgorithmVersion = nil
            outfitUseCase.clearSnapshot()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        guard let walkContext, let weather else {
            // Keep the last valid App Group snapshot while the app is waiting
            // for fresh weather or preparing the in-memory walk context.
            outfitRecommendation = nil
            recommendationAlgorithmVersion = nil
            return
        }
        guard let weatherUpdatedAt,
              RecommendationFreshnessPolicy(now: now).state(for: weatherUpdatedAt) == .fresh
        else {
            outfitRecommendation = nil
            recommendationAlgorithmVersion = nil
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        do {
            let output = try outfitUseCase.execute(
                weather: weather,
                profile: profile,
                walkContext: walkContext,
                cityName: cityName,
                generatedAt: weatherUpdatedAt,
                now: now
            )
            outfitRecommendation = output.recommendation
            recommendationAlgorithmVersion = output.snapshot.algorithmVersion
        } catch {
            outfitRecommendation = nil
            recommendationAlgorithmVersion = nil
            outfitUseCase.clearSnapshot()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleFreshnessTransition() {
        freshnessTask?.cancel()

        let freshness = RecommendationFreshnessPolicy(now: nowProvider())
        guard let delay = freshness.timeUntilStale(from: weatherUpdatedAt), delay > 0 else {
            refreshFreshness()
            return
        }

        freshnessTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.refreshFreshness()
        }
    }

    private func hydrateCacheIfAvailable() {
        guard let cached = cachedWeatherProvider() else {
            contentState = .unavailable(message: L10n.text("Погода недоступна"))
            return
        }
        let observation = RawWeatherObservation(
            source: .manual,
            temperature: cached.temperature,
            apparentTemperature: cached.apparentTemperature,
            windSpeed: cached.windSpeed,
            precipitation: cached.precipitation,
            weatherCode: cached.weatherCode
        )
        guard let normalized = try? WeatherNormalizer.normalize(observation) else { return }
        weather = normalized
        weatherUpdatedAt = cached.updatedAt
        cityName = cached.cityName
        contentState = classifiedState(isCached: true)
        scheduleFreshnessTransition()
    }

    private func classifiedState(isCached: Bool, now: Date? = nil) -> ContentState {
        guard weather != nil else {
            return .unavailable(message: error ?? L10n.text("Погода недоступна"))
        }
        let date = now ?? nowProvider()
        switch RecommendationFreshnessPolicy(now: date).state(for: weatherUpdatedAt) {
        case .fresh:
            return .fresh(isCached: isCached)
        case .stale:
            return .cachedStale(updatedAt: weatherUpdatedAt ?? date)
        case .unavailable:
            return .unavailable(message: error ?? L10n.text("Погода недоступна"))
        }
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
#if DEBUG
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
#endif
}
