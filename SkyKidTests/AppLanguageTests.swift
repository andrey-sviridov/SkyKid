import XCTest
@testable import SkyKid

@MainActor
final class AppLanguageTests: XCTestCase {
    // MARK: - Selection

    func test_supportedSavedLanguageIsResolved() {
        XCTAssertEqual(
            AppLanguagePreferences.resolve("en"),
            .english
        )
    }

    func test_unknownSavedLanguageFallsBackToSystem() {
        XCTAssertEqual(
            AppLanguagePreferences.resolve("unsupported"),
            .system
        )
    }

    // MARK: - Supported Languages

    func test_allExplicitLanguagesHaveAReadableNativeNameAndBundle() {
        for language in AppLanguage.allCases where language != .system {
            XCTAssertFalse(language.displayName.isEmpty)
            XCTAssertNotEqual(
                AppLanguagePreferences.localizationBundle(for: language),
                Bundle.main
            )
        }
    }

    func test_explicitBundleLocalizesWithoutChangingStoredPreference() {
        let englishBundle = AppLanguagePreferences.localizationBundle(
            for: .english
        )
        let value = String(
            localized: "Язык приложения",
            bundle: englishBundle
        )

        XCTAssertEqual(value, "App language")
    }
}
