import Foundation

struct OutfitItem: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let reason: String
}

struct OutfitAdvisor {
    static func recommend(weather: WeatherData, profile: ChildProfile? = nil) -> [OutfitItem] {
        var items: [OutfitItem] = []

        // Apply age offset: young children feel colder than adults
        let offset = profile?.ageGroup.temperatureOffset ?? 0
        let t = weather.apparentTemperature + offset
        let wind = weather.windSpeed
        let rain = weather.precipitation
        let code = weather.weatherCode
        let isSnowing = (71...77).contains(code)
        let isRaining = (51...82).contains(code) || rain > 0.1
        let ageGroup = profile?.ageGroup

        // Base clothing by effective temperature
        switch t {
        case ..<(-10):
            items += [
                .init(icon: "🧥", name: "Зимний комбинезон", reason: "Сильный мороз"),
                .init(icon: "🧣", name: "Термобельё", reason: "Доп. тепло при сильном морозе"),
                .init(icon: "🧤", name: "Варежки", reason: "Защита от обморожения"),
                .init(icon: "🎿", name: "Зимняя шапка", reason: "Обязательно в мороз")
            ]
        case -10..<0:
            items += [
                .init(icon: "🧥", name: "Зимняя куртка", reason: "Мороз"),
                .init(icon: "🧤", name: "Перчатки", reason: "Холодно"),
                .init(icon: "🎿", name: "Шапка", reason: "Защита головы")
            ]
        case 0..<5:
            items += [
                .init(icon: "🧥", name: "Тёплая куртка", reason: "Около нуля"),
                .init(icon: "🧤", name: "Перчатки", reason: "Прохладно"),
                .init(icon: "🎿", name: "Шапка", reason: "Прохладная погода")
            ]
        case 5..<15:
            items += [
                .init(icon: "🧥", name: "Куртка", reason: "Прохладно"),
                .init(icon: "👕", name: "Кофта", reason: "Переменчивая погода")
            ]
        case 15..<22:
            items += [
                .init(icon: "🧥", name: "Лёгкая куртка", reason: "Может быть прохладно"),
                .init(icon: "👕", name: "Футболка или кофта", reason: "Комфортная температура")
            ]
        default:
            items += [
                .init(icon: "👕", name: "Лёгкая одежда", reason: "Тепло"),
                .init(icon: "🧢", name: "Панамка / кепка", reason: "Защита от солнца")
            ]
        }

        // Age-specific extras
        if let group = ageGroup {
            switch group {
            case .infant:
                items.insert(.init(icon: "🩱", name: "Боди + конверт", reason: "Малышам до 6 мес нужен дополнительный слой"), at: 0)
            case .baby:
                items.append(.init(icon: "🧦", name: "Тёплые носочки", reason: "Ножки мёрзнут быстрее всего"))
            case .toddler where t < 10:
                items.append(.init(icon: "🧦", name: "Тёплые носки", reason: "Активно двигается — ножки должны быть в тепле"))
            default:
                break
            }

            // Защита шеи при холоде — шарф опасен детям до ~4 лет (риск удушения на площадке)
            if t < 5 {
                switch group {
                case .infant, .baby, .toddler:
                    items.append(.init(icon: "🧣", name: "Бафф / снуд", reason: "Безопаснее шарфа: не зацепится на площадке"))
                case .preschool:
                    items.append(.init(icon: "🧣", name: "Бафф или короткий шарф", reason: "Следите, чтобы не намотался на оборудование"))
                case .schoolAge, .teen:
                    items.append(.init(icon: "🧣", name: "Шарф", reason: "Защита шеи и горла от холодного воздуха"))
                }
            }
        }

        // Wind modifier
        if wind > 7 {
            items.append(.init(icon: "🪬", name: "Ветровка поверх", reason: "Сильный ветер \(Int(wind)) м/с"))
        }

        // Rain / snow
        if isSnowing {
            items.append(.init(icon: "👢", name: "Зимние сапоги", reason: "Снег на улице"))
        } else if isRaining {
            items += [
                .init(icon: "🌂", name: "Дождевик или зонт", reason: "Идёт дождь"),
                .init(icon: "🥾", name: "Резиновые сапоги", reason: "Мокрые дороги")
            ]
        }

        return items
    }
}
