import SwiftUI

// MARK: - WardrobeAlternativesCard

struct WardrobeAlternativesCard: View {
    let alternatives: [RecommendedLayer]
    let fit: OutfitFit?
    let severity: SafetyWarning.Severity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "arrow.triangle.swap")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Text(intro)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(alternatives) { alternative in
                alternativeRow(alternative)
            }

            Text(fallbackAdvice)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("outfit.wardrobeAlternatives")
    }

    // MARK: - Rows

    private func alternativeRow(_ alternative: RecommendedLayer) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: alternative.systemImage)
                .foregroundStyle(tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(alternative.name)
                    .font(.subheadline.weight(.medium))
                Text(substitutionHint(for: alternative))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Advice

    private var title: String {
        alternatives.isEmpty
            ? L10n.text("Ближайший доступный комплект")
            : L10n.text("Чем можно улучшить комплект")
    }

    private var intro: String {
        alternatives.isEmpty
            ? L10n.text("Гардероб не позволяет точно попасть в расчётную цель, поэтому показан ближайший совместимый вариант.")
            : L10n.text("Это варианты замены, а не обязательный список покупок.")
    }

    private var tint: Color {
        switch severity {
        case .danger, .blocked: return .red
        case .caution:         return .orange
        case .info:            return .blue
        }
    }

    private var fallbackAdvice: String {
        guard let fit else {
            return L10n.text("Если аналога нет, особенно внимательно проверьте открытые участки тела после выхода.")
        }
        if fit.deltaTOG < 0 {
            return L10n.text("Если аналога нет, выберите более короткую прогулку и проверьте живот или заднюю поверхность шеи через 10 минут.")
        }
        return L10n.text("Если аналога нет, используйте ближайший доступный вариант и снимите один лёгкий слой при влажной горячей коже.")
    }

    private func substitutionHint(for alternative: RecommendedLayer) -> String {
        guard let layer = GarmentCatalog.byID[alternative.id]?.layer else {
            return L10n.text("Подойдёт вещь с тем же назначением и похожей плотностью.")
        }

        switch layer {
        case .baseFull, .baseTop, .baseBottom:
            return L10n.text("Можно заменить другим базовым слоем похожей плотности.")
        case .midFull, .midTop, .midBottom:
            return L10n.text("Можно заменить флисовым или шерстяным средним слоем похожей плотности.")
        case .outerwear:
            return L10n.text("Можно заменить верхней одеждой того же сезона без второго объёмного слоя.")
        case .accessory:
            return L10n.text("Можно заменить аксессуаром, который закрывает ту же часть тела.")
        case .sleepwear:
            return L10n.text("Используйте только подходящую для прогулки альтернативу из гардероба.")
        }
    }
}
