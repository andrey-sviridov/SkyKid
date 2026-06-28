import SwiftUI

// MARK: - WeatherView

struct WeatherView: View {
    let weather: WeatherData
    let cityName: String
    var currentProvider: WeatherProvider = .openMeteo
    var onProviderChange: ((WeatherProvider, String?) -> Void)?

    @State private var showProviderSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                cardsSection
            }
        }
        .skyKidBackground()
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

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                Text(cityName)
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 12)

            Image(systemName: weather.conditionIcon)
                .font(.system(size: 76))
                .symbolRenderingMode(.multicolor)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
                .padding(.top, 10)

            Text("\(Int(weather.temperature.rounded()))°")
                .font(.system(size: 96, weight: .thin, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(weather.conditionDescription)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)

            Text("Ощущается как \(Int(weather.apparentTemperature.rounded()))°")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Cards (стеклянные карточки на градиенте)

    private var cardsSection: some View {
        VStack(spacing: 16) {
            if !weather.hourly.isEmpty {
                HourlyForecastCard(hourly: weather.hourly)
            }
            statsGrid
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
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

}

// MARK: - HourlyForecastCard

struct HourlyForecastCard: View {
    let hourly: [HourlyForecast]

    private var next24: [HourlyForecast] {
        let now = Date()
        return Array(
            hourly
                .filter { $0.time >= now.addingTimeInterval(-1800) }
                .prefix(24)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Почасовой прогноз", systemImage: "clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if next24.isEmpty {
                Text("Нет данных о прогнозе")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: 8) {
                        ForEach(next24, id: \.time) { item in
                            hourCell(item: item)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func hourCell(item: HourlyForecast) -> some View {
        VStack(spacing: 6) {
            Text(item.time, format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Image(systemName: wmoIcon(item.weatherCode))
                .font(.system(size: 22))
                .symbolRenderingMode(.multicolor)
                .frame(height: 30)

            Text("\(Int(item.temperature.rounded()))°")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(tempColorFor(item.temperature))
        }
        .frame(width: 44)
    }

    private func wmoIcon(_ code: Int) -> String {
        switch code {
        case 0:              return "sun.max.fill"
        case 1:              return "cloud.sun.fill"
        case 2, 3:           return "cloud.fill"
        case 45, 48:         return "cloud.fog.fill"
        case 51, 53, 55:     return "cloud.drizzle.fill"
        case 61, 63, 65:     return "cloud.rain.fill"
        case 71, 73, 75, 77: return "snowflake"
        case 80, 81, 82:     return "cloud.heavyrain.fill"
        case 95, 96, 99:     return "cloud.bolt.rain.fill"
        default:             return "cloud.fill"
        }
    }

    private func tempColorFor(_ t: Double) -> Color {
        switch t {
        case ..<0:    return .blue
        case 0..<12:  return Color(red: 0.2, green: 0.55, blue: 1.0)
        case 12..<22: return .green
        case 22..<28: return .orange
        default:      return .red
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("☀️ Ясно · 18°") {
    NavigationStack {
        WeatherView(weather: .mock, cityName: "Москва")
    }
}

#Preview("🌧 Дождь") {
    NavigationStack {
        WeatherView(weather: .mockRainy, cityName: "Санкт-Петербург")
    }
}

#Preview("❄️ Зима") {
    NavigationStack {
        WeatherView(weather: .mockWinter, cityName: "Сургут")
    }
}
#endif
