import Foundation
import Observation

// MARK: - OutfitViewModel

@MainActor
@Observable
final class OutfitViewModel {
    private(set) var recommendation: OutfitRecommendation?
    private(set) var profile: ChildProfile?
    private(set) var walkContext: WalkContext?

    private let personalizationStore: PersonalOffsetStore

    init(
        profile: ChildProfile?,
        recommendation: OutfitRecommendation?,
        walkContext: WalkContext?,
        personalizationStore: PersonalOffsetStore
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
        self.profile = profile
        self.recommendation = recommendation
        self.walkContext = walkContext
    }

    @discardableResult
    func resetPersonalization() -> Bool {
        guard let profile else { return false }
        let hadData = personalizationSummary?.hasAnyData == true
        personalizationStore.clearOffset(for: profile)
        return hadData
    }

    // MARK: - Private

    private var personalizationContext: PersonalizationContext? {
        guard let recommendation, let walkContext else { return nil }
        return .recommendation(recommendation, walkContext: walkContext)
    }

}
