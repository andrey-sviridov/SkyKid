import SwiftUI

// MARK: - LiveWalkInProgressRow

/// Строка журнала для прогулки, которая идёт прямо сейчас.
///
/// Намеренно не переиспользует `liveBadge` из `WalkLogRow`: тот означает
/// «прогулка отслеживалась вживую» — про прошедшее время. Здесь смысл
/// другой, «идёт прямо сейчас», и один значок на два смысла читался бы
/// неверно.
struct LiveWalkInProgressRow: View {
    let walk: ActiveWalk
    /// `nil` — прогулка своя.
    let ownerName: String?

    private var isOwn: Bool { ownerName == nil }

    var body: some View {
        HStack(spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 3) {
                ElapsedTimeText(since: walk.startDate, size: .compact)

                StatusDotLabel(
                    text: isOwn ? L10n.text("Идёт сейчас") : L10n.format("Гуляет %@", ownerName ?? ""),
                    color: .green,
                    isPulsing: true
                )
            }

            Spacer(minLength: 8)

            if !walk.events.isEmpty {
                marksBadge
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16, padding: 0)
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 18))
                .foregroundStyle(.green)
        }
    }

    private var marksBadge: some View {
        Text(L10n.format("%lld отметок", walk.events.count))
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.primary.opacity(0.07), in: Capsule())
    }
}

// MARK: - Оформление строки в List

extension View {
    /// Одинаковые отступы и прозрачный фон для строк живых прогулок в
    /// журнале — набор модификаторов `List` тут длиннее самой строки.
    func liveWalkRowChrome() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 16))
    }
}
