import SwiftUI

/// Человекочитаемая оценка комплекта. Числа остаются внутренней деталью расчёта.
struct WalkTOGVerdict {
    let effective: Double
    let target: Double?

    enum Level: Equatable {
        case cold, cool, comfortable, warm, hot, unknown

        var label: String {
            switch self {
            case .cold:        return OutfitFitPresentation.addWarmLayer.label
            case .cool:        return OutfitFitPresentation.addLightLayer.label
            case .comfortable: return OutfitFitPresentation.suitable.label
            case .warm:        return OutfitFitPresentation.removeLightLayer.label
            case .hot:         return OutfitFitPresentation.removeWarmLayer.label
            case .unknown:     return OutfitFitPresentation.unknown.label
            }
        }

        var guidance: String {
            switch self {
            case .cold, .cool:
                return L10n.text("Добавьте слой перед выходом и проверьте ребёнка на прогулке")
            case .comfortable:
                return L10n.text("Проверьте живот или заднюю поверхность шеи через 10–15 минут")
            case .warm, .hot:
                return L10n.text("Снимите слой перед выходом и проверьте ребёнка на прогулке")
            case .unknown:
                return L10n.text("Нет данных для сравнения с рекомендацией")
            }
        }

        var icon: String {
            switch self {
            case .cold:        return "snowflake"
            case .cool:        return "wind"
            case .comfortable: return "checkmark.circle.fill"
            case .warm:        return "sun.max.fill"
            case .hot:         return "flame.fill"
            case .unknown:     return "questionmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .cold:        return .blue
            case .cool:        return .teal
            case .comfortable: return .green
            case .warm:        return .orange
            case .hot:         return .red
            case .unknown:     return .secondary
            }
        }
    }

    /// Внутреннее отклонение набора от цели. nil, если цель неизвестна.
    var delta: Double? {
        guard let target else { return nil }
        return effective - target
    }

    var level: Level {
        guard let delta else { return .unknown }
        switch delta {
        case ..<(-1.0):      return .cold
        case -1.0..<(-0.4):  return .cool
        case -0.4...0.4:     return .comfortable
        case 0.4...1.0:      return .warm
        default:             return .hot
        }
    }

    static func densityLabel(for insulation: Double) -> String {
        switch insulation {
        case ..<0.5: return L10n.text("Лёгкая вещь")
        case ..<1.5: return L10n.text("Средняя по теплоте вещь")
        default:     return L10n.text("Тёплая вещь")
        }
    }
}
