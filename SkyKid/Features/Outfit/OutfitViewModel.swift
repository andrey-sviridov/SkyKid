import Foundation
import Observation

// MARK: - OutfitViewModel

@MainActor
@Observable
final class OutfitViewModel {
    private(set) var recommendation: OutfitRecommendation?
    private(set) var profile: ChildProfile?
    private(set) var walkContext: WalkContext?
    private(set) var feedbackSent: UserFeedback?
    private(set) var feedbackMessage: String?

    private let personalizationStore: PersonalOffsetStore
    private var feedbackSourceID = UUID()
    private var lastFeedbackRecordedAt: Date?
    private var feedbackResetTask: Task<Void, Never>?

    init(
        profile: ChildProfile?,
        recommendation: OutfitRecommendation?,
        walkContext: WalkContext?,
        personalizationStore: PersonalOffsetStore = .shared
    ) {
        self.profile = profile
        self.recommendation = recommendation
        self.walkContext = walkContext
        self.personalizationStore = personalizationStore
    }

    // MARK: - Presentation state

    var displayLayers: [RecommendedLayer] {
        recommendation?.allDisplayLayers ?? []
    }

    var microclimateTemperature: Double? {
        recommendation?.temperatures.microclimate
    }

    var blockingWarning: SafetyWarning? {
        recommendation?.blockingWarning
    }

    var personalizationSummary: PersonalizationSummary? {
        guard let profile, let personalizationContext else { return nil }
        return personalizationStore.summary(
            for: profile.thermalProfile,
            context: personalizationContext
        )
    }

    // MARK: - Input updates

    func update(
        profile: ChildProfile?,
        recommendation: OutfitRecommendation?,
        walkContext: WalkContext?
    ) {
        let previousKey = feedbackContextKey
        self.profile = profile
        self.recommendation = recommendation
        self.walkContext = walkContext

        if previousKey != feedbackContextKey {
            beginNewFeedbackSession()
        }
    }

    // MARK: - Feedback

    @discardableResult
    func recordFeedback(_ feedback: UserFeedback) -> Bool {
        guard let profile, let personalizationContext else { return false }
        let recordedAt = Date()
        if let lastFeedbackRecordedAt,
           recordedAt.timeIntervalSince(lastFeedbackRecordedAt)
            >= PersonalizationPolicy.independentSignalInterval {
            feedbackSourceID = UUID()
        }

        let update = personalizationStore.record(
            feedback,
            for: profile,
            context: personalizationContext,
            sourceID: feedbackSourceID,
            source: .outfitScreen,
            recordedAt: recordedAt
        )
        lastFeedbackRecordedAt = recordedAt
        feedbackSent = feedback
        feedbackMessage = message(for: feedback, update: update)
        scheduleFeedbackReset()
        return update.didChangeOffset
    }

    @discardableResult
    func resetPersonalization() -> Bool {
        guard let profile else { return false }
        let hadData = personalizationSummary?.hasAnyData == true
        personalizationStore.clearOffset(for: profile)
        beginNewFeedbackSession()
        return hadData
    }

    // MARK: - Private

    private var personalizationContext: PersonalizationContext? {
        guard let recommendation, let walkContext else { return nil }
        return .recommendation(recommendation, walkContext: walkContext)
    }

    private var feedbackContextKey: FeedbackContextKey? {
        guard let profile, let context = personalizationContext else { return nil }
        return FeedbackContextKey(
            birthday: profile.birthday,
            band: context.temperatureBand,
            scenario: context.scenario
        )
    }

    private func beginNewFeedbackSession() {
        feedbackSourceID = UUID()
        lastFeedbackRecordedAt = nil
        feedbackResetTask?.cancel()
        feedbackSent = nil
        feedbackMessage = nil
    }

    private func scheduleFeedbackReset() {
        feedbackResetTask?.cancel()
        feedbackResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.feedbackSent = nil
            self?.feedbackMessage = nil
        }
    }

    private func message(
        for feedback: UserFeedback,
        update: PersonalizationUpdate
    ) -> String {
        if feedback == .comfortable {
            return L10n.text("Комфорт подтверждён — текущая поправка сохранена")
        }
        if update.didChangeOffset {
            let sign = update.currentOffset > 0 ? "+" : ""
            let offset = update.currentOffset.formatted(
                .number
                    .precision(.fractionLength(1))
                    .locale(L10n.locale)
            )
            return L10n.format(
                "Сигнал повторился — поправка теперь %@%@ TOG",
                sign,
                offset
            )
        }
        return L10n.text("Наблюдение сохранено — изменение будет только после повторения")
    }
}

// MARK: - FeedbackContextKey

private struct FeedbackContextKey: Equatable {
    let birthday: Date
    let band: TempBand
    let scenario: PersonalizationScenario
}
