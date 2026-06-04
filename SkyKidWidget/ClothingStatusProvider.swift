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

/// Читает кешированные данные о погоде из App Group UserDefaults.
/// Кеш заполняется основным приложением при каждом fetch (WeatherViewModel).
///
/// Для подключения реальной геолокации в виджете: замените `makeEntry()` на
/// асинхронный вариант с CLLocationManager + OpenMeteoService.
struct ClothingStatusProvider: TimelineProvider {

    // MARK: Протокол TimelineProvider

    func placeholder(in context: Context) -> ClothingStatusEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ClothingStatusEntry) -> Void) {
        // В галерее виджетов показываем заглушку с реалистичными данными
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClothingStatusEntry>) -> Void) {
        let entry = makeEntry()

        // Следующее обновление — через 30 минут.
        // WidgetKit соблюдает бюджет обновлений (~40-70 в день для активных виджетов).
        // При загрузке погоды в приложении вызывается WidgetCenter.reloadAllTimelines(),
        // поэтому реальная задержка будет значительно меньше.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    // MARK: Построение записи из кеша

    private func makeEntry() -> ClothingStatusEntry {
        let weather = AppGroup.loadCachedWeather()
        let profile = AppGroup.loadProfile()

        guard let weather else {
            // Кеш пуст или устарел: просим пользователя открыть приложение
            return .placeholder
        }

        let rec = WidgetClothingCalculator.recommend(weather: weather, profile: profile)
        return ClothingStatusEntry(date: Date(), recommendation: rec, isPlaceholder: false)
    }
}

// MARK: - Замена на реальную геолокацию в виджете (TODO)
//
// Чтобы виджет сам получал погоду без запуска приложения:
//
// 1. Добавьте Background Modes → Background fetch в capabilities виджета.
// 2. Замените makeEntry() на async вариант:
//
//    private func fetchEntry() async -> ClothingStatusEntry {
//        guard let location = await resolveLocation() else { return .placeholder }
//        guard let weather  = try? await OpenMeteoService.fetch(coordinate: location) else { return .placeholder }
//        let cached = CachedWeather(temperature: weather.temperature, ...)
//        let rec = WidgetClothingCalculator.recommend(weather: cached, profile: AppGroup.loadProfile())
//        return ClothingStatusEntry(date: Date(), recommendation: rec, isPlaceholder: false)
//    }
//
// 3. Смените политику обновления на .atEnd для более частых обновлений.
