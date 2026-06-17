import SwiftUI
import CoreLocation
import AppIntents
import UIKit

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var weatherVM = WeatherViewModel(service: WeatherProvider.activeService)
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
        .task { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: locationManager.location) { old, new in
            guard let new else { return }
            // Не перегружаем погоду, если позиция почти не изменилась (< 5 км).
            // Кешированная позиция → сразу грузит. Свежий фикс → обновит только
            // если пользователь реально переместился.
            if let old, new.distance(from: old) < 5_000, weatherVM.weather != nil { return }
            Task { await weatherVM.load(coordinate: new.coordinate) }
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
                        profile:          childProfile,
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

    private var mapTab: some View {
        NavigationStack {
            if let coord = locationManager.location?.coordinate {
                // Нативный RadarMapView — нет WKWebView, нет зависания от CDN,
                // нет JS-таймеров, которые мешали автоблокировке экрана.
                RadarMapView(coordinate: coord, weather: weatherVM.weather)
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
            ClothingCalculatorView(profile: childProfile, weather: weatherVM.weather)
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
                // Принудительно перезагружаем погоду + просим свежую геопозицию
                locationManager.startUpdating()
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

// MARK: - Profile summary tab

struct ProfileSummaryView: View {
    @Binding var profile: ChildProfile?
    @State private var showEdit = false
    @State private var notificationsOn = NotificationService.shared.isEnabled
    @AppStorage("colorScheme") private var colorSchemeRaw: String = "system"

    var body: some View {
        ScrollView {
            if let p = profile {
                VStack(spacing: 20) {
                    avatarHeader(p)
                    infoCards(p)
                    wardrobeCard
                    notificationsCard
                    themeCard
                    siriCard
                    editButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .skyKidBackground()
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showEdit) {
            ChildProfileSetupView(profile: $profile)
        }
    }

    // MARK: - Avatar header

    private func avatarHeader(_ p: ChildProfile) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: p.gender == .boy
                                ? [Color(red: 0.28, green: 0.42, blue: 0.96),
                                   Color(red: 0.12, green: 0.60, blue: 0.86)]
                                : [Color(red: 0.92, green: 0.32, blue: 0.60),
                                   Color(red: 0.72, green: 0.18, blue: 0.78)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: (p.gender == .boy ? Color.blue : Color.pink).opacity(0.4),
                            radius: 14, y: 5)
                Image(systemName: "figure.child")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(p.name)
                    .font(.title2.weight(.bold))
                Text(p.ageLabel + " · " + p.ageGroup.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Info cards

    private func infoCards(_ p: ChildProfile) -> some View {
        let ageOffset = p.ageGroup.temperatureOffset
        let showHealth = !p.healthFeatures.isEmpty
        let showTempPref = p.temperaturePreferenceOffset != 0

        return VStack(spacing: 1) {
            infoRow(icon: "birthday.cake.fill", color: .pink,
                    title: "День рождения",
                    value: p.birthday.formatted(.dateTime.day().month(.wide).year()),
                    isFirst: true, isLast: false)

            infoRow(icon: "figure.child", color: .orange,
                    title: "Возрастная группа",
                    value: p.ageGroup.description,
                    isFirst: false, isLast: false)

            infoRow(icon: p.activityLevel.icon, color: .green,
                    title: "Активность",
                    value: p.activityLevel.rawValue + " · " + activityDetail(p.activityLevel),
                    isFirst: false, isLast: false)

            infoRow(icon: p.walkType.icon, color: .teal,
                    title: "Тип прогулки",
                    value: p.walkType.label + " (" + p.walkType.detail + ")",
                    isFirst: false, isLast: false)

            infoRow(icon: "thermometer.medium", color: .blue,
                    title: "Возрастная поправка",
                    value: ageOffset == 0 ? "Как у взрослого" : "\(Int(ageOffset))° (ощущает холоднее)",
                    isFirst: false, isLast: !showTempPref && !showHealth)

            if showTempPref {
                let off = p.temperaturePreferenceOffset
                let sign = off > 0 ? "+" : ""
                infoRow(icon: "slider.horizontal.3", color: .purple,
                        title: "Склонность",
                        value: off < -1 ? "Мёрзнет (\(sign)\(Int(off))°)" :
                               off > 1  ? "Жаркий (\(sign)\(Int(off))°)" :
                               "Нейтрально",
                        isFirst: false, isLast: !showHealth)
            }

            if showHealth {
                infoRow(icon: "cross.case.fill", color: .red,
                        title: "Особенности здоровья",
                        value: p.healthFeatures.map(\.label).joined(separator: ", "),
                        isFirst: false, isLast: true)
            }
        }
    }

    private func activityDetail(_ level: ActivityLevel) -> String {
        switch level {
        case .low:      return "в коляске / спокойно"
        case .moderate: return "обычная прогулка"
        case .high:     return "активно бегает"
        }
    }

    private func infoRow(icon: String, color: Color, title: String, value: String,
                         isFirst: Bool, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.13))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.regularMaterial)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius:     isFirst ? 18 : 5,
            bottomLeadingRadius:  isLast  ? 18 : 5,
            bottomTrailingRadius: isLast  ? 18 : 5,
            topTrailingRadius:    isFirst ? 18 : 5
        ))
        .padding(.vertical, 0.5)
    }

    // MARK: - Wardrobe card (P1-1)

    private var wardrobeCard: some View {
        NavigationLink {
            MyWardrobeView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.indigo.opacity(0.13))
                        .frame(width: 36, height: 36)
                    Image(systemName: "hanger")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.indigo)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Мой гардероб")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(wardrobeSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var wardrobeSummary: String {
        let total = GarmentCatalog.all.count - 1  // без подгузника
        let owned = GarmentCatalog.all.filter {
            $0.id != "diaper" && UserWardrobeStore.shared.isOwned($0.id)
        }.count
        return owned == total
            ? "Все предметы каталога в наличии"
            : "В наличии \(owned) из \(total) предметов"
    }

    // MARK: - Notifications card (P2-3)

    private var notificationsCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.orange.opacity(0.13))
                    .frame(width: 36, height: 36)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Уведомления")
                    .font(.body)
                Text("Проветрить дождевик · время для прогулки")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $notificationsOn)
                .labelsHidden()
                .tint(.orange)
                .onChange(of: notificationsOn) { _, on in
                    Task {
                        let actual = await NotificationService.shared.setEnabled(on)
                        // система могла отказать в разрешении — синхронизируем тумблер
                        if actual != notificationsOn { notificationsOn = actual }
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Theme card

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Тема оформления", systemImage: "paintpalette.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                themeOption(label: "Авто",    icon: "circle.lefthalf.filled", tag: "system")
                themeOption(label: "Светлая", icon: "sun.max.fill",           tag: "light")
                themeOption(label: "Тёмная",  icon: "moon.fill",              tag: "dark")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func themeOption(label: String, icon: String, tag: String) -> some View {
        let selected = colorSchemeRaw == tag
        return Button {
            withAnimation(.spring(response: 0.3)) { colorSchemeRaw = tag }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selected ? Color.blue.opacity(0.14) : Color.primary.opacity(0.07))
                        .frame(height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(selected ? .blue : .secondary)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(selected ? Color.blue : Color.clear, lineWidth: 1.5)
                )
                Text(label)
                    .font(.caption)
                    .foregroundStyle(selected ? .blue : .secondary)
                    .fontWeight(selected ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Siri card

    private var siriCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Спросить Siri", systemImage: "mic.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text("Добавьте шорткат «Что надеть» в приложение Shortcuts и назовите его любой фразой — Siri будет вызывать рекомендацию без открытия SkyKid.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if #available(iOS 17, *) {
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Открыть Shortcuts", systemImage: "arrow.up.forward.app")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Edit button

    private var editButton: some View {
        Button { showEdit = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.body.weight(.medium))
                Text("Изменить данные ребёнка")
                    .font(.body.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
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

// MARK: - Previews

#if DEBUG
#Preview("👤 Профиль") {
    NavigationStack {
        ProfileSummaryView(profile: .constant(.mock))
    }
}
#endif
