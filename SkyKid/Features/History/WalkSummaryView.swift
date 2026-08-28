import SwiftUI

// MARK: - WalkSummaryView

/// Подробная сводка завершённой прогулки: длительность, сон, люлька,
/// самочувствие и основные отметки таймлайна.
struct WalkSummaryView: View {
    let log: WalkLog

    private var summary: WalkSummary {
        WalkSummaryBuilder.make(from: log)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                metricsGrid
                detailsCard

                if summary.isSleepInProgressAtFinish {
                    sleepNote
                }

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
                icon: "moon.zzz.fill",
                color: .purple,
                value: sleepValue,
                label: sleepLabel
            )

            if let bassinetteMinutes = summary.bassinetteDurationMinutes {
                SummaryMetricCard(
                    icon: "tray.and.arrow.down.fill",
                    color: .indigo,
                    value: L10n.format("%lld мин", bassinetteMinutes),
                    label: L10n.text("В люльке")
                )
            }

            SummaryMetricCard(
                icon: "heart.fill",
                color: summary.comfortLevel.color,
                value: summary.comfortLevel.label,
                label: L10n.text("Самочувствие")
            )
        }
    }

    private var detailsCard: some View {
        SectionCard(title: L10n.text("Детали прогулки"), systemImage: "list.bullet.rectangle") {
            summaryRow(
                icon: "moon.zzz.fill",
                label: L10n.text("Эпизоды сна"),
                value: summary.hasSleepData
                    ? String(summary.sleepSessionCount)
                    : L10n.text("Не отмечен")
            )

            if summary.bassinetteSessionCount > 0 {
                summaryRow(
                    icon: "tray.and.arrow.down.fill",
                    label: L10n.text("Заезды в люльку"),
                    value: String(summary.bassinetteSessionCount)
                )
            }

            summaryRow(
                icon: "hanger",
                label: L10n.text("Изменения одежды"),
                value: String(summary.garmentChangeCount)
            )

            summaryRow(
                icon: "flag.fill",
                label: L10n.text("Отметки"),
                value: String(summary.eventCount)
            )

            if let planned = summary.plannedDurationMinutes {
                summaryRow(
                    icon: "target",
                    label: L10n.text("План"),
                    value: plannedStatus(planned: planned)
                )
            }

            summaryRow(
                icon: "thermometer.medium",
                label: L10n.text("Температура"),
                value: L10n.format("%lld°C", Int(summary.weatherTemperature.rounded()))
            )
        }
    }

    private var sleepNote: some View {
        Label(
            L10n.text("Сон продолжался до завершения прогулки"),
            systemImage: "info.circle.fill"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
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

    private var sleepValue: String {
        guard let minutes = summary.sleepDurationMinutes else {
            return "—"
        }
        return L10n.format("%lld мин", minutes)
    }

    private var sleepLabel: String {
        summary.hasSleepData ? L10n.text("Сон") : L10n.text("Сон не отмечен")
    }

    private func plannedStatus(planned: Int) -> String {
        guard let didReach = summary.didReachPlannedDuration else { return "—" }
        if didReach {
            return L10n.format(
                "%@ · %@",
                L10n.text("Выполнено"),
                WalkDurationFormatter.string(minutes: planned)
            )
        }
        return L10n.format(
            "%@ · %@",
            L10n.text("Не выполнено"),
            WalkDurationFormatter.string(minutes: planned)
        )
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 3)
    }
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
