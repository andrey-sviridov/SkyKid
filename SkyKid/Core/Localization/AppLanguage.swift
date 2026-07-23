import Foundation

// MARK: - App Language

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case russian = "ru"
    case kazakh = "kk"
    case english = "en"
    case french = "fr"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale {
        guard let localizationIdentifier else {
            return .autoupdatingCurrent
        }
        return Locale(identifier: localizationIdentifier)
    }

    var displayName: String {
        guard let localizationIdentifier else {
            return L10n.text("Как в системе")
        }

        let nativeLocale = Locale(identifier: localizationIdentifier)
        let localizedName = nativeLocale.localizedString(
            forIdentifier: localizationIdentifier
        ) ?? localizationIdentifier

        return localizedName.capitalized(with: nativeLocale)
    }

    var localizationIdentifier: String? {
        self == .system ? nil : rawValue
    }
}

// MARK: - App Language Preferences

enum AppLanguagePreferences {
    static let storageKey = "preferred_app_language"

    static var selectedLanguage: AppLanguage {
        resolve(
            AppGroup.defaults.string(forKey: storageKey)
        )
    }

    static var locale: Locale {
        selectedLanguage.locale
    }

    static var localizationBundle: Bundle {
        localizationBundle(for: selectedLanguage)
    }

    static func resolve(_ rawValue: String?) -> AppLanguage {
        guard let rawValue else { return .system }
        return AppLanguage(rawValue: rawValue) ?? .system
    }

    static func localizationBundle(
        for language: AppLanguage,
        in mainBundle: Bundle = .main
    ) -> Bundle {
        guard
            let identifier = language.localizationIdentifier,
            let path = mainBundle.path(
                forResource: identifier,
                ofType: "lproj"
            ),
            let bundle = Bundle(path: path)
        else {
            return mainBundle
        }

        return bundle
    }
}
