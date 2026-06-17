import WidgetKit
import Foundation

// MARK: - Timeline Entry

struct ClothingStatusEntry: TimelineEntry {
    let date: Date
    let recommendation: WidgetOutfitRecommendation
    let isPlaceholder: Bool

    static var placeholder: ClothingStatusEntry {
        ClothingStatusEntry(
            date: Date(),
            recommendation: WidgetClothingCalculator.placeholder,
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

/// Читает кешированные данные из AppGroup.
/// Если кеш старше 90 минут — пытается самостоятельно получить свежую погоду
/// через OpenMeteoService, используя последние известные координаты из AppGroup.
struct ClothingStatusProvider: TimelineProvider {

    // MARK: TimelineProvider

    func placeholder(in context: Context) -> ClothingStatusEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ClothingStatusEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            Task { completion(await makeEntry()) }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClothingStatusEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            // Следующее плановое обновление — через 30 минут.
            // При загрузке погоды в приложении WidgetCenter.reloadAllTimelines()
            // вызывается раньше, поэтому реальная задержка обычно меньше.
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    // MARK: - Entry construction

    private func makeEntry() async -> ClothingStatusEntry {
        let profile = AppGroup.loadProfile()

        // Пробуем прочитать кеш без ограничения возраста
        let rawCached = AppGroup.loadCachedWeatherIgnoringAge()
        let cacheAge  = rawCached.map { Date().timeIntervalSince($0.updatedAt) } ?? .infinity

        // Кеш свежий (< 90 мин) — используем его напрямую
        if cacheAge < 5_400, let cached = rawCached {
            return entry(from: cached, profile: profile)
        }

        // Кеш устарел или пуст — пробуем живой fetch
        if let coordinate = AppGroup.loadLastKnownCoordinate(),
           let weatherData = try? await OpenMeteoService().fetch(coordinate: coordinate) {
            let fresh = CachedWeather(
                temperature:         weatherData.temperature,
                apparentTemperature: weatherData.apparentTemperature,
                weatherCode:         weatherData.weatherCode,
                windSpeed:           weatherData.windSpeed,
                precipitation:       weatherData.precipitation,
                // Название города берём из старого кеша, если есть
                cityName:            rawCached?.cityName ?? "—",
                updatedAt:           Date()
            )
            return entry(from: fresh, profile: profile)
        }

        // Последний вариант: устаревший кеш лучше, чем заглушка
        if let stale = rawCached {
            return entry(from: stale, profile: profile)
        }

        return .placeholder
    }

    private func entry(from weather: CachedWeather, profile: ChildProfile?) -> ClothingStatusEntry {
        // Prefer TOG cache (personalized, matches Outfit tab)
        if let tog = AppGroup.loadTOGOutfit(),
           Date().timeIntervalSince(tog.updatedAt) < 5_400 {
            let rec = WidgetOutfitRecommendation(
                temperature:         weather.temperature,
                apparentTemperature: weather.apparentTemperature,
                effectiveChildTemp:  tog.effectiveChildTemp,
                cityName:            weather.cityName,
                status:              WidgetClothingCalculator.status(for: tog.effectiveChildTemp),
                outfitItems:         tog.layers.map(\.name),
                ageLabel:            profile?.ageLabel ?? "малыша",
                updatedAt:           tog.updatedAt
            )
            return ClothingStatusEntry(date: Date(), recommendation: rec, isPlaceholder: false)
        }
        // Fallback: CLO calculator
        let rec = WidgetClothingCalculator.recommend(weather: weather, profile: profile)
        return ClothingStatusEntry(date: Date(), recommendation: rec, isPlaceholder: false)
    }
}
