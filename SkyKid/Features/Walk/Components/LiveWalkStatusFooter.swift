import SwiftUI

// MARK: - LiveWalkStatusFooter

/// Подвал экрана чужой прогулки: кто её ведёт и насколько свежие данные.
///
/// Свежесть показывается честно, потому что канал может отвалиться, а
/// таймер на экране продолжит тикать сам по себе — без этой строки
/// «зависшая» прогулка выглядела бы как живая.
struct LiveWalkStatusFooter: View {
    let ownerName: String?
    let updatedAt: Date
    let isConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let ownerName {
                Label(
                    L10n.format("Прогулку ведёт %@", ownerName),
                    systemImage: "person.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            StatusDotLabel(
                text: statusText,
                color: isConnected ? .green : .orange,
                isPulsing: isConnected
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var statusText: String {
        isConnected
            ? L10n.text("Обновляется в реальном времени")
            : L10n.format("Нет связи · обновлено в %@", updatedAt.formatted(
                .dateTime.hour().minute().locale(L10n.locale)
              ))
    }
}
