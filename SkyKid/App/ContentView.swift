import SwiftUI
import UIKit
import CoreLocation

struct ContentView: View {
    let onStartupReady: @MainActor () -> Void

    @State private var locationManager = LocationManager()
    @State private var weatherVM = WeatherViewModel(service: WeatherProvider.activeService)
    @State private var wardrobeStore = UserWardrobeStore.shared
    @State private var walkContextStore = WalkContextStore.shared
    @State private var activeWalkStore = ActiveWalkStore.shared
    @State private var selectedTab = 0
    @State private var showWalkSetup = false
    @State private var tabBeforeWalk = 0
    private let walkTag = 3

    @State private var childProfile: ChildProfile? = ChildProfileStore.shared.profile
    @State private var showProfileSetup = false

    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"
    @AppStorage(
        AppLanguagePreferences.storageKey,
        store: AppGroup.defaults
    )
    private var appLanguageRawValue = AppLanguage.system.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastForegroundReload: Date = .distantPast
    @State private var didSignalStartupReady = false

    private var preferredScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        Group {
            if childProfile == nil {
                // First launch: collect child info before anything else
                ChildProfileSetupView(profile: $childProfile)
            } else {
                switch locationManager.authorizationStatus {
                case .notDetermined:
                    PermissionView { locationManager.requestWhenInUse() }
                case .denied, .restricted:
                    DeniedView()
                default:
                    mainTabs
                }
            }
        }
        .task {
            prepareWalkContext()
            await loadInitialWeatherIfNeeded()
            notifyStartupReadyIfNeeded()
        }
        .onChange(of: childProfile) { _, newProfile in
            walkContextStore.prepare(
                for: newProfile,
                availableGarmentIDs: wardrobeStore.ownedIDs
            )
            refreshOutfitRecommendation()
            notifyStartupReadyIfNeeded()
        }
        .onChange(of: wardrobeStore.ownedIDs) { _, _ in
            walkContextStore.updateAvailableGarments(wardrobeStore.ownedIDs)
        }
        .onChange(of: walkContextStore.context) { _, _ in
            refreshOutfitRecommendation()
        }
        .onChange(of: locationManager.authorizationStatus) { _, _ in
            Task { await loadInitialWeatherIfNeeded() }
            notifyStartupReadyIfNeeded()
        }
        .onChange(of: weatherVM.weather != nil) { _, _ in
            notifyStartupReadyIfNeeded()
        }
        .onChange(of: weatherVM.isLoading) { _, _ in
            notifyStartupReadyIfNeeded()
        }
        .onChange(of: weatherVM.error) { _, _ in
            notifyStartupReadyIfNeeded()
        }
        .onChange(of: appLanguageRawValue) { _, _ in
            weatherVM.refreshLocalization()
        }
        .onChange(of: locationManager.location) { old, new in
            guard let new else { return }
            // Не перегружаем погоду, если позиция почти не изменилась (< 5 км).
            // Кешированная позиция → сразу грузит. Свежий фикс → обновит только
            // если пользователь реально переместился.
            if let old, new.distance(from: old) < 5_000, weatherVM.weather != nil { return }
            Task { await weatherVM.load(coordinate: new.coordinate) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            ActiveWalkStore.shared.refresh()
            guard Date().timeIntervalSince(lastForegroundReload) > 30 * 60 else { return }
            lastForegroundReload = Date()
            Task { await weatherVM.reload() }
        }
        .sheet(isPresented: $showProfileSetup) {
            ChildProfileSetupView(profile: $childProfile)
        }
        .sheet(isPresented: $showWalkSetup) {
            WalkSetupSheet(
                weather: weatherVM.weather,
                profile: childProfile,
                recommendation: weatherVM.outfitRecommendation,
                walkContext: walkContextStore.context,
                onStarted: { selectedTab = walkTag }
            )
        }
        .onChange(of: activeWalkStore.isActive) { wasActive, isActive in
            if wasActive && !isActive {
                selectedTab = tabBeforeWalk
            }
        }
        .onOpenURL { url in
            guard url.scheme == "skykid", url.host == "walk" else { return }
            selectedTab = walkTag
        }
        .preferredColorScheme(preferredScheme)
    }

    private var isStartupContentReady: Bool {
        guard childProfile != nil else { return true }

        switch locationManager.authorizationStatus {
        case .notDetermined, .denied, .restricted:
            return true
        default:
            return weatherVM.weather != nil || (!weatherVM.isLoading && weatherVM.error != nil)
        }
    }

    @MainActor
    private func notifyStartupReadyIfNeeded() {
        guard !didSignalStartupReady, isStartupContentReady else { return }
        didSignalStartupReady = true
        onStartupReady()
    }

    private func loadInitialWeatherIfNeeded() async {
        guard childProfile != nil else { return }
        guard weatherVM.weather == nil, !weatherVM.isLoading else { return }
        guard locationManager.authorizationStatus == .authorizedWhenInUse
            || locationManager.authorizationStatus == .authorizedAlways else { return }
        guard let location = locationManager.location else { return }
        await weatherVM.load(coordinate: location.coordinate)
    }

    @ViewBuilder
    private var mainTabs: some View {
        // .safeAreaInset позиционирует бар внизу TabView, но НЕ ужимает safe
        // area контента вкладок (каждая вкладка — отдельный NavigationStack,
        // граница TabView эту информацию не пробрасывает). Закреплённые
        // снизу элементы вкладок (кнопка «Завершить прогулку», FAB в
        // «Истории») сами резервируют место под баром через
        // SkyKidTabBarMetrics.totalHeight — статическую константу geometrии
        // бара (runtime-измерение через PreferenceKey/environment здесь не
        // сработало: кнопка пропадала, проверено на симуляторе).
        TabView(selection: $selectedTab) {
            weatherTab
            outfitTab
            walkTab
            historyTab
            profileTab
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(
                selectedTab: $selectedTab,
                items: tabBarItems,
                walkTag: walkTag,
                isWalkActive: activeWalkStore.isActive,
                walkStartDate: activeWalkStore.current?.startDate,
                weatherCode: activeWalkStore.current?.weatherCode,
                onWalkTap: {
                    tabBeforeWalk = selectedTab
                    showWalkSetup = true
                }
            )
        }
    }

    private var tabBarItems: [TabBarItem] {
        [
            TabBarItem(tag: 0, title: L10n.text("Погода"), systemImage: "sun.max.fill"),
            TabBarItem(tag: 2, title: L10n.text("Одежда"), systemImage: "hanger"),
            TabBarItem(tag: walkTag, title: L10n.text("Прогулка"), systemImage: "figure.walk"),
            TabBarItem(tag: 4, title: L10n.text("История"), systemImage: "clock.arrow.circlepath"),
            TabBarItem(tag: 5, title: childProfile.map(\.name) ?? L10n.text("Малыш"), systemImage: "person.circle.fill"),
        ]
    }

    private var weatherTab: some View {
        NavigationStack {
            Group {
                if weatherVM.isLoading || weatherVM.weather == nil {
                    VStack(spacing: 14) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Загружаем погоду…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .skyKidBackground()
                } else if let w = weatherVM.weather {
                    WeatherView(
                        weather:          w,
                        cityName:         cityName,
                        currentProvider:  weatherVM.currentProvider,
                        onProviderChange: { provider, key in weatherVM.switchProvider(provider, apiKey: key) }
                    )
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SKY KID")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .kerning(4)
                }
                refreshButton
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(0)
    }

    private var outfitTab: some View {
        NavigationStack {
            if let weather = weatherVM.weather {
                OutfitView(
                    weather: weather,
                    profile: childProfile,
                    recommendation: weatherVM.outfitRecommendation,
                    walkContext: walkContextStore.context,
                    onWalkContextChange: { context in
                        walkContextStore.update(context)
                    },
                    onFeedbackRecorded: {
                        refreshOutfitRecommendation()
                    }
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(2)
    }

    private var walkTab: some View {
        NavigationStack {
            WalkTabView(
                weather: weatherVM.weather,
                profile: childProfile,
                onChanged: refreshOutfitRecommendation
            )
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(walkTag)
    }

    private var historyTab: some View {
        NavigationStack {
            WalkHistoryView(
                weather: weatherVM.weather,
                profile: childProfile,
                recommendation: weatherVM.outfitRecommendation,
                walkContext: walkContextStore.context,
                onPersonalizationChange: refreshOutfitRecommendation
            )
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(4)
    }

    private var profileTab: some View {
        NavigationStack {
            ProfileSummaryView(profile: $childProfile)
        }
        .toolbar(.hidden, for: .tabBar)
        .tag(5)
    }

    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                // Принудительно перезагружаем погоду + просим свежую геопозицию
                locationManager.requestOnce()
                Task { await weatherVM.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(weatherVM.isLoading)
        }
    }

    private var cityName: String {
        weatherVM.cityName
    }

    // MARK: - Recommendation context

    private func prepareWalkContext() {
        walkContextStore.prepare(
            for: childProfile,
            availableGarmentIDs: wardrobeStore.ownedIDs
        )
        refreshOutfitRecommendation()
    }

    private func refreshOutfitRecommendation() {
        weatherVM.refreshOutfitRecommendation(
            for: childProfile,
            walkContext: walkContextStore.context
        )
    }
}

// MARK: - Permission screens

struct PermissionView: View {
    let onAllow: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 72))
                .symbolRenderingMode(.multicolor)
            Text("Нужен доступ к местоположению")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Чтобы показать актуальную погоду и карту осадков рядом с вами")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Разрешить", action: onAllow)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
    }
}

struct DeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Доступ к геолокации запрещён")
                .font(.headline)
            Text("Откройте Настройки → SkyKid → Геолокация")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Открыть настройки") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
    }
}

#if DEBUG
private struct IdleTimerDebugBanner: View {
    @State private var isDisabled: Bool = UIApplication.shared.isIdleTimerDisabled
    @State private var flipCount: Int = 0

    var body: some View {
        Text("idleTimer disabled: \(isDisabled ? "TRUE ⚠️" : "false ✓")  flips: \(flipCount)")
            .font(.system(size: 11, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isDisabled ? Color.red.opacity(0.85) : Color.black.opacity(0.65))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .padding(.bottom, 90)
            .task {
                var prev = UIApplication.shared.isIdleTimerDisabled
                while true {
                    try? await Task.sleep(for: .seconds(1))
                    let cur = UIApplication.shared.isIdleTimerDisabled
                    if cur != prev { flipCount += 1; prev = cur }
                    isDisabled = cur
                }
            }
    }
}
#endif
