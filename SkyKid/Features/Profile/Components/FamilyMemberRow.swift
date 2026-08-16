import SwiftUI

/// Строка родителя в составе семьи: аватарка, имя/почта и способ входа.
///
/// Нужна, чтобы «второй родитель» перестал быть безымянным: по коду
/// приглашения в семью попадает конкретный аккаунт, и оба родителя должны
/// видеть, чей именно.
struct FamilyMemberRow: View {
    let member: FamilyMember
    /// Это сам владелец устройства — его строка помечается «вы».
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 10) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    if isCurrentUser {
                        Text("вы")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.primary.opacity(0.08), in: Capsule())
                    }
                }

                if let subtitle = member.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            if let provider = member.signInProvider {
                Label(provider.label, systemImage: provider.icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    private var avatar: some View {
        // Аватарка — украшение: пока (или если) картинка не приезжает,
        // на её месте остаётся кружок с первой буквой имени.
        AsyncImage(url: member.avatarURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                Circle().fill(.primary.opacity(0.08))
                Text(member.monogram)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
    }
}
