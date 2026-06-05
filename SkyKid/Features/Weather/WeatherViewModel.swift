import Foundation
import CoreLocation
import Observation
import WidgetKit

// DIP: ViewModel зависит от WeatherService (абстракция), не от OpenMeteoService.
// Для тестов достаточно создать WeatherViewModel(service: MockWeatherService()).

@MainActor
@Observable
final class WeatherViewModel {
    private let service: any WeatherService

    var weather: WeatherData?
    var isLoading = false
    var error: String?

    init(service: any WeatherService = OpenMeteoService()) {
        self.service = service
    }

    func load(coordinate: CLLocationCoordinate2D, cityName: String = "Моё местоположение") async {
        isLoading = true
        error = nil
        do {
            let data = try await service.fetch(coordinate: coordinate)
            weather = data
            AppGroup.saveWeather(
                temperature:   data.temperature,
                apparentTemp:  data.apparentTemperature,
                weatherCode:   data.weatherCode,
                windSpeed:     data.windSpeed,
                precipitation: data.precipitation,
                cityName:      cityName
            )
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = "Не удалось загрузить погоду"
        }
        isLoading = false
    }
}
