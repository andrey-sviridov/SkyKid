# SkyKid — Карта проекта

> Версия: 2026-06-09  
> Стек: SwiftUI · iOS 17+ · Swift 6 · @Observable · WidgetKit  
> Bundle ID: `com.skykid.app` · App Group: `group.com.skykid.app`

---

## 1. Структура директорий

```
SkyKid/
├── App/
│   ├── SkyKidApp.swift              @main — точка входа
│   └── ContentView.swift            Роутер + все 5 вкладок + экраны разрешений
│
├── Features/
│   ├── Weather/
│   │   ├── WeatherView.swift        Вкладка 0 «Погода»
│   │   └── WeatherViewModel.swift   Загрузка + кеш → WidgetKit
│   │
│   ├── Map/
│   │   ├── RadarMapView.swift       Вкладка 1 «Осадки»
│   │   ├── RadarMapViewModel.swift  Плеер фреймов радара
│   │   └── RainViewerOverlay.swift  MKTileOverlay + renderer
│   │
│   ├── Outfit/
│   │   ├── OutfitView.swift              Вкладка 2 «Одежда»
│   │   ├── OutfitAdvisor.swift           Правила рекомендаций (OCP)
│   │   ├── ClothingCalculatorView.swift  Вкладка 3 «Конструктор»
│   │   ├── WardrobeModel.swift           CLO-логика, авто-выбор
│   │   ├── GarmentCatalog.swift          Каталог предметов одежды
│   │   └── ClothingRecommendationEngine.swift  Новый слоевой движок
│   │
│   └── Profile/
│       ├── ChildProfileSetupView.swift  Онбординг + редактирование
│       └── ChildWeatherPerception.swift Комфорт-карточка ребёнка
│
├── Core/
│   ├── Network/
│   │   ├── WeatherServiceProtocol.swift  protocol WeatherService
│   │   ├── OpenMeteoService.swift        Провайдер 1 (бесплатно, без ключа)
│   │   ├── OpenWeatherMapService.swift   Провайдер 2 (API-ключ)
│   │   ├── WeatherAPIService.swift       Провайдер 3 (API-ключ)
│   │   ├── WeatherKitService.swift       Провайдер 4 (Apple, без ключа)
│   │   ├── WeatherServiceSettings.swift  Реестр + фабрика провайдеров
│   │   └── RainViewerService.swift       Радарные фреймы (RainViewer API)
│   │
│   ├── Location/
│   │   └── LocationManager.swift        CLLocationManager (@Observable)
│   │
│   └── Models/
│       ├── WeatherData.swift            Доменная модель погоды + RadarFrame
│       ├── ChildProfile.swift           Профиль + AgeGroup + ActivityLevel +
│       │                                AppGroup (UserDefaults) + CachedWeather
│       ├── ChildProfileStore.swift      Singleton-обёртка над AppGroup
│       └── BiasStore.swift              Адаптивный bias (история отзывов)
│
└── Info.plist

SkyKidWidget/
├── SkyKidWidgetBundle.swift         @main → 2 виджета
├── WidgetClothingCalculator.swift   Логика виджета (без основного таргета)
├── ClothingStatusProvider.swift     TimelineProvider (30 мин цикл)
└── ClothingStatusWidgetView.swift   Small / Medium / Circular / Rectangular
```

---

## 2. Навигация и роутинг

```
SkyKidApp (@main)
└── ContentView
    ├── [profile == nil]  → ChildProfileSetupView (онбординг, fullscreen)
    ├── [notDetermined]   → PermissionView ("Разрешить геолокацию")
    ├── [denied]          → DeniedView ("Открыть настройки")
    └── [authorized]      → TabView (5 вкладок)
         ├── 0  weatherTab   → NavigationStack → WeatherView
         ├── 1  mapTab       → NavigationStack → RadarMapView
         ├── 2  outfitTab    → NavigationStack → OutfitView
         ├── 3  calculatorTab→ NavigationStack → ClothingCalculatorView
         └── 4  profileTab   → NavigationStack → ProfileSummaryView
                                                  └── sheet → ChildProfileSetupView
```

**Триггеры перезагрузки погоды в ContentView:**
- Изменение `locationManager.location` (срабатывает через `onChange`)
- Дистанция < 5 км от предыдущей точки + погода уже есть → пропуск (защита от дребезга)
- Кнопка «↻» в toolbar `weatherTab`

---

## 3. Вкладки — детальное описание

### 3.1 Вкладка «Погода» (WeatherView)

**Что показывает:**
- Hero-секция: город · иконка погоды (SF Symbols multicolor) · большая температура · состояние · «Ощущается как N°»
- `ChildPerceptionCard` — карточка восприятия погоды ребёнком (если профиль заполнен):
  - Эмодзи настроения · имя · возраст · метка комфорта
  - Прогресс-бар комфорта (0–100, анимированный)
  - Текст-резюме (personalised по имени и возрасту)
  - Возрастная подсказка (блок «💡 …»)
  - Эффективная температура «для малыша» = `feelsLike + ageOffset`
- `statsGrid` — 4 карточки: Ветер (м/с) · Направление ветра · Влажность (%) · Осадки (мм)
- Градиент фона меняется по коду погоды и температуре (7 состояний)

**Зависимости:**
- `WeatherView` — pure view, принимает `WeatherData` + `ChildProfile?` как параметры
- `ChildPerceptionCard` ← `ChildWeatherPerception` (вычисляемая обёртка)
- `WeatherViewModel` — владеет состоянием, не инжектируется во view

---

### 3.2 Вкладка «Осадки» (RadarMapView)

**Что показывает:**
- `MKMapView` с центром на текущей позиции пользователя
- Тайловый слой `RainViewerOverlay` (opacity 0.6) — радар или спутник
- Плеер: кнопка Play/Pause · timeline-slider · метка времени фрейма

**Логика (RadarMapViewModel):**
- `loadFrames()` → `RainViewerService.fetchFrames()` → массив `RadarFrame`
- Начальный индекс = первый фрейм ≥ Date() (самый свежий «прошедший»)
- `play()` запускает `Task` с циклом `sleep(600ms)` → `currentIndex++`
- При достижении конца — перемотка в начало

**RainViewerService:**
- `fetchFrames(layer:)` — поддерживает `.radar` и `.satellite`
- `tileURL(path:layer:z:x:y:)` — строит URL тайла по протоколу RainViewer v2

---

### 3.3 Вкладка «Одежда» (OutfitView)

**Что показывает:**
- Banner-шапка: эмодзи · заголовок («Одеваемся тепло!» / «Лёгкий слой» / …) · эффективная температура
- Список `OutfitItem` — каждый: цветная иконка-эмодзи · название · причина
- Градиент баннера зависит от effectiveTemp (синий / бирюзовый / оранжевый)

**Логика (OutfitAdvisor):**
- OCP-паттерн: 6 правил, реализующих `fileprivate protocol OutfitRule`
- Правила применяются последовательно; каждое возвращает `[OutfitItem]`, все объединяются

| Правило | Условие срабатывания |
|---|---|
| `InfantLayeringRule` | `ageGroup == .infant` → боди + конверт |
| `BaseTemperatureRule` | по диапазонам effectiveTemp (6 диапазонов) |
| `AgeExtrasRule` | `.baby` всегда / `.toddler` при t < 10 → тёплые носки |
| `NeckProtectionRule` | t < 5 → бафф/снуд (малыши) или шарф (школьники) |
| `WindRule` | windSpeed > 7 м/с → ветровка |
| `PrecipitationRule` | weatherCode 71–77 → зимние сапоги; 51–82 → дождевик + резиновые |

**effectiveTemp** = `feelsLike + ageGroup.temperatureOffset`

---

### 3.4 Вкладка «Конструктор» (ClothingCalculatorView + WardrobeModel)

**Что показывает:**
- `WeatherControlsCard`: слайдер температуры (−25…+35°C, step 1) · иконка погоды · пикер возрастной группы
- `RiskMeterCard`: прогресс-бар тепла · CLO-отклонение · текст риска
- `AlertCard`: предупреждения при экстремальных температурах (≥30°C и ≤−10°C)
- `AutoSelectButton`: автоматический подбор одежды
- `PediatricNoteCard`: медицинская подсказка
- `ClothingConstructorSection`: `LazyVGrid` из карточек `GarmentCard`

**Инициализация с feelsLike:**
- `ClothingCalculatorView(profile:, weather:)` — при наличии `WeatherData`
- начальная температура слайдера = `weather.apparentTemperature`
- начальная группа возраста = `profile.ageGroup.toWardrobeAgeGroup`

**WardrobeModel — CLO-логика:**

```
requiredHeat = max(0, (24 - temperature) × 0.5)
              × 0.85 если ageGroup == .active && temperature < 15

currentHeat  = Σ(selectedItems.heatValue)
heatDeviation = currentHeat - requiredHeat
```

**Зональная оценка риска (ThermalRisk):**

| TempZone | Диапазон отклонения | Результат |
|---|---|---|
| hot (≥22°C) | d ≥ 1.5 | criticalOverheat |
| hot | d > 0.5 | hot |
| hot | иначе | optimal |
| mild (10–22°C) | d ≥ 3.0 | criticalOverheat |
| mild | d ≥ −1.0 | optimal |
| mild | d ≥ −2.5 | slightlyCold |
| cold (<10°C) | d ≥ 5.0 | hot |
| cold | d ≥ −1.5 | optimal |
| cold | d ≥ −4.0 | slightlyCold |

**autoSelect() — жадный алгоритм:**
1. Экстремальная жара → только подгузник
2. Начать с подгузника, проверить уже optimal → выйти
3. Добавлять элементы из `orderedIDs` (зависит от диапазона температуры и `isNewborn`)
4. Не накладывать два тяжёлых верхних слоя (`demi` + `winter`)
5. Не добавлять, если после добавления станет `criticalOverheat`
6. Выйти при достижении `optimal` или `warm`
7. Экстремальный холод → принудительно добавить `warm_blanket`

**GarmentCatalog — 19 предметов:**
```
.base      : подгузник · боди · термобельё · носки (2) · царапки
.insulator : флис-комбез · свитер · брюки
.outer     : ветровка · демисез. комбез · зимний комбез · одеялко (2)
.accessory : шапочки (2) · варежки · пинетки · слюнявчик
```
Pre-computed lookup: `byID: [String: GarmentItem]` и `byLayer: [GarmentLayer: [GarmentItem]]`

---

### 3.5 Вкладка «Профиль» (ProfileSummaryView)

**Что показывает:**
- Аватар (цветной градиентный круг с эмодзи пола)
- Карточки: день рождения · возрастная группа · температурная поправка
- Пикер темы: Авто / Светлая / Тёмная (через `@AppStorage("colorScheme")`)
- Кнопка «Изменить данные» → sheet → `ChildProfileSetupView`

---

## 4. Модели данных

### 4.1 WeatherData

```swift
struct WeatherData: Equatable {
    temperature:         Double   // реальная температура (°C)
    apparentTemperature: Double   // ощущаемая (feelsLike)
    humidity:            Int      // (%)
    windSpeed:           Double   // (м/с)
    windDirection:       Int      // (градусы, 0 = север)
    precipitation:       Double   // (мм)
    weatherCode:         Int      // WMO код (0 = ясно … 99 = гроза)
}
```

Вычисляемые свойства: `conditionDescription` · `conditionIcon` · `windDirectionLabel`

---

### 4.2 ChildProfile

```swift
struct ChildProfile: Codable, Equatable {
    name:                       String
    gender:                     ChildGender        // .boy / .girl
    birthday:                   Date
    activityLevel:              ActivityLevel      // .low / .moderate / .high
    temperaturePreferenceOffset: Double            // ручная поправка (°C), default 0
}
```

Вычисляемые: `ageYears` · `ageMonths` · `ageLabel` · `ageGroup: AgeGroup`

**Склонение имени:** метод `name(_:RussianCase)` покрывает все распространённые русские имена (окончания -а/-я/-й/-ь/согласная).

---

### 4.3 AgeGroup

| Кейс | Возраст | temperatureOffset | Особенности |
|---|---|---|---|
| `.infant` | 0–5 мес | −5°C | Не регулирует температуру тела |
| `.baby` | 6–11 мес | −4°C | Начинает двигаться, уязвим |
| `.toddler` | 1–3 года | −3°C | Активный, не скажет что холодно |
| `.preschool` | 3–6 лет | −2°C | Мёрзнут руки и ноги |
| `.schoolAge` | 6–12 лет | −1°C | Близко к взрослому |
| `.teen` | 12+ | 0°C | Как взрослый |

---

### 4.4 ActivityLevel

| Кейс | temperatureAdjustment | Описание |
|---|---|---|
| `.low` | −2°C | В коляске, дремлет |
| `.moderate` | 0°C | Спокойно играет |
| `.high` | +3°C | Активно бегает |

---

### 4.5 AppGroup (UserDefaults, suite: `group.com.skykid.app`)

| Ключ | Тип | Назначение |
|---|---|---|
| `child_profile` | Data (JSON) | ChildProfile |
| `wg_temperature` | Double | Погода для виджета |
| `wg_apparent_temp` | Double | feelsLike для виджета |
| `wg_weather_code` | Int | Код погоды |
| `wg_wind_speed` | Double | Ветер |
| `wg_precipitation` | Double | Осадки |
| `wg_city_name` | String | Название города |
| `wg_updated_at` | Double | Timestamp обновления |
| `bias_v1_index` | [String] | Индекс ключей BiasStore |
| `bias_v1_<key>` | Data (JSON) | Массив FeedbackEvent |
| `weatherProvider` | String | Активный провайдер |
| `owmApiKey` | String | Ключ OpenWeatherMap |
| `wapiApiKey` | String | Ключ WeatherAPI.com |
| `colorScheme` | String | Тема (system/light/dark) |

Кеш погоды считается устаревшим через **2 часа** от `wg_updated_at`.

---

## 5. Сетевой слой — Weather Providers

### 5.1 Протокол

```swift
protocol WeatherService: Sendable {
    func fetch(coordinate: CLLocationCoordinate2D) async throws -> WeatherData
}
```

### 5.2 Реализации

| Класс | Провайдер | Ключ | Лимит | Статус |
|---|---|---|---|---|
| `OpenMeteoService` | Open-Meteo | Не нужен | Без лимита | ✅ Активен по умолчанию |
| `WeatherKitService` | Apple WeatherKit | Не нужен (App ID) | 500K/мес | ✅ Требует capability |
| `OpenWeatherMapService` | OpenWeatherMap | `owmApiKey` | 1M/мес (free) | ✅ |
| `WeatherAPIService` | WeatherAPI.com | `wapiApiKey` | 1M/мес (free) | ✅ |
| — | Gismeteo | Коммерческий | — | ⚠️ Stub |
| — | Яндекс Погода | Коммерческий | — | ⚠️ Stub |

**WeatherProvider.activeService** — статическое свойство; читает `weatherProvider` из UserDefaults, создаёт нужный сервис через фабрику, при ошибке (нет ключа) возвращает `OpenMeteoService()`.

**WeatherKitService** — использует `WeatherKit.WeatherService.shared.weather(for:including:.current)`. Маппинг 33 кейсов `WeatherCondition` → WMO коды. Осадки: `precipitationIntensity` (Measurement<UnitSpeed>, база м/с) × 3 600 000 = мм/ч.

---

## 6. Адаптивный Bias — BiasStore

### 6.1 Концепция

Система накапливает отзывы «холодно» / «жарко» и автоматически корректирует `effectiveTemp` в будущих рекомендациях. Bias рассчитывается **отдельно для каждой температурной зоны** — ребёнок может мёрзнуть при морозе, но нормально переносить тепло.

### 6.2 Температурные зоны (TempZone)

| Зона | Диапазон feelsLike |
|---|---|
| `.freezing` | < 0°C |
| `.cold` | 0–10°C |
| `.mild` | 10–20°C |
| `.warm` | > 20°C |

### 6.3 Формула (ClothingBiasEngine)

```
w_i    = exp(−0.02 · daysSince_i)        // затухание, half-life ≈ 35 дней
raw    = Σ(vote_i · w_i) / Σ(w_i)        // взвешенное среднее ∈ [−1, 1]
         vote: tooCold = −1, tooWarm = +1
conf   = min(1.0, Σ(w_i) / 3.0)          // уверенность: растёт с объёмом данных
bias   = raw · 3°C · conf                 // ∈ [−3, +3°C]
```

**Поведение по примерам:**

| Сценарий | Bias |
|---|---|
| 1 отзыв «холодно» сегодня | ≈ −1.0°C |
| 3 отзыва «холодно» подряд | −3.0°C (максимум) |
| Смешанные отзывы | ≈ 0°C |
| Отзыв 90-дневной давности | ×0.16 веса |
| Нет отзывов в зоне | 0°C |

**Лимиты:** максимум 60 событий на профиль (старейшие удаляются).

### 6.4 API

```swift
// Записать отзыв (вызывать из OutfitView или ClothingCalculatorView)
BiasStore.shared.record(.tooCold, for: profile, feelsLike: weather.apparentTemperature)

// Получить текущий bias перед расчётом рекомендации
let bias = BiasStore.shared.currentBias(for: profile, feelsLike: weather.apparentTemperature)

// Разбивка по зонам (для UI аналитики / настроек)
let summary: [TempZone: Double] = BiasStore.shared.zoneSummary(for: profile)

// Сброс (при удалении профиля)
BiasStore.shared.clearBias(for: profile)
```

---

## 7. ClothingRecommendationEngine

Новый слоевой движок. Работает параллельно с `OutfitAdvisor` (не заменяет его — UI пока подключён к OutfitAdvisor).

### 7.1 Формула effectiveTemp

```
EffectiveTemp = feelsLike
              + activityLevel.temperatureAdjustment    // −2 / 0 / +3
              + ageGroup.temperatureOffset              // −5 … 0
              + profile.temperaturePreferenceOffset    // ручная поправка
              + learnedBias                            // из BiasStore
```

### 7.2 Структура результата

```swift
struct LayeredOutfit {
    effectiveTemp: Double
    baseLayer:   Layer?    // нательное бельё / термобельё
    midLayer:    Layer?    // утеплитель; nil при t ≥ 18°C
    outerLayer:  Layer?    // куртка / конверт; nil в жару без осадков
    accessories: [Layer]   // шапка, перчатки, шарф, обувь
}
```

### 7.3 Стратегии (OCP)

| Стратегия | Применяется при |
|---|---|
| `StandardLayerStrategy` | `ageGroup` = toddler, preschool, schoolAge, teen |
| `InfantLayerStrategy` | `ageGroup` = infant, baby (в коляске, конверт вместо куртки) |

Новый контекст (горы, бассейн) → новый тип, реализующий `protocol LayerStrategy`. Существующие стратегии не изменяются.

### 7.4 Типичный вызов (из @MainActor ViewModel)

```swift
let bias  = BiasStore.shared.currentBias(for: profile, feelsLike: weather.apparentTemperature)
let outfit = ClothingRecommendationEngine.recommend(weather: weather, profile: profile, learnedBias: bias)
```

---

## 8. Widget

### 8.1 Два виджета

| Виджет | Семейства | Описание |
|---|---|---|
| `ClothingStatusWidget` | systemSmall, systemMedium | Домашний экран |
| `ClothingStatusLockScreenWidget` | accessoryCircular, accessoryRectangular | Экран блокировки |

### 8.2 Поток данных виджета

```
Основное приложение
└── WeatherViewModel.load()
    └── AppGroup.saveWeather(...)        // кешируем в UserDefaults
        └── WidgetCenter.reloadAllTimelines()

SkyKidWidgetExtension
└── ClothingStatusProvider.getTimeline()
    └── makeEntry()
        ├── AppGroup.loadCachedWeather() // читаем кеш (TTL 2ч)
        ├── AppGroup.loadProfile()
        └── WidgetClothingCalculator.recommend(weather:, profile:)
            └── → WidgetOutfitRecommendation
```

Обновление по расписанию: `policy: .after(30 минут)`. При загрузке из приложения — мгновенно через `reloadAllTimelines()`.

### 8.3 WidgetClothingCalculator

Независимый вычислитель (не импортирует основной таргет):
- `status(for effectiveTemp:)` → `ClothingWidgetStatus` (7 уровней)
- `outfitItems(effectiveTemp:weatherCode:windSpeed:precipitation:)` → `[String]`
- `recommend(weather:, profile:)` → `WidgetOutfitRecommendation`

`WidgetOutfitRecommendation.topItemsSummary` — топ-3 вещи через «·» (для Rectangular виджета).

---

## 9. Ключевые паттерны и принципы

| Принцип | Применение |
|---|---|
| **SRP** | WardrobeModel — только CLO-логика; ClothingCalculatorView — только UI |
| **OCP** | OutfitAdvisor: новое правило = новый тип OutfitRule. LayerStrategy: новый контекст = новая стратегия |
| **DIP** | WeatherViewModel зависит от `any WeatherService`, а не от OpenMeteoService |
| **@Observable** | WeatherViewModel, WardrobeModel, RadarMapViewModel, LocationManager, BiasStore — все @MainActor |
| **AppGroup** | Единый UserDefaults между основным таргетом и виджетом |
| **Codable** | ChildProfile, FeedbackEvent — backward-compatible (новые поля через try?) |
| **Pure functions** | ClothingBiasEngine, ClothingRecommendationEngine — без I/O, легко тестировать |

---

## 10. Известные ограничения и точки роста

### 10.1 UI не подключён к новому движку

- `OutfitView` использует старый `OutfitAdvisor` (плоский список)
- `ClothingRecommendationEngine` реализован и готов, но не отображается в интерфейсе
- **Задача:** создать `LayeredOutfitView` или переключить `OutfitView` на новый движок

### 10.2 Feedback UI отсутствует

- `BiasStore` реализован и персистирует, но кнопок «Холодно» / «Жарко» в интерфейсе нет
- **Задача:** добавить в `OutfitView` или `WeatherView` пару кнопок → `BiasStore.shared.record(...)`

### 10.3 Выбор провайдера погоды

- `WeatherServiceSettings.swift` готов, но UI переключения не реализован
- `WeatherViewModel` создаёт `OpenMeteoService()` напрямую в `init`, не через фабрику
- **Задача:** добавить `WeatherViewModel(service: WeatherProvider.activeService)` + экран настроек провайдера с полем для API-ключа

### 10.4 ActivityLevel не отображается в профиле

- Поле добавлено в `ChildProfile`, но не вынесено в `ChildProfileSetupView` и `ProfileSummaryView`
- **Задача:** добавить пикер активности в онбординг и профиль

### 10.5 temperaturePreferenceOffset не используется в UI

- Поле есть в модели, но нет ни ввода, ни отображения
- **Задача:** слайдер «Постоянная поправка» в профиле (−4…+4°C)

### 10.6 Город не определяется

- `WeatherViewModel.load(coordinate:cityName:)` принимает `cityName`, но `ContentView` передаёт `"Моё местоположение"` hardcoded
- **Задача:** добавить reverse geocoding через `CLGeocoder` в `LocationManager` или `WeatherViewModel`

### 10.7 Виджет не имеет независимой геолокации

- Читает кеш приложения; если приложение не запускалось — данных нет
- **Задача:** описана в `ClothingStatusProvider.swift` (TODO-блок): Background fetch + CLLocationManager в виджете

### 10.8 Нет обработки ошибок в UI

- `WeatherViewModel.error` устанавливается, но ни одна view не подписана на него
- **Задача:** toast или alert при ошибке загрузки

### 10.9 OutfitAdvisor и ClothingRecommendationEngine дублируют логику

- Два параллельных движка — временное состояние
- **Задача:** перевести `OutfitView` на `ClothingRecommendationEngine`, удалить `OutfitAdvisor`

---

## 11. Зависимости между файлами

```
ContentView
├── WeatherViewModel       ← WeatherService (protocol)
│                               ← OpenMeteoService | WeatherKitService | OWM | WAPI
├── LocationManager
├── WeatherView            ← WeatherData, ChildProfile
│   └── ChildPerceptionCard ← ChildWeatherPerception
├── RadarMapView           ← RadarMapViewModel ← RainViewerService
├── OutfitView             ← WeatherData, ChildProfile
│   └── OutfitAdvisor      ← WeatherData, AgeGroup
├── ClothingCalculatorView ← WeatherData?, ChildProfile?
│   └── WardrobeModel      ← GarmentCatalog
│       └── (ClothingRecommendationEngine — пока не подключён)
│           └── BiasStore  ← FeedbackEvent, TempZone, ClothingBiasEngine
└── ProfileSummaryView     ← ChildProfile
    └── ChildProfileSetupView ← ChildProfileStore ← AppGroup
```

**Shared между таргетами (SkyKid + SkyKidWidget):**
- `ChildProfile.swift` — включает AppGroup, CachedWeather, ActivityLevel
- `WeatherData.swift`

**Только SkyKidWidget:**
- `WidgetClothingCalculator.swift`, `ClothingStatusProvider.swift`, `ClothingStatusWidgetView.swift`

---

## 12. Конфигурация проекта

| Параметр | Значение |
|---|---|
| Bundle ID | `com.skykid.app` |
| Widget Bundle ID | `com.skykid.app.widget` |
| App Group | `group.com.skykid.app` |
| iOS Deployment Target | 17.0 |
| Swift Version | 6.0 |
| Entitlements | App Groups · WeatherKit |
| Frameworks (основной таргет) | WeatherKit.framework |
| Frameworks (виджет) | WidgetKit.framework · SwiftUI.framework |
| Тема | `@AppStorage("colorScheme")`: system / light / dark |
