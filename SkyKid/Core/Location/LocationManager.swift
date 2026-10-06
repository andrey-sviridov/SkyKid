import CoreLocation
import Observation

// MARK: - Location selection

struct ManualLocation: Codable, Equatable, Sendable {
    let cityName: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum LocationSelection: Codable, Equatable, Sendable {
    case currentLocation
    case manualCity(ManualLocation)
}

@MainActor
@Observable
final class LocationSelectionStore {
    private static let storageKey = "location_selection_v1"
    private let defaults: UserDefaults

    private(set) var selection: LocationSelection?

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        selection = defaults.data(forKey: Self.storageKey)
            .flatMap { try? JSONDecoder().decode(LocationSelection.self, from: $0) }
    }

    func selectCurrentLocation() {
        save(.currentLocation)
    }

    func selectManualCity(_ location: ManualLocation) {
        save(.manualCity(location))
    }

    private func save(_ selection: LocationSelection) {
        self.selection = selection
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

@MainActor
protocol CityGeocoding {
    func location(for city: String) async throws -> ManualLocation
}

enum CityGeocodingError: LocalizedError, Equatable {
    case emptyQuery
    case notFound

    var errorDescription: String? {
        switch self {
        case .emptyQuery: return L10n.text("Введите название города")
        case .notFound: return L10n.text("Город не найден. Проверьте название и попробуйте снова.")
        }
    }
}

struct AppleCityGeocoder: CityGeocoding {
    func location(for city: String) async throws -> ManualLocation {
        let query = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw CityGeocodingError.emptyQuery }
        let placemarks = try await CLGeocoder().geocodeAddressString(query)
        guard let placemark = placemarks.first, let coordinate = placemark.location?.coordinate else {
            throw CityGeocodingError.notFound
        }
        return ManualLocation(
            cityName: placemark.locality ?? placemark.name ?? query,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    var location: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        // Километровая точность достаточна для погоды и даёт фикс быстрее
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
        hydrateCachedLocationIfAvailable()
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func requestOnce() {
        // requestLocation() — однократный запрос: автоматически останавливается
        // после первого фикса или по таймауту. В отличие от startUpdatingLocation()
        // не удерживает экран активным пока ждёт GPS.
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        // requestLocation() сам останавливается — stopUpdatingLocation() не нужен.
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Тихо игнорируем: геолокация опциональная, погода загрузится по кешу.
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        guard authorizationStatus == .authorizedWhenInUse
           || authorizationStatus == .authorizedAlways else { return }

        if hydrateCachedLocationIfAvailable(maxAge: 300) { return }

        // Запрашиваем свежий фикс только если кеш устарел или отсутствует.
        requestOnce()
    }

    @discardableResult
    private func hydrateCachedLocationIfAvailable(maxAge: TimeInterval? = nil) -> Bool {
        guard let cached = manager.location else { return false }
        location = cached
        guard let maxAge else { return true }
        return cached.timestamp.timeIntervalSinceNow > -maxAge
    }
}
