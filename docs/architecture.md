# Архитектура SkyKid

## Паттерны

- **MVVM** — Views не обращаются к сети напрямую, только через ViewModel
- **`@Observable` + `@MainActor`** на всех VM — безопасно для Swift 6 concurrency
- **`@unchecked Sendable`** на `ChildProfileStore` — корректно, т.к. UserDefaults thread-safe
- `LocationManager` — `@Observable NSObject`, запрашивает геолокацию, останавливает обновление после первого фикса
- `RadarTileView` — UIViewRepresentable-мост для `MKTileOverlay` поверх SwiftUI `Map`
- **App Group** (`group.com.skykid.app`) — единое хранилище; виджет и приложение читают один `UserDefaults(suiteName:)`
- **WidgetKit** — `StaticConfiguration`; таймлайн обновляется каждые 30 мин ИЛИ немедленно при загрузке погоды (`WidgetCenter.reloadAllTimelines()`)

## SOLID

| Принцип | Реализация |
|---|---|
| **S** — SRP | `ClothingCalculatorView` — только views; `WardrobeModel` — только логика; `ChildProfileStore` — только persistence |
| **O** — OCP | `OutfitRule` протокол: новые правила — новый тип, не модификация `OutfitAdvisor` |
| **L** — LSP | Struct/enum-архитектура, иерархий наследования нет |
| **I** — ISP | `WeatherService` содержит только `fetch(coordinate:)` — минимальный интерфейс |
| **D** — DIP | `WeatherViewModel(service: any WeatherService)` — зависимость от абстракции, не от `OpenMeteoService` |

## Поток данных

```
ContentView
  └─ LocationManager.location → onChange → WeatherViewModel.load(coordinate:cityName:)
       └─ service.fetch(coordinate:)       ← any WeatherService (по умолч. OpenMeteoService)
            → WeatherData
            ├─ AppGroup.saveWeather(...)
            ├─ WidgetCenter.reloadAllTimelines()
            ├─ WeatherView(weather, cityName, profile?)
            │    └─ ChildPerceptionCard ← ChildWeatherPerception(profile, weather)
            └─ OutfitView(weather, profile?)
                 └─ OutfitAdvisor.recommend(weather, profile?)
                      └─ rules.flatMap { $0.apply(...) }

ContentView
  └─ RadarMapView(coordinate)
       └─ RadarMapViewModel.loadFrames() → RainViewerService.fetchFrames() → [RadarFrame]
            └─ RainViewerOverlay рисуется через RadarTileView (UIViewRepresentable)

ContentView
  └─ ClothingCalculatorView(profile?)
       └─ WardrobeModel
            ├─ riskLevel → ThermalRisk (CLO-формула + safety overrides)
            └─ autoSelect() → жадный алгоритм → selectedItems: Set<GarmentItem>
                 └─ GarmentCatalog.byID / .byLayer

Виджет
  └─ ClothingStatusProvider.getTimeline()
       ├─ AppGroup.loadCachedWeather()
       ├─ AppGroup.loadProfile()
       └─ WidgetClothingCalculator.recommend() → ClothingStatusWidgetView
```

## Онбординг / навигация (ContentView)

```
childProfile == nil → ChildProfileSetupView  (первый запуск)
childProfile != nil →
  .notDetermined → PermissionView
  .denied        → DeniedView
  иначе          → TabView (теги 0–4)
    0 — Погода       (WeatherView)
    1 — Осадки       (RadarMapView)
    2 — Одежда       (OutfitView)
    3 — Конструктор  (ClothingCalculatorView)
    4 — Профиль      (ProfileSummaryView + sheet редактирования)
```

## Тема оформления

`@AppStorage("colorScheme")` — `"system"` / `"light"` / `"dark"`.  
Читается в `ContentView` → `.preferredColorScheme(preferredScheme)`.  
Picker — вкладка «Профиль» → секция «Оформление».
