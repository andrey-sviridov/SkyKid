import Foundation
import CoreLocation

// DIP: WeatherViewModel зависит от этой абстракции, а не от конкретной реализации.
// Подменяется в тестах / предпросмотрах без изменения ViewModel.

protocol WeatherService: Sendable {
    func fetch(coordinate: CLLocationCoordinate2D) async throws -> NormalizedWeather
}
