import Foundation

// MARK: - LiveWalkNotificationContent

enum LiveWalkNotificationContent {
    static let startedTitle = L10n.text("Живая прогулка")
    static let startedBody = L10n.text("Второй родитель начал прогулку")

    static let timelineTitle = L10n.text("Живая прогулка")
    static func timelineBody(eventCount: Int) -> String {
        L10n.format("%lld новых отметок", eventCount)
    }

    static let finishedTitle = L10n.text("Прогулка завершена")
    static let finishedBody = L10n.text("Второй родитель закончил прогулку")
}
