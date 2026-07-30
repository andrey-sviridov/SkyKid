import SwiftUI

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
