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
│   ├── ContentView.swift            Роутер: онбординг → геолокация → TabView(5 вкладок)
│   │                                ProfileSummaryView (+ переход «Мой гардероб»),
│   │                                PermissionView, DeniedView
│   └── SkyKidIntents.swift          AppIntents (Siri): рекомендация из кеша AppGroup
│
├── Features/
│   ├── Weather/
│   │   ├── WeatherView.swift        Вкладка «Погода»: header, ChildPerceptionCard, statsGrid, StatCard
│   │   └── WeatherViewModel.swift   @MainActor @Observable; init(service: any WeatherService)
│   │                                cityName: CLGeocoder reverse-geocode (кэш 1 км)
│   │
│   ├── Map/
│   │   ├── RadarMapView.swift       Вкладка «Осадки»: MKMapView + радар + плеер
│   │   ├── RadarMapViewModel.swift  @MainActor @Observable; frames[], playTask
│   │   ├── RainViewerOverlay.swift  MKTileOverlay + renderer (opacity 0.6)
│   │   └── WeatherTileOverlay.swift Тайлы осадков/спутника
│   │
│   ├── Outfit/                      ── TOG-пайплайн §2→§6 (вкладка «Одежда») ──
│   │   ├── OutfitView.swift         UI: hero, warnings, walkWindow, слои, фидбек
│   │   ├── OutfitConfig.swift       §2–§6 константы
│   │   ├── GearModels.swift         TransportMode, RainCoverState, GearSetup
│   │   ├── OutfitOutputModels.swift OutfitRecommendation, CalcStep, SafetyWarning
│   │   ├── EffectiveTemperatureCalculator.swift  §2 (ветер, влажность, осадки, солнце)
│   │   ├── MicroclimateCalculator.swift          §3 (T_micro в коляске/слинге)
│   │   ├── TOGCalculator.swift                   §4 (возраст, недоношенность, здоровье)
│   │   ├── OutfitSolver.swift                    §5 (скелет-шаблоны + личный гардероб)
│   │   ├── SafetyRulesEngine.swift               §6 (предупреждения, walkWindow)
│   │   ├── OutfitRecommendationService.swift     оркестратор §2→§6
│   │   │
│   │   │                            ── Старый CLO-движок (вкладка «Конструктор») ──
│   │   ├── GarmentCatalog.swift     GarmentLayer, WardrobeAgeGroup, ThermalRisk, GarmentItem,
│   │   │                            enum GarmentCatalog { all, byID, byLayer } (общий для обоих)
│   │   ├── WardrobeModel.swift      @MainActor @Observable; CLO-логика, riskLevel, autoSelect()
│   │   ├── ClothingRecommendationEngine.swift  старые правила рекомендаций
│   │   └── ClothingCalculatorView.swift  Вкладка «Конструктор» — только SwiftUI views
│   │                                     WeatherControlsCard, RiskMeterCard, RiskMeterBar,
│   │                                     AlertCard, AutoSelectButton, GarmentCard, …
│   │
│   └── Profile/
│       ├── ChildProfileSetupView.swift  Онбординг + редактирование (вкл. TOG-карточку:
│       │                                недоношенность, здоровье §4.5, активность §4.4)
│       ├── MyWardrobeView.swift         «Мой гардероб» — чек-лист GarmentCatalog (P1-1)
│       └── ChildWeatherPerception.swift summary, ageContextNote, effectiveFeelsLike,
│                                        comfortScore/Label/Color, moodEmoji
│
├── Core/
│   ├── Network/
│   │   ├── WeatherServiceProtocol.swift  protocol WeatherService: Sendable
│   │   ├── WeatherServiceSettings.swift  WeatherProvider enum, ключи, makeService
│   │   ├── OpenMeteoService.swift        основной: current + hourly (walkWindow)
│   │   ├── WeatherKitService.swift       заглушка → OpenMeteo (нет entitlement)
│   │   ├── OpenWeatherMapService.swift   по API-ключу
│   │   ├── WeatherAPIService.swift       по API-ключу
│   │   ├── YandexWeatherService.swift    по API-ключу
│   │   └── RainViewerService.swift       fetchFrames() → [RadarFrame]
│   ├── Location/
│   │   └── LocationManager.swift         @Observable CLLocationManager
│   └── Models/
│       ├── WeatherData.swift             WeatherData, PrecipType(wmoCode:), HourlyForecast, RadarFrame
│       ├── ChildProfile.swift            ChildProfile, ChildGender, AgeGroup, HealthCondition,
│       │                                 BabyActivityLevel, TempBand, RussianCase,
│       │                                 AppGroup (enum), CachedWeather
│       │                                 ⚠️ Target Membership: SkyKid + SkyKidWidget
│       ├── ChildProfileStore.swift       final class singleton; только таргет SkyKid
│       ├── UserWardrobeStore.swift       @Observable singleton; user_wardrobe в AppGroup (P1-1)
│       ├── BiasStore.swift               °C-обучение (старый движок)
│       └── PersonalOffsetStore.swift     §8 TOG-обучение (новый движок)
│
└── Info.plist

SkyKidWidget/
├── SkyKidWidgetBundle.swift         @main WidgetBundle
├── WidgetClothingCalculator.swift   ClothingWidgetStatus, WidgetOutfitRecommendation
├── ClothingStatusProvider.swift     TimelineProvider (30 мин); читает AppGroup
└── ClothingStatusWidgetView.swift   Small, Medium, Circular, Rectangular views
```
