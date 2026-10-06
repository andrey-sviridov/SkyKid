# API SkyKid

SkyKid не использует backend для профиля, истории или активной прогулки. Эти данные сохраняются локально в App Group; наружу уходят только координаты и учётные данные выбранного погодного провайдера.

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

`WeatherViewModel.ContentState` различает загрузку, свежие данные (включая
свежий кеш), устаревший кеш и полную недоступность. При сетевой ошибке прежние
данные не получают новую дату: свежий кеш остаётся пригодным до общего
freshness-порога, устаревший показывается только как устаревший, а отсутствие
кеша приводит к конечному состоянию ошибки.

Техническая ошибка и выбор альтернативного провайдера доступны только в DEBUG;
production всегда использует Open-Meteo и не показывает ввод API-ключей.

```swift
protocol WeatherService: Sendable {
    func fetch(coordinate: CLLocationCoordinate2D) async throws -> NormalizedWeather
}
```

`WeatherViewModel` инициализируется через `init(service: any WeatherService = OpenMeteoService())`.  
Для тестов/превью: `WeatherViewModel(service: MockWeatherService())`.

## WeatherKit: отложенная production-интеграция

`WeatherKitService` сейчас не является адаптером Apple WeatherKit: в DEBUG он
делегирует запрос `OpenMeteoService`, а возвращаемый `WeatherSource` остаётся
`.openMeteo`. Production-фабрика всегда выбирает Open-Meteo. Поэтому наличие
варианта WeatherKit в диагностическом меню нельзя трактовать как подключённый
источник Apple.

Активация заблокирована до двух внешних решений:

1. WeatherKit capability должен быть включён для App ID и signing profile
   `com.skykid.app` владельцем Apple Developer Account.
2. Владелец продукта должен подтвердить условия использования, атрибуцию,
   лимиты и fallback-политику для целевых регионов.

До выполнения обоих условий entitlement не добавляется, SDK reference
`WeatherKit.framework` не связывается с target, закомментированная заготовка не
включается, а данные Open-Meteo никогда не маркируются как Apple WeatherKit.

После одобрения реализация должна проходить через существующую границу
`RawWeatherObservation → WeatherNormalizer`. Проверка состоит из трёх уровней:

- unit fixtures для mapping, optional-полей, source attribution и ошибок;
- parity-тесты нормализованного результата с другими провайдерами;
- entitlement smoke-test на подписанном устройстве. Симулятор допустим только
  как дополнительная проверка поддерживаемого Xcode/runtime и не заменяет
  проверку signing/capability на устройстве.

Ошибки авторизации или провайдера должны завершать запрос явной ошибкой. Тихая
подмена источника допустима только как явно выбранный fallback, который
сохраняет фактический `.openMeteo` в данных и UI.

## AQI: будущая граница API

SkyKid не запрашивает и не интерпретирует AQI. Перед добавлением источника нужны
отдельные решения по провайдеру, региональной шкале, приватности и safety-copy.
Будущий адаптер качества воздуха получает только координаты и собственные
credentials; профиль ребёнка, история и гардероб ему не передаются.

AQI не должен добавляться полем в `WeatherService` или маскироваться внутри
`NormalizedWeather`. Это отдельное optional-наблюдение с собственными source,
captured-at, шкалой/регионом и качеством полей. Отсутствие или устаревание такого
наблюдения не блокирует погодный запрос и рекомендацию одежды.
