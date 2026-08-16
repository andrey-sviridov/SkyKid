import Foundation

/// Способ входа в аккаунт — в том виде, в каком его показывают родителям.
///
/// Supabase отдаёт провайдера строкой (`app_metadata.provider` у себя,
/// `family_members_info().provider` у второго родителя), поэтому неизвестное
/// значение не отбрасывается, а показывается как есть: лучше «Github», чем
/// пустое место.
enum SignInProvider: Hashable {
    case google
    case apple
    case email
    case other(String)

    init?(identifier: String?) {
        guard let identifier = identifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !identifier.isEmpty
        else { return nil }

        switch identifier {
        case "google": self = .google
        case "apple": self = .apple
        case "email": self = .email
        default: self = .other(identifier)
        }
    }

    var label: String {
        switch self {
        case .google: "Google"
        case .apple: "Apple"
        case .email: L10n.text("Почта")
        case .other(let identifier): identifier.capitalized
        }
    }

    var icon: String {
        switch self {
        case .google: "globe"
        case .apple: "apple.logo"
        case .email, .other: "envelope.fill"
        }
    }
}
