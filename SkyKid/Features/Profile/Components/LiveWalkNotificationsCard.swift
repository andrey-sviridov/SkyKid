import SwiftUI

// MARK: - LiveWalkNotificationsCard

/// Тумблер включения уведомлений о чужих прогулках.
///
/// Показывается только если пользователь вошёл в аккаунт.
struct LiveWalkNotificationsCard: View {
    @State private var isEnabled = LiveWalkNotificationPreferences.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.text("Уведомления о прогулке"), systemImage: "bell.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        LiveWalkNotificationPreferences.isEnabled = newValue
                    }
            }

            Text(L10n.text("Уведомления приходят, пока приложение открыто. Пуши на закрытое приложение появятся позже."))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}
