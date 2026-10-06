# Архитектура SkyKid

## Паттерны

- **MVVM** — Views не обращаются к сети напрямую, только через ViewModel
- **`@Observable` + `@MainActor`** на долгоживущих VM; локальное состояние короткой формы может быть value-type
- **`@unchecked Sendable`** на `ChildProfileStore` — корректно, т.к. UserDefaults thread-safe
- `LocationManager` — `@Observable NSObject`, запрашивает геолокацию, останавливает обновление после первого фикса
- **App Group** (`group.com.skykid.app`) — единое хранилище; виджет и приложение читают один `UserDefaults(suiteName:)`
- Профиль, журнал и активная прогулка изменяются локальными store-объектами без скрытых сетевых side effect; аккаунт, семейная синхронизация и remote-live отсутствуют
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
ContentView → AppComposition → RootFlow → MainTabView
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
  │         ├─ WalkWeatherSnapshotCard
  │         └─ WalkOutfitChipsCard → ActiveWalkStore
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

## Онбординг / навигация

`RootFlow` принимает два равноправных локальных источника координат: одноразовое
местоположение Core Location или сохранённый вручную выбранный город. Отказ в
разрешении не блокирует приложение: `LocationSelectionStore` хранит выбранный
вариант и координаты города в App Group, а Apple geocoder скрыт за тестируемым
`CityGeocoding`. Данные ребёнка геокодеру и погодному провайдеру не передаются.

```
ContentView (тонкий entry adapter) → AppComposition (единственные экземпляры зависимостей)
  → RootFlow (startup/lifecycle routing)
childProfile == nil → ChildProfileSetupView (первый запуск)
childProfile != nil →
  .notDetermined → PermissionView
  .denied        → DeniedView
  иначе          → MainTabView (ровно три вкладки)
    Сегодня — погода + рекомендация + контекст + окно + состояние прогулки
    История — WalkHistoryView
    Профиль — ProfileSummaryView

`TodayViewModel` оркестрирует только presentation-состояния loading / unavailable /
stale / blocked / ready. Расчёт остаётся единственным результатом
`BuildOutfitRecommendationUseCase`; активная прогулка продолжает принадлежать
`ActiveWalkStore` и восстанавливается из App Group.
```

## Тема оформления

`@AppStorage("colorScheme")` — `"system"` / `"light"` / `"dark"`.  
Читается в `RootFlow` → `.preferredColorScheme(preferredScheme)`.
Picker — вкладка «Профиль» → секция «Оформление».

## Backup, restore и удаление данных

`LocalBackupService` собирает доменные снимки локальных store, кодирует
версионированный `SkyKidBackup` и выполняет двухфазный restore:
decode/migrate/validate, затем подтверждённый replace. Commit упорядочен как
profile → walks → personalization → wardrobe → settings; при ошибке применяется
rollback-снимок. Файл передаётся через системный share sheet и не загружается
автоматически.

`LocalDataResetService` — единственный orchestrator удаления. Он останавливает
активную/Live Activity прогулку, очищает прогулки, персонализацию, гардероб,
 recommendation snapshot, профиль, текущий контекст, weather/location cache,
напоминания и выбор/ключи погодного провайдера. Язык и тема сохраняются;
внешние backup-файлы и системные permissions не затрагиваются. Отмена ничего не
меняет, частичная ошибка восстанавливает локальный снимок.

`ShareOutfitComposer` формирует только presentation-текст: имя при наличии,
погода и её актуальность, одежда, сценарий и короткая причина. UUID, координаты,
health-поля, история, внутренние ID и TOG не включаются.

## Отложенная граница данных об окружающей среде

AQI не входит в runtime-модель v1. Если отдельный продуктовый, privacy- и
safety-review разрешит интеграцию, минимальная композиция будет выглядеть так:

```text
WeatherService → WeatherSnapshot ───────────────┐
                                                ├→ Today orchestration
AirQualityService → AirQualityObservation? ─────┘        ├→ одежда: только WeatherSnapshot
                                                        └→ отдельная AQ policy/UI guidance
```

`AirQualityObservation` — будущий узкий контракт, а не универсальный словарь
environment metrics. Ему потребуются timestamp, фактический provider, конкретная
региональная шкала и статус качества. AQ policy не изменяет TOG и не входит в
медицинские правила; она может сформировать только отдельно проверенный
информационный совет. `nil`, stale или low-confidence AQI означает отсутствие
совета, но никогда не отсутствие рекомендации одежды.

WeatherKit остаётся реализацией существующего `WeatherService`, а не причиной
обобщать доменный pipeline. Capability, framework и production adapter можно
добавить только после внешнего entitlement/commercial решения, описанного в
`docs/api.md`.
