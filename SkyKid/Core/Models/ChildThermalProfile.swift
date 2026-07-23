import Foundation

// MARK: - StableThermalTrait

/// Long-lived characteristics that may affect thermal comfort.
/// Acute illness never belongs here; it is represented by `WalkContext`.
enum StableThermalTrait: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case frequentIllness
    case coldSensitive
    case heatSensitive
    case anemia
    case atopicDermatitis
    case cardioRespiratory

    var id: String { rawValue }

    var label: String {
        switch self {
        case .frequentIllness:     return L10n.text("Часто болеет")
        case .coldSensitive:       return L10n.text("Чувствителен к холоду")
        case .heatSensitive:       return L10n.text("Плохо переносит жару")
        case .anemia:              return L10n.text("Анемия")
        case .atopicDermatitis:    return L10n.text("Атопический дерматит")
        case .cardioRespiratory:   return L10n.text("Особенности сердца/дыхания")
        }
    }

    var note: String {
        switch self {
        case .frequentIllness:     return L10n.text("Учитывается как небольшая постоянная поправка")
        case .coldSensitive:       return L10n.text("Может мёрзнуть быстрее")
        case .heatSensitive:       return L10n.text("Нужен более осторожный подбор в жару")
        case .anemia:              return L10n.text("Учитывается повышенная чувствительность к холоду")
        case .atopicDermatitis:    return L10n.text("Исключаются раздражающие ткани")
        case .cardioRespiratory:   return L10n.text("Применяются более строгие погодные ограничения")
        }
    }

    var systemImage: String {
        switch self {
        case .frequentIllness:     return "cross.case.fill"
        case .coldSensitive:       return "thermometer.snowflake"
        case .heatSensitive:       return "thermometer.sun.fill"
        case .anemia:              return "drop.fill"
        case .atopicDermatitis:    return "allergens"
        case .cardioRespiratory:   return "lungs.fill"
        }
    }
}

// MARK: - ChildThermalProfile

/// Persistent child data. It deliberately excludes today's health, activity,
/// transport and other conditions of a particular walk.
struct ChildThermalProfile: Codable, Equatable, Sendable {
    var name: String
    var gender: ChildGender
    var birthday: Date
    var gestationalAgeWeeks: Int
    var stableTraits: Set<StableThermalTrait>
    var temperaturePreferenceOffset: Double

    init(
        name: String,
        gender: ChildGender,
        birthday: Date,
        gestationalAgeWeeks: Int = 40,
        stableTraits: Set<StableThermalTrait> = [],
        temperaturePreferenceOffset: Double = 0
    ) {
        self.name = name
        self.gender = gender
        self.birthday = birthday
        self.gestationalAgeWeeks = min(max(gestationalAgeWeeks, 22), 40)
        self.stableTraits = stableTraits
        self.temperaturePreferenceOffset = min(max(temperaturePreferenceOffset, -3), 3)
    }

    // MARK: - Age

    var ageComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month], from: birthday, to: Date())
    }

    var ageYears: Int { max(0, ageComponents.year ?? 0) }
    var ageMonths: Int { max(0, ageComponents.month ?? 0) }
    var chronologicalAgeMonths: Int { ageYears * 12 + ageMonths }

    var chronologicalAgeWeeks: Int {
        Int(max(0, Date().timeIntervalSince(birthday)) / 604_800)
    }

    var correctedAgeWeeks: Int {
        chronologicalAgeWeeks - (40 - gestationalAgeWeeks)
    }

    var ageGroup: AgeGroup {
        switch chronologicalAgeMonths {
        case 0..<6:    return .infant
        case 6..<12:   return .baby
        case 12..<36:  return .toddler
        case 36..<72:  return .preschool
        case 72..<144: return .schoolAge
        default:       return .teen
        }
    }

    var ageLabel: String {
        var components = DateComponents()
        components.year = ageYears
        components.month = ageMonths

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.year, .month]
        formatter.maximumUnitCount = 2
        formatter.unitsStyle = .full
        return formatter.string(from: components) ?? L10n.text("Возраст не указан")
    }

    var isNewbornPeriod: Bool { chronologicalAgeWeeks < 4 }
    var usesStroller: Bool { [.infant, .baby, .toddler].contains(ageGroup) }

    // MARK: - Presentation

    func name(_ grammaticalCase: RussianCase) -> String {
        name.declined(to: grammaticalCase, gender: gender)
    }
}
