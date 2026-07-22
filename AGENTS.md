# SkyKid — AGENTS.md

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
| [docs/models.md](docs/models.md) | RawWeatherObservation, NormalizedWeather, ChildThermalProfile, WalkContext, migration |
| [docs/algorithms.md](docs/algorithms.md) | Основной TOG-пайплайн, OutfitSolver, safety-правила и legacy CLO-конструктор |
| [docs/api.md](docs/api.md) | Open-Meteo, RainViewer, WeatherService протокол |
| [docs/conventions.md](docs/conventions.md) | Соглашения кода, SOLID-специфика, производительность, виджет |
| [docs/safety.md](docs/safety.md) | Уровни safety-решений, официальные источники, медицинские ограничения |
| [docs/accessibility.md](docs/accessibility.md) | VoiceOver, Dynamic Type, размеры целей и ручной release-checklist |
| [docs/improvement-plan.md](docs/improvement-plan.md) | План исправлений, критерии готовности и журнал выполнения |

---

## Карта файлов

```
SkyKid/
├── App/
│   ├── SkyKidApp.swift              @main → ContentView
│   ├── ContentView.swift            Роутер: онбординг → геолокация → TabView(5 вкладок)
│   │                                ProfileSummaryView (+ переход «Мой гардероб»),
│   │                                PermissionView, DeniedView
│   └── SkyKidIntents.swift          AppIntents (Siri): единый RecommendationSnapshot
│
├── Features/
│   ├── Weather/
│   │   ├── WeatherView.swift        Вкладка «Погода»: источник, качество, statsGrid
│   │   ├── WeatherViewModel.swift   @MainActor @Observable; init(service: any WeatherService)
│   │                                cityName + weatherUpdatedAt; CLGeocoder кэш 1 км
│   │   └── Components/WeatherDataQualityCard.swift  уверенность и неполные поля
│   │
│   ├── Map/
│   │   ├── RadarMapView.swift       Вкладка «Осадки»: MKMapView + радар + плеер
│   │   ├── RadarMapViewModel.swift  @MainActor @Observable; frames[], playTask
│   │   ├── RainViewerOverlay.swift  MKTileOverlay + renderer (opacity 0.6)
│   │   └── WeatherTileOverlay.swift Тайлы осадков/спутника
│   │
│   ├── History/
│   │   ├── WalkHistoryView.swift         прогулки + история отзывов
│   │   ├── FeedbackHistoryItem.swift     presentation builder наблюдений
│   │   └── FeedbackHistorySection.swift  сворачиваемая карточка отзывов
│   │
│   ├── Outfit/                      ── TOG-пайплайн §2→§6 (вкладка «Одежда») ──
│   │   ├── OutfitView.swift         UI: короткий ответ, safety, слои, alternatives, feedback
│   │   ├── OutfitViewModel.swift    presentation state + контекстный TOG-фидбек
│   │   ├── OutfitParentSummary.swift pure builder: что/почему/проверка/уверенность
│   │   ├── TransportMode+Presentation.swift подписи/иконки транспорта
│   │   ├── Components/              Parent summary, details, alternatives, warnings, feedback
│   │   ├── WalkPreparation/         Упрощённая форма прогулки + value-type ViewModel
│   │   ├── OutfitConfig.swift       §2–§6 константы
│   │   ├── GearModels.swift         TransportMode, RainCoverState, GearSetup
│   │   ├── OutfitOutputModels.swift OutfitRecommendation, OutfitFit, CalcStep, SafetyWarning
│   │   ├── WeatherThermalEffects.swift           независимые погодные вклады
│   │   ├── EffectiveTemperatureCalculator.swift  §2: один расчёт погодных вкладов
│   │   ├── TransportExposureProfile.swift        коэффициенты защиты транспорта
│   │   ├── MicroclimateCalculator.swift          §3: композиция → T_micro
│   │   ├── TOGCalculator.swift                   §4 (возраст, недоношенность, здоровье)
│   │   ├── GarmentCompatibilityPolicy.swift     §5 зоны, слоты, exclusive-группы
│   │   ├── OutfitCombinationSolver.swift        §5 поиск совместимых слоёв по TOG
│   │   ├── OutfitAccessoryResolver.swift        §5 защита головы, рук и стоп
│   │   ├── OutfitSolver.swift                    §5 оркестратор реального/идеального комплекта
│   │   ├── SafetyAssessmentContext.swift         единый вход safety-политик
│   │   ├── AgeSafetyPolicy.swift                 возрастные продуктовые границы
│   │   ├── MedicalSafetyPolicy.swift             лихорадка, болезнь, особая осторожность
│   │   ├── WeatherSafetyPolicy.swift             холод, жара, ветер, осадки, UV
│   │   ├── TransportSafetyPolicy.swift           дождевик, лицо, автокресло
│   │   ├── ThermalComfortCheckPolicy.swift       проверка шеи/верхней части спины
│   │   ├── SafetyRulesEngine.swift               оркестратор предупреждений и walkWindow
│   │   ├── OutfitRecommendationService.swift     оркестратор §2→§6
│   │   ├── BuildOutfitRecommendationUseCase.swift один result для UI + snapshot
│   │   │
│   │   │                            ── Старый CLO-движок (вкладка «Конструктор») ──
│   │   ├── GarmentCatalog.swift     GarmentLayer, WardrobeAgeGroup, ThermalRisk, GarmentItem,
│   │   │                            enum GarmentCatalog { all, byID, byLayer } (общий для обоих)
│   │   ├── WardrobeModel.swift      @MainActor @Observable; CLO-логика, riskLevel, UI actions
│   │   ├── LegacyWardrobeAutoSelector.swift  жадный CLO-подбор только для Конструктора
│   │   ├── ClothingRecommendationEngine.swift  старые правила рекомендаций
│   │   └── ClothingCalculatorView.swift  Вкладка «Конструктор» — только SwiftUI views
│   │                                     WeatherControlsCard, RiskMeterCard, RiskMeterBar,
│   │                                     AlertCard, AutoSelectButton, GarmentCard, …
│   │
│   └── Profile/
│       ├── ChildProfileSetupView.swift  Онбординг + редактирование только постоянных данных
│       ├── Components/StableThermalTraitRow.swift  Строка устойчивой особенности
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
│   ├── Notifications/
│   │   ├── NotificationService.swift      планирование безопасных уведомлений
│   │   └── SafeReminderContent.swift      тестируемые тексты без stale outfit
│   └── Models/
│       ├── RawWeatherObservation.swift   Optional transport model + WeatherSource
│       ├── NormalizedWeather.swift       Единый вход расчёта + качество полей
│       ├── WeatherNormalizer.swift       Safe fallback и различение nil / реального нуля
│       ├── WeatherData.swift             Legacy WeatherData, PrecipType, HourlyForecast, RadarFrame
│       ├── ChildThermalProfile.swift     Постоянные данные + StableThermalTrait
│       ├── WalkContext.swift             Временные условия одной прогулки; не Codable
│       ├── WalkContextStore.swift        In-memory context lifecycle; только SkyKid
│       ├── ChildProfile.swift            Codable v2 / legacy migration, ChildGender, AgeGroup,
│       │                                 AppGroup (enum), CachedWeather
│       │                                 ⚠️ Target Membership: SkyKid + SkyKidWidget
│       ├── OutfitRecommendationSnapshot.swift общий снимок + время/условия
│       ├── OutfitFeedback.swift          UserFeedback без зависимости от legacy engine
│       ├── PersonalizationModels.swift  контекст, observation, state, summary
│       ├── PersonalizationEngine.swift  повторяемые сигналы, дедупликация, лимиты
│       ├── ChildProfileStore.swift       final class singleton; только таргет SkyKid
│       ├── UserWardrobeStore.swift       @Observable singleton; user_wardrobe в AppGroup (P1-1)
│       ├── BiasStore.swift               °C-обучение (старый движок)
│       ├── PersonalOffsetStore.swift     §8 persistence + миграция v1 → v2
│       └── WalkLog.swift                 прогулка + optional feedback-контекст
│   └── Storage/
│       ├── RecommendationSnapshotStore.swift App Group persistence, SkyKid + Widget
│       └── WalkLogStore.swift           журнал + синхронизация персонализации
│
└── Info.plist

SkyKidWidget/
├── SkyKidWidgetBundle.swift         @main WidgetBundle
├── WidgetClothingCalculator.swift   только presentation-адаптер snapshot; без расчёта одежды
├── ClothingStatusProvider.swift     fresh outfit / stale update metadata
└── ClothingStatusWidgetView.swift   Small, Medium, Circular, Rectangular + время/контекст
```

---

## Обязательные правила Swift-разработки

При написании и рефакторинге кода действовать как Senior Swift Developer со строгим фокусом на модульность, читаемость и Clean Architecture.

1. **Zero Spaghetti.** Не объединять несвязанные обязанности в одном файле, классе или SwiftUI View.
2. **Decomposition.** Разбивать реализацию на небольшие переиспользуемые функции и изолированные компоненты. У каждой функции и компонента должна быть одна ответственность.
3. **File Structure.** Компоненты разных уровней и ответственности размещать в отдельных файлах с понятными именами.
4. **Logical Blocks.** Использовать `// MARK: - [Section Name]` для свойств, инициализации, действий и вспомогательной логики. Связанные protocol conformances и дополнительную функциональность группировать через `extension`.
5. **Idiomatic Swift.** Следовать Apple Swift API Design Guidelines. Не размещать тяжёлую бизнес-логику в SwiftUI Views; выносить её в ViewModel, сервисы, use cases или доменные компоненты.
6. **Dependency direction.** UI зависит от доменных абстракций, а инфраструктура реализует эти абстракции. Не протягивать сетевые, storage- или framework-типы в доменную логику без адаптеров.
7. **Testability.** Новые вычислители, правила и use cases проектировать как детерминированные и независимо тестируемые компоненты с явными входами и выходами.
