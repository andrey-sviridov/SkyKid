import SwiftUI

struct StatsHeaderCard: View {
    let store: WalkLogStore

    var body: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(store.recentCount)",
                label: L10n.text("За 7 дней"),
                icon: "figure.walk",
                color: .blue
            )
            Divider().frame(height: 46)
            statCell(
                value: avgDuration,
                label: L10n.text("Средняя\nдлительность"),
                icon: "clock",
                color: .teal
            )
            Divider().frame(height: 46)
            statCell(
                value: "\(store.totalCount)",
                label: L10n.text("Всего\nзаписей"),
                icon: "list.bullet.clipboard",
                color: .purple
            )
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var avgDuration: String {
        guard !store.logs.isEmpty else { return "—" }
        let avg = store.logs.map(\.durationMinutes).reduce(0, +) / store.logs.count
        return WalkDurationFormatter.string(minutes: avg)
    }
}
