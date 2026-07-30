import Foundation
import SwiftUI

// MARK: - BabyComfortLevel

enum BabyComfortLevel: String, Codable, CaseIterable, Identifiable {
    case cold        = "cold"
    case comfortable = "comfortable"
    case warm        = "warm"
    case sweating    = "sweating"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cold:        return L10n.text("Мёрз")
        case .comfortable: return L10n.text("Комфортно")
        case .warm:        return L10n.text("Тепловато")
        case .sweating:    return L10n.text("Потел")
        }
    }

    var icon: String {
        switch self {
        case .cold:        return "snowflake"
        case .comfortable: return "checkmark.circle.fill"
        case .warm:        return "sun.max.fill"
        case .sweating:    return "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .cold:        return .blue
        case .comfortable: return .green
        case .warm:        return .orange
        case .sweating:    return .red
        }
    }

}

// MARK: - WalkEventKind

/// Тип события, произошедшего во время живой прогулки.
enum WalkEventKind: String, Codable, CaseIterable, Identifiable {
    case addedGarment      = "addedGarment"
    case removedGarment    = "removedGarment"
    case openedBassinette  = "openedBassinette"
    case closedBassinette  = "closedBassinette"
    case sleep             = "sleep"
    case wake              = "wake"
    case checkpoint        = "checkpoint"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addedGarment:     return L10n.text("Надели")
        case .removedGarment:   return L10n.text("Сняли")
        case .openedBassinette: return L10n.text("Открыли люльку")
        case .closedBassinette: return L10n.text("Закрыли люльку")
        case .sleep:            return L10n.text("Уснул")
        case .wake:             return L10n.text("Проснулся")
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
        case .wake:             return "sun.max.fill"
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
        case .wake:             return .orange
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

// MARK: - WalkLog

struct WalkLog: Codable, Identifiable, Hashable {
    var id: UUID
    var date: Date
    var durationMinutes: Int
    var outfitItemIDs: [String]
    var comfortLevel: BabyComfortLevel
    var weatherTemperature: Double
    var apparentTemperature: Double
    var microclimateTemperature: Double?
    var transportMode: TransportMode?
    var activityLevel: BabyActivityLevel?
    var walkType: WalkType?
    var targetTOG: Double?
    var effectiveOutfitTOG: Double?
    /// Таймлайн событий (только для живых прогулок).
    var events: [WalkEvent]
    /// `true`, если прогулка велась вживую с таймером, а не записана задним числом.
    var isLiveTracked: Bool
    /// Код погоды WMO на момент прогулки — для иконки/градиента.
    var weatherCode: Int?
    /// Целевая длительность, если пользователь её задал.
    var plannedDurationMinutes: Int?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        durationMinutes: Int,
        outfitItemIDs: [String] = [],
        comfortLevel: BabyComfortLevel,
        weatherTemperature: Double,
        apparentTemperature: Double,
        microclimateTemperature: Double? = nil,
        transportMode: TransportMode? = nil,
        activityLevel: BabyActivityLevel? = nil,
        walkType: WalkType? = nil,
        targetTOG: Double? = nil,
        effectiveOutfitTOG: Double? = nil,
        events: [WalkEvent] = [],
        isLiveTracked: Bool = false,
        weatherCode: Int? = nil,
        plannedDurationMinutes: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.outfitItemIDs = outfitItemIDs
        self.comfortLevel = comfortLevel
        self.weatherTemperature = weatherTemperature
        self.apparentTemperature = apparentTemperature
        self.microclimateTemperature = microclimateTemperature
        self.transportMode = transportMode
        self.activityLevel = activityLevel
        self.walkType = walkType
        self.targetTOG = targetTOG
        self.effectiveOutfitTOG = effectiveOutfitTOG
        self.events = events
        self.isLiveTracked = isLiveTracked
        self.weatherCode = weatherCode
        self.plannedDurationMinutes = plannedDurationMinutes
    }

    // Ручной `init(from:)` нужен, потому что синтезированный Codable НЕ применяет
    // значения по умолчанию к отсутствующим ключам — старый JSON без новых полей
    // иначе не декодируется.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                      = try c.decode(UUID.self, forKey: .id)
        date                    = try c.decode(Date.self, forKey: .date)
        durationMinutes         = try c.decode(Int.self, forKey: .durationMinutes)
        outfitItemIDs           = try c.decodeIfPresent([String].self, forKey: .outfitItemIDs) ?? []
        comfortLevel            = try c.decode(BabyComfortLevel.self, forKey: .comfortLevel)
        weatherTemperature      = try c.decode(Double.self, forKey: .weatherTemperature)
        apparentTemperature     = try c.decode(Double.self, forKey: .apparentTemperature)
        microclimateTemperature = try c.decodeIfPresent(Double.self, forKey: .microclimateTemperature)
        transportMode           = try c.decodeIfPresent(TransportMode.self, forKey: .transportMode)
        activityLevel           = try c.decodeIfPresent(BabyActivityLevel.self, forKey: .activityLevel)
        walkType                = try c.decodeIfPresent(WalkType.self, forKey: .walkType)
        targetTOG               = try c.decodeIfPresent(Double.self, forKey: .targetTOG)
        effectiveOutfitTOG      = try c.decodeIfPresent(Double.self, forKey: .effectiveOutfitTOG)
        events                  = try c.decodeIfPresent([WalkEvent].self, forKey: .events) ?? []
        isLiveTracked           = try c.decodeIfPresent(Bool.self, forKey: .isLiveTracked) ?? false
        weatherCode             = try c.decodeIfPresent(Int.self, forKey: .weatherCode)
        plannedDurationMinutes  = try c.decodeIfPresent(Int.self, forKey: .plannedDurationMinutes)
    }
}
