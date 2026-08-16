import Foundation

/// Родитель в семье — так, как его видит второй родитель.
///
/// Приезжает из `auth.users` через RPC `family_members_info()`: таблица
/// пользователей клиенту недоступна напрямую, а функция отдаёт только
/// участников своей семьи (см. миграцию `2026-08-16-family-member-identity`).
///
/// Все поля, кроме идентификатора, опциональны: провайдер входа может не
/// отдать ни имени, ни аватарки, а почта скрыта у пользователей с
/// «Скрыть e-mail» (Sign in with Apple).
struct FamilyMember: Identifiable, Hashable, Decodable {
    let userID: UUID
    let email: String?
    let displayName: String?
    let avatarURL: URL?
    /// Способ входа: `google`, `apple`, `email`…
    let provider: String?

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case provider
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userID = try c.decode(UUID.self, forKey: .userID)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        // Битую ссылку на аватарку молча пропускаем — она украшение, а не
        // причина потерять всю карточку участника.
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
            .flatMap(URL.init(string:))
        provider = try c.decodeIfPresent(String.self, forKey: .provider)
    }
}

extension FamilyMember {
    /// Заголовок строки: имя, а если провайдер его не дал — почта.
    var title: String {
        displayName ?? email ?? L10n.text("Родитель")
    }

    /// Подпись под именем. Почта не дублируется, если она же и в заголовке.
    var subtitle: String? {
        displayName == nil ? nil : email
    }

    /// Как пользователь входит — чтобы второй родитель понимал, под каким
    /// аккаунтом его позвали, даже когда почты нет.
    var signInProvider: SignInProvider? {
        SignInProvider(identifier: provider)
    }

    /// Буква для заглушки вместо аватарки.
    var monogram: String {
        title.first.map { String($0).uppercased() } ?? "?"
    }
}
