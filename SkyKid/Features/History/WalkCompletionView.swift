import SwiftUI

// MARK: - WalkCompletionView

/// Экран, который показывается сразу после завершения живой прогулки.
/// Основные итоги остаются на виду, а подробности открываются отдельной
/// кнопкой, чтобы завершение не превращалось в длинный отчёт.
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

                    NavigationLink {
                        WalkSummaryView(log: log)
                    } label: {
                        Label(
                            L10n.text("Сводка о прогулке"),
                            systemImage: "list.bullet.clipboard.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("walk.completion.summary")
                    .accessibilityHint(L10n.text("Показывает длительность сна и другие итоги прогулки"))

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
                icon: "moon.zzz.fill",
                color: .purple,
                value: sleepValue,
                label: L10n.text("Сон")
            )
        }
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 18, padding: 0)
    }

    private var sleepValue: String {
        guard let minutes = summary.sleepDurationMinutes else {
            return L10n.text("Не отмечен")
        }
        return L10n.format("%lld мин", minutes)
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
