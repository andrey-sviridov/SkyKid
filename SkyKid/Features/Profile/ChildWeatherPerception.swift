import Foundation

struct ChildWeatherPerception {
    let profile: ChildProfile
    let weather: NormalizedWeather
    /// Если передана явно (из outfit.effectiveTemp) — используется как есть.
    /// По умолчанию — apparentTemp + ageOffset (простая формула для вкладки «Погода»).
    private let _effectiveTemp: Double?

    init(profile: ChildProfile, weather: NormalizedWeather, effectiveTemp: Double? = nil) {
        self.profile = profile
        self.weather = weather
        self._effectiveTemp = effectiveTemp
    }

    var effectiveFeelsLike: Double {
        _effectiveTemp ?? (weather.apparentTemperature + profile.ageGroup.temperatureOffset)
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
            parts.append(
                L10n.format(
                    "%@ сейчас очень холодно — %@ мёрзнет даже в тёплой одежде",
                    dat,
                    pronoun
                )
            )
        case -15..<(-5):
            parts.append(L10n.format("%@ холодно", dat))
        case -5..<0:
            parts.append(L10n.format("Для %@ прохладно", gen))
        case 0..<8:
            parts.append(L10n.format("Для %@ свежо", gen))
        case 8..<16:
            parts.append(L10n.format("Для %@ комфортно", gen))
        case 16..<22:
            parts.append(L10n.format("%@ будет тепло", dat))
        default:
            parts.append(L10n.format("%@ жарко", dat))
        }

        // Ветер
        if wind > 10 {
            parts.append(
                L10n.format(
                    "сильный ветер (%lld м/с) будет продувать",
                    Int(wind)
                )
            )
        } else if wind > 6 {
            parts.append(L10n.text("ветер добавляет ощущение холода"))
        }

        // Осадки
        let isSnow = (71...77).contains(code)
        if isSnow {
            parts.append(L10n.text("снег на улице"))
        } else if rain > 0.5 {
            parts.append(L10n.text("дождь намочит одежду"))
        } else if rain > 0 {
            parts.append(L10n.text("небольшой дождь"))
        }

        return parts.joined(separator: ", ") + "."
    }

    // Детальное объяснение с учётом возрастной группы
    var ageContextNote: String {
        let name = profile.name
        let group = profile.ageGroup

        switch group {
        case .infant:
            return L10n.format(
                "%@ ещё не умеет самостоятельно регулировать температуру тела — механизм терморегуляции созревает к 3–6 месяцам. Проверяйте шею и спинку: если тёплые — всё хорошо. Холодные ручки у грудничков в норме.",
                name
            )
        case .baby:
            return L10n.format(
                "%@ активно двигается, но ещё не может сказать, что замёрз. Ориентируйтесь на шею и грудку — они тёплые у согретого ребёнка. Ручки и ушки у грудничков холодные в норме.",
                name
            )
        case .toddler:
            return L10n.format(
                "%@ много бегает и разогревается, но быстро остывает, когда остановится. Одевайте слоями — легко снять, если станет жарко.",
                name
            )
        case .preschool:
            return L10n.format(
                "%@ в этом возрасте часто не замечает, что замёрз, пока не начнёт хныкать. Следите за затылком и щёчками — надёжные индикаторы в этом возрасте.",
                name
            )
        case .schoolAge:
            return L10n.format(
                "%@ уже неплохо понимает, когда замёрз, но часто игнорирует — не захочет уходить с прогулки.",
                name
            )
        case .teen:
            return L10n.format(
                "%@ воспринимает температуру примерно как взрослый.",
                name
            )
        }
    }

    var moodSystemImage: String {
        switch effectiveFeelsLike {
        case ..<(-10): return "thermometer.snowflake.circle.fill"
        case -10..<0:  return "thermometer.snowflake"
        case 0..<10:   return "cloud.fill"
        case 10..<20:  return "sun.max.fill"
        default:       return "thermometer.sun.fill"
        }
    }

    var moodColor: (Double, Double, Double) {
        switch effectiveFeelsLike {
        case ..<(-10): return (0.1, 0.3, 0.9)
        case -10..<0:  return (0.3, 0.55, 1.0)
        case 0..<10:   return (0.2, 0.65, 0.9)
        case 10..<20:  return (0.2, 0.78, 0.4)
        default:       return (1.0, 0.45, 0.1)
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
        case 80...100: return L10n.text("Комфортно")
        case 55..<80: return L10n.text("Терпимо")
        case 30..<55: return L10n.text("Прохладно")
        default: return L10n.text("Некомфортно")
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
