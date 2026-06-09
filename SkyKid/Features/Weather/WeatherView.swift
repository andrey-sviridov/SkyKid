import SwiftUI

// MARK: - WeatherView

struct WeatherView: View {
    let weather: WeatherData
    let cityName: String
    var profile: ChildProfile?
    var currentProvider: WeatherProvider = .openMeteo
    var onProviderChange: ((WeatherProvider, String?) -> Void)?

    @State private var showProviderSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            // Полноэкранный градиент — вытекает под статус-бар и навигацию
            LinearGradient(colors: weatherGradientColors, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    cardsSection
                }
            }
        }
        // Прозрачный nav bar + белые иконки поверх градиента
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showProviderSheet) {
            ProviderPickerView(
                current: currentProvider,
                onSelect: { provider, key in
                    onProviderChange?(provider, key)
                    showProviderSheet = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Hero (белый текст на градиенте)

    private var heroSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                Text(cityName)
                    .font(.subheadline)
            }
            .foregroundStyle(.white.opacity(0.75))
            .padding(.top, 12)

            Image(systemName: weather.conditionIcon)
                .font(.system(size: 76))
                .symbolRenderingMode(.multicolor)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
                .padding(.top, 10)

            Text("\(Int(weather.temperature.rounded()))°")
                .font(.system(size: 96, weight: .thin, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .contentTransition(.numericText())

            Text(weather.conditionDescription)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white)

            Text("Ощущается как \(Int(weather.apparentTemperature.rounded()))°")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))

            // Attribution chip — не навязчивый, но доступный
            Button {
                showProviderSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: currentProvider.iconName)
                        .font(.system(size: 9, weight: .medium))
                    Text(currentProvider.displayName)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Cards (системный фон, скруглённый верхний край)

    private var cardsSection: some View {
        VStack(spacing: 16) {
            if let profile {
                ChildPerceptionCard(
                    perception: ChildWeatherPerception(profile: profile, weather: weather)
                )
            }
            statsGrid
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30))
        .overlay(alignment: .top) {
            // Тонкая разделительная линия — хорошо видна в обеих темах
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                .frame(height: 60)
                .clipped()
        }
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatCard(icon: "wind",               color: .teal,   title: "Ветер",
                     value: "\(Int(weather.windSpeed.rounded())) м/с")
            StatCard(icon: "location.north.fill", color: .orange, title: "Направление",
                     value: weather.windDirectionLabel,
                     iconRotation: Double(weather.windDirection))
            StatCard(icon: "humidity.fill",       color: .blue,   title: "Влажность",
                     value: "\(weather.humidity)%")
            StatCard(icon: "cloud.rain.fill",     color: .indigo, title: "Осадки",
                     value: String(format: "%.1f мм", weather.precipitation))
        }
    }

    // MARK: - Gradient

    private var weatherGradientColors: [Color] {
        let code = weather.weatherCode
        let temp = weather.temperature

        switch code {
        case 71...77:  // Снег
            return [Color(red: 0.38, green: 0.48, blue: 0.66), Color(red: 0.18, green: 0.26, blue: 0.46)]
        case 95...99:  // Гроза
            return [Color(red: 0.10, green: 0.07, blue: 0.24), Color(red: 0.24, green: 0.16, blue: 0.40)]
        case 45, 48:   // Туман
            return [Color(red: 0.26, green: 0.30, blue: 0.38), Color(red: 0.42, green: 0.46, blue: 0.54)]
        case 51...82:  // Дождь/ливень
            return [Color(red: 0.06, green: 0.13, blue: 0.34), Color(red: 0.16, green: 0.34, blue: 0.56)]
        default:       // Ясно/облачно — по температуре
            if temp < 0 {
                return [Color(red: 0.03, green: 0.06, blue: 0.28), Color(red: 0.08, green: 0.26, blue: 0.55)]
            } else if temp < 10 {
                return [Color(red: 0.04, green: 0.20, blue: 0.44), Color(red: 0.06, green: 0.46, blue: 0.68)]
            } else if temp < 20 {
                return [Color(red: 0.00, green: 0.36, blue: 0.56), Color(red: 0.00, green: 0.58, blue: 0.50)]
            } else if temp < 28 {
                return [Color(red: 0.80, green: 0.36, blue: 0.06), Color(red: 1.00, green: 0.64, blue: 0.18)]
            } else {
                return [Color(red: 0.66, green: 0.10, blue: 0.04), Color(red: 0.98, green: 0.40, blue: 0.06)]
            }
        }
    }
}

// MARK: - ChildPerceptionCard

struct ChildPerceptionCard: View {
    let perception: ChildWeatherPerception

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(comfortColor.opacity(0.14))
                        .frame(width: 56, height: 56)
                    Image(systemName: comfortIcon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(comfortColor)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(perception.profile.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(perception.profile.ageLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Label(perception.comfortLabel, systemImage: comfortIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(comfortColor)
                }

                Spacer(minLength: 8)

                VStack(spacing: 1) {
                    Text("\(Int(perception.effectiveFeelsLike.rounded()))°")
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(comfortColor)
                    Text("для малыша")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Прогресс-бар комфорта
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemFill))
                        .frame(height: 5)
                    Capsule()
                        .fill(comfortColor.gradient)
                        .frame(width: geo.size.width * CGFloat(perception.comfortScore) / 100, height: 5)
                        .animation(.spring(response: 0.5), value: perception.comfortScore)
                }
            }
            .frame(height: 5)

            // Текст-резюме
            Text(perception.summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            // Возрастная подсказка
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .padding(.top, 1)
                Text(perception.ageContextNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
    }

    private var comfortColor: Color {
        let c = perception.comfortColor
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    private var comfortIcon: String {
        switch perception.comfortScore {
        case 80...100: return "checkmark.circle.fill"
        case 55..<80:  return "minus.circle.fill"
        case 30..<55:  return "thermometer.low"
        default:       return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - ProviderPickerView

struct ProviderPickerView: View {
    let current: WeatherProvider
    let onSelect: (WeatherProvider, String?) -> Void

    private static let integratedProviders: [WeatherProvider] = [.openMeteo, .openWeatherMap, .weatherAPI, .yandex]

    @State private var selected: WeatherProvider
    @State private var apiKey: String = ""
    @FocusState private var keyFocused: Bool

    init(current: WeatherProvider, onSelect: @escaping (WeatherProvider, String?) -> Void) {
        self.current = current
        self.onSelect = onSelect
        _selected = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Self.integratedProviders) { provider in
                        ProviderRow(
                            provider: provider,
                            isSelected: selected == provider,
                            action: {
                                withAnimation(.spring(response: 0.28)) {
                                    selected = provider
                                    apiKey = ""
                                    keyFocused = false
                                }
                                if !provider.requiresKey { onSelect(provider, nil) }
                            }
                        )
                    }
                } header: {
                    Text("Доступные источники")
                } footer: {
                    Text("Источник влияет на точность ощущаемой температуры. Все сервисы передают ветер и влажность.")
                }

                if selected.requiresKey {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("API-ключ для \(selected.displayName)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            TextField("Введите ключ", text: $apiKey)
                                .font(.body.monospaced())
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($keyFocused)
                            if let url = apiKeyURL(for: selected) {
                                Link("Получить ключ →", destination: url)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Авторизация")
                    }

                    Section {
                        Button {
                            let stored = storedKey(for: selected)
                            onSelect(selected, apiKey.isEmpty ? stored : apiKey)
                        } label: {
                            Text("Применить")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(apiKey.isEmpty && storedKey(for: selected) == nil ? Color.secondary : Color.blue)
                        }
                        .disabled(apiKey.isEmpty && storedKey(for: selected) == nil)
                    }
                    .onAppear { apiKey = storedKey(for: selected) ?? "" }
                }

            }
            .navigationTitle("Источник данных")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func storedKey(for provider: WeatherProvider) -> String? {
        switch provider {
        case .openWeatherMap: return UserDefaults.standard.string(forKey: WeatherProvider.owmKeyKey)
        case .weatherAPI:     return UserDefaults.standard.string(forKey: WeatherProvider.wapiKeyKey)
        case .yandex:         return UserDefaults.standard.string(forKey: WeatherProvider.yandexKeyKey)
        default:              return nil
        }
    }

    private func apiKeyURL(for provider: WeatherProvider) -> URL? {
        switch provider {
        case .openWeatherMap: return URL(string: "https://openweathermap.org/api")
        case .weatherAPI:     return URL(string: "https://www.weatherapi.com/signup.aspx")
        case .yandex:         return URL(string: "https://developer.tech.yandex.ru/services/meteoreader")
        default:              return nil
        }
    }
}

// MARK: - ProviderRow

private struct ProviderRow: View {
    let provider: WeatherProvider
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.blue.opacity(0.14) : Color(.tertiarySystemBackground))
                        .frame(width: 36, height: 36)
                    Image(systemName: provider.iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(provider.displayName)
                            .foregroundStyle(.primary)
                            .font(.body.weight(isSelected ? .semibold : .regular))
                        if !provider.requiresKey {
                            Text("Бесплатно")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12), in: Capsule())
                        }
                    }
                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.system(size: 18))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - StatCard

struct StatCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    var iconRotation: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.13))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(iconRotation))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}
