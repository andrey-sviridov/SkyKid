import Foundation

// MARK: - BabyComfortLevel

enum BabyComfortLevel: String, Codable, CaseIterable, Identifiable {
    case cold        = "cold"
    case comfortable = "comfortable"
    case warm        = "warm"
    case sweating    = "sweating"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cold:        return "Мёрз"
        case .comfortable: return "Комфортно"
        case .warm:        return "Тепловато"
        case .sweating:    return "Потел"
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

    var colorName: String {
        switch self {
        case .cold:        return "blue"
        case .comfortable: return "green"
        case .warm:        return "orange"
        case .sweating:    return "red"
        }
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

    init(
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
        effectiveOutfitTOG: Double? = nil
    ) {
        self.id = UUID()
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
    }
}
