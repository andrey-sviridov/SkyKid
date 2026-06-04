import Foundation
import CoreLocation
import Observation
import WidgetKit

@MainActor
@Observable
final class WeatherViewModel {
    var weather: WeatherData?
    var isLoading = false
    var error: String?

    func load(coordinate: CLLocationCoordinate2D, cityName: String = "Моё местоположение") async {
        isLoading = true
        error = nil
        do {
            let data = try await OpenMeteoService.fetch(coordinate: coordinate)
            weather = data
            // Кешируем данные в App Group — виджет читает их без доступа к геолокации
            AppGroup.saveWeather(
                temperature:   data.temperature,
                apparentTemp:  data.apparentTemperature,
                weatherCode:   data.weatherCode,
                windSpeed:     data.windSpeed,
                precipitation: data.precipitation,
                cityName:      cityName
            )
            // Перезапускаем timeline виджета сразу после получения свежих данных
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = "Не удалось загрузить погоду"
        }
        isLoading = false
    }
}
