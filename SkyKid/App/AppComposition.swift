import Foundation
import Observation

// MARK: - AppComposition

@MainActor
@Observable
final class AppComposition {
    let locationManager: LocationManager
    let weatherViewModel: WeatherViewModel
    let wardrobeStore: UserWardrobeStore
    let walkContextStore: WalkContextStore
    let activeWalkStore: ActiveWalkStore
    let walkLogStore: WalkLogStore
    let personalOffsetStore: PersonalOffsetStore
    let childProfileStore: ChildProfileStore
    let notificationService: NotificationService

    init(
        locationManager: LocationManager = LocationManager(),
        weatherViewModel: WeatherViewModel = WeatherViewModel(
            service: WeatherProvider.activeService,
            outfitUseCase: BuildOutfitRecommendationUseCase(recommendationService: .shared)
        ),
        wardrobeStore: UserWardrobeStore = .shared,
        walkContextStore: WalkContextStore = .shared,
        activeWalkStore: ActiveWalkStore = .shared,
        walkLogStore: WalkLogStore = .shared,
        personalOffsetStore: PersonalOffsetStore = .shared,
        childProfileStore: ChildProfileStore = .shared,
        notificationService: NotificationService = .shared
    ) {
        self.locationManager = locationManager
        self.weatherViewModel = weatherViewModel
        self.wardrobeStore = wardrobeStore
        self.walkContextStore = walkContextStore
        self.activeWalkStore = activeWalkStore
        self.walkLogStore = walkLogStore
        self.personalOffsetStore = personalOffsetStore
        self.childProfileStore = childProfileStore
        self.notificationService = notificationService
    }
}
