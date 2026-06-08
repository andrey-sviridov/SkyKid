import Foundation

struct ChildWeatherPerception {
    let profile: ChildProfile
    let weather: WeatherData

    // Эффективная температура с поправкой на возраст
    var effectiveFeelsLike: Double {
        weather.apparentTemperature + profile.ageGroup.temperatureOffset
    }

    // Главное: как ребёнок сейчас чувствует погоду — одним предложением
    var summary: String {
        let dat = profile.name(.dative)    // Маше / Ивану
        let gen = profile.name(.genitive)  // Маши / Ивана
        let t = effectiveFeelsLike
        let wind = weather.windSpeed
        let rain = weather.precipitation
        let code = weather.weatherCode
        let pronoun = profile.gender.pronoun

        var parts: [String] = []

        // Базовое ощущение температуры
        switch t {
        case ..<(-15):
            parts.append("\(dat) сейчас очень холодно — \(pronoun) мёрзнет даже в тёплой одежде")
        case -15..<(-5):
            parts.append("\(dat) холодно")
        case -5..<0:
            parts.append("Для \(gen) прохладно")
        case 0..<8:
            parts.append("Для \(gen) свежо")
        case 8..<16:
            parts.append("Для \(gen) комфортно")
        case 16..<22:
            parts.append("\(dat) будет тепло")
        default:
            parts.append("\(dat) жарко")
        }

        // Ветер
        if wind > 10 {
            parts.append("сильный ветер (\(Int(wind)) м/с) будет продувать")
        } else if wind > 6 {
            parts.append("ветер добавляет ощущение холода")
        }

        // Осадки
        let isSnow = (71...77).contains(code)
        if isSnow {
            parts.append("снег на улице")
        } else if rain > 0.5 {
            parts.append("дождь намочит одежду")
        } else if rain > 0 {
            parts.append("небольшой дождь")
        }

        return parts.joined(separator: ", ") + "."
    }

    // Детальное объяснение с учётом возрастной группы
    var ageContextNote: String {
        let name = profile.name
        let group = profile.ageGroup

        switch group {
        case .infant:
            return "\(name) ещё не умеет самостоятельно регулировать температуру тела — механизм терморегуляции созревает к 3–6 месяцам. Проверяйте шею и спинку: если тёплые — всё хорошо. Холодные ручки у грудничков в норме."
        case .baby:
            return "\(name) активно двигается, но ещё не может сказать, что замёрз. Ориентируйтесь на шею и грудку — они тёплые у согретого ребёнка. Ручки и ушки у грудничков холодные в норме."
        case .toddler:
            return "\(name) много бегает и разогревается, но быстро остывает, когда остановится. Одевайте слоями — легко снять, если станет жарко."
        case .preschool:
            return "\(name) в этом возрасте часто не замечает, что замёрз, пока не начнёт хныкать. Следите за затылком и щёчками — надёжные индикаторы в этом возрасте."
        case .schoolAge:
            return "\(name) уже неплохо понимает, когда замёрз, но часто игнорирует — не захочет уходить с прогулки."
        case .teen:
            return "\(name) воспринимает температуру примерно как взрослый."
        }
    }

    // Иконка настроения
    var moodEmoji: String {
        switch effectiveFeelsLike {
        case ..<(-10): return "🥶"
        case -10..<0:  return "😬"
        case 0..<10:   return "😐"
        case 10..<20:  return "😊"
        default:       return "🥵"
        }
    }

    // Шкала комфорта 0–100
    var comfortScore: Int {
        let t = effectiveFeelsLike
        switch t {
        case ..<(-15): return 5
        case -15..<(-5): return 20
        case -5..<0: return 40
        case 0..<5: return 60
        case 5..<12: return 80
        case 12..<22: return 100
        case 22..<28: return 85
        default: return 50
        }
    }

    var comfortLabel: String {
        switch comfortScore {
        case 80...100: return "Комфортно"
        case 55..<80: return "Терпимо"
        case 30..<55: return "Прохладно"
        default: return "Некомфортно"
        }
    }

    var comfortColor: (Double, Double, Double) { // r, g, b 0-1
        switch comfortScore {
        case 80...100: return (0.2, 0.8, 0.4)
        case 55..<80: return (1.0, 0.75, 0.0)
        case 30..<55: return (1.0, 0.45, 0.1)
        default: return (0.8, 0.1, 0.2)
        }
    }
}
