import Foundation

enum ShareOutfitComposer {
    static func compose(
        summary: OutfitParentSummary,
        childName: String?,
        weather: NormalizedWeather?,
        weatherUpdatedAt: Date?,
        walkContext: WalkContext?,
        now: Date = .now
    ) -> String {
        var lines = [title(childName: childName), summary.outfit]
        if let weather {
            lines.append(L10n.format(
                "Погода: %.0f°C, %@",
                weather.temperature,
                weather.conditionDescription
            ))
        }
        lines.append(freshnessLine(updatedAt: weatherUpdatedAt, now: now))
        if let walkContext {
            lines.append(L10n.format("Сценарий: %@", walkContext.transportMode.walkLabel))
        } else {
            lines.append(L10n.text("Сценарий прогулки не указан"))
        }
        lines.append(L10n.format("Почему: %@", summary.reason))
        lines.append(summary.check)
        return lines.joined(separator: "\n")
    }

    static func compose(summary: OutfitParentSummary) -> String {
        [
            title(childName: nil),
            summary.outfit,
            L10n.text("Погодный контекст не указан"),
            L10n.text("Сценарий прогулки не указан"),
            L10n.format("Почему: %@", summary.reason),
            summary.check,
        ].joined(separator: "\n")
    }

    private static func title(childName: String?) -> String {
        guard let name = childName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return L10n.text("Рекомендация SkyKid") }
        return L10n.format("Рекомендация SkyKid для %@", name)
    }

    private static func freshnessLine(updatedAt: Date?, now: Date) -> String {
        guard let updatedAt else { return L10n.text("Актуальность погоды неизвестна") }
        switch RecommendationFreshnessPolicy(now: now).state(for: updatedAt) {
        case .fresh: return L10n.text("Погода актуальна на момент расчёта")
        case .stale: return L10n.text("Погода могла устареть — обновите перед выходом")
        case .unavailable: return L10n.text("Актуальность погоды неизвестна")
        }
    }
}
