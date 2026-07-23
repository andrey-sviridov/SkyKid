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
│   │   ├── ClothingRecommendationEngine.swift  Legacy CLO-движок
│   │   ├── ClothingCalculatorView.swift  Вкладка 3 «Конструктор» — только SwiftUI views
│   │   ├── WardrobeModel.swift           CLO-состояние и действия Конструктора
│   │   ├── LegacyWardrobeAutoSelector.swift жадный CLO-подбор только Конструктора
│   │   └── GarmentCatalog.swift          Единый каталог одежды и метаданных
│   │
│   ├── History/
│   │   ├── WalkHistoryView.swift         Прогулки + история отзывов
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
│       ├── WalkLog.swift                прогулка + optional-контекст feedback
│       └── BiasStore.swift             TempZone + ClothingBiasEngine + BiasStore @MainActor
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
- `ClothingRecommendationEngine.swift` и `WardrobeModel.swift` сохранены только для legacy-вкладки «Конструктор»
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
         ├── 1  mapTab        → NavigationStack → RadarMapView
         ├── 2  outfitTab     → NavigationStack → OutfitView
         ├── 3  calculatorTab → NavigationStack → ClothingCalculatorView
         └── 4  profileTab    → NavigationStack → ProfileSummaryView
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

### 3.4 Вкладка «Конструктор» (ClothingCalculatorView + WardrobeModel)

- `WeatherControlsCard`: слайдер −25…+35°C · иконка погоды · пикер возраста
- `RiskMeterCard`: прогресс-бар CLO · отклонение · метка риска
- `AlertCard`: экстремальная жара (≥ 30°C) и мороз (≤ −10°C)
- `AutoSelectButton`: жадный авто-выбор одежды
- `ComfortCheckCard`: нейтральная подсказка проверки комфорта без ложной атрибуции педиатру
- `ClothingConstructorSection`: `LazyVGrid` из `GarmentCard`

**Инициализация:** `weather.apparentTemperature` → начальная температура слайдера

**Сброс (`resetAll()`):**
- Температура → `model.weatherTemperature` (последняя актуальная погода с вкладки «Погода»)
- Вся выбранная одежда → снимается
- Кнопка «Сбросить» активна если температура изменена вручную ИЛИ есть выбранная одежда

**`onChange(of: weather?.apparentTemperature)`:** обновляет `model.weatherTemperature` при обновлении погоды

**CLO-формула:**
```
requiredHeat = max(0, (24 − temperature) × 0.5) × 0.85 если active && t < 15
currentHeat  = Σ(selectedItems.heatValue)
heatDeviation = currentHeat − requiredHeat
```

**GarmentCatalog:** один список для личного гардероба, основного TOG-решателя и legacy-Конструктора. Каждая позиция содержит возраст, TOG/CLO, покрываемые зоны, назначение и группу несовместимости. Скрытый набор solver-предметов удалён.

---

### 3.5 Вкладка «Профиль» (ProfileSummaryView)

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
| `bias_v1_index` | [String] | Индекс ключей BiasStore |
| `bias_v1_<key>_<ts>` | Data (JSON) | Массив FeedbackEvent |
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

## 6. Legacy ClothingRecommendationEngine

Этот раздел описывает только изолированный CLO-конструктор. Основная вкладка «Одежда», виджет и Siri его не вызывают.

### 6.1 Формула effectiveTemp

```
EffectiveTemp = feelsLike
              + activityLevel.temperatureAdjustment    // −2 / 0 / +3
              + ageGroup.temperatureOffset              // −5 … 0
              + walkType.temperatureAdjustment          // −1.5 … +1
              + healthFeatures.Σ(temperatureAdjustment) // −6 … +1.5 (сумма флагов)
              + temperaturePreferenceOffset             // ручная поправка
              + learnedBias                            // из BiasStore (−3 … +3)
```

### 6.2 Структура результата

```swift
struct LayeredOutfit: Equatable, Sendable {
    effectiveTemp: Double
    baseLayer:    Layer?    // нательный слой — всегда
    midLayer:     Layer?    // утеплитель; nil при t ≥ 18°C
    outerLayer:   Layer?    // куртка / конверт; nil в жару без осадков
    accessories: [Layer]    // шапка, перчатки, шарф, обувь
    // computed: allLayers = [base, mid, outer].compactMap{$0} + accessories
}

struct LayeredOutfit.Layer: Equatable, Sendable, Identifiable {
    name:        String    // русское название
    systemImage: String    // SF Symbol
    reason:      String    // пояснение
    // id = name + systemImage
}
```

### 6.3 Стратегии (OCP)

| Стратегия | Применяется при | Особенности |
|---|---|---|
| `StandardLayerStrategy` | toddler, preschool, schoolAge, teen | Шарф vs бафф по возрасту; ветровка при > 7 м/с |
| `InfantLayerStrategy` | infant, baby | Конверт вместо куртки; шапка всегда; пинетки при t < 5 |

Новый контекст → новый тип, реализующий `protocol LayerStrategy: Sendable`. Существующие стратегии не изменяются.

### 6.4 Типичный вызов

```swift
// Только legacy-вкладка «Конструктор»
let bias   = BiasStore.shared.currentBias(for: profile, feelsLike: weather.apparentTemperature)
let outfit = ClothingRecommendationEngine.recommend(weather: weather, profile: profile, learnedBias: bias)
```

---

## 7. Адаптивный Bias — BiasStore

### 7.1 Температурные зоны (TempZone)

| Зона | Диапазон feelsLike |
|---|---|
| `.freezing` | < 0°C |
| `.cold` | 0–10°C |
| `.mild` | 10–20°C |
| `.warm` | > 20°C |

### 7.2 Формула (ClothingBiasEngine — pure static)

```
w_i   = exp(−0.02 · daysSince_i)         // half-life ≈ 35 дней
raw   = Σ(vote_i · w_i) / Σ(w_i)         // vote: tooCold = −1, tooWarm = +1
conf  = min(1.0, Σ(w_i) / 3.0)           // уверенность (3 взвешенных события = 100%)
bias  = raw · 3°C · conf                  // ∈ [−3, +3°C]
```

Лимит: 60 событий на профиль, старейшие удаляются. Ключ хранения: `"\(name)_\(Int(birthday.timeIntervalSince1970))"`.

### 7.3 UserFeedback

```swift
enum UserFeedback {
    case tooCold      // записывается в BiasStore
    case comfortable  // только анимация, в BiasStore не пишется
    case tooWarm      // записывается в BiasStore
}
```

---

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
├── ClothingCalculatorView    ← NormalizedWeather?, ChildProfile?
│   └── WardrobeModel         ← GarmentCatalog
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
