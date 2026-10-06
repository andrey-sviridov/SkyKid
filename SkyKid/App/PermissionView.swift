import SwiftUI

struct PermissionView: View {
    let onAllow: () -> Void
    let onManualCity: (ManualLocation) -> Void
    let showsCurrentLocationOption: Bool

    @State private var city = ""
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let geocoder: any CityGeocoding

    init(
        geocoder: any CityGeocoding = AppleCityGeocoder(),
        showsCurrentLocationOption: Bool = true,
        onAllow: @escaping () -> Void,
        onManualCity: @escaping (ManualLocation) -> Void
    ) {
        self.geocoder = geocoder
        self.showsCurrentLocationOption = showsCurrentLocationOption
        self.onAllow = onAllow
        self.onManualCity = onManualCity
    }

    var body: some View {
        VStack(spacing: 24) {
            if showsCurrentLocationOption {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 72))
                    .symbolRenderingMode(.multicolor)
                Text("Нужен доступ к местоположению")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Чтобы показать актуальную погоду рядом с вами")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Разрешить", action: onAllow)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Divider()
            }

            VStack(spacing: 12) {
                Text("Или выберите город вручную")
                    .font(.headline)
                TextField("Название города", text: $city)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.addressCity)
                    .submitLabel(.search)
                    .onSubmit(searchCity)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                Button(action: searchCity) {
                    if isSearching { ProgressView() } else { Text("Найти город") }
                }
                .buttonStyle(.bordered)
                .disabled(isSearching || city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(minHeight: 44)
            }
        }
        .padding(32)
    }

    private func searchCity() {
        isSearching = true
        errorMessage = nil
        Task {
            do {
                let location = try await geocoder.location(for: city)
                onManualCity(location)
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? L10n.text("Не удалось найти город. Проверьте подключение к интернету.")
            }
            isSearching = false
        }
    }
}
