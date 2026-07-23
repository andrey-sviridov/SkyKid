import Foundation

enum L10n {
    // MARK: - Public API

    static var locale: Locale {
        AppLanguagePreferences.locale
    }

    static func text(_ key: String) -> String {
        String(
            localized: String.LocalizationValue(key),
            bundle: AppLanguagePreferences.localizationBundle
        )
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: text(key),
            locale: locale,
            arguments: arguments
        )
    }
}
