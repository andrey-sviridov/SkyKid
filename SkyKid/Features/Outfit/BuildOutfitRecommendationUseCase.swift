import Foundation

// MARK: - BuildOutfitRecommendationUseCase

/// Application-level entry point for building and publishing a recommendation.
/// The returned value and the persisted value originate from the same calculation.
@MainActor
struct BuildOutfitRecommendationUseCase {
    struct Output {
        let recommendation: OutfitRecommendation
        let snapshot: OutfitRecommendationSnapshot
    }

    private let recommendationService: OutfitRecommendationService
    private let snapshotStore: any RecommendationSnapshotStoring

    init(
        recommendationService: OutfitRecommendationService,
        snapshotStore: any RecommendationSnapshotStoring = AppGroupRecommendationSnapshotStore()
    ) {
        self.recommendationService = recommendationService
        self.snapshotStore = snapshotStore
    }

    // MARK: - Execution

    func execute(
        weather: NormalizedWeather,
        profile: ChildThermalProfile,
        walkContext: WalkContext,
        cityName: String,
        generatedAt: Date = Date()
    ) -> Output {
        let recommendation = recommendationService.recommend(
            weather: weather,
            profile: profile,
            walkContext: walkContext
        )
        let snapshot = OutfitRecommendationSnapshot(
            recommendation: recommendation,
            childName: profile.name,
            childAgeLabel: profile.ageLabel,
            cityName: cityName,
            context: RecommendationSnapshotContext(
                weatherCondition: weather.conditionDescription,
                weatherSource: weather.source.displayName,
                weatherConfidence: weather.confidence.level.label,
                transport: walkContext.transportMode.walkLabel,
                activity: walkContext.activityLevel.label,
                walkType: walkContext.walkType.label
            ),
            generatedAt: generatedAt
        )
        snapshotStore.save(snapshot)
        return Output(recommendation: recommendation, snapshot: snapshot)
    }

    /// Compatibility bridge for the isolated legacy path and older tests.
    func execute(
        weather: NormalizedWeather,
        profile: ChildProfile,
        gearSetup: GearSetup,
        cityName: String,
        generatedAt: Date = Date()
    ) -> Output {
        execute(
            weather: weather,
            profile: profile.thermalProfile,
            walkContext: .migrated(
                from: profile,
                gearSetup: gearSetup,
                availableGarmentIDs: UserWardrobeStore.shared.ownedIDs
            ),
            cityName: cityName,
            generatedAt: generatedAt
        )
    }

    func clearSnapshot() {
        snapshotStore.clear()
    }
}
