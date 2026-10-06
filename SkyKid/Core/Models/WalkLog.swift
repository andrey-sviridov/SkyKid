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

// MARK: - Optional completion feedback

enum WalkComfortFeedback: String, Codable, CaseIterable, Identifiable, Sendable {
    case cold
    case comfortable
    case hot
    case unsure
    case skipped

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cold:        return L10n.text("Было холодно")
        case .comfortable: return L10n.text("Было комфортно")
        case .hot:         return L10n.text("Было жарко")
        case .unsure:      return L10n.text("Не уверен(а)")
        case .skipped:     return L10n.text("Ответ пропущен")
        }
    }

    var icon: String {
        switch self {
        case .cold:        return "snowflake"
        case .comfortable: return "checkmark.circle.fill"
        case .hot:         return "sun.max.fill"
        case .unsure:      return "questionmark.circle.fill"
        case .skipped:     return "forward.fill"
        }
    }

    var color: Color {
        switch self {
        case .cold:        return .blue
        case .comfortable: return .green
        case .hot:         return .orange
        case .unsure, .skipped: return .secondary
        }
    }

    var isPersonalizationSignal: Bool {
        self != .unsure && self != .skipped
    }

    var legacyLevel: BabyComfortLevel {
        switch self {
        case .cold:        return .cold
        case .comfortable: return .comfortable
        case .hot:         return .warm
        case .unsure, .skipped: return .comfortable
        }
    }

    fileprivate init(legacyLevel: BabyComfortLevel) {
        switch legacyLevel {
        case .cold:        self = .cold
        case .comfortable: self = .comfortable
        case .warm, .sweating: self = .hot
        }
    }
}

enum ClothingAdjustment: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case removedLayer
    case addedLayer
    case unknown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:         return L10n.text("Одежду не меняли")
        case .removedLayer: return L10n.text("Сняли слой")
        case .addedLayer:   return L10n.text("Добавили слой")
        case .unknown:      return L10n.text("Не помню")
        }
    }
}

struct WalkCompletionFeedback: Equatable, Sendable {
    let comfort: WalkComfortFeedback
    let clothingAdjustment: ClothingAdjustment
    let garmentID: String?

    static let skipped = WalkCompletionFeedback(
        comfort: .skipped,
        clothingAdjustment: .unknown,
        garmentID: nil
    )
}

// MARK: - WalkLog
// `WalkEventKind`/`WalkEvent` живут в ActiveWalk.swift (общий файл для
// SkyKid + SkyKidWidgetExtension — используются интентами быстрых меток).

struct WalkLog: Codable, Identifiable, Hashable {
    var id: UUID
    var date: Date
    /// Semantic recommendation behavior version. Nil is legacy/unknown.
    var algorithmVersion: Int?
    var durationMinutes: Int
    var outfitItemIDs: [String]
    /// Legacy compatibility mirror. New UI reads `comfortFeedback`.
    var comfortLevel: BabyComfortLevel
    var comfortFeedback: WalkComfortFeedback
    var clothingAdjustment: ClothingAdjustment
    var adjustedGarmentID: String?
    var weatherTemperature: Double?
    var apparentTemperature: Double?
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
    /// Explicit origin used to decide whether this record may train personalization.
    /// Legacy payloads infer it from `isLiveTracked` and remain ineligible without
    /// sufficient provenance evidence.
    var origin: WalkOrigin
    /// Код погоды WMO на момент прогулки — для иконки/градиента.
    var weatherCode: Int?
    /// Immutable weather provenance. Legacy logs decode with `nil`.
    var weatherSnapshot: WeatherSnapshot?
    /// Целевая длительность, если пользователь её задал.
    var plannedDurationMinutes: Int?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        algorithmVersion: Int? = RecommendationAlgorithmVersion.current,
        durationMinutes: Int,
        outfitItemIDs: [String] = [],
        comfortLevel: BabyComfortLevel,
        comfortFeedback: WalkComfortFeedback? = nil,
        clothingAdjustment: ClothingAdjustment = .unknown,
        adjustedGarmentID: String? = nil,
        weatherTemperature: Double? = nil,
        apparentTemperature: Double? = nil,
        microclimateTemperature: Double? = nil,
        transportMode: TransportMode? = nil,
        activityLevel: BabyActivityLevel? = nil,
        walkType: WalkType? = nil,
        targetTOG: Double? = nil,
        effectiveOutfitTOG: Double? = nil,
        events: [WalkEvent] = [],
        isLiveTracked: Bool = false,
        origin: WalkOrigin? = nil,
        weatherCode: Int? = nil,
        weatherSnapshot: WeatherSnapshot? = nil,
        plannedDurationMinutes: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.algorithmVersion = algorithmVersion
        self.durationMinutes = durationMinutes
        self.outfitItemIDs = outfitItemIDs
        self.comfortLevel = comfortLevel
        self.comfortFeedback = comfortFeedback ?? WalkComfortFeedback(legacyLevel: comfortLevel)
        self.clothingAdjustment = clothingAdjustment
        self.adjustedGarmentID = adjustedGarmentID
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
        self.origin = origin ?? (isLiveTracked ? .tracked : .manual)
        self.weatherCode = weatherCode
        self.weatherSnapshot = weatherSnapshot
        self.plannedDurationMinutes = plannedDurationMinutes
    }

    // Ручной `init(from:)` нужен, потому что синтезированный Codable НЕ применяет
    // значения по умолчанию к отсутствующим ключам — старый JSON без новых полей
    // иначе не декодируется.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                      = try c.decode(UUID.self, forKey: .id)
        date                    = try c.decode(Date.self, forKey: .date)
        algorithmVersion        = try c.decodeIfPresent(Int.self, forKey: .algorithmVersion)
        durationMinutes         = try c.decode(Int.self, forKey: .durationMinutes)
        outfitItemIDs           = try c.decodeIfPresent([String].self, forKey: .outfitItemIDs) ?? []
        comfortLevel            = try c.decode(BabyComfortLevel.self, forKey: .comfortLevel)
        comfortFeedback         = try c.decodeIfPresent(WalkComfortFeedback.self, forKey: .comfortFeedback)
            ?? WalkComfortFeedback(legacyLevel: comfortLevel)
        clothingAdjustment      = try c.decodeIfPresent(ClothingAdjustment.self, forKey: .clothingAdjustment)
            ?? .unknown
        adjustedGarmentID       = try c.decodeIfPresent(String.self, forKey: .adjustedGarmentID)
        weatherTemperature      = try c.decodeIfPresent(Double.self, forKey: .weatherTemperature)
        apparentTemperature     = try c.decodeIfPresent(Double.self, forKey: .apparentTemperature)
        microclimateTemperature = try c.decodeIfPresent(Double.self, forKey: .microclimateTemperature)
        transportMode           = try c.decodeIfPresent(TransportMode.self, forKey: .transportMode)
        activityLevel           = try c.decodeIfPresent(BabyActivityLevel.self, forKey: .activityLevel)
        walkType                = try c.decodeIfPresent(WalkType.self, forKey: .walkType)
        targetTOG               = try c.decodeIfPresent(Double.self, forKey: .targetTOG)
        effectiveOutfitTOG      = try c.decodeIfPresent(Double.self, forKey: .effectiveOutfitTOG)
        events                  = try c.decodeIfPresent([WalkEvent].self, forKey: .events) ?? []
        isLiveTracked           = try c.decodeIfPresent(Bool.self, forKey: .isLiveTracked) ?? false
        origin                  = try c.decodeIfPresent(WalkOrigin.self, forKey: .origin)
            ?? (isLiveTracked ? .tracked : .manual)
        weatherCode             = try c.decodeIfPresent(Int.self, forKey: .weatherCode)
        weatherSnapshot         = try c.decodeIfPresent(WeatherSnapshot.self, forKey: .weatherSnapshot)
        plannedDurationMinutes  = try c.decodeIfPresent(Int.self, forKey: .plannedDurationMinutes)
    }
}

extension WalkLog {
    var personalizationEligibility: PersonalizationEligibility {
        personalizationEligibility(at: .now)
    }

    func personalizationEligibility(at now: Date) -> PersonalizationEligibility {
        guard comfortFeedback.isPersonalizationSignal else {
            return .excluded(.missingWalkContext)
        }
        return PersonalizationEngine.evaluateEligibility(for: self, now: now)
    }
}
