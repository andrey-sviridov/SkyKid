# API SkyKid

## Open-Meteo (`Core/Network/OpenMeteoService.swift`)

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude=…&longitude=…
  &current=temperature_2m,apparent_temperature,relative_humidity_2m,
           wind_speed_10m,wind_direction_10m,weather_code,precipitation
  &wind_speed_unit=ms&timezone=auto
```

Бесплатно, без ключей.  
Парсится в приватные `OMRoot → OMCurrent`.  
`OpenMeteoService` конформит `WeatherService` — instance method `fetch(coordinate:)`.

## RainViewer (`Core/Network/RainViewerService.swift`)

```
GET https://api.rainviewer.com/public/weather-maps.json
→ { radar: { past: [{time, path}], nowcast: [{time, path}] } }

Тайл: https://tilecache.rainviewer.com{path}/256/{z}/{x}/{y}/2/1_1.png
```

Бесплатно, без ключей.  
`past` ≈ последние 2 ч, `nowcast` ≈ следующие 30 мин.  
`fetchFrames()` объединяет past + nowcast → `[RadarFrame]`.

## WeatherService протокол (`Core/Network/WeatherServiceProtocol.swift`)

```swift
protocol WeatherService: Sendable {
    func fetch(coordinate: CLLocationCoordinate2D) async throws -> WeatherData
}
```

`WeatherViewModel` инициализируется через `init(service: any WeatherService = OpenMeteoService())`.  
Для тестов/превью: `WeatherViewModel(service: MockWeatherService())`.
