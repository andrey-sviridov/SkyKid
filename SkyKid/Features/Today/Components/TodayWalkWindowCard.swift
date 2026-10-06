import SwiftUI

// MARK: - TodayWalkWindowCard

struct TodayWalkWindowCard: View {
    let interval: DateInterval

    var body: some View {
        let style = Date.FormatStyle.dateTime.hour().minute().locale(L10n.locale)
        Label(
            L10n.format("Более подходящее время для прогулки: %@–%@", interval.start.formatted(style), interval.end.formatted(style)),
            systemImage: "clock.badge.checkmark"
        )
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.walkWindow")
    }
}
