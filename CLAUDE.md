# SkyKid — детское погодное приложение для iPhone

## Суть проекта

iOS-приложение (SwiftUI, iOS 17+), которое показывает актуальную погоду и помогает родителям решить, во что одеть ребёнка на прогулку.

## Ключевые функции

### 1. Текущая погода
- Температура (фактическая + ощущается как)
- Влажность
- Скорость и направление ветра (с иконкой компаса)
- Описание состояния (ясно / облачно / дождь / снег и т.д.)

### 2. Карта осадков с плеером
- Интерактивная тайловая карта (провайдер: RainViewer API или Open-Meteo Radar)
- Слой осадков с анимацией — ретроспектива + прогноз суммарно ~24 ч
- Плеер: кнопки ▶ / ⏸, ползунок времени, отметки каждый час
- Текущее положение пользователя на карте

### 3. Рекомендации одежды для ребёнка
- Входные данные: температура, ощущаемая температура, ветер, осадки
- Выходные данные: список предметов одежды с иконками (шапка, куртка, перчатки, резиновые сапоги и т.п.)
- Алгоритм с пороговыми значениями; в будущем — настройка возраста ребёнка

## Стек

| Слой | Решение |
|---|---|
| UI | SwiftUI |
| Карта | MapKit (SwiftUI `Map`) + тайловый оверлей `MKTileOverlay` |
| Геолокация | CoreLocation (`CLLocationManager`) |
| Погода | Open-Meteo API (бесплатно, без ключа) |
| Радар | RainViewer API v2 (бесплатно) |
| Архитектура | MVVM + `@Observable` (Swift 5.9) |
| Сборка | Xcode 16, Swift 6 concurrency |

## Структура директорий

```
SkyKid/
├── App/
│   ├── SkyKidApp.swift          # @main
│   └── ContentView.swift        # TabView: Weather | Map | Outfit
├── Features/
│   ├── Weather/
│   │   ├── WeatherView.swift
│   │   └── WeatherViewModel.swift
│   ├── Map/
│   │   ├── RadarMapView.swift
│   │   ├── RadarMapViewModel.swift
│   │   └── RainViewerOverlay.swift
│   └── Outfit/
│       ├── OutfitView.swift
│       └── OutfitAdvisor.swift
├── Core/
│   ├── Network/
│   │   ├── OpenMeteoService.swift
│   │   └── RainViewerService.swift
│   ├── Location/
│   │   └── LocationManager.swift
│   └── Models/
│       ├── WeatherData.swift
│       └── RadarFrame.swift
└── Resources/
    └── Assets.xcassets/
```

## API

### Open-Meteo (погода)
```
GET https://api.open-meteo.com/v1/forecast
  ?latitude={lat}&longitude={lon}
  &current=temperature_2m,apparent_temperature,relative_humidity_2m,
            wind_speed_10m,wind_direction_10m,weather_code,precipitation
  &hourly=precipitation_probability
  &wind_speed_unit=ms
  &timezone=auto
```

### RainViewer (радарные тайлы)
```
GET https://api.rainviewer.com/public/weather-maps.json
→ даёт список timestamped path-ов для тайлов
Тайл: https://tilecache.rainviewer.com{path}/256/{z}/{x}/{y}/2/1_1.png
```

## Алгоритм одежды (OutfitAdvisor)

Входные параметры: `feelsLike` (°C), `windSpeed` (м/с), `precipitation` (мм/ч), `weatherCode`

| Условие | Рекомендация |
|---|---|
| feelsLike > 22 | Лёгкая одежда, панамка |
| feelsLike 15–22 | Лёгкая куртка |
| feelsLike 5–15 | Куртка, шапка, тонкая кофта |
| feelsLike 0–5 | Тёплая куртка, шапка, перчатки |
| feelsLike < 0 | Зимний комбинезон, шапка, варежки, термобельё |
| windSpeed > 7 м/с | +ветрозащитная куртка |
| precipitation > 0 | +дождевик / зонт, резиновые сапоги |
| снег (weatherCode 71-77) | +резиновые сапоги → валенки |

## Разработка

```bash
# Открыть в Xcode
open SkyKid.xcodeproj

# Симулятор (нет GPS — Location Manager даёт mock координаты)
# Устройство — реальный GPS

# Линтинг
swiftlint
```

## Соглашения

- Никаких `!` force-unwrap — только `guard let` / `if let`
- `async/await` везде, никаких колбеков
- Все строки на экране — через `LocalizedStringKey` (подготовка к локализации)
- Размеры и отступы через константы в `Design.swift`, не магические числа
