import SwiftUI

// MARK: - ThermalLearningCard

struct ThermalLearningCard: View {
    let insights: WalkHistoryInsights

    var body: some View {
        SectionCard(
            title: L10n.text("Что SkyKid узнал"),
            systemImage: "sparkles"
        ) {
            Label(insights.similarWalkCountText, systemImage: "figure.walk")
                .font(.subheadline.weight(.semibold))

            Text(insights.comfortPattern)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let clothingPattern = insights.clothingPattern {
                Label(clothingPattern, systemImage: "tshirt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Text(insights.adaptation)
                .font(.subheadline.weight(.medium))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("history.thermalLearning")
    }

    private var accessibilitySummary: String {
        [
            L10n.text("Что SkyKid узнал"),
            insights.similarWalkCountText,
            insights.comfortPattern,
            insights.clothingPattern,
            insights.adaptation
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }
}
