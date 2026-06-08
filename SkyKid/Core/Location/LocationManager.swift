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
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        guard authorizationStatus == .authorizedWhenInUse
           || authorizationStatus == .authorizedAlways else { return }

        // Используем кешированную позицию iOS сразу — погода начнёт грузиться
        // ещё до получения нового GPS-фикса. Для последующих запусков это
        // убирает задержку 3–8 секунд и заменяет её на ~0 мс.
        if let cached = manager.location {
            location = cached
        }

        // Параллельно запускаем обновление для свежей позиции.
        // Когда придёт — onChange сработает повторно и обновит погоду в фоне.
        startUpdating()
    }
}
