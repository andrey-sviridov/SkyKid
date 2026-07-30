import ActivityKit
import Foundation

// MARK: - WalkActivityAttributes
// Dual-target: нужен и приложению (запуск/обновление активности), и
// SkyKidWidgetExtension (рендер Live Activity / Dynamic Island).
// ContentState намеренно содержит только примитивы — виджет-таргет не
// должен зависеть от GarmentCatalog/WalkEventKind.

/// Какая из кнопок быстрых меток сейчас применяется — от тапа до записи
/// события показывает спиннер и блокирует весь ряд кнопок, чтобы было видно,
/// что действие в процессе.
enum QuickMarkControl: String, Codable, Hashable {
    case sleep, bassinette, checkpoint
}

struct WalkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var outfitCount: Int
        var effectiveTOG: Double
        var lastEventTitle: String?
        var lastEventIcon: String?
        var lastEventDate: Date?
        /// Спит ли ребёнок сейчас — определяет подпись/иконку кнопки «Сон/Подъём»
        /// на экране блокировки.
        var isSleeping: Bool
        /// Открыта ли люлька сейчас — определяет подпись/иконку кнопки-переключателя.
        var isBassinetteOpen: Bool
        /// Кнопка, у которой тап уже произошёл, но событие ещё не записано —
        /// `nil`, когда все три кнопки в состоянии покоя.
        var pendingControl: QuickMarkControl?
    }

    var startDate: Date
    var plannedDurationMinutes: Int?
    var weatherTemperature: Double
    var weatherCode: Int?
    var weatherIconSymbol: String?
    var weatherDescription: String?
    var targetTOG: Double?
}
