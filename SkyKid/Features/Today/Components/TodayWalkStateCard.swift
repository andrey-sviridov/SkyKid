import SwiftUI

// MARK: - TodayWalkStateCard

struct TodayWalkStateCard: View {
    let isActive: Bool
    let startedAt: Date?
    let onStart: () -> Void

    var body: some View {
        SectionCard(
            title: isActive ? L10n.text("Прогулка идёт") : L10n.text("Готовы гулять?"),
            systemImage: isActive ? "figure.walk.motion" : "figure.walk"
        ) {
            if let startedAt, isActive {
                Text(L10n.format("Начали в %@", startedAt.formatted(.dateTime.hour().minute().locale(L10n.locale))))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onStart) {
                    Label(L10n.text("Начать прогулку"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }
        }
        .accessibilityIdentifier("today.walkState")
    }
}
