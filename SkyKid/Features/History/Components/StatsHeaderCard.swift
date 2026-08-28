import SwiftUI

/// Ряд из трёх счётчиков над журналом прогулок.
struct StatsHeaderCard: View {
    let store: WalkLogStore

    var body: some View {
        HStack(spacing: 0) {
            MetricTile(
                icon: "figure.walk",
                color: .blue,
                value: "\(store.recentCount)",
                label: L10n.text("За 7 дней")
            )
            Divider().frame(height: 46)
            MetricTile(
                icon: "clock",
                color: .teal,
                value: avgDuration,
                label: L10n.text("Средняя\nдлительность")
            )
            Divider().frame(height: 46)
            MetricTile(
                icon: "list.bullet.clipboard",
                color: .purple,
                value: "\(store.totalCount)",
                label: L10n.text("Всего\nзаписей")
            )
        }
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 18, padding: 0)
    }

    private var avgDuration: String {
        guard !store.logs.isEmpty else { return "—" }
        let avg = store.logs.map(\.durationMinutes).reduce(0, +) / store.logs.count
        return WalkDurationFormatter.string(minutes: avg)
    }
}
