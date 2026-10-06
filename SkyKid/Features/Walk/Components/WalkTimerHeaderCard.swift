import SwiftUI

// MARK: - WalkTimerHeaderCard

/// Шапка прогулки: живой таймер и остаток до цели.
///
/// Общая для своего экрана прогулки и для просмотра прогулки второго
/// родителя — поэтому принимает `ActiveWalk` и не знает ни про стор, ни про
/// то, можно ли что-то менять.
struct WalkTimerHeaderCard: View {
    let walk: ActiveWalk
    /// Имя того, кто ведёт прогулку. `nil` — это своя прогулка, подписывать нечего.
    var ownerName: String?

    var body: some View {
        VStack(spacing: 8) {
            if let ownerName {
                Text(ownerName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(L10n.text("Прогулка идёт"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(durationText(at: context.date))
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel(
                        L10n.format("Длительность прогулки: %@", durationText(at: context.date))
                    )
            }

            if let planned = walk.plannedDurationMinutes {
                CountdownLabel(
                    target: walk.startDate.addingTimeInterval(TimeInterval(planned * 60)),
                    ongoingText: L10n.text("осталось"),
                    finishedText: L10n.text("цель достигнута")
                )
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.1), lineWidth: 1))
    }

    private func durationText(at now: Date) -> String {
        let totalSeconds = Int(walk.elapsedSeconds(now: now))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
