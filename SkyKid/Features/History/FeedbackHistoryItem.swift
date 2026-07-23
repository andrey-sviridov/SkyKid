import Foundation

// MARK: - FeedbackHistoryItem

struct FeedbackHistoryItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let recordedAt: Date
    let feedback: UserFeedback
    let title: String
    let source: String
    let context: String
}

// MARK: - FeedbackHistoryItemBuilder

enum FeedbackHistoryItemBuilder {
    static func make(
        from observations: [PersonalizationObservation]
    ) -> [FeedbackHistoryItem] {
        observations.map { observation in
            FeedbackHistoryItem(
                id: observation.id,
                recordedAt: observation.recordedAt,
                feedback: observation.feedback,
                title: title(for: observation.feedback),
                source: source(for: observation.source),
                context: context(for: observation.context)
            )
        }
    }

    // MARK: - Presentation mapping

    private static func title(for feedback: UserFeedback) -> String {
        switch feedback {
        case .tooCold:     return L10n.text("Ребёнку было холодно")
        case .comfortable: return L10n.text("Ребёнку было комфортно")
        case .tooWarm:     return L10n.text("Ребёнку было жарко")
        }
    }

    private static func source(
        for source: PersonalizationFeedbackSource
    ) -> String {
        switch source {
        case .outfitScreen:     return L10n.text("Быстрый отзыв")
        case .walkLog:          return L10n.text("Журнал прогулки")
        case .compatibilityAPI: return L10n.text("Ранее сохранённый отзыв")
        }
    }

    private static func context(
        for context: PersonalizationContext
    ) -> String {
        let temperature = Int(context.microclimateTemperature.rounded())
        return L10n.format(
            "%@ · %@ · около %lld°C",
            context.transportMode.walkLabel,
            context.activityLevel.label,
            temperature
        )
    }
}
