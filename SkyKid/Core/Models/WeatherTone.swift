import SwiftUI

// MARK: - WeatherTone
// Общий для приложения и виджет-экстеншна (Live Activity): категория погоды
// по коду WMO + опорные цвета. Живёт отдельно от Theme.swift, чтобы не тащить
// в widget target UI-обвязку основного приложения (skyKidBackground и т.п.).

/// Категория погоды для окрашивания живой прогулки — из кода WMO.
enum WeatherTone {
    case sunny, cloudy, overcast, rain, snow

    init(weatherCode: Int?) {
        switch weatherCode ?? 0 {
        case 0:               self = .sunny
        case 1, 2:            self = .cloudy
        case 3, 45, 48:       self = .overcast
        case 71, 73, 75, 77, 85, 86: self = .snow
        case 51...67, 80...82, 95...99: self = .rain
        default:              self = .cloudy
        }
    }

    /// Опорные цвета по ТЗ: солнечно — оранжево-жёлтый, облачно — бело-серый,
    /// пасмурно — серо-тёмно-синий, дождь — тёмно-синий/серый, снег — белый.
    var colors: [Color] {
        switch self {
        case .sunny:
            return [Color(red: 1.00, green: 0.80, blue: 0.35),
                    Color(red: 0.98, green: 0.60, blue: 0.22)]
        case .cloudy:
            return [Color(red: 0.92, green: 0.94, blue: 0.97),
                    Color(red: 0.70, green: 0.74, blue: 0.80)]
        case .overcast:
            return [Color(red: 0.52, green: 0.57, blue: 0.66),
                    Color(red: 0.28, green: 0.33, blue: 0.44)]
        case .rain:
            return [Color(red: 0.24, green: 0.32, blue: 0.46),
                    Color(red: 0.16, green: 0.19, blue: 0.26)]
        case .snow:
            return [Color(red: 0.98, green: 0.99, blue: 1.00),
                    Color(red: 0.80, green: 0.88, blue: 0.96)]
        }
    }

    /// Читаемый цвет текста поверх градиента.
    var onColor: Color {
        switch self {
        case .sunny, .cloudy, .snow: return Color(red: 0.15, green: 0.18, blue: 0.24)
        case .overcast, .rain:       return .white
        }
    }
}

/// Диагональный градиент по погоде — для индикатора активной прогулки
/// (таб-бар, Live Activity). В виджетах используется статично, без анимации.
func weatherGradient(for weatherCode: Int?) -> LinearGradient {
    LinearGradient(
        colors: WeatherTone(weatherCode: weatherCode).colors,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
