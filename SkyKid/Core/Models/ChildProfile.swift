import Foundation

enum ChildGender: String, Codable, CaseIterable {
    case boy = "boy"
    case girl = "girl"

    var label: String { self == .boy ? "Мальчик" : "Девочка" }
    var emoji: String { self == .boy ? "👦" : "👧" }
    var pronoun: String { self == .boy ? "он" : "она" }
    var pronounCapital: String { self == .boy ? "Он" : "Она" }
}

struct ChildProfile: Codable, Equatable {
    var name: String
    var gender: ChildGender
    var birthday: Date

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

    // Вспомогательный метод для String.dropLast() → String
    private func dropLast() -> String { String(self.dropLast()) }
}

// MARK: - Persistence

final class ChildProfileStore: @unchecked Sendable {
    static let shared = ChildProfileStore()
    private let key = "child_profile"

    var profile: ChildProfile? {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(ChildProfile.self, from: data)
        }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
}
