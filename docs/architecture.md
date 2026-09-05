# Архитектура SkyKid

## Паттерны

- **MVVM** — Views не обращаются к сети напрямую, только через ViewModel
- **`@Observable` + `@MainActor`** на долгоживущих VM; локальное состояние короткой формы может быть value-type
- **`@unchecked Sendable`** на `ChildProfileStore` — корректно, т.к. UserDefaults thread-safe
- `LocationManager` — `@Observable NSObject`, запрашивает геолокацию, останавливает обновление после первого фикса
- `RadarTileView` — UIViewRepresentable-мост для `MKTileOverlay` поверх SwiftUI `Map`
- **App Group** (`group.com.skykid.app`) — единое хранилище; виджет и приложение читают один `UserDefaults(suiteName:)`
- **WidgetKit** — `StaticConfiguration`; таймлайн обновляется каждые 30 мин ИЛИ немедленно при загрузке погоды (`WidgetCenter.reloadAllTimelines()`)

## SOLID

| Принцип | Реализация |
|---|---|
| **S** — SRP | `ChildThermalProfile` — постоянные данные; `WalkContext` — одна прогулка; `ChildProfileStore` — persistence; SwiftUI views — presentation |
| **O** — OCP | Новые погодные провайдеры реализуют `WeatherService`; возрастные, медицинские, погодные и транспортные safety-правила изолированы в отдельных политиках |
| **L** — LSP | Struct/enum-архитектура, иерархий наследования нет |
| **I** — ISP | `WeatherService` содержит только `fetch(coordinate:)` — минимальный интерфейс |
| **D** — DIP | `WeatherViewModel(service: any WeatherService)` — зависимость от абстракции, не от `OpenMeteoService` |

## Поток данных

```
ContentView
  ├─ ChildProfileStore → ChildThermalProfile (persistent)
  ├─ WalkContextStore → WalkContext (in-memory, one planned walk)
  └─ LocationManager.location → onChange → WeatherViewModel.load(coordinate:cityName:)
       └─ service.fetch(coordinate:)       ← any WeatherService (по умолч. OpenMeteoService)
            → RawWeatherObservation → WeatherNormalizer → NormalizedWeather
            ├─ AppGroup.saveWeather(...)
            ├─ BuildOutfitRecommendationUseCase
            │    ├─ NormalizedWeather + ChildThermalProfile + WalkContext
            │    ├─ OutfitRecommendationService → OutfitRecommendation
            │    └─ RecommendationSnapshotStore
            │         ├─ generatedAt = WeatherViewModel.weatherUpdatedAt
            │         ├─ RecommendationSnapshotContext
            │         └─ App Group
            ├─ WidgetCenter.reloadAllTimelines()
            ├─ WeatherView(weather, cityName, profile?)
            │    └─ ChildPerceptionCard ← ChildWeatherPerception(profile, weather)
            └─ OutfitView(weather, profile, walkContext, recommendation)
                 ├─ OutfitViewModel → presentation state + контекстный TOG feedback
                 │    └─ PersonalOffsetStore → PersonalizationEngine → offset §8
                 ├─ OutfitParentSummaryBuilder → что надеть / почему / что проверить
                 ├─ ParentOutfitSummaryCard → возраст + общая уверенность
                 ├─ WardrobeAlternativesCard → отсутствующие вещи как замены
                 ├─ OutfitCalculationDetailsCard → свёрнутая техническая трассировка
                 ├─ WalkPreparationView → update WalkContext → recalculate same weather
                 └─ OutfitRecommendation
                      ├─ EffectiveTemperatureCalculator → WeatherThermalEffects
                      ├─ TransportExposureProfile → коэффициенты транспорта
                      ├─ MicroclimateCalculator → T_micro + accessoryTemperature
                      ├─ TOGCalculator → TOG_required
                      ├─ GarmentCompatibilityPolicy → возраст, зоны, конфликты
                      ├─ OutfitCombinationSolver → доступные слои корпуса
                      ├─ OutfitAccessoryResolver → открытые зоны
                      ├─ OutfitSolver → layers, missingGarments, OutfitFit
                      └─ SafetyRulesEngine
                           ├─ AgeSafetyPolicy → базовые продуктовые границы
                           ├─ MedicalSafetyPolicy → болезнь и дополнительная осторожность
                           ├─ WeatherSafetyPolicy → погода и более подходящее окно
                           ├─ TransportSafetyPolicy → дождевик, лицо, автокресло
                           └─ ThermalComfortCheckPolicy → проверка ребёнка

ContentView
  └─ WalkHistoryView
       ├─ WalkLogStore
       │    ├─ App Group → WalkLog[]
       │    └─ PersonalOffsetStore → replace/remove observation by WalkLog.id
       └─ PersonalOffsetStore.feedbackHistory
            └─ FeedbackHistoryItemBuilder → FeedbackHistorySection

ContentView
  ├─ WalkTabView
  │    └─ ActiveWalkView
  │         ├─ WalkTimerHeaderCard
  │         ├─ WalkOutfitChipsCard → UserWardrobeStore
  │         ├─ WalkQuickActionsCard
  │         └─ WalkTimelineCard → ActiveWalkStore
  └─ WalkHistoryView
       ├─ WalkHistoryInsightsCard → последние 7 дней
       └─ FeedbackHistorySection → PersonalOffsetStore

Виджет
  └─ ClothingStatusProvider.getTimeline()
       └─ RecommendationSnapshotStore.load()
            ├─ fresh → outfit + generatedAt + snapshot context
            └─ stale → last update/context without outfit

Siri / AppIntent
  └─ RecommendationSnapshotStore.load()
       ├─ fresh → OutfitRecommendation + time/context → OutfitSnippetView
       └─ stale → timestamped refresh error

NotificationService
  ├─ SafeReminderContentFactory → deterministic safe copy
  ├─ daily/scheduled → request fresh weather, never repeat an outfit
  ├─ walk window → cautious forecast wording + refresh request
  └─ rain cover → ventilation and thermal check
```

Старый ручной CLO-конструктор удалён из приложения вместе с его UI и состоянием. Основной расчёт одежды выполняется через `OutfitSolver`, а состав реального гардероба хранится в `UserWardrobeStore`.

Все погодные адаптеры завершаются одной границей `WeatherNormalizer`. Доменные вычислители не знают формат конкретного API и получают вместе со значениями метаданные качества. UI показывает фактический `WeatherSource`, поэтому заглушка WeatherKit не выдаётся за данные Apple.

`EffectiveTemperatureCalculator` не зависит от транспорта и вычисляет каждый погодный вклад один раз. `TransportExposureProfile` — отдельная policy-модель без UI и сети; `MicroclimateCalculator` применяет её к готовым компонентам. Утепление конвертом и пледом остаётся обязанностью `OutfitSolver`, что исключает двойной учёт.

`GarmentCatalog` является общей доменной базой вещей. Основной `OutfitSolver` получает снимок реального гардероба через `WalkContext`, а совместимость и поиск комбинации делегирует небольшим чистым компонентам.

`ChildProfile` остаётся границей миграции и legacy-совместимости. Основной расчёт принимает `ChildThermalProfile` и `WalkContext` явно. Временный контекст не кодируется и не записывается в App Group.

`OutfitRecommendationSnapshot` хранит полный `OutfitRecommendation`, версию схемы, время использованной погоды, срок действия и presentation-safe контекст. `WeatherViewModel` не меняет время погоды при локальном пересчёте, поэтому отзывы и изменения гардероба не продлевают TTL. При устаревшем снимке расширения не пересчитывают и не показывают одежду, но могут безопасно сообщить время и условия последних данных.

`PersonalizationEngine` является чистой доменной policy: он фильтрует наблюдения по температурной зоне и активности, дедуплицирует одну прогулку и ограничивает шаг/диапазон. `PersonalOffsetStore` отвечает только за profile key, миграцию и persistence; SwiftUI отображает готовый `PersonalizationSummary`. `WalkLogStore` использует `WalkLog.id` как стабильный источник, поэтому редактирование и удаление не накапливают скрытые дубли.

`OutfitParentSummaryBuilder` — чистый presentation-адаптер без SwiftUI-состояния. Он объединяет рекомендацию, нормализованную погоду, возраст и контекст прогулки в короткий ответ родителю. Уровень уверенности не вычисляется декоративно: выбирается худший из `WeatherConfidence` и `OutfitFit.confidence`. Подробный расчёт остаётся тем же доменным результатом и только раскрывается по запросу в отдельном компоненте.

`SafeReminderContentFactory` отделяет проверяемые тексты от `UserNotifications`. Повторяющееся уведомление не хранит комплект или температуру: к моменту доставки они могут устареть. Старый идентификатор такого уведомления удаляется при инициализации сервиса.

## Онбординг / навигация (ContentView)

```
childProfile == nil → ChildProfileSetupView  (первый запуск)
childProfile != nil →
  .notDetermined → PermissionView
  .denied        → DeniedView
  иначе          → TabView (теги 0, 2–5)
    0 — Погода     (WeatherView)
    2 — Одежда     (OutfitView)
    3 — Прогулка   (WalkTabView → ActiveWalkView / WalkSetupSheet)
    4 — История    (WalkHistoryView)
    5 — Профиль    (ProfileSummaryView + sheet редактирования)
```

## Тема оформления

`@AppStorage("colorScheme")` — `"system"` / `"light"` / `"dark"`.  
Читается в `ContentView` → `.preferredColorScheme(preferredScheme)`.  
Picker — вкладка «Профиль» → секция «Оформление».
