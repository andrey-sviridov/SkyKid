import ActivityKit
import Foundation

// MARK: - WalkActivityAttributes
// Dual-target: нужен и приложению (запуск/обновление активности), и
// SkyKidWidgetExtension (рендер Live Activity / Dynamic Island).
// ContentState намеренно содержит только примитивы — виджет-таргет не
// должен зависеть от GarmentCatalog/WalkEventKind.

struct WalkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var outfitCount: Int
        var effectiveTOG: Double
        var lastEventTitle: String?
        var lastEventIcon: String?
        var lastEventDate: Date?
    }

    var startDate: Date
    var plannedDurationMinutes: Int?
    var weatherTemperature: Double
    var weatherCode: Int?
    var weatherIconSymbol: String?
    var weatherDescription: String?
    var targetTOG: Double?
}
