import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class WeatherViewModel {
    var weather: WeatherData?
    var isLoading = false
    var error: String?

    func load(coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        error = nil
        do {
            weather = try await OpenMeteoService.fetch(coordinate: coordinate)
        } catch {
            self.error = "Не удалось загрузить погоду"
        }
        isLoading = false
    }
}
