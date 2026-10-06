import CoreLocation
import SwiftUI

// MARK: - RootRoute

enum RootRoute: Equatable {
    case onboarding
    case locationPermission
    case locationDenied
    case main

    static func resolve(
        profileExists: Bool,
        authorization: CLAuthorizationStatus,
        hasManualLocation: Bool = false
    ) -> RootRoute {
        guard profileExists else { return .onboarding }
        if hasManualLocation { return .main }
        switch authorization {
        case .notDetermined: return .locationPermission
        case .denied, .restricted: return .locationDenied
        default: return .main
        }
    }
}

// MARK: - RootFlow

struct RootFlow: View {
    let composition: AppComposition
    let onStartupReady: @MainActor () -> Void

    @State private var profile: ChildProfile?
    @State private var selectedTab: MainTab = .today
    @State private var showWalkSetup = false
    @State private var completedWalk: WalkLog?
    @State private var didSignalStartupReady = false
    @State private var lastForegroundReload: Date = .distantPast
    @State private var locationSelectionStore = LocationSelectionStore()

    @AppStorage("colorScheme") private var colorSchemeRaw = "system"
    @AppStorage(AppLanguagePreferences.storageKey, store: AppGroup.defaults)
    private var appLanguageRawValue = AppLanguage.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    init(composition: AppComposition, onStartupReady: @escaping @MainActor () -> Void) {
        self.composition = composition
        self.onStartupReady = onStartupReady
        _profile = State(initialValue: composition.childProfileStore.profile)
    }

    var body: some View {
        observedContent
            .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
            .sheet(isPresented: $showWalkSetup) { walkSetupContent }
            .sheet(item: $completedWalk) { WalkCompletionView(log: $0) }
            .onOpenURL { url in
                guard url.scheme == "skykid", url.host == "walk" else { return }
                selectedTab = composition.activeWalkStore.isActive ? .walk : .today
            }
            .preferredColorScheme(preferredScheme)
            .environment(composition.wardrobeStore)
            .environment(composition.walkLogStore)
            .environment(composition.personalOffsetStore)
            .environment(composition.childProfileStore)
            .environment(composition.notificationService)
            .environment(composition.activeWalkStore)
    }

    private var observedContent: some View {
        Group { routedContent }
            .task {
                prepareWalkContext()
                await loadInitialWeatherIfNeeded()
                notifyStartupReadyIfNeeded()
            }
            .onChange(of: profile) { _, newProfile in
                composition.walkContextStore.prepare(
                    for: newProfile,
                    availableGarmentIDs: composition.wardrobeStore.ownedIDs
                )
                refreshRecommendation()
                notifyStartupReadyIfNeeded()
            }
            .onChange(of: composition.wardrobeStore.ownedIDs) { _, ids in
                composition.walkContextStore.updateAvailableGarments(ids)
            }
            .onChange(of: composition.walkContextStore.context) { _, _ in refreshRecommendation() }
            .onChange(of: composition.activeWalkStore.isActive) { _, isActive in
                if !isActive, selectedTab == .walk {
                    selectedTab = .today
                }
            }
            .onChange(of: composition.locationManager.authorizationStatus) { _, _ in
                Task { await loadInitialWeatherIfNeeded() }
                notifyStartupReadyIfNeeded()
            }
            .onChange(of: composition.locationManager.location) { old, new in
                guard manualLocation == nil else { return }
                guard let new else { return }
                if let old, new.distance(from: old) < 5_000,
                   composition.weatherViewModel.weather != nil { return }
                Task { await composition.weatherViewModel.load(coordinate: new.coordinate) }
            }
            .onChange(of: composition.weatherViewModel.isLoading) { _, _ in notifyStartupReadyIfNeeded() }
            .onChange(of: composition.weatherViewModel.error) { _, _ in notifyStartupReadyIfNeeded() }
            .onChange(of: appLanguageRawValue) { _, _ in composition.weatherViewModel.refreshLocalization() }
    }

    @ViewBuilder
    private var routedContent: some View {
        switch RootRoute.resolve(
            profileExists: profile != nil,
            authorization: composition.locationManager.authorizationStatus,
            hasManualLocation: manualLocation != nil
        ) {
        case .onboarding:
            ChildProfileSetupView(profile: $profile)
        case .locationPermission:
            PermissionView(
                onAllow: selectCurrentLocation,
                onManualCity: selectManualLocation
            )
        case .locationDenied:
            DeniedView(onManualCity: selectManualLocation)
        case .main:
            mainTabs
        }
    }

    private var mainTabs: some View {
        MainTabView(
            selection: $selectedTab,
            profile: $profile,
            weatherViewModel: composition.weatherViewModel,
            walkContext: composition.walkContextStore.context,
            personalOffsetStore: composition.personalOffsetStore,
            onWalkContextChange: composition.walkContextStore.update,
            onRefresh: refreshWeather,
            onStartWalk: { showWalkSetup = true },
            onFinishWalk: { completedWalk = $0 },
            onPersonalizationChange: refreshRecommendation
        )
    }

    @ViewBuilder
    private var walkSetupContent: some View {
        if isSupportedAge {
            WalkSetupSheet(
                weather: composition.weatherViewModel.weather,
                profile: profile,
                recommendation: composition.weatherViewModel.outfitRecommendation,
                recommendationAlgorithmVersion: composition.weatherViewModel.recommendationAlgorithmVersion,
                walkContext: composition.walkContextStore.context,
                weatherCapturedAt: composition.weatherViewModel.weatherUpdatedAt,
                onStarted: { selectedTab = .walk }
            )
        } else {
            ContentUnavailableView(
                "Рекомендация недоступна",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Сейчас SkyKid поддерживает рекомендации только для детей от рождения до 12 месяцев.")
            )
            .padding(24)
        }
    }

    private var preferredScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    private var isSupportedAge: Bool {
        profile.map { AgeSafetyPolicy.isSupported($0.thermalProfile) } == true
    }

    private var isStartupReady: Bool {
        guard profile != nil else { return true }
        switch composition.locationManager.authorizationStatus {
        case .notDetermined, .denied, .restricted: return true
        default:
            return composition.weatherViewModel.weather != nil
                || (!composition.weatherViewModel.isLoading && composition.weatherViewModel.error != nil)
        }
    }

    private func prepareWalkContext() {
        composition.walkContextStore.prepare(
            for: profile,
            availableGarmentIDs: composition.wardrobeStore.ownedIDs
        )
        refreshRecommendation()
    }

    private func refreshRecommendation() {
        composition.weatherViewModel.refreshOutfitRecommendation(
            for: profile.flatMap { AgeSafetyPolicy.isSupported($0.thermalProfile) ? $0 : nil },
            walkContext: composition.walkContextStore.context
        )
    }

    private func refreshWeather() {
        if let manualLocation {
            Task {
                await composition.weatherViewModel.load(
                    coordinate: manualLocation.coordinate,
                    cityName: manualLocation.cityName
                )
            }
            return
        }
        if let location = composition.locationManager.location {
            Task { await composition.weatherViewModel.load(coordinate: location.coordinate) }
            return
        }
        if case .currentLocation = locationSelectionStore.selection {
            composition.locationManager.requestOnce()
        }
        Task { await composition.weatherViewModel.reload() }
    }

    private func loadInitialWeatherIfNeeded() async {
        let viewModel = composition.weatherViewModel
        guard profile != nil, !viewModel.isLoading else { return }
        if case .fresh = viewModel.contentState { return }
        if let manualLocation {
            await viewModel.load(
                coordinate: manualLocation.coordinate,
                cityName: manualLocation.cityName
            )
            return
        }
        let status = composition.locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways,
              let location = composition.locationManager.location else { return }
        await viewModel.load(coordinate: location.coordinate)
    }

    private var manualLocation: ManualLocation? {
        guard case let .manualCity(location) = locationSelectionStore.selection else { return nil }
        return location
    }

    private func selectCurrentLocation() {
        locationSelectionStore.selectCurrentLocation()
        composition.locationManager.requestWhenInUse()
    }

    private func selectManualLocation(_ location: ManualLocation) {
        locationSelectionStore.selectManualCity(location)
        Task {
            await composition.weatherViewModel.load(
                coordinate: location.coordinate,
                cityName: location.cityName
            )
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        guard phase == .active else { return }
        composition.activeWalkStore.refresh()
        if !isSupportedAge { refreshRecommendation() }
        guard Date().timeIntervalSince(lastForegroundReload) > 30 * 60 else { return }
        lastForegroundReload = Date()
        Task { await composition.weatherViewModel.reload() }
    }

    @MainActor
    private func notifyStartupReadyIfNeeded() {
        guard !didSignalStartupReady, isStartupReady else { return }
        didSignalStartupReady = true
        onStartupReady()
    }
}
