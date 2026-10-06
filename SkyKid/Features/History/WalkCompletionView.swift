import SwiftUI

// MARK: - WalkCompletionView

/// Экран, который показывается сразу после завершения живой прогулки.
/// Короткое подтверждение сохранения без журнала событий.
struct WalkCompletionView: View {
    let log: WalkLog

    @Environment(\.dismiss) private var dismiss

    private var summary: WalkSummary {
        WalkSummaryBuilder.make(from: log)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    completionHero
                    previewCard

                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .skyKidBackground()
            .navigationTitle(L10n.text("Прогулка завершена"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("Закрыть")) { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var completionHero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 82, height: 82)
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.green)
            }

            Text(log.date.formatted(.dateTime.day().month(.wide).hour().minute().locale(L10n.locale)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var previewCard: some View {
        HStack(spacing: 0) {
            MetricTile(
                icon: "timer",
                color: .teal,
                value: WalkDurationFormatter.string(minutes: summary.durationMinutes),
                label: L10n.text("Продолжительность")
            )

            Divider().frame(height: 54)

            MetricTile(
                icon: log.comfortFeedback.icon,
                color: log.comfortFeedback.color,
                value: log.comfortFeedback.label,
                label: L10n.text("Самочувствие")
            )
        }
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 18, padding: 0)
    }

}

#if DEBUG
#Preview("Завершение прогулки") {
    WalkCompletionView(log: WalkLog(
        date: .now.addingTimeInterval(-45 * 60),
        durationMinutes: 45,
        comfortLevel: .comfortable,
        weatherTemperature: 12,
        apparentTemperature: 12,
        events: [
            WalkEvent(timestamp: .now.addingTimeInterval(-35 * 60), kind: .sleep),
            WalkEvent(timestamp: .now.addingTimeInterval(-20 * 60), kind: .wake)
        ],
        isLiveTracked: true
    ))
}
#endif
