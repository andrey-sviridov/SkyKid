# SkyKid — CLAUDE.md

iOS-приложение (SwiftUI, iOS 17+, Swift 6). Показывает погоду, карту осадков и рекомендует одежду для ребёнка с учётом его возраста.

## Быстрая сборка

```bash
open /Users/northarion/projects/SkyKid/SkyKid.xcodeproj

xcodebuild -project SkyKid.xcodeproj -scheme SkyKid \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Bundle ID: `com.skykid.app` · iOS 17.0 · Swift 6.0 · App Group: `group.com.skykid.app`

## Документация

| Файл | Содержимое |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Паттерны, SOLID-таблица, поток данных, навигация, тема |
| [docs/models.md](docs/models.md) | WeatherData, ChildProfile, AgeGroup, AppGroup, GarmentCatalog, WardrobeModel, склонение |
| [docs/algorithms.md](docs/algorithms.md) | OutfitAdvisor (OCP-правила), WardrobeModel.riskLevel, autoSelect() |
| [docs/api.md](docs/api.md) | Open-Meteo, RainViewer, WeatherService протокол |
| [docs/conventions.md](docs/conventions.md) | Соглашения кода, SOLID-специфика, производительность, виджет |

---

## Карта файлов

```
SkyKid/
├── App/
│   ├── SkyKidApp.swift              @main → ContentView
│   └── ContentView.swift            Роутер: онбординг → геолокация → TabView(5 вкладок)
│                                    ProfileSummaryView, PermissionView, DeniedView
│
├── Features/
│   ├── Weather/
│   │   ├── WeatherView.swift        Вкладка «Погода»: header, ChildPerceptionCard, statsGrid, StatCard
│   │   └── WeatherViewModel.swift   @MainActor @Observable; init(service: any WeatherService)
│   │
│   ├── Map/
│   │   ├── RadarMapView.swift       Вкладка «Осадки»: MKMapView + радар + плеер
│   │   ├── RadarMapViewModel.swift  @MainActor @Observable; frames[], playTask
│   │   └── RainViewerOverlay.swift  MKTileOverlay + renderer (opacity 0.6)
│   │
│   ├── Outfit/
│   │   ├── OutfitView.swift         Вкладка «Одежда»: список OutfitItem
│   │   ├── OutfitAdvisor.swift      OCP: protocol OutfitRule → 6 правил → [OutfitItem]
│   │   ├── GarmentCatalog.swift     GarmentLayer, WardrobeAgeGroup, ThermalRisk, GarmentItem,
│   │   │                            enum GarmentCatalog { all, byID, byLayer }
│   │   ├── WardrobeModel.swift      @MainActor @Observable; CLO-логика, riskLevel, autoSelect()
│   │   └── ClothingCalculatorView.swift  Вкладка «Конструктор» — только SwiftUI views
│   │                                     WeatherControlsCard, RiskMeterCard, RiskMeterBar,
│   │                                     AlertCard, AutoSelectButton, GarmentCard, …
│   │
│   └── Profile/
│       ├── ChildProfileSetupView.swift  Онбординг + редактирование профиля
│       └── ChildWeatherPerception.swift summary, ageContextNote, effectiveFeelsLike,
│                                        comfortScore/Label/Color, moodEmoji
│
├── Core/
│   ├── Network/
│   │   ├── WeatherServiceProtocol.swift  protocol WeatherService: Sendable
│   │   ├── OpenMeteoService.swift        struct: WeatherService; instance fetch(coordinate:)
│   │   └── RainViewerService.swift       fetchFrames() → [RadarFrame]
│   ├── Location/
│   │   └── LocationManager.swift         @Observable CLLocationManager
│   └── Models/
│       ├── WeatherData.swift             WeatherData + RadarFrame
│       ├── ChildProfile.swift            ChildProfile, ChildGender, AgeGroup, RussianCase,
│       │                                 AppGroup (enum), CachedWeather
│       │                                 ⚠️ Target Membership: SkyKid + SkyKidWidget
│       └── ChildProfileStore.swift       final class singleton; только таргет SkyKid
│
└── Info.plist

SkyKidWidget/
├── SkyKidWidgetBundle.swift         @main WidgetBundle
├── WidgetClothingCalculator.swift   ClothingWidgetStatus, WidgetOutfitRecommendation
├── ClothingStatusProvider.swift     TimelineProvider (30 мин); читает AppGroup
└── ClothingStatusWidgetView.swift   Small, Medium, Circular, Rectangular views
```
