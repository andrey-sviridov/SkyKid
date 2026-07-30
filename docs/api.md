# API SkyKid

## Open-Meteo (`Core/Network/OpenMeteoService.swift`)

```
GET https://api.open-meteo.com/v1/forecast
  ?latitude=…&longitude=…
  &current=temperature_2m,apparent_temperature,relative_humidity_2m,
           wind_speed_10m,wind_direction_10m,weather_code,precipitation,
           wind_gusts_10m,cloud_cover
  &hourly=temperature_2m,apparent_temperature,precipitation_probability,
          weather_code,uv_index
  &wind_speed_unit=ms&timezone=auto
```

Бесплатно, без ключей.  
Парсится в приватные `OMRoot → OMCurrent/OMHourly`. Ближайший почасовой UV помечается как `derived`.

## Единая адаптация провайдеров

Каждый сервис сохраняет необязательные поля в `RawWeatherObservation` и передаёт их в `WeatherNormalizer`. Только после этого наружу возвращается `NormalizedWeather`.

| Провайдер | Порывы | UV | Облачность | Почасовой прогноз |
|---|---:|---:|---:|---:|
| Open-Meteo | текущие | ближайший hourly (`derived`) | текущая | да |
| OpenWeatherMap | если есть | нет | если есть | нет |
| WeatherAPI.com | если есть | текущий | текущая | нет |
| Яндекс Погода | если есть | нет | текущая | нет |
| WeatherKit | временно делегирует Open-Meteo | фактический источник — Open-Meteo | фактический источник — Open-Meteo | да |

Отсутствующие UV и облачность не превращаются в «ясно и солнечно»: нормализатор ставит UV `0`, облачность `100%`, отмечает оба поля как `unavailable` и тем самым отключает неподтверждённую солнечную прибавку. Отсутствующий порыв безопасно приравнивается к устойчивому ветру.

## WeatherService протокол (`Core/Network/WeatherServiceProtocol.swift`)

```swift
protocol WeatherService: Sendable {
    func fetch(coordinate: CLLocationCoordinate2D) async throws -> NormalizedWeather
}
```

`WeatherViewModel` инициализируется через `init(service: any WeatherService = OpenMeteoService())`.  
Для тестов/превью: `WeatherViewModel(service: MockWeatherService())`.
