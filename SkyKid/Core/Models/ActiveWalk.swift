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

// MARK: - Passive weather updates

enum PassiveWeatherChange: String, Codable, Hashable, Sendable {
    case becameColder
    case becameWarmer
    case precipitationStarted
    case precipitationStopped

    var message: String {
        switch self {
        case .becameColder:         return L10n.text("На улице стало заметно холоднее")
        case .becameWarmer:         return L10n.text("На улице стало заметно теплее")
        case .precipitationStarted: return L10n.text("Начались осадки")
        case .precipitationStopped: return L10n.text("Осадки закончились")
        }
    }
}

struct PassiveWalkWeatherUpdate: Codable, Hashable, Sendable {
    let snapshot: WeatherSnapshot
    let change: PassiveWeatherChange
}

enum PassiveWeatherChangePolicy {
    static let significantTemperatureDelta = 3.0
    static let precipitationThreshold = 0.1

    static func change(
        from previous: WeatherSnapshot,
        to current: WeatherSnapshot
    ) -> PassiveWeatherChange? {
        if let previousPrecipitation = previous.precipitation,
           let currentPrecipitation = current.precipitation {
            let wasRaining = previousPrecipitation > precipitationThreshold
            let isRaining = currentPrecipitation > precipitationThreshold
            if wasRaining != isRaining {
                return isRaining ? .precipitationStarted : .precipitationStopped
            }
        }

        guard let previousTemperature = previous.apparentTemperature ?? previous.temperature,
              let currentTemperature = current.apparentTemperature ?? current.temperature else {
            return nil
        }
        let delta = currentTemperature - previousTemperature
        if delta <= -significantTemperatureDelta { return .becameColder }
        if delta >= significantTemperatureDelta { return .becameWarmer }
        return nil
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
    var weatherTemperature: Double?
    var apparentTemperature: Double?
    var microclimateTemperature: Double?
    var weatherCode: Int?
    /// Immutable provider/quality/freshness evidence captured at walk start.
    /// Optional for backward compatibility with pre-SKY-002 payloads.
    var weatherSnapshot: WeatherSnapshot?
    /// Снимок иконки/описания погоды на старте — для Live Activity (виджет-таргет
    /// не должен зависеть от WeatherData/PrecipType, поэтому передаём готовые строки).
    var weatherIconSymbol: String?
    var weatherDescription: String?
    /// Significant later observations. The immutable start snapshot above is
    /// never replaced. Optional keeps pre-SKY-020 payloads decodable.
    var passiveWeatherUpdates: [PassiveWalkWeatherUpdate]?

    // Контекст прогулки (для персонализации при завершении).
    var transportMode: TransportMode?
    var activityLevel: BabyActivityLevel?
    var walkType: WalkType?
    var targetTOG: Double?
    /// Semantic recommendation behavior version used to start this walk.
    /// Nil is preserved for legacy walks started before versioning.
    var algorithmVersion: Int?

    // Текущий набор одежды и таймлайн событий.
    var outfitItemIDs: [String]
    var events: [WalkEvent]

    init(
        id: UUID = UUID(),
        startDate: Date = .now,
        plannedDurationMinutes: Int? = nil,
        weatherTemperature: Double? = nil,
        apparentTemperature: Double? = nil,
        microclimateTemperature: Double? = nil,
        weatherCode: Int? = nil,
        weatherSnapshot: WeatherSnapshot? = nil,
        weatherIconSymbol: String? = nil,
        weatherDescription: String? = nil,
        passiveWeatherUpdates: [PassiveWalkWeatherUpdate] = [],
        transportMode: TransportMode? = nil,
        activityLevel: BabyActivityLevel? = nil,
        walkType: WalkType? = nil,
        targetTOG: Double? = nil,
        algorithmVersion: Int? = nil,
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
        self.weatherSnapshot = weatherSnapshot
        self.weatherIconSymbol = weatherIconSymbol
        self.weatherDescription = weatherDescription
        self.passiveWeatherUpdates = passiveWeatherUpdates
        self.transportMode = transportMode
        self.activityLevel = activityLevel
        self.walkType = walkType
        self.targetTOG = targetTOG
        self.algorithmVersion = algorithmVersion
        self.outfitItemIDs = outfitItemIDs
        self.events = events
    }

    /// Осталось до целевой длительности (сек), если она задана.
    func remainingSeconds(now: Date = .now) -> TimeInterval? {
        guard let planned = plannedDurationMinutes else { return nil }
        let target = startDate.addingTimeInterval(TimeInterval(planned * 60))
        return target.timeIntervalSince(now)
    }

    /// Absolute dates survive timezone and DST changes. A manual clock rollback
    /// is clamped so consumer duration can never become negative.
    func elapsedSeconds(now: Date = .now) -> TimeInterval {
        max(0, now.timeIntervalSince(startDate))
    }

    var latestWeatherSnapshot: WeatherSnapshot? {
        passiveWeatherUpdates?.last?.snapshot ?? weatherSnapshot
    }

    var latestWeatherChange: PassiveWeatherChange? {
        passiveWeatherUpdates?.last?.change
    }

    var garmentChangeEvents: [WalkEvent] {
        events
            .filter { $0.kind == .addedGarment || $0.kind == .removedGarment }
            .sorted { $0.timestamp < $1.timestamp }
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
