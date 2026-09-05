import SwiftUI

// MARK: - WalkHistoryInsightsCard

/// One quiet overview above the journal. It appears only after enough data is
/// available to make the numbers useful.
struct WalkHistoryInsightsCard: View {
    let insights: WalkHistoryInsights

    var body: some View {
        SectionCard(
            title: L10n.text("Последние 7 дней"),
            systemImage: "chart.bar.xaxis"
        ) {
            Text(L10n.text("По вашим отметкам"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                metric(
                    value: String(insights.walkCount),
                    label: L10n.text("Прогулок")
                )

                Divider().frame(height: 42)

                metric(
                    value: WalkDurationFormatter.string(minutes: insights.averageDurationMinutes),
                    label: L10n.text("Средняя прогулка")
                )

                Divider().frame(height: 42)

                metric(
                    value: sleepValue,
                    label: L10n.text("Сон всего")
                )

                Divider().frame(height: 42)

                metric(
                    value: L10n.format("%lld%%", insights.comfortablePercent),
                    label: L10n.text("Комфортно")
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("history.insights")
    }

    private var sleepValue: String {
        guard let minutes = insights.sleepMinutes else { return "—" }
        return WalkDurationFormatter.string(minutes: minutes)
    }

    private var accessibilitySummary: String {
        L10n.format(
            "%lld прогулок за 7 дней, средняя длительность %@, сна %@, комфортно %@",
            insights.walkCount,
            WalkDurationFormatter.string(minutes: insights.averageDurationMinutes),
            sleepValue,
            L10n.format("%lld%%", insights.comfortablePercent)
        )
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
