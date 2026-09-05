# SkyKid — Карта проекта

> Версия: 2026-07-23 (профиль v2 + нормализованная погода + контекстная персонализация v2 + родительский UX)
> Стек: SwiftUI · iOS 17+ · Swift 6 · @Observable · WidgetKit · AppIntents
> Bundle ID: `com.skykid.app` · App Group: `group.com.skykid.app`

---

## 1. Структура директорий

```
SkyKid/
├── App/
│   ├── SkyKidApp.swift              @main — точка входа
│   ├── ContentView.swift            Роутер + 5 вкладок + ProfileSummaryView + экраны разрешений
│   └── SkyKidIntents.swift          Siri AppIntent: GetOutfitRecommendationIntent + OutfitSnippetView
│
├── Features/
│   ├── Weather/
│   │   ├── WeatherView.swift        Вкладка 0 «Погода»
│   │   ├── WeatherViewModel.swift   @MainActor @Observable; DI через any WeatherService
│   │   └── Components/WeatherDataQualityCard.swift источник и уверенность
│   │
│   ├── Map/
│   │   ├── RadarMapView.swift       Вкладка 1 «Осадки»
│   │   ├── RadarMapViewModel.swift  Плеер фреймов радара
│   │   └── RainViewerOverlay.swift  MKTileOverlay + renderer (opacity 0.6)
│   │
│   ├── Outfit/
│   │   ├── OutfitView.swift              Вкладка 2 «Одежда»
│   │   ├── OutfitViewModel.swift         Presentation state + контекстный TOG feedback
│   │   ├── OutfitParentSummary.swift     Короткий ответ + общая уверенность
│   │   ├── TransportMode+Presentation.swift подписи/иконки транспорта
│   │   ├── WalkPreparation/              Форма контекста прогулки + value-type ViewModel
│   │   ├── Components/                   Parent summary, alternatives, details, warnings, feedback
│   │   ├── BuildOutfitRecommendationUseCase.swift UI result + App Group snapshot
│   │   ├── OutfitRecommendationService.swift пайплайн §2→§6
│   │   ├── WeatherThermalEffects.swift  независимые вклады среды
│   │   ├── EffectiveTemperatureCalculator.swift единый расчёт среды
│   │   ├── TransportExposureProfile.swift коэффициенты защиты транспорта
│   │   ├── MicroclimateCalculator.swift  композиция среды и транспорта
│   │   ├── GarmentCompatibilityPolicy.swift зоны тела и совместимость
│   │   ├── OutfitCombinationSolver.swift поиск доступных слоёв по TOG
│   │   ├── OutfitAccessoryResolver.swift защита головы, рук и стоп
│   │   ├── OutfitSolver.swift            оркестрация корпуса/аксессуаров/fit
│   │   └── GarmentCatalog.swift          Единый каталог одежды и метаданных
│   │
│   ├── Walk/
│   │   ├── WalkTabView.swift             Текущая и совместная прогулка
│   │   ├── ActiveWalkView.swift           Таймер, одежда, быстрые отметки и журнал
│   │   ├── WalkSetupSheet.swift           Подготовка и запуск прогулки
│   │   └── Components/                   Карточки таймера, одежды, действий и отметок
│   │
│   ├── History/
│   │   ├── WalkHistoryView.swift         Прогулки + история отзывов
│   │   ├── WalkHistoryInsights.swift      Сводка последних 7 дней
│   │   ├── Components/WalkHistoryInsightsCard.swift
│   │   ├── FeedbackHistoryItem.swift     Presentation builder наблюдений
│   │   └── FeedbackHistorySection.swift  Сворачиваемая карточка истории
│   │
│   └── Profile/
│       ├── ChildProfileSetupView.swift  Онбординг + только постоянные данные
│       ├── Components/StableThermalTraitRow.swift
│       └── ChildWeatherPerception.swift Вычисляемая обёртка комфорта ребёнка
│
├── Core/
│   ├── Network/
│   │   ├── WeatherServiceProtocol.swift  protocol WeatherService: Sendable
│   │   ├── OpenMeteoService.swift        Провайдер 1 — активен по умолчанию (без ключа)
│   │   ├── OpenWeatherMapService.swift   Провайдер 2 — ключ owmApiKey
│   │   ├── WeatherAPIService.swift       Провайдер 3 — ключ wapiApiKey
│   │   ├── WeatherKitService.swift       Провайдер 4 — ⚠️ заглушка (requires Dev Portal capability)
│   │   ├── YandexWeatherService.swift    Провайдер 5 — ключ yandexApiKey
│   │   ├── WeatherServiceSettings.swift  WeatherProvider enum + фабрика + activeService
│   │   └── RainViewerService.swift       Радарные фреймы (RainViewer API v2)
│   │
│   ├── Location/
│   │   └── LocationManager.swift        @Observable CLLocationManager
│   │
│   ├── Notifications/
│   │   ├── NotificationService.swift    Планирование локальных уведомлений
│   │   └── SafeReminderContent.swift    Проверяемые безопасные тексты
│   │
│   ├── Models/
│       ├── RawWeatherObservation.swift Optional-поля ответа + WeatherSource
│       ├── NormalizedWeather.swift     Единая погодная модель + WeatherConfidence
│       ├── WeatherNormalizer.swift     Safe fallback и статусы качества
│       ├── WeatherData.swift           Legacy scalar model + PrecipType/Hourly/RadarFrame
│       ├── ChildThermalProfile.swift    Постоянные данные + StableThermalTrait
│       ├── WalkContext.swift            Текущая прогулка; намеренно не Codable
│       ├── WalkContextStore.swift       In-memory lifecycle контекста
│       ├── ChildProfile.swift           Codable v2 + миграция legacy JSON
│       │                                ⚠️ Target Membership: SkyKid + SkyKidWidget
│       ├── ChildProfileStore.swift      Singleton-обёртка над AppGroup (только SkyKid)
│       ├── OutfitRecommendationSnapshot.swift версионированный общий снимок
│       ├── PersonalizationModels.swift  контекст, наблюдение, state и summary
│       ├── PersonalizationEngine.swift  повторяемые сигналы, дедупликация, лимиты
│       ├── PersonalOffsetStore.swift    App Group persistence + миграция v1 → v2
│       └── WalkLog.swift                прогулка + optional-контекст feedback
│   └── Storage/
│       ├── RecommendationSnapshotStore.swift App Group persistence
│       └── WalkLogStore.swift           журнал + синхронизация наблюдений
│
└── Info.plist

SkyKidWidget/
├── SkyKidWidgetBundle.swift         @main → 2 виджета (Home + LockScreen)
├── WidgetClothingCalculator.swift   Presentation-адаптер snapshot + ClothingWidgetStatus
├── ClothingStatusProvider.swift     fresh outfit / stale update metadata
└── ClothingStatusWidgetView.swift   Outfit + время/контекст или запрос обновления
```

**История миграции:**
- `OutfitAdvisor.swift` удалён; основная вкладка использует TOG-пайплайн `OutfitRecommendationService` → `OutfitSolver`
- Старый CLO-конструктор и его UI удалены; `UserWardrobeStore` используется для фактического гардероба
- Виджет и Siri не пересчитывают одежду: они читают `OutfitRecommendationSnapshot`

---

## 2. Навигация и роутинг

```
SkyKidApp (@main)
└── ContentView
    ├── [profile == nil]  → ChildProfileSetupView (онбординг, fullscreen)
    ├── [notDetermined]   → PermissionView
    ├── [denied]          → DeniedView
    └── [authorized]      → TabView (5 вкладок)
         ├── 0  weatherTab    → NavigationStack → WeatherView
         ├── 2  outfitTab     → NavigationStack → OutfitView
         ├── 3  walkTab       → NavigationStack → WalkTabView
         ├── 4  historyTab    → NavigationStack → WalkHistoryView
         └── 5  profileTab    → NavigationStack → ProfileSummaryView
                                                   └── sheet → ChildProfileSetupView
```

**Триггеры перезагрузки погоды:**
- `onChange(locationManager.location)` → расстояние < 5 км + данные есть → пропуск
- Кнопка «↻» в toolbar weatherTab → `locationManager.startUpdating()`

---

## 3. Вкладки — детальное описание

### 3.1 Вкладка «Погода» (WeatherView)

- Hero: город · SF Symbol иконка (multicolor) · большая температура · «Ощущается N°»
- `ChildPerceptionCard` (если профиль есть): эмодзи · имя · возраст · прогресс-бар комфорта · текст резюме · возрастная подсказка
- `statsGrid`: Ветер (м/с) · Направление · Влажность (%) · Осадки (мм)
- Градиент фона: 7 состояний по `weatherCode` и температуре
- Время последнего обновления и предупреждение после 2 часов; обновление доступно в toolbar

**Зависимости:** pure view — принимает `NormalizedWeather` + `ChildProfile?`; при сниженной уверенности показывает `WeatherDataQualityCard`.

---

### 3.2 Вкладка «Осадки» (RadarMapView)

- `MKMapView` + `RainViewerOverlay` (тайловый слой, opacity 0.6)
- Плеер: Play/Pause · slider · метка времени фрейма
- `RadarMapViewModel`: `loadFrames()` → `fetchFrames()` → `[RadarFrame]`; `play()` → Task с `sleep(600ms)`

---

### 3.3 Вкладка «Одежда» (OutfitView)

**Порядок ответа для родителя:**
- `ParentOutfitSummaryCard`: что надеть, почему выбран комплект и как проверить ребёнка; рядом точный возраст, диапазон группы и худшая из погодной/гардеробной уверенностей
- `WalkContextSummaryCard`: текущий транспорт, активность, самочувствие и кнопка изменения
- safety-предупреждения и более подходящее погодное окно
- реальные слои из личного гардероба
- `WardrobeAlternativesCard`: недостающие вещи как варианты замены с безопасным fallback-действием
- `OutfitCalculationDetailsCard`: температуры, источник, качество, `OutfitFit` и трассировка; по умолчанию свёрнута
- персонализация и обратная связь после прогулки

Форма `WalkPreparationView` использует по одному пикеру транспорта и утепления, очищает несовместимые параметры при смене транспорта и закрепляет основное действие снизу. Ключевые тексты не обрезаются; заголовок summary и feedback-кнопки переходят в вертикальную раскладку при accessibility Dynamic Type.

**Feedback-секция (PersonalOffsetStore):**
- Три кнопки: `thermometer.snowflake` (Холодно) · `checkmark.circle` (Комфортно) · `thermometer.sun` (Жарко)
- Haptics: `UIImpactFeedbackGenerator(style: .light)`
- Выбор передаётся в `OutfitViewModel` как контекстное наблюдение; одно нажатие не меняет TOG
- Сигналы ближе четырёх часов считаются одной прогулкой; изменение начинается после двух согласованных наблюдений
- `PersonalizationStatusCard` показывает зону, активность, текущий offset и правила обучения, а также даёт полный сброс
- Баннер подтверждения различает сохранённое наблюдение, повторившийся сигнал и подтверждение «Комфортно»

**Движок:**
```swift
let output = BuildOutfitRecommendationUseCase().execute(
    weather: weather,
    profile: profile.thermalProfile,
    walkContext: walkContext,
    cityName: cityName
)
```

---

### 3.4 Вкладка «Прогулка» (WalkTabView)

- Во время прогулки сразу видны таймер с погодой, список одежды и быстрые действия
- Быстрые действия: сон/пробуждение, открытие/закрытие люльки и прежняя кнопка «Отметка»
- Таблица «Отметки» отображается всегда; при пустом состоянии показывает спокойную заглушку
- Последнюю отметку можно отменить; снятие одежды отражается отдельной строкой и может быть отменено
- `WalkHistoryInsightsCard` появляется после двух прогулок и показывает прогулки, среднюю длительность, сон и комфорт за 7 дней

`UserWardrobeStore` остаётся единственным источником фактической одежды. Старый ручной CLO-конструктор удалён.

---

### 3.5 Вкладка «История» (WalkHistoryView)

- Список завершённых прогулок
- Сводка последних 7 дней при наличии достаточного числа прогулок
- История отзывов и персонализации

### 3.6 Вкладка «Профиль» (ProfileSummaryView)

- Аватар (градиентный круг + эмодзи пола)
- Карточки: день рождения · возрастная группа · срок рождения · температурная склонность · устойчивые тепловые особенности
- Пикер темы: Авто / Светлая / Тёмная (`@AppStorage("colorScheme")`)
- **Карточка «Спросить Siri»:** `ShortcutsLink()` — открывает Shortcuts.app где пользователь сам назначает произвольную фразу для `GetOutfitRecommendationIntent`
- Кнопка «Изменить данные» → sheet → `ChildProfileSetupView`

---

## 4. Модели данных

### 4.1 NormalizedWeather

```swift
struct NormalizedWeather: Equatable, Sendable {
    source: WeatherSource
    temperature, apparentTemperature: Double  // °C
    humidity:                          Int     // %
    windSpeed:                         Double  // м/с
    windGust:                          Double  // м/с
    windDirection:                     Int     // градусы
    precipitation:                     Double  // мм
    weatherCode:                       Int     // WMO (0–99)
    uvIndex, cloudCover:               Double
    fieldStatuses: [WeatherField: WeatherFieldStatus]
}
// computed: confidence, conditionDescription, conditionIcon, windDirectionLabel
```

`RawWeatherObservation` сохраняет `nil` из API. `WeatherNormalizer` является единственным местом fallback-правил. `WeatherData` оставлен только для legacy CLO-конструктора и общих типов виджета.

---

### 4.2 ChildThermalProfile

```swift
struct ChildThermalProfile: Codable, Equatable, Sendable {
    var name: String
    var gender: ChildGender
    var birthday: Date
    var gestationalAgeWeeks: Int
    var stableTraits: Set<StableThermalTrait>
    var temperaturePreferenceOffset: Double
}
```

Это единственная долгоживущая тепловая модель ребёнка. Она не содержит текущую болезнь, активность, длительность или транспорт.

`ChildProfile` оборачивает эту модель для Codable-миграции. Схема v2 хранит только `thermalProfile`; острые и прогулочные поля старой схемы при миграции отбрасываются.

---

### 4.3 AgeGroup

| Кейс | Возраст | temperatureOffset | Стратегия |
|---|---|---|---|
| `.infant` | 0–5 мес | −5°C | `InfantLayerStrategy` |
| `.baby` | 6–11 мес | −4°C | `InfantLayerStrategy` |
| `.toddler` | 1–3 года | −3°C | `StandardLayerStrategy` |
| `.preschool` | 3–6 лет | −2°C | `StandardLayerStrategy` |
| `.schoolAge` | 6–12 лет | −1°C | `StandardLayerStrategy` |
| `.teen` | 12+ | 0°C | `StandardLayerStrategy` |

---

### 4.4 StableThermalTrait

`frequentIllness`, `coldSensitive`, `heatSensitive`, `anemia`, `atopicDermatitis`, `cardioRespiratory`. Точный срок рождения хранится отдельно в `gestationalAgeWeeks`, а не как булевый флаг.

---

### 4.5 WalkContext

```swift
struct WalkContext: Equatable, Sendable {
    var healthStatus: CurrentHealthStatus
    var bodyTemperatureCelsius: Double?
    var activityLevel: BabyActivityLevel
    var transportMode: TransportMode
    var hoodUp: Bool
    var rainCover: RainCoverState
    var strollerConvertTOG: Double?
    var blanketTOG: Double?
    var walkType: WalkType
    var parentWearingCarrier: Bool
    var availableGarmentIDs: Set<String>
}
```

`WalkContext.standard(for:)` выбирает возрастно-уместные начальные значения. `WalkContextStore` хранит контекст только в памяти; модель не `Codable`.

---

### 4.6 CurrentHealthStatus и BabyActivityLevel

- `CurrentHealthStatus`: `.well`, `.coldWithoutFever`, `.fever`.
- Температура тела 38°C и выше активирует лихорадочные safety-правила независимо от текстового статуса.
- `BabyActivityLevel`: `.sleeping`, `.calmAwake`, `.activeInStroller`, `.walkingCrawling`.
- `WalkType`: `.short`, `.regular`, `.long`, `.park`.

---

### 4.7 AppGroup (UserDefaults, suite: `group.com.skykid.app`)

| Ключ | Тип | Назначение |
|---|---|---|
| `child_profile` | Data (JSON v2) | `ChildThermalProfile` внутри `ChildProfile` migration envelope |
| `wg_temperature` | Double | Реальная температура |
| `wg_apparent_temp` | Double | feelsLike |
| `wg_weather_code` | Int | WMO-код |
| `wg_wind_speed` | Double | Ветер м/с |
| `wg_precipitation` | Double | Осадки мм |
| `wg_city_name` | String | Название города |
| `wg_updated_at` | Double | Unix timestamp обновления |
| `wg_latitude` | Double | Последняя известная широта |
| `wg_longitude` | Double | Последняя известная долгота |
| `weatherProvider` | String | Активный провайдер |
| `owmApiKey` | String | Ключ OpenWeatherMap |
| `wapiApiKey` | String | Ключ WeatherAPI.com |
| `yandexApiKey` | String | Ключ Яндекс Погоды |
| `colorScheme` | String | Тема: system / light / dark |

**Методы AppGroup:**
- `saveWeather(...)` / `loadCachedWeather()` — legacy-кеш погоды; не используется для подбора одежды в расширениях
- `saveLocation(lat:lon:)` / `loadLastKnownCoordinate()` — кеш последней известной позиции приложения
- `saveProfile(_:)` / `loadProfile()` / `deleteProfile()`
- `AppGroupRecommendationSnapshotStore.save/load/loadFresh` — единый `OutfitRecommendation` с временем/контекстом использованной погоды, TTL 2 ч

---

## 5. Сетевой слой — Weather Providers

### 5.1 Протокол

```swift
protocol WeatherService: Sendable {
    func fetch(coordinate: CLLocationCoordinate2D) async throws -> NormalizedWeather
}
```

### 5.2 Реализации

| Класс | Провайдер | Ключ | Статус |
|---|---|---|---|
| `OpenMeteoService` | Open-Meteo (ECMWF) | Не нужен | ✅ По умолчанию |
| `OpenWeatherMapService` | OpenWeatherMap | `owmApiKey` | ✅ |
| `WeatherAPIService` | WeatherAPI.com | `wapiApiKey` | ✅ |
| `YandexWeatherService` | Яндекс Погода | `yandexApiKey` | ✅ |
| `WeatherKitService` | Apple WeatherKit | App ID capability | ⚠️ Заглушка — делегирует на OpenMeteo |

**WeatherKit отключён:** entitlement `com.apple.developer.weatherkit` и `WeatherKit.framework` убраны из проекта. Для активации: включить capability в Dev Portal, раскомментировать тело `WeatherKitService.fetch()`.

**DI:** `ContentView` создаёт `WeatherViewModel(service: WeatherProvider.activeService)`. `WeatherProvider.activeService` читает `UserDefaults["weatherProvider"]`, фабрика `makeService(for:)` возвращает нужный сервис (или `OpenMeteoService` как fallback).

---

## 6–7. Удалённый legacy-код

Старый CLO-конструктор, `ClothingRecommendationEngine`, `WardrobeModel` и связанный с ними адаптивный `BiasStore` удалены из production-приложения. Основная рекомендация использует TOG-пайплайн `OutfitRecommendationService` → `OutfitSolver`, а персонализация прогулок — `PersonalizationEngine` и `PersonalOffsetStore`.
## 8. ChildProfileSetupView — секции формы

### Карточка 1: Основная информация
- Имя (TextField)
- Пол (GenderButton × 2)
- Дата рождения (DatePicker, compact)

### Карточка 2: Рождение
- Признак недоношенности
- Точный срок рождения в неделях

### Карточка 3: Предпочтения
- **Склонность к температуре**: Slider −3…+3°C (step 0.5), цвет: синий ← зелёный → оранжевый
- **Устойчивые тепловые особенности** (`StableThermalTraitRow`, multi-select)

### Карточка предпросмотра + кнопка «Начать» / «Сохранить»

Текущее самочувствие, температура тела, активность, транспорт и длительность задаются не здесь, а в `WalkPreparationView`. Старые профили загружаются через миграцию v2; острые данные при этом не переносятся.

---

## 9. Widget

### 9.1 Два виджета

| Виджет | Семейства |
|---|---|
| `ClothingStatusWidget` | `.systemSmall`, `.systemMedium` |
| `ClothingStatusLockScreenWidget` | `.accessoryCircular`, `.accessoryRectangular` |

### 9.2 Поток данных

```
Основное приложение
└── WeatherViewModel.load(coordinate:)
    ├── BuildOutfitRecommendationUseCase.execute()
    │   ├── OutfitRecommendationService.recommend()
    │   └── RecommendationSnapshotStore.save()
    └── WidgetCenter.reloadAllTimelines()

SkyKidWidgetExtension
└── ClothingStatusProvider.getTimeline()
    └── RecommendationSnapshotStore.load()
        ├── fresh → OutfitRecommendation + время + условия
        ├── stale → время/условия последних данных без одежды
        └── nil → «Откройте SkyKid»
```

### 9.3 Баннер экстремального риска

| Виджет | `.extremeHeat` / `.extremeCold` |
|---|---|
| Small | Вся площадь заменяется: иконка + `status.label` + `safetyWarning` + температура |
| Medium | Правая колонка (список одежды) заменяется баннером с предупреждением |

`ClothingWidgetStatus` — 7 уровней: `extremeCold` · `cold` · `slightlyCold` · `ideal` · `warm` · `hot` · `extremeHeat`

### 9.4 Файлы в Sources обоих таргетов

Виджет-таргет явно включает: `ChildProfile.swift` · `ChildThermalProfile.swift` · `OutfitOutputModels.swift` · `OutfitRecommendationSnapshot.swift` · `RecommendationSnapshotStore.swift`.

---

## 10. Siri / AppIntents

### 10.1 GetOutfitRecommendationIntent

```swift
@available(iOS 17, *)
struct GetOutfitRecommendationIntent: AppIntent {
    static let title: LocalizedStringResource = "Что надеть"
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        // RecommendationSnapshotStore.load() + isFresh()
        // → тот же OutfitRecommendation, что в UI и виджете
        // → .result(view: OutfitSnippetView(...))
    }
}
```

Ошибка: `LocalizedError` просит открыть SkyKid, если снимок отсутствует. Для устаревшего снимка сообщение дополнительно показывает время и краткие условия последних данных.

### 10.2 OutfitSnippetView

Компактная карточка Siri: имя + возраст + город · время, условия, источник и уверенность · температура с цветом · топ-4 слоя. Все тексты: `fixedSize(horizontal: false, vertical: true)`.

### 10.3 Подключение Siri пользователем

**Без фиксированных фраз** (нет `AppShortcutsProvider`). В `ProfileSummaryView` карточка «Спросить Siri» с `ShortcutsLink()` → пользователь открывает Shortcuts.app и сам назначает любую фразу. Это решает проблему локализации — переводить нечего.

---

## 11. Зависимости между файлами

```
ContentView
├── ChildProfileStore       → ChildProfile.thermalProfile (persistent)
├── WalkContextStore       → WalkContext (in-memory only)
├── WeatherViewModel          ← any WeatherService
│                                  ← OpenMeteoService (default) | OWM | WAPI | WeatherKit(stub)
│                                  ← WeatherProvider.activeService (UserDefaults)
│   └── BuildOutfitRecommendationUseCase
│       ├── NormalizedWeather + ChildThermalProfile + WalkContext
│       ├── OutfitRecommendationService
│       │   ├── EffectiveTemperatureCalculator → WeatherThermalEffects
│       │   ├── TransportExposureProfile → MicroclimateCalculator
│       │   ├── TOGCalculator → OutfitSolver
│       │   ├── SafetyRulesEngine
│       │   │   ├── AgeSafetyPolicy + MedicalSafetyPolicy
│       │   │   ├── WeatherSafetyPolicy + TransportSafetyPolicy
│       │   │   └── ThermalComfortCheckPolicy
│       │   └── OutfitRecommendation
│       └── RecommendationSnapshotStore → AppGroup
├── LocationManager
│
├── WeatherView               ← NormalizedWeather, ChildProfile?
│   └── ChildPerceptionCard  ← ChildWeatherPerception
│
├── RadarMapView              ← RadarMapViewModel ← RainViewerService
│
├── OutfitView                ← NormalizedWeather, ChildProfile?, WalkContext?, OutfitRecommendation
│   ├── OutfitViewModel       ← presentation state, PersonalOffsetStore
│   └── WalkPreparationView   → explicit WalkContext update
│
├── WalkTabView               ← ActiveWalkStore, LiveWalkObserver
│   ├── ActiveWalkView        ← таймер, одежда, быстрые действия, отметки
│   └── WalkHistoryInsights   ← WalkLog[] за последние 7 дней
│
└── ProfileSummaryView        ← ChildProfile
    └── ChildProfileSetupView ← ChildProfileStore ← AppGroup

SkyKidIntents
├── GetOutfitRecommendationIntent ← RecommendationSnapshotStore
└── OutfitSnippetView             ← OutfitRecommendation

SkyKidWidget
├── ClothingStatusProvider   ← RecommendationSnapshotStore
└── ClothingStatusWidgetView ← presentation adapter ← OutfitRecommendation
```

**Shared (SkyKid + SkyKidWidget):**
`ChildProfile.swift` · `ChildThermalProfile.swift` · `OutfitOutputModels.swift` · `OutfitRecommendationSnapshot.swift` · `RecommendationSnapshotStore.swift`

---

## 12. Конфигурация проекта

| Параметр | Значение |
|---|---|
| Bundle ID | `com.skykid.app` |
| Widget Bundle ID | `com.skykid.app.widget` |
| App Group | `group.com.skykid.app` |
| iOS Deployment Target | 17.0 |
| Swift Version | 6.0 |
| Entitlements | App Groups (WeatherKit удалён) |
| Frameworks основной таргет | AppIntents (через import, auto-linked) |
| Frameworks виджет | WidgetKit · SwiftUI |

---

## 13. Открытые задачи

| Задача | Приоритет |
|---|---|
| UI выбора погодного провайдера + ввод API-ключа | Средний |
| Reverse geocoding (CLGeocoder) вместо «Моё местоположение» | Низкий |
| Обработка ошибок в UI (`WeatherViewModel.error`) | Низкий |
| Нативная и клиническая вычитка локализаций | Перед релизом |
| AssistantSchemas (Apple Intelligence, iOS 18.2+) | Будущее |
