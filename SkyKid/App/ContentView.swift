import SwiftUI
import UIKit
import CoreLocation

struct ContentView: View {
    let onStartupReady: @MainActor () -> Void

    @State private var locationManager = LocationManager()
    @State private var weatherVM = WeatherViewModel(service: WeatherProvider.activeService)
    @State private var selectedTab = 0

    @State private var childProfile: ChildProfile? = ChildProfileStore.shared.profile
    @State private var showProfileSetup = false

    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"
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
            await loadInitialWeatherIfNeeded()
            notifyStartupReadyIfNeeded()
        }
        .onChange(of: childProfile) { _, _ in
            notifyStartupReadyIfNeeded()
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
            guard Date().timeIntervalSince(lastForegroundReload) > 30 * 60 else { return }
            lastForegroundReload = Date()
            Task { await weatherVM.reload() }
        }
        .sheet(isPresented: $showProfileSetup) {
            ChildProfileSetupView(profile: $childProfile)
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
        TabView(selection: $selectedTab) {
            weatherTab
            outfitTab
            calculatorTab
            historyTab
            profileTab
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
        .tabItem { Label("Погода", systemImage: "sun.max.fill") }
        .tag(0)
    }

    private var outfitTab: some View {
        NavigationStack {
            if let weather = weatherVM.weather {
                OutfitView(weather: weather, profile: childProfile)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tabItem { Label("Одежда", systemImage: "hanger") }
        .tag(2)
    }

    private var calculatorTab: some View {
        NavigationStack {
            ClothingCalculatorView(profile: childProfile, weather: weatherVM.weather)
        }
        .tabItem { Label("Конструктор", systemImage: "slider.horizontal.3") }
        .tag(3)
    }

    private var historyTab: some View {
        NavigationStack {
            WalkHistoryView(weather: weatherVM.weather, profile: childProfile)
        }
        .tabItem { Label("История", systemImage: "clock.arrow.circlepath") }
        .tag(4)
    }

    private var profileTab: some View {
        NavigationStack {
            ProfileSummaryView(profile: $childProfile)
        }
        .tabItem {
            Label(
                childProfile.map { $0.name } ?? "Малыш",
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

