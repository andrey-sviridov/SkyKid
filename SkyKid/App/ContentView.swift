import SwiftUI
import UIKit
import CoreLocation

struct ContentView: View {
    let onStartupReady: @MainActor () -> Void

    @State private var locationManager = LocationManager()
    @State private var weatherVM = WeatherViewModel(
        service: WeatherProvider.activeService,
        outfitUseCase: BuildOutfitRecommendationUseCase(recommendationService: .shared)
    )
    @State private var wardrobeStore = UserWardrobeStore.shared
    @State private var walkContextStore = WalkContextStore.shared
    @State private var activeWalkStore = ActiveWalkStore.shared
    @State private var walkLogStore = WalkLogStore.shared
    @State private var personalOffsetStore = PersonalOffsetStore.shared
    @State private var childProfileStore = ChildProfileStore.shared
    @State private var notificationService = NotificationService.shared
    @State private var authService = SupabaseAuthService.shared
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
    @State private var didRestoreSession = false
    @State private var didAttemptInitialSync = false

    private var preferredScheme: ColorScheme? {
        switch colorSchemeRaw {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        // Цепочка модификаторов разбита на два звена сознательно: одним
        // выражением она перестаёт проверяться компилятором по времени
        // («unable to type-check this expression in reasonable time»).
        observedRootContent
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            activeWalkStore.refresh()
            Task { await refreshSharedFamilyData() }
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
        .environment(wardrobeStore)
        .environment(walkLogStore)
        .environment(personalOffsetStore)
        .environment(childProfileStore)
        .environment(notificationService)
        .environment(activeWalkStore)
        .environment(authService)
    }

    private var observedRootContent: some View {
        // Group сохраняет прежнюю структуру: `.task` и `.onChange` висят на
        // контейнере, а не на конкретной ветке роутера.
        Group { rootContent }
        .task {
            await authService.restoreSession()
            didRestoreSession = true
            // Синхронизация идёт до погоды: пока профиль не подтянут из
            // аккаунта, роутер не знает, показывать ли онбординг, и ждать
            // ради этого сетевой запрос погоды незачем.
            await syncOnLaunch()
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
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                // Вход мог случиться уже после стартового syncOnLaunch() —
                // на экране выбора входа или из карточки аккаунта. Сбрасываем
                // флаг только когда локального профиля нет: иначе экран уже
                // настроенного приложения сменился бы заглушкой синхронизации.
                if childProfile == nil { didAttemptInitialSync = false }
                Task { await syncOnLaunch() }
            } else {
                // signOut() стёр локальный кеш, но @State-копия профиля живёт
                // отдельно от стора — без сброса профиль «воскреснет» здесь.
                childProfile = childProfileStore.profile
            }
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
    }

    /// Роутер экранов: восстановление сессии → выбор входа → профиль
    /// ребёнка → геолокация → вкладки.
    @ViewBuilder
    private var rootContent: some View {
        if !didRestoreSession {
            // Пока сессия не восстановлена, неизвестно, вошёл ли
            // пользователь — экран выбора входа здесь мигнул бы у тех,
            // кто уже в аккаунте. Наверху всё равно висит лаунч-оверлей.
            Color.clear
        } else if !authService.hasPassedEntryGate {
            // До профиля ребёнка: аккаунт или сознательно автономно
            AuthGateView()
        } else if childProfile == nil {
            if didAttemptInitialSync {
                // First launch: collect child info before anything else
                ChildProfileSetupView(profile: $childProfile)
            } else {
                // Вошедший пользователь: профиль ещё тянется из аккаунта.
                // Без этой ветки экран создания профиля успевает мигнуть
                // поверх данных, которые вот-вот приедут с сервера.
                accountSyncPlaceholder
            }
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

    private var accountSyncPlaceholder: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Загружаем данные аккаунта…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .skyKidBackground()
    }

    private var isStartupContentReady: Bool {
        guard didRestoreSession else { return false }
        guard authService.hasPassedEntryGate else { return true }
        // Лаунч-оверлей держится, пока идёт первая синхронизация — у него
        // есть свой предохранитель на 8 секунд, если сеть не отвечает.
        guard didAttemptInitialSync else { return false }
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
        // Нативный таб-бар: на iOS 26 он сам получает Liquid Glass и всё
        // системное поведение (реакция на скролл контента под ним), а safe
        // area вкладок ужимает без ручной арифметики отступов.
        TabView(selection: tabSelection) {
            weatherTab
            outfitTab
            walkTab
            historyTab
            profileTab
        }
    }

    /// Тап по «Прогулке», когда прогулки нет, запускает новую, а не открывает
    /// пустую вкладку — поведение прежней круглой кнопки в самодельном баре.
    private var tabSelection: Binding<Int> {
        Binding {
            selectedTab
        } set: { newValue in
            guard newValue == walkTag, !activeWalkStore.isActive else {
                selectedTab = newValue
                return
            }
            tabBeforeWalk = selectedTab
            showWalkSetup = true
        }
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
        .tabItem { Label(L10n.text("Погода"), systemImage: "sun.max.fill") }
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
                    personalOffsetStore: personalOffsetStore,
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
        .tabItem { Label(L10n.text("Одежда"), systemImage: "hanger") }
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
        .tabItem {
            // Пока прогулка идёт — символ в движении: живой таймер, который
            // был в круглой кнопке, теперь показывают Live Activity и сама
            // вкладка, а бару достаётся только признак «идёт».
            Label(
                L10n.text("Прогулка"),
                systemImage: activeWalkStore.isActive ? "figure.walk.motion" : "figure.walk"
            )
        }
        // Точка, а не число: считать тут нечего, нужен сам факт «идёт».
        // Символ взят явно — пустая строка в бейдже может не отрисоваться.
        .badge(activeWalkStore.isActive ? Text(verbatim: "•") : nil)
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
        .tabItem { Label(L10n.text("История"), systemImage: "clock.arrow.circlepath") }
        .tag(4)
    }

    private var profileTab: some View {
        NavigationStack {
            ProfileSummaryView(profile: $childProfile)
        }
        .tabItem {
            Label(
                childProfile.map(\.name) ?? L10n.text("Малыш"),
                systemImage: "person.circle.fill"
            )
        }
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

    /// Подтягивает то, что второй родитель добавил на своём устройстве.
    ///
    /// Это не realtime-подписка: изменения приезжают при возвращении в
    /// приложение и при запуске. Прогулки только добавляются — удаления и
    /// правки, сделанные вторым родителем, здесь не разъезжаются обратно,
    /// потому что конфликт-резолвера у синка нет (см. `syncOnLaunch`).
    private func refreshSharedFamilyData() async {
        guard authService.isSignedIn,
              authService.isLocalDataLinkedToCurrentAccount,
              authService.familyID != nil
        else { return }

        if let remoteProfile = await SupabaseSyncService.shared.pullProfile(),
           remoteProfile != childProfile {
            childProfileStore.profile = remoteProfile
            childProfile = remoteProfile
        }

        let remoteLogs = await SupabaseSyncService.shared.pullAllWalkLogs()
        let knownIDs = Set(walkLogStore.logs.map(\.id))
        for log in remoteLogs.reversed() where !knownIDs.contains(log.id) {
            walkLogStore.add(log, profile: childProfile)
        }
    }

    // MARK: - Supabase sync (первый вход после установки/переустановки)

    /// Один раз при старте, три взаимоисключающих случая:
    ///
    /// 1. Локально пусто — гидратируем устройство из Supabase и привязываем
    ///    хранилище к аккаунту (даже если на сервере тоже пусто: аккаунт
    ///    новый, всё созданное дальше сразу синхронизируется).
    /// 2. Локальные данные уже привязаны к этому аккаунту — выгружаем их,
    ///    как и раньше. Без конфликт-резолвера — см. план синка.
    /// 3. Локальные данные есть, но созданы автономно — не трогаем ничего.
    ///    Такой перенос делается только с согласия пользователя, через
    ///    предложение в `AccountCard`.
    private func syncOnLaunch() async {
        // Роутер ждёт этот флаг, поэтому он поднимается при любом исходе —
        // включая недоступную сеть. Иначе экран создания профиля не покажется
        // никогда.
        defer { didAttemptInitialSync = true }
        guard authService.isSignedIn else { return }

        // Данные принадлежат семье, а не пользователю: без её идентификатора
        // ни выгрузка, ни загрузка невозможны. Для одинокого родителя семья
        // создаётся здесь же и состоит из него одного.
        try? await SupabaseSyncService.shared.ensureFamily()
        guard authService.familyID != nil else { return }

        let hasLocalData = childProfile != nil || !walkLogStore.logs.isEmpty

        if !hasLocalData {
            if let remoteProfile = await SupabaseSyncService.shared.pullProfile() {
                childProfileStore.profile = remoteProfile
                childProfile = remoteProfile
            }
            let remoteLogs = await SupabaseSyncService.shared.pullAllWalkLogs()
            for log in remoteLogs.reversed() {
                walkLogStore.add(log, profile: childProfile)
            }
            authService.linkLocalDataToCurrentAccount()
        } else if authService.isLocalDataLinkedToCurrentAccount {
            if let profile = childProfile {
                await SupabaseSyncService.shared.pushProfile(profile)
            }
            for log in walkLogStore.logs {
                await SupabaseSyncService.shared.pushWalkLog(log)
            }
            // Дальше идёт пул — без него новые прогулки другого родителя не
            // появятся, пока приложение не свернут и не развернут: `.onChange`
            // на `scenePhase` не срабатывает на само появление вью при
            // холодном старте, он видит только последующие переходы.
            await refreshSharedFamilyData()
        }
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
