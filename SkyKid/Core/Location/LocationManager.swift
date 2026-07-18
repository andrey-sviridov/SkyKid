import CoreLocation
import Observation

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
