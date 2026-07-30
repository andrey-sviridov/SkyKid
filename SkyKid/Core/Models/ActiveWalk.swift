import Foundation
import SwiftUI

// MARK: - ActiveWalkStorage
// Dual-target: используется и приложением (SkyKid), и SkyKidWidgetExtension
// (интенты Live Activity читают/пишут ту же запись напрямую из App Group).

enum ActiveWalkStorage {
    static let key = "active_walk_v1"
}

// MARK: - WalkEventKind

/// Тип события, произошедшего во время живой прогулки.
enum WalkEventKind: String, Codable, CaseIterable, Identifiable {
    case addedGarment      = "addedGarment"
    case removedGarment    = "removedGarment"
    case openedBassinette  = "openedBassinette"
    case closedBassinette  = "closedBassinette"
    case sleep             = "sleep"
    case wake               = "wake"
    case checkpoint        = "checkpoint"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addedGarment:     return L10n.text("Надели")
        case .removedGarment:   return L10n.text("Сняли")
        case .openedBassinette: return L10n.text("Открыли люльку")
        case .closedBassinette: return L10n.text("Закрыли люльку")
        case .sleep:            return L10n.text("Уснул")
        case .wake:              return L10n.text("Проснулся")
        case .checkpoint:       return L10n.text("Отметка")
        }
    }

    var icon: String {
        switch self {
        case .addedGarment:     return "plus.circle.fill"
        case .removedGarment:   return "minus.circle.fill"
        case .openedBassinette: return "tray.and.arrow.up.fill"
        case .closedBassinette: return "tray.and.arrow.down.fill"
        case .sleep:            return "moon.zzz.fill"
        case .wake:              return "sun.max.fill"
        case .checkpoint:       return "flag.fill"
        }
    }

    // ВАЖНО: именно `Color`, а не имя цвета строкой — `Color("green")` ищет
    // цвет в asset catalog, которого у нас нет, и рисует невидимый цвет
    // (из-за этого «Быстрые отметки» выглядели как пустая карточка).
    var color: Color {
        switch self {
        case .addedGarment:     return .green
        case .removedGarment:   return .orange
        case .openedBassinette: return .blue
        case .closedBassinette: return .indigo
        case .sleep:            return .purple
        case .wake:              return .orange
        case .checkpoint:       return .cyan
        }
    }
}

// MARK: - WalkEvent

/// Одна отметка на таймлайне живой прогулки, привязанная ко времени.
struct WalkEvent: Codable, Identifiable, Hashable {
    var id: UUID
    var timestamp: Date
    var kind: WalkEventKind
    var garmentID: String?
    var note: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        kind: WalkEventKind,
        garmentID: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.garmentID = garmentID
        self.note = note
    }
}

// MARK: - ActiveWalk

/// Прогулка, идущая прямо сейчас. Персистится целиком, чтобы пережить
/// перезапуск/выгрузку приложения (таймер восстанавливается из `startDate`).
/// Намеренно не содержит computed-свойств, зависящих от `GarmentCatalog` —
/// этот файл компилируется и в виджет-таргет (`SkyKidWidgetExtension`) для
/// интентов быстрых меток на экране блокировки.
struct ActiveWalk: Codable, Identifiable, Hashable {
    var id: UUID
    var startDate: Date
    var plannedDurationMinutes: Int?

    // Снапшот погоды на момент старта.
    var weatherTemperature: Double
    var apparentTemperature: Double
    var microclimateTemperature: Double?
    var weatherCode: Int?
    /// Снимок иконки/описания погоды на старте — для Live Activity (виджет-таргет
    /// не должен зависеть от WeatherData/PrecipType, поэтому передаём готовые строки).
    var weatherIconSymbol: String?
    var weatherDescription: String?

    // Контекст прогулки (для персонализации при завершении).
    var transportMode: TransportMode?
    var activityLevel: BabyActivityLevel?
    var walkType: WalkType?
    var targetTOG: Double?

    // Текущий набор одежды и таймлайн событий.
    var outfitItemIDs: [String]
    var events: [WalkEvent]

    init(
        id: UUID = UUID(),
        startDate: Date = .now,
        plannedDurationMinutes: Int? = nil,
        weatherTemperature: Double,
        apparentTemperature: Double,
        microclimateTemperature: Double? = nil,
        weatherCode: Int? = nil,
        weatherIconSymbol: String? = nil,
        weatherDescription: String? = nil,
        transportMode: TransportMode? = nil,
        activityLevel: BabyActivityLevel? = nil,
        walkType: WalkType? = nil,
        targetTOG: Double? = nil,
        outfitItemIDs: [String] = [],
        events: [WalkEvent] = []
    ) {
        self.id = id
        self.startDate = startDate
        self.plannedDurationMinutes = plannedDurationMinutes
        self.weatherTemperature = weatherTemperature
        self.apparentTemperature = apparentTemperature
        self.microclimateTemperature = microclimateTemperature
        self.weatherCode = weatherCode
        self.weatherIconSymbol = weatherIconSymbol
        self.weatherDescription = weatherDescription
        self.transportMode = transportMode
        self.activityLevel = activityLevel
        self.walkType = walkType
        self.targetTOG = targetTOG
        self.outfitItemIDs = outfitItemIDs
        self.events = events
    }

    /// Осталось до целевой длительности (сек), если она задана.
    func remainingSeconds(now: Date = .now) -> TimeInterval? {
        guard let planned = plannedDurationMinutes else { return nil }
        let target = startDate.addingTimeInterval(TimeInterval(planned * 60))
        return target.timeIntervalSince(now)
    }

    /// Спит ли ребёнок сейчас — по последнему событию среди `.sleep`/`.wake`.
    var isSleeping: Bool {
        events.filter { $0.kind == .sleep || $0.kind == .wake }
            .max { $0.timestamp < $1.timestamp }?
            .kind == .sleep
    }

    /// Открыта ли люлька сейчас — по последнему событию среди пары открыть/закрыть.
    var isBassinetteOpen: Bool {
        events.filter { $0.kind == .openedBassinette || $0.kind == .closedBassinette }
            .max { $0.timestamp < $1.timestamp }?
            .kind == .openedBassinette
    }
}
