import Foundation
import CoreLocation

// MARK: - ActivityLevel

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case low      = "Низкая"      // в коляске, дремлет
    case moderate = "Умеренная"   // спокойно играет
    case high     = "Высокая"     // активно бегает

    var id: String { rawValue }

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

// MARK: - ChildGender

enum ChildGender: String, Codable, CaseIterable {
    case boy = "boy"
    case girl = "girl"

    var label: String { self == .boy ? "Мальчик" : "Девочка" }
    var emoji: String { self == .boy ? "👦" : "👧" }
    var pronoun: String { self == .boy ? "он" : "она" }
    var pronounCapital: String { self == .boy ? "Он" : "Она" }
}

struct ChildProfile: Equatable {
    var name: String
    var gender: ChildGender
    var birthday: Date
    /// Уровень физической активности ребёнка во время прогулки.
    var activityLevel: ActivityLevel = .moderate
    /// Накопленный сдвиг предпочтений (°C), изменяется через `ClothingRecommendationEngine.adjustPreferences`.
    var temperaturePreferenceOffset: Double = 0.0

    var ageComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month], from: birthday, to: Date())
    }

    var ageYears: Int { ageComponents.year ?? 0 }
    var ageMonths: Int { ageComponents.month ?? 0 }

    var ageLabel: String {
        let y = ageYears
        let m = ageMonths
        if y == 0 {
            return "\(m) \(monthWord(m))"
        } else if m == 0 {
            return "\(y) \(yearWord(y))"
        } else {
            return "\(y) \(yearWord(y)) \(m) \(monthWord(m))"
        }
    }

    var ageGroup: AgeGroup {
        let totalMonths = ageYears * 12 + ageMonths
        switch totalMonths {
        case 0..<6:   return .infant
        case 6..<12:  return .baby
        case 12..<36: return .toddler
        case 36..<72: return .preschool
        case 72..<144: return .schoolAge
        default:      return .teen
        }
    }

    private func yearWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod100 >= 11 && mod100 <= 19 { return "лет" }
        switch mod10 {
        case 1: return "год"
        case 2, 3, 4: return "года"
        default: return "лет"
        }
    }

    private func monthWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod100 >= 11 && mod100 <= 19 { return "месяцев" }
        switch mod10 {
        case 1: return "месяц"
        case 2, 3, 4: return "месяца"
        default: return "месяцев"
        }
    }
}

// MARK: - Codable (backward-compatible: новые поля имеют дефолты при отсутствии в JSON)

extension ChildProfile: Codable {
    enum CodingKeys: String, CodingKey {
        case name, gender, birthday, activityLevel, temperaturePreferenceOffset
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name     = try c.decode(String.self,      forKey: .name)
        gender   = try c.decode(ChildGender.self, forKey: .gender)
        birthday = try c.decode(Date.self,        forKey: .birthday)
        activityLevel              = (try? c.decode(ActivityLevel.self, forKey: .activityLevel))              ?? .moderate
        temperaturePreferenceOffset = (try? c.decode(Double.self, forKey: .temperaturePreferenceOffset))       ?? 0.0
    }
}

enum AgeGroup {
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
        case .infant:    return "До 6 месяцев"
        case .baby:      return "6–12 месяцев"
        case .toddler:   return "1–3 года"
        case .preschool: return "3–6 лет"
        case .schoolAge: return "6–12 лет"
        case .teen:      return "12+ лет"
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

