import Foundation
import CoreLocation

// MARK: - HealthCondition §4.5 (TOG pipeline — new spec)

enum HealthCondition: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case fever              // температура прямо сейчас
    case coldNoFever        // ОРВИ без температуры
    case anemia             // анемия
    case atopicDermatitis   // атопический дерматит
    case cardioRespiratory  // кардио/респираторные

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fever:             return L10n.text("Температура сейчас")
        case .coldNoFever:       return L10n.text("ОРВИ без температуры")
        case .anemia:            return L10n.text("Анемия")
        case .atopicDermatitis:  return L10n.text("Атопический дерматит")
        case .cardioRespiratory: return L10n.text("Кардио/дыхательные")
        }
    }

    /// Что условие меняет в расчёте — см. TOGCalculator.healthDelta (§4.5).
    var note: String {
        switch self {
        case .fever:             return L10n.text("−0.5 TOG, не перегревать")
        case .coldNoFever:       return L10n.text("предупреждение на прогулке")
        case .anemia:            return L10n.text("+0.3 TOG — мёрзнет быстрее")
        case .atopicDermatitis:  return L10n.text("фильтр тканей в гардеробе")
        case .cardioRespiratory: return L10n.text("строже пороги «не гулять»")
        }
    }

    var icon: String {
        switch self {
        case .fever:             return "thermometer.high"
        case .coldNoFever:       return "facemask.fill"
        case .anemia:            return "drop.fill"
        case .atopicDermatitis:  return "allergens"
        case .cardioRespiratory: return "lungs.fill"
        }
    }
}

// MARK: - BabyActivityLevel §4.4 (TOG pipeline — new spec)

enum BabyActivityLevel: String, Codable, CaseIterable, Sendable {
    case sleeping           // спит в коляске (метаболизм снижен)
    case calmAwake          // спокойно бодрствует
    case activeInStroller   // активен в коляске (машет руками, 8+ мес)
    case walkingCrawling    // сам ходит/ползает на улице

    var label: String {
        switch self {
        case .sleeping:         return L10n.text("Спит")
        case .calmAwake:        return L10n.text("Бодрствует")
        case .activeInStroller: return L10n.text("Активен в коляске")
        case .walkingCrawling:  return L10n.text("Ходит/ползает")
        }
    }

    var icon: String {
        switch self {
        case .sleeping:         return "moon.zzz.fill"
        case .calmAwake:        return "face.smiling"
        case .activeInStroller: return "figure.wave"
        case .walkingCrawling:  return "figure.walk"
        }
    }
}

// MARK: - TempBand §8 (temperature band for personal TOG offset)

enum TempBand: String, Codable, CaseIterable, Sendable {
    case cold   // T_micro < 10
    case mild   // 10 ≤ T_micro ≤ 22
    case hot    // T_micro > 22

    init(tMicro: Double) {
        if tMicro < 10 { self = .cold }
        else if tMicro <= 22 { self = .mild }
        else { self = .hot }
    }
}

// MARK: - HealthFeature

enum HealthFeature: String, Codable, CaseIterable, Identifiable, Hashable {
    case frequentIllness = "frequent_illness"  // часто болеет → одевать теплее
    case coldSensitive   = "cold_sensitive"    // аллергия/реакция на холод
    case premature       = "premature"         // недоношенный → как младший возраст
    case heatSensitive   = "heat_sensitive"    // плохо переносит жару

    var id: String { rawValue }

    var label: String {
        switch self {
        case .frequentIllness: return L10n.text("Часто болеет")
        case .coldSensitive:   return L10n.text("Реакция на холод")
        case .premature:       return L10n.text("Недоношенный")
        case .heatSensitive:   return L10n.text("Плохо переносит жару")
        }
    }

    var description: String {
        switch self {
        case .frequentIllness: return L10n.text("−1.5° к порогу одевания")
        case .coldSensitive:   return L10n.text("−2° к порогу одевания")
        case .premature:       return L10n.text("−2° к порогу одевания")
        case .heatSensitive:   return L10n.text("+1.5° к порогу одевания")
        }
    }

    var icon: String {
        switch self {
        case .frequentIllness: return "cross.case.fill"
        case .coldSensitive:   return "thermometer.snowflake"
        case .premature:       return "heart.fill"
        case .heatSensitive:   return "thermometer.sun.fill"
        }
    }

    var color: String { // used in UI accent
        switch self {
        case .frequentIllness: return "red"
        case .coldSensitive:   return "blue"
        case .premature:       return "pink"
        case .heatSensitive:   return "orange"
        }
    }

    /// Поправка к effectiveTemp: отрицательная → одеть теплее.
    var temperatureAdjustment: Double {
        switch self {
        case .frequentIllness: return -1.5
        case .coldSensitive:   return -2.0
        case .premature:       return -2.0
        case .heatSensitive:   return +1.5
        }
    }
}

// MARK: - WalkType

enum WalkType: String, Codable, CaseIterable, Identifiable, Sendable {
    case short   = "short"    // ≤ 30 мин
    case regular = "regular"  // ~ 1 час
    case long    = "long"     // 2+ часа
    case park    = "park"     // парк / лес

    var id: String { rawValue }

    var label: String {
        switch self {
        case .short:   return L10n.text("Короткая")
        case .regular: return L10n.text("Обычная")
        case .long:    return L10n.text("Долгая")
        case .park:    return L10n.text("Парк / лес")
        }
    }

    var detail: String {
        switch self {
        case .short:   return L10n.text("до 30 мин")
        case .regular: return L10n.text("около 1 часа")
        case .long:    return L10n.text("2+ часа")
        case .park:    return L10n.text("ветер, влажность")
        }
    }

    var icon: String {
        switch self {
        case .short:   return "timer"
        case .regular: return "figure.walk"
        case .long:    return "figure.hiking"
        case .park:    return "leaf.fill"
        }
    }

    /// Поправка к effectiveTemp.
    var temperatureAdjustment: Double {
        switch self {
        case .short:   return +1.0   // недолго → чуть теплее воспринимает
        case .regular: return  0.0
        case .long:    return -1.5   // долго на улице → нужен запас тепла
        case .park:    return -1.0   // ветер и влажность в парке/лесу
        }
    }
}

// MARK: - ActivityLevel

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case low      = "Низкая"      // в коляске, дремлет
    case moderate = "Умеренная"   // спокойно играет
    case high     = "Высокая"     // активно бегает

    var id: String { rawValue }

    var label: String { L10n.text(rawValue) }

    /// Поправка к температуре ощущений (°C).
    /// Высокая активность → сам греется → воспринимает как теплее.
    var temperatureAdjustment: Double {
        switch self {
        case .low:      return -2.0
        case .moderate: return  0.0
        case .high:     return +3.0
        }
    }

    var icon: String {
        switch self {
        case .low:      return "tortoise.fill"
        case .moderate: return "figure.walk"
        case .high:     return "figure.run"
        }
    }
}

// MARK: - StrollerType

/// Конструктивный тип коляски — влияет на тепловое сопротивление корпуса
/// и безопасность нахождения ребёнка.
/// Source: Алгоритм одевания младенца, стр. 5 — таблица ΔCLO колясок.
enum StrollerType: String, Codable, CaseIterable, Identifiable {
    case open        = "open"        // прогулочный блок, открытый капор
    case deepWinter  = "deep_winter" // глубокая закрытая люлька
    case covered     = "covered"     // накрыта дождевиком / плотной накидкой

    var id: String { rawValue }

    var label: String {
        switch self {
        case .open:       return L10n.text("Открытая")
        case .deepWinter: return L10n.text("Закрытая люлька")
        case .covered:    return L10n.text("Накрыта накидкой")
        }
    }

    var detail: String {
        switch self {
        case .open:       return L10n.text("обычный капор")
        case .deepWinter: return L10n.text("корпус сам греет")
        case .covered:    return L10n.text("ОПАСНО: парниковый эффект")
        }
    }

    var icon: String {
        switch self {
        case .open:       return "stroller"
        case .deepWinter: return "thermometer.snowflake"
        case .covered:    return "exclamationmark.triangle.fill"
        }
    }

    // Source: Алгоритм одевания младенца, стр. 5
    // Глубокая зимняя люлька добавляет тепловое сопротивление корпуса →
    // ребёнок ощущает температуру выше, нужно меньше слоёв одежды.
    var effectiveTempAdjustment: Double {
        switch self {
        case .open:       return  0.0
        case .deepWinter: return +3.0
        case .covered:    return  0.0  // расчёт блокируется на уровне View
        }
    }

    /// Требует показа красного алерта — накрытая коляска опасна для жизни.
    var isSafetyAlarm: Bool { self == .covered }
}

// MARK: - ChildGender

enum ChildGender: String, Codable, CaseIterable, Sendable {
    case boy = "boy"
    case girl = "girl"

    var label: String { self == .boy ? L10n.text("Мальчик") : L10n.text("Девочка") }
    var emoji: String { self == .boy ? "👦" : "👧" }
    var pronoun: String { self == .boy ? L10n.text("он") : L10n.text("она") }
    var pronounCapital: String { self == .boy ? L10n.text("Он") : L10n.text("Она") }
}

struct ChildProfile: Equatable {
    static let currentSchemaVersion = 2

    var thermalProfile: ChildThermalProfile

    // These compatibility fields are kept only for the isolated legacy engine
    // and decoding old call sites. They are never persisted in schema v2 and
    // are not consumed by the main recommendation pipeline.
    var activityLevel: ActivityLevel = .moderate
    var walkType: WalkType = .regular
    var strollerType: StrollerType = .open
    var healthConditions: Set<HealthCondition> = []
    var babyActivityLevel: BabyActivityLevel = .calmAwake

    init(name: String, gender: ChildGender, birthday: Date) {
        thermalProfile = ChildThermalProfile(
            name: name,
            gender: gender,
            birthday: birthday
        )
    }

    // MARK: - Stable profile forwarding

    var name: String {
        get { thermalProfile.name }
        set { thermalProfile.name = newValue }
    }

    var gender: ChildGender {
        get { thermalProfile.gender }
        set { thermalProfile.gender = newValue }
    }

    var birthday: Date {
        get { thermalProfile.birthday }
        set { thermalProfile.birthday = newValue }
    }

    var gestationalAgeWeeks: Int {
        get { thermalProfile.gestationalAgeWeeks }
        set { thermalProfile.gestationalAgeWeeks = min(max(newValue, 22), 40) }
    }

    var temperaturePreferenceOffset: Double {
        get { thermalProfile.temperaturePreferenceOffset }
        set { thermalProfile.temperaturePreferenceOffset = min(max(newValue, -3), 3) }
    }

    var stableTraits: Set<StableThermalTrait> {
        get { thermalProfile.stableTraits }
        set { thermalProfile.stableTraits = newValue }
    }

    // MARK: - Legacy stable-feature bridge

    var healthFeatures: Set<HealthFeature> {
        get {
            var features: Set<HealthFeature> = []
            if stableTraits.contains(.frequentIllness) { features.insert(.frequentIllness) }
            if stableTraits.contains(.coldSensitive) { features.insert(.coldSensitive) }
            if stableTraits.contains(.heatSensitive) { features.insert(.heatSensitive) }
            if gestationalAgeWeeks < 37 { features.insert(.premature) }
            return features
        }
        set {
            stableTraits.subtract([.frequentIllness, .coldSensitive, .heatSensitive])
            if newValue.contains(.frequentIllness) { stableTraits.insert(.frequentIllness) }
            if newValue.contains(.coldSensitive) { stableTraits.insert(.coldSensitive) }
            if newValue.contains(.heatSensitive) { stableTraits.insert(.heatSensitive) }
            if newValue.contains(.premature), gestationalAgeWeeks == 40 {
                gestationalAgeWeeks = 36
            }
        }
    }

    var healthTemperatureAdjustment: Double {
        healthFeatures.map(\.temperatureAdjustment).reduce(0, +)
    }

    // MARK: - Age forwarding

    var usesStroller: Bool { thermalProfile.usesStroller }
    var isNewbornPeriod: Bool { thermalProfile.isNewbornPeriod }
    var ageComponents: DateComponents { thermalProfile.ageComponents }
    var ageYears: Int { thermalProfile.ageYears }
    var ageMonths: Int { thermalProfile.ageMonths }
    var ageLabel: String { thermalProfile.ageLabel }
    var chronologicalAgeWeeks: Int { thermalProfile.chronologicalAgeWeeks }
    var correctedAgeWeeks: Int { thermalProfile.correctedAgeWeeks }
    var chronologicalAgeMonths: Int { thermalProfile.chronologicalAgeMonths }
    var ageGroup: AgeGroup { thermalProfile.ageGroup }
}

// MARK: - Codable migration

extension ChildProfile: Codable {
    enum CodingKeys: String, CodingKey {
        case schemaVersion, thermalProfile
        case name, gender, birthday, activityLevel, walkType, healthFeatures
        case temperaturePreferenceOffset, strollerType
        case gestationalAgeWeeks, healthConditions, babyActivityLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let thermalProfile = try container.decodeIfPresent(
            ChildThermalProfile.self,
            forKey: .thermalProfile
        ) {
            self.thermalProfile = thermalProfile
            return
        }

        let name = try container.decode(String.self, forKey: .name)
        let gender = try container.decode(ChildGender.self, forKey: .gender)
        let birthday = try container.decode(Date.self, forKey: .birthday)
        let legacyFeatures = try container.decodeIfPresent(
            Set<HealthFeature>.self,
            forKey: .healthFeatures
        ) ?? []
        let legacyConditions = try container.decodeIfPresent(
            Set<HealthCondition>.self,
            forKey: .healthConditions
        ) ?? []
        var gestationalWeeks = try container.decodeIfPresent(
            Int.self,
            forKey: .gestationalAgeWeeks
        ) ?? 40
        if legacyFeatures.contains(.premature), gestationalWeeks == 40 {
            gestationalWeeks = 36
        }

        var traits: Set<StableThermalTrait> = []
        if legacyFeatures.contains(.frequentIllness) { traits.insert(.frequentIllness) }
        if legacyFeatures.contains(.coldSensitive) { traits.insert(.coldSensitive) }
        if legacyFeatures.contains(.heatSensitive) { traits.insert(.heatSensitive) }
        if legacyConditions.contains(.anemia) { traits.insert(.anemia) }
        if legacyConditions.contains(.atopicDermatitis) { traits.insert(.atopicDermatitis) }
        if legacyConditions.contains(.cardioRespiratory) { traits.insert(.cardioRespiratory) }

        thermalProfile = ChildThermalProfile(
            name: name,
            gender: gender,
            birthday: birthday,
            gestationalAgeWeeks: gestationalWeeks,
            stableTraits: traits,
            temperaturePreferenceOffset: try container.decodeIfPresent(
                Double.self,
                forKey: .temperaturePreferenceOffset
            ) ?? 0
        )
        // Acute illness and the previous walk setup are intentionally discarded.
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(thermalProfile, forKey: .thermalProfile)
    }
}

enum AgeGroup: Equatable, Sendable {
    case infant      // 0–5 мес: не регулирует температуру, перегревается и мёрзнет быстро
    case baby        // 6–11 мес: начинает двигаться, но ещё очень уязвим
    case toddler     // 1–3 года: активный, но не может сообщить о дискомфорте
    case preschool   // 3–6 лет: много бегает, разогревается, но мёрзнут руки/ноги
    case schoolAge   // 6–12 лет: близко к взрослому восприятию
    case teen        // 12+: как взрослый

    // Поправка к комфортной температуре: насколько холоднее ребёнок ощущает по сравнению с взрослым
    var temperatureOffset: Double {
        switch self {
        case .infant:    return -5   // нужно на 5° теплее
        case .baby:      return -4
        case .toddler:   return -3
        case .preschool: return -2
        case .schoolAge: return -1
        case .teen:      return 0
        }
    }

    var description: String {
        switch self {
        case .infant:    return L10n.text("До 6 месяцев")
        case .baby:      return L10n.text("6–12 месяцев")
        case .toddler:   return L10n.text("1–3 года")
        case .preschool: return L10n.text("3–6 лет")
        case .schoolAge: return L10n.text("6–12 лет")
        case .teen:      return L10n.text("12+ лет")
        }
    }
}

// MARK: - Russian declension

enum RussianCase {
    case nominative   // Маша, Иван
    case accusative   // Одеваем Машу, Ивана
    case dative       // Маше холодно, Ивану тепло
    case genitive     // Для Маши, Ивана
}

extension ChildProfile {
    func name(_ grammaticalCase: RussianCase) -> String {
        name.declined(to: grammaticalCase, gender: gender)
    }
}

extension String {
    // Склоняет имя по падежу с учётом пола.
    // Покрывает все распространённые русские имена и большинство иностранных.
    func declined(to grammaticalCase: RussianCase, gender: ChildGender) -> String {
        guard Locale.current.language.languageCode?.identifier == "ru" else { return self }
        guard grammaticalCase != .nominative, !isEmpty, let last = self.last else { return self }

        switch last {

        // Имена на «а»: Маша, Алина, Никита, Серёжа, Данила
        case "а":
            switch grammaticalCase {
            case .accusative: return dropLast() + "у"   // Машу / Алину
            case .dative:     return dropLast() + "е"   // Маше / Алине
            case .genitive:
                // После ж/ш/щ/ч/г/к/х пишем «и» (Маши, Саши),
                // после остальных твёрдых согласных — «ы» (Алины, Никиты)
                let softeners: Set<Character> = ["ж","ш","щ","ч","г","к","х"]
                let suffix = dropLast().last.map { softeners.contains($0) ? "и" : "ы" } ?? "и"
                return dropLast() + suffix
            case .nominative: return self
            }

        // Имена на «я»: Оля, Катя, Коля, Илья, Дарья, Вася
        case "я":
            switch grammaticalCase {
            case .accusative: return dropLast() + "ю"   // Олю / Илью
            case .dative:     return dropLast() + "е"   // Оле / Илье / Дарье
            case .genitive:   return dropLast() + "и"   // Оли / Ильи / Дарьи
            case .nominative: return self
            }

        // Мужские имена на «й»: Андрей, Сергей, Алексей, Николай, Тимофей
        case "й" where gender == .boy:
            switch grammaticalCase {
            case .accusative, .genitive: return dropLast() + "я"  // Андрея
            case .dative:                return dropLast() + "ю"  // Андрею
            case .nominative:            return self
            }

        // Мягкий знак — зависит от пола
        case "ь":
            if gender == .boy {
                // Игорь, Фёдор… (редко)
                switch grammaticalCase {
                case .accusative, .genitive: return dropLast() + "я"  // Игоря
                case .dative:                return dropLast() + "ю"  // Игорю
                case .nominative:            return self
                }
            } else {
                // Любовь, Адель — 3-е склонение
                switch grammaticalCase {
                case .accusative:            return self            // = именительный
                case .dative, .genitive:     return dropLast() + "и"
                case .nominative:            return self
                }
            }

        // Мужские имена на согласную: Иван, Максим, Кирилл, Павел, Тимур, Арсений…
        default:
            if gender == .boy {
                switch grammaticalCase {
                case .accusative, .genitive: return self + "а"   // Ивана
                case .dative:                return self + "у"   // Ивану
                case .nominative:            return self
                }
            }
            // Иностранные женские на согласную (Элис, Жасмин) — несклоняемые
            return self
        }
    }

    // dropLast(1) вызывает BidirectionalCollection.dropLast(_:), не этот метод
    private func dropLast() -> String { String(self.dropLast(1)) }
}

// MARK: - App Group shared store
// ⚠️  Добавьте этот файл (ChildProfile.swift) также в таргет «SkyKidWidget»
//     через Target Membership в инспекторе файла в Xcode.
//     Оба таргета должны иметь capability «App Groups» с ID: group.com.skykid.app

enum AppGroup {
    static let suiteName = "group.com.skykid.app"

    // nonisolated(unsafe): UserDefaults — thread-safe, unsafe здесь означает только
    // «компилятор не проверяет», но Sendable-семантика соблюдается платформой.
    nonisolated(unsafe) static let defaults: UserDefaults =
        UserDefaults(suiteName: suiteName) ?? .standard

    // MARK: Child Profile

    static let profileKey = "child_profile"

    static func saveProfile(_ profile: ChildProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: profileKey)
    }

    static func loadProfile() -> ChildProfile? {
        guard let data = defaults.data(forKey: profileKey) else { return nil }
        return try? JSONDecoder().decode(ChildProfile.self, from: data)
    }

    static func deleteProfile() {
        defaults.removeObject(forKey: profileKey)
    }

    // MARK: Weather Cache
    // Записывается WeatherViewModel после каждого fetch, читается виджетом.

    private enum WK {
        static let temp    = "wg_temperature"
        static let feels   = "wg_apparent_temp"
        static let code    = "wg_weather_code"
        static let wind    = "wg_wind_speed"
        static let precip  = "wg_precipitation"
        static let city    = "wg_city_name"
        static let updated = "wg_updated_at"
    }

    static func saveWeather(
        temperature: Double, apparentTemp: Double, weatherCode: Int,
        windSpeed: Double, precipitation: Double, cityName: String
    ) {
        let d = defaults
        d.set(temperature,                  forKey: WK.temp)
        d.set(apparentTemp,                 forKey: WK.feels)
        d.set(weatherCode,                  forKey: WK.code)
        d.set(windSpeed,                    forKey: WK.wind)
        d.set(precipitation,                forKey: WK.precip)
        d.set(cityName,                     forKey: WK.city)
        d.set(Date().timeIntervalSince1970, forKey: WK.updated)
    }

    // MARK: Location Cache

    private enum LK {
        static let lat = "wg_latitude"
        static let lon = "wg_longitude"
    }

    static func saveLocation(latitude: Double, longitude: Double) {
        defaults.set(latitude,  forKey: LK.lat)
        defaults.set(longitude, forKey: LK.lon)
    }

    static func loadLastKnownCoordinate() -> CLLocationCoordinate2D? {
        guard defaults.object(forKey: LK.lat) != nil,
              defaults.object(forKey: LK.lon) != nil else { return nil }
        return CLLocationCoordinate2D(
            latitude:  defaults.double(forKey: LK.lat),
            longitude: defaults.double(forKey: LK.lon)
        )
    }

    /// nil если кэш пуст или устарел (> 2 ч). Основной читатель — виджет.
    static func loadCachedWeather() -> CachedWeather? {
        let d = defaults
        guard d.object(forKey: WK.temp)    != nil,
              d.object(forKey: WK.updated) != nil else { return nil }
        let updatedAt = Date(timeIntervalSince1970: d.double(forKey: WK.updated))
        guard Date().timeIntervalSince(updatedAt) < 7_200 else { return nil }
        return cachedWeather(from: d, updatedAt: updatedAt)
    }

    /// Читает кеш без проверки возраста — для виджетного fallback при устаревших данных.
    static func loadCachedWeatherIgnoringAge() -> CachedWeather? {
        let d = defaults
        guard d.object(forKey: WK.temp)    != nil,
              d.object(forKey: WK.updated) != nil else { return nil }
        let updatedAt = Date(timeIntervalSince1970: d.double(forKey: WK.updated))
        return cachedWeather(from: d, updatedAt: updatedAt)
    }

    private static func cachedWeather(from d: UserDefaults, updatedAt: Date) -> CachedWeather {
        CachedWeather(
            temperature:         d.double(forKey:  WK.temp),
            apparentTemperature: d.double(forKey:  WK.feels),
            weatherCode:         d.integer(forKey: WK.code),
            windSpeed:           d.double(forKey:  WK.wind),
            precipitation:       d.double(forKey:  WK.precip),
            cityName:            d.string(forKey:  WK.city) ?? "—",
            updatedAt:           updatedAt
        )
    }

}

// MARK: - Снимок кешированных данных о погоде

struct CachedWeather: Sendable {
    let temperature: Double
    let apparentTemperature: Double
    let weatherCode: Int
    let windSpeed: Double
    let precipitation: Double
    let cityName: String
    let updatedAt: Date
}

// MARK: - Preview mocks

#if DEBUG
extension ChildProfile {
    static var mock: ChildProfile {
        ChildProfile(
            name: "Ваня",
            gender: .boy,
            birthday: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        )
    }
    static var mockInfant: ChildProfile {
        ChildProfile(
            name: "Соня",
            gender: .girl,
            birthday: Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date()
        )
    }
}
#endif
