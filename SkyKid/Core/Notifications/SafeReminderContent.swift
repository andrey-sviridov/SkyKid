import Foundation

// MARK: - SafeReminderContent

struct SafeReminderContent: Equatable, Sendable {
    let title: String
    let body: String
}

// MARK: - SafeReminderContentFactory

/// Produces notification copy that never presents an old outfit or forecast
/// as a current recommendation.
enum SafeReminderContentFactory {
    static func dailyWeatherRefresh() -> SafeReminderContent {
        SafeReminderContent(
            title: L10n.text("Обновите условия перед прогулкой"),
            body: L10n.text("Откройте SkyKid: приложение обновит погоду и подберёт одежду для текущей прогулки.")
        )
    }

    static func rainCoverVentilationCheck() -> SafeReminderContent {
        SafeReminderContent(
            title: L10n.text("Проверьте вентиляцию дождевика"),
            body: L10n.text("Проверьте штатную вентиляцию и живот или заднюю поверхность шеи ребёнка. Снимите дождевик, когда осадки закончатся.")
        )
    }

    static func suitableWalkWindow(start: Date) -> SafeReminderContent {
        let time = start.formatted(
            Date.FormatStyle.dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute()
                .locale(L10n.locale)
        )
        return SafeReminderContent(
            title: L10n.text("Более подходящее время по прогнозу"),
            body: L10n.format(
                "Расчётное окно начинается в %@. Перед выходом обновите погоду и проверьте самочувствие ребёнка.",
                time
            )
        )
    }

    static func scheduledWalkCheck() -> SafeReminderContent {
        SafeReminderContent(
            title: L10n.text("Пора проверить условия прогулки"),
            body: L10n.text("Откройте SkyKid, обновите погоду и проверьте самочувствие ребёнка перед выходом.")
        )
    }
}
