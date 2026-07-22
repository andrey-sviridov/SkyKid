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
            title: "Обновите условия перед прогулкой",
            body: "Откройте SkyKid: приложение обновит погоду и подберёт одежду для текущей прогулки."
        )
    }

    static func rainCoverVentilationCheck() -> SafeReminderContent {
        SafeReminderContent(
            title: "Проверьте вентиляцию дождевика",
            body: "Проверьте штатную вентиляцию и шею или верх спины ребёнка. Снимите дождевик, когда осадки закончатся."
        )
    }

    static func suitableWalkWindow(start: Date) -> SafeReminderContent {
        let time = start.formatted(
            Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute()
        )
        return SafeReminderContent(
            title: "Более подходящее время по прогнозу",
            body: "Расчётное окно начинается в (time). Перед выходом обновите погоду и проверьте самочувствие ребёнка."
        )
    }

    static func scheduledWalkCheck() -> SafeReminderContent {
        SafeReminderContent(
            title: "Пора проверить условия прогулки",
            body: "Откройте SkyKid, обновите погоду и проверьте самочувствие ребёнка перед выходом."
        )
    }
}
