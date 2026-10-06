import SwiftUI

// MARK: - TodayTakeAlongCard

struct TodayTakeAlongCard: View {
    let items: [RecommendedLayer]

    var body: some View {
        SectionCard(title: L10n.text("Можно взять с собой"), systemImage: "bag.fill") {
            ForEach(items.prefix(2)) { item in
                Label(item.name, systemImage: item.systemImage)
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("today.takeAlong")
    }
}
