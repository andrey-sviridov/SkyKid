# SkyKid — CLAUDE.md

iOS-приложение (SwiftUI, iOS 17+, Swift 6). Показывает погоду, карту осадков и рекомендует одежду для ребёнка с учётом его возраста.

## Быстрая сборка

```bash
# Открыть в Xcode
open /Users/northarion/projects/SkyKid/SkyKid.xcodeproj

# Сборка через CLI (симулятор iPhone 17 Pro)
xcodebuild -project SkyKid.xcodeproj -scheme SkyKid \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Bundle ID: `com.skykid.app` · Deployment target: iOS 17.0 · Swift 6.0

---

## Карта файлов

```
SkyKid/
├── App/
│   ├── SkyKidApp.swift              @main, WindowGroup → ContentView
│   └── ContentView.swift            Роутер: онбординг → геолокация → TabView(4 вкладки)
│                                    + ProfileSummaryView, PermissionView, DeniedView
│
├── Features/
│   ├── Weather/
│   │   ├── WeatherView.swift        Вкладка «Погода»: header + ChildPerceptionCard + statsGrid
│   │   │                            Содержит также: StatCard, ChildPerceptionCard
│   │   └── WeatherViewModel.swift   @MainActor @Observable; вызывает OpenMeteoService
│   │
│   ├── Map/
│   │   ├── RadarMapView.swift       Вкладка «Осадки»: UnifiedRadarMapView + плеер (▶/⏸ + Slider)
│   │   │                            UnifiedRadarMapView — ОДИН MKMapView (карта + радар + точка)
│   │   ├── RadarMapViewModel.swift  @MainActor @Observable; управляет frames[], playTask
│   │   └── RainViewerOverlay.swift  MKTileOverlay + MKTileOverlayRenderer (opacity 0.6)
│   │
│   ├── Outfit/
│   │   ├── OutfitView.swift         Вкладка «Одежда»: баннер + список OutfitItem
│   │   └── OutfitAdvisor.swift      Чистая функция: recommend(weather:profile:) → [OutfitItem]
│   │
│   └── Profile/
│       ├── ChildProfileSetupView.swift  Онбординг + редактирование (имя / пол / ДР)
│       └── ChildWeatherPerception.swift Структура-вычислитель: summary, ageContextNote,
│                                        effectiveFeelsLike, comfortScore/Label/Color, moodEmoji
│
├── Core/
│   ├── Network/
│   │   ├── OpenMeteoService.swift   fetch(coordinate:) → WeatherData (async throws)
│   │   └── RainViewerService.swift  fetchFrames() → [RadarFrame]; tileURL(path:z:x:y:)
│   ├── Location/
│   │   └── LocationManager.swift   @Observable CLLocationManager; requestWhenInUse / startUpdating
│   └── Models/
│       ├── WeatherData.swift        Struct: temp, apparentTemp, humidity, windSpeed/Dir,
│       │                            precipitation, weatherCode + computed: windDirectionLabel,
│       │                            conditionDescription, conditionIcon (SF Symbols)
│       └── ChildProfile.swift       ChildProfile (Codable), ChildGender, AgeGroup,
│                                    RussianCase, String.declined(to:gender:),
│                                    ChildProfileStore (@unchecked Sendable, UserDefaults)
│
└── Info.plist                       CFBundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER) ← обязательно
```

---

## Поток данных

```
ContentView
  └─ LocationManager.location → onChange → WeatherViewModel.load(coordinate:)
       └─ OpenMeteoService.fetch() → WeatherData
            ├─ WeatherView(weather, cityName, profile?)
            │    └─ ChildPerceptionCard ← ChildWeatherPerception(profile, weather)
            └─ OutfitView(weather, profile?)
                 └─ OutfitAdvisor.recommend(weather, profile?)

ContentView
  └─ RadarMapView(coordinate)
       └─ RadarMapViewModel.loadFrames() → RainViewerService.fetchFrames() → [RadarFrame]
            └─ RainViewerOverlay(path) рисуется через RadarTileView (UIViewRepresentable)
```

---

## Ключевые модели

### WeatherData
| Поле | Тип | Источник |
|---|---|---|
| `temperature` | Double | `temperature_2m` |
| `apparentTemperature` | Double | `apparent_temperature` |
| `humidity` | Int | `relative_humidity_2m` |
| `windSpeed` | Double | `wind_speed_10m` (м/с) |
| `windDirection` | Int | `wind_direction_10m` (градусы) |
| `precipitation` | Double | `precipitation` (мм/ч) |
| `weatherCode` | Int | WMO код (0=ясно … 99=гроза) |

### ChildProfile
- `name: String`, `gender: ChildGender (.boy/.girl)`, `birthday: Date`
- Вычисляемые: `ageYears`, `ageMonths`, `ageLabel` (склонённые числительные), `ageGroup`
- Сохранение: `ChildProfileStore.shared.profile` → UserDefaults (ключ `"child_profile"`, JSON)

### AgeGroup + температурные поправки
| Группа | Возраст | Offset | Логика |
|---|---|---|---|
| `.infant` | 0–5 мес | −5° | Не регулирует температуру |
| `.baby` | 6–11 мес | −4° | Уязвим, ориентир — шея/грудь |
| `.toddler` | 1–3 г | −3° | Активный, быстро остывает в покое |
| `.preschool` | 3–6 л | −2° | Не замечает холода, ориентир — затылок/щёки |
| `.schoolAge` | 6–12 л | −1° | Понимает, но игнорирует |
| `.teen` | 12+ л | 0° | Как взрослый |

### RadarFrame
```swift
struct RadarFrame: Identifiable {
    let id: UUID; let time: Date; let path: String  // path → тайлы RainViewer
}
```

---

## Алгоритм OutfitAdvisor

Входные данные: `weather.apparentTemperature + ageGroup.temperatureOffset` = `t`

| t (°C) | Базовый список |
|---|---|
| < −10 | Комбинезон, термобельё, варежки, шапка |
| −10…0 | Зимняя куртка, перчатки, шапка |
| 0…5 | Тёплая куртка, перчатки, шапка |
| 5…15 | Куртка, кофта |
| 15…22 | Лёгкая куртка, футболка |
| > 22 | Лёгкая одежда, панамка |

**Возрастные добавки:** infant → боди+конверт; baby → тёплые носочки; toddler при t<10 → носки  
**Защита шеи при t<5:** infant/baby/toddler → **бафф/снуд** (шарф опасен — риск удушения на площадке); preschool → бафф или короткий шарф; school/teen → шарф  
**Ветер > 7 м/с** → ветровка  
**Снег (weatherCode 71–77)** → зимние сапоги  
**Дождь (код 51–82 или precipitation > 0.1)** → дождевик + резиновые сапоги

---

## Склонение имён (RussianCase)

Файл: `ChildProfile.swift`, метод `String.declined(to:gender:)`.  
Вызов: `profile.name(.accusative)` / `.dative` / `.genitive` / `.nominative`

| Окончание | Пример | Вин | Дат | Род |
|---|---|---|---|---|
| `-а` после шипящих/г/к/х | Маша | Машу | Маше | Маши |
| `-а` после остальных | Алина | Алину | Алине | Алины |
| `-я` | Оля, Дарья | Олю/Дарью | Оле/Дарье | Оли/Дарьи |
| `-й` (муж) | Андрей | Андрея | Андрею | Андрея |
| `-ь` (муж) | Игорь | Игоря | Игорю | Игоря |
| `-ь` (жен) | Любовь | Любовь | Любови | Любови |
| согласная (муж) | Иван | Ивана | Ивану | Ивана |
| согласная (жен) | Элис | Элис | Элис | Элис |

Применяется в: `OutfitView.navigationTitle` (вин.), `ChildWeatherPerception.summary` (дат./род.)

---

## API

### Open-Meteo
```
GET https://api.open-meteo.com/v1/forecast
  ?latitude=…&longitude=…
  &current=temperature_2m,apparent_temperature,relative_humidity_2m,
           wind_speed_10m,wind_direction_10m,weather_code,precipitation
  &wind_speed_unit=ms&timezone=auto
```
Бесплатно, без ключей. Парсится в `OMRoot → OMCurrent` (private structs в `OpenMeteoService.swift`).

### RainViewer
```
GET https://api.rainviewer.com/public/weather-maps.json
→ { radar: { past: [{time, path}], nowcast: [{time, path}] } }

Тайл: https://tilecache.rainviewer.com{path}/256/{z}/{x}/{y}/2/1_1.png
```
Бесплатно, без ключей. `past` ≈ последние 2 ч, `nowcast` ≈ следующие 30 мин.

---

## Архитектура и паттерны

- **MVVM** — Views не обращаются к сети напрямую, только через ViewModel
- **`@Observable` + `@MainActor`** на всех VM — безопасно для Swift 6 concurrency
- **`@unchecked Sendable`** на `ChildProfileStore` — корректно, т.к. UserDefaults thread-safe
- `LocationManager` — `@Observable NSObject`, запрашивает геолокацию и останавливает обновление после первого фикса
- `RadarTileView` — UIViewRepresentable-мост для `MKTileOverlay` поверх SwiftUI `Map`

## Тема оформления

`@AppStorage("colorScheme")` — ключ UserDefaults, значения: `"system"` / `"light"` / `"dark"`.  
Читается в `ContentView` → `.preferredColorScheme(preferredScheme)`.  
Picker находится в `ProfileSummaryView` (вкладка «Профиль» → секция «Оформление»).

## Онбординг / навигация (ContentView)

```
childProfile == nil → ChildProfileSetupView  (первый запуск)
childProfile != nil →
  authorizationStatus == .notDetermined → PermissionView
  authorizationStatus == .denied        → DeniedView
  иначе                                 → TabView (теги 0–3)
    0 — Погода    (WeatherView)
    1 — Осадки    (RadarMapView)
    2 — Одежда    (OutfitView)
    3 — Профиль   (ProfileSummaryView + редактирование через sheet)
```

---

## Соглашения кода

- Нет `!` force-unwrap — только `guard let` / `if let`
- `async/await` везде, колбеков нет
- Все VM: `@MainActor @Observable final class`
- Размеры в коде пока без констант — при рефакторинге выносить в `Design.swift` (не создан)
- Локализация не подключена — строки вшиты напрямую
