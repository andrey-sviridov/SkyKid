# Модели данных SkyKid

## WeatherData (`Core/Models/WeatherData.swift`)

| Поле | Тип | Источник |
|---|---|---|
| `temperature` | Double | `temperature_2m` |
| `apparentTemperature` | Double | `apparent_temperature` |
| `humidity` | Int | `relative_humidity_2m` |
| `windSpeed` | Double | `wind_speed_10m` (м/с) |
| `windDirection` | Int | `wind_direction_10m` (градусы) |
| `precipitation` | Double | `precipitation` (мм/ч) |
| `weatherCode` | Int | WMO код (0=ясно … 99=гроза) |

Computed: `windDirectionLabel`, `conditionDescription`, `conditionIcon` (SF Symbols).  
Также содержит `RadarFrame: Identifiable { id, time, path }`.

## ChildProfile (`Core/Models/ChildProfile.swift`)

- `name: String`, `gender: ChildGender (.boy/.girl)`, `birthday: Date`
- Вычисляемые: `ageYears`, `ageMonths`, `ageLabel`, `ageGroup: AgeGroup`
- Сохранение: `ChildProfileStore.shared.profile` → `AppGroup` (suite `group.com.skykid.app`, ключ `"child_profile"`, JSON)

### AgeGroup + температурные поправки

| Группа | Возраст | Offset | Логика |
|---|---|---|---|
| `.infant` | 0–5 мес | −5° | Не регулирует температуру |
| `.baby` | 6–11 мес | −4° | Уязвим, ориентир — шея/грудь |
| `.toddler` | 1–3 г | −3° | Активный, быстро остывает в покое |
| `.preschool` | 3–6 л | −2° | Не замечает холода, ориентир — затылок/щёки |
| `.schoolAge` | 6–12 л | −1° | Понимает, но игнорирует |
| `.teen` | 12+ л | 0° | Как взрослый |

### Склонение имён (RussianCase)

Метод `String.declined(to:gender:)` в `ChildProfile.swift`.  
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

## AppGroup (`Core/Models/ChildProfile.swift`)

Enum-пространство имён; методы статические, обращаются к `UserDefaults(suiteName: "group.com.skykid.app")`.

| Метод | Описание |
|---|---|
| `saveProfile(_:)` / `loadProfile()` / `deleteProfile()` | Профиль ребёнка (Codable JSON) |
| `saveWeather(temperature:apparentTemp:weatherCode:windSpeed:precipitation:cityName:)` | Кеш погоды |
| `loadCachedWeather() → CachedWeather?` | nil если > 2 ч или пуст |

**App Group capability** должна быть включена для обоих таргетов с ID `group.com.skykid.app`.

## ChildProfileStore (`Core/Models/ChildProfileStore.swift`)

`final class @unchecked Sendable` — singleton только в основном таргете (не в виджете).  
`profile { get/set }` проксирует вызовы в `AppGroup.load/save/deleteProfile()`.

## GarmentCatalog (`Features/Outfit/GarmentCatalog.swift`)

```swift
enum GarmentCatalog {
    static let all: [GarmentItem]                       // 20 предметов
    static let byID: [String: GarmentItem]              // O(1) lookup
    static let byLayer: [GarmentLayer: [GarmentItem]]   // O(1) по категории
}
```

Типы в том же файле: `GarmentLayer` (4 слоя), `WardrobeAgeGroup` (.newborn/.active),  
`ThermalRisk` (7 уровней + `.color` + `.symbol`), `GarmentItem` (id, name, heatValue, layer, symbol).  
Также: `extension AgeGroup { var toWardrobeAgeGroup: WardrobeAgeGroup }`.

## WardrobeModel (`Features/Outfit/WardrobeModel.swift`)

`@MainActor @Observable final class`.

| Свойство | Описание |
|---|---|
| `temperature: Double` | Вход: слайдер −25…+35 |
| `ageGroup: WardrobeAgeGroup` | .newborn / .active |
| `selectedItems: Set<GarmentItem>` | Выбранные предметы |
| `requiredHeat` | `max(0, (24 − temp) × 0.5)` × 0.85 для .active при temp < 15 |
| `currentHeat` | Сумма CLO selectedItems |
| `heatDeviation` | currentHeat − requiredHeat |
| `riskLevel: ThermalRisk` | Зональная оценка + safety overrides |
| `autoSelect()` | Жадный алгоритм → selectedItems |
