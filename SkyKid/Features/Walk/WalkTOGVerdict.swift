import SwiftUI

/// Вердикт «жарко/холодно» по суммарному TOG набора относительно целевого TOG.
struct WalkTOGVerdict {
    let effective: Double
    let target: Double?

    enum Level {
        case cold, cool, comfortable, warm, hot

        var label: String {
            switch self {
            case .cold:        return L10n.text("Замёрзнет")
            case .cool:        return L10n.text("Прохладно")
            case .comfortable: return L10n.text("Комфортно")
            case .warm:        return L10n.text("Тепловато")
            case .hot:         return L10n.text("Перегрев")
            }
        }

        var icon: String {
            switch self {
            case .cold:        return "snowflake"
            case .cool:        return "wind"
            case .comfortable: return "checkmark.circle.fill"
            case .warm:        return "sun.max.fill"
            case .hot:         return "flame.fill"
            }
        }

        var color: Color {
            switch self {
            case .cold:        return .blue
            case .cool:        return .teal
            case .comfortable: return .green
            case .warm:        return .orange
            case .hot:         return .red
            }
        }
    }

    /// Отклонение набора от цели (TOG). nil, если цель неизвестна.
    var delta: Double? {
        guard let target else { return nil }
        return effective - target
    }

    var level: Level {
        guard let delta else { return .comfortable }
        switch delta {
        case ..<(-1.0):      return .cold
        case -1.0..<(-0.4):  return .cool
        case -0.4...0.4:     return .comfortable
        case 0.4...1.0:      return .warm
        default:             return .hot
        }
    }
}
