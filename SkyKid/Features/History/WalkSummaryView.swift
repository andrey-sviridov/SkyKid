import SwiftUI

// MARK: - WalkSummaryView

/// Подробная сводка завершённой прогулки без журнала событий.
struct WalkSummaryView: View {
    let log: WalkLog

    private var summary: WalkSummary {
        WalkSummaryBuilder.make(from: log)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                metricsGrid
                if !log.outfitItemIDs.isEmpty {
                    outfitCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .skyKidBackground()
        .navigationTitle(L10n.text("Сводка о прогулке"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var metricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            SummaryMetricCard(
                icon: "timer",
                color: .teal,
                value: WalkDurationFormatter.string(minutes: summary.durationMinutes),
                label: L10n.text("Продолжительность")
            )

            SummaryMetricCard(
                icon: summary.comfortFeedback.icon,
                color: summary.comfortFeedback.color,
                value: summary.comfortFeedback.label,
                label: L10n.text("Самочувствие")
            )

            SummaryMetricCard(
                icon: "arrow.triangle.2.circlepath",
                color: .blue,
                value: summary.clothingAdjustment.label,
                label: L10n.text("Изменение одежды")
            )
        }
    }

    private var outfitCard: some View {
        SectionCard(title: L10n.text("Одежда"), systemImage: "hanger") {
            FlowLayout(spacing: 8) {
                ForEach(log.outfitItemIDs, id: \.self) { id in
                    if let item = GarmentCatalog.byID[id] {
                        Text(item.name)
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.10), in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Formatting

}

// MARK: - SummaryMetricCard

private struct SummaryMetricCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 16, padding: 0)
    }
}

#if DEBUG
#Preview("Сводка") {
    NavigationStack {
        WalkSummaryView(log: WalkLog(
            date: .now.addingTimeInterval(-60 * 60),
            durationMinutes: 60,
            comfortLevel: .comfortable,
            weatherTemperature: 12,
            apparentTemperature: 12,
            events: [
                WalkEvent(timestamp: .now.addingTimeInterval(-50 * 60), kind: .sleep),
                WalkEvent(timestamp: .now.addingTimeInterval(-25 * 60), kind: .wake),
                WalkEvent(timestamp: .now.addingTimeInterval(-10 * 60), kind: .checkpoint)
            ],
            isLiveTracked: true
        ))
    }
}
#endif
