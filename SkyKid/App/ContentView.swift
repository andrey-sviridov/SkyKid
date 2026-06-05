import SwiftUI
import CoreLocation

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var weatherVM = WeatherViewModel()
    @State private var selectedTab = 0

    @State private var childProfile: ChildProfile? = ChildProfileStore.shared.profile
    @State private var showProfileSetup = false

    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"

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
        .onChange(of: locationManager.location) { _, location in
            guard let location else { return }
            Task { await weatherVM.load(coordinate: location.coordinate) }
        }
        .sheet(isPresented: $showProfileSetup) {
            ChildProfileSetupView(profile: $childProfile)
        }
        .preferredColorScheme(preferredScheme)
    }

    @ViewBuilder
    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            weatherTab
            mapTab
            outfitTab
            calculatorTab
            profileTab
        }
    }

    private var weatherTab: some View {
        NavigationStack {
            Group {
                if weatherVM.isLoading || weatherVM.weather == nil {
                    ProgressView("Загружаем погоду…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let w = weatherVM.weather {
                    WeatherView(weather: w, cityName: cityName, profile: childProfile)
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

    private var mapTab: some View {
        NavigationStack {
            if let coord = locationManager.location?.coordinate {
                RadarMapView(coordinate: coord)
            } else {
                ProgressView("Определяем местоположение…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tabItem { Label("Осадки", systemImage: "cloud.rain.fill") }
        .tag(1)
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
            ClothingCalculatorView(profile: childProfile)
        }
        .tabItem { Label("Конструктор", systemImage: "slider.horizontal.3") }
        .tag(3)
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
        .tag(4)
    }

    private var refreshButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                locationManager.startUpdating()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    private var cityName: String {
        "Моё местоположение"
    }
}

// MARK: - Profile summary tab

struct ProfileSummaryView: View {
    @Binding var profile: ChildProfile?
    @State private var showEdit = false
    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"

    var body: some View {
        List {
            if let p = profile {
                Section {
                    HStack(spacing: 16) {
                        Text(p.gender.emoji)
                            .font(.system(size: 52))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.name)
                                .font(.title2.weight(.semibold))
                            Text(p.ageLabel)
                                .foregroundStyle(.secondary)
                            Text(p.ageGroup.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("День рождения") {
                    Label(
                        p.birthday.formatted(.dateTime.day().month(.wide).year()),
                        systemImage: "birthday.cake.fill"
                    )
                }

                Section("Возрастная группа") {
                    Label(p.ageGroup.description, systemImage: "figure.child")
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Поправка к температуре")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let offset = p.ageGroup.temperatureOffset
                        Text(offset == 0 ? "Как у взрослого" : "\(Int(offset))° (ощущает холоднее)")
                            .font(.body)
                    }
                }

                Section("Оформление") {
                    Picker("Тема", selection: $colorSchemeRaw) {
                        Label("Системная", systemImage: "circle.lefthalf.filled")
                            .tag("system")
                        Label("Светлая", systemImage: "sun.max.fill")
                            .tag("light")
                        Label("Тёмная", systemImage: "moon.fill")
                            .tag("dark")
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Button("Изменить данные ребёнка") {
                        showEdit = true
                    }
                }
            }
        }
        .navigationTitle("Профиль")
        .sheet(isPresented: $showEdit) {
            ChildProfileSetupView(profile: $profile)
        }
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
