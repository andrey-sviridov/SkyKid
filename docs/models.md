# Модели данных SkyKid

## Погодные модели

### RawWeatherObservation (`Core/Models/RawWeatherObservation.swift`)

Транспортная модель адаптеров. Все погодные значения необязательны, поэтому настоящий `0` (штиль, отсутствие осадков или UV) не смешивается с отсутствующим полем ответа. `source` хранит фактического провайдера, а `qualityOverrides` и `notes` позволяют адаптеру отметить вычисленное значение.

### NormalizedWeather (`Core/Models/NormalizedWeather.swift`)

Единственный погодный вход основного UI и TOG-пайплайна. Содержит температуру, ощущаемую температуру, влажность, устойчивый ветер и порыв, направление, осадки, WMO-код, UV, облачность, тип осадков и почасовой прогноз.

Для каждого `WeatherField` хранится `WeatherFieldStatus`:

- `source` — реальный поставщик данных;
- `origin` — провайдер, вычисление из ответа или защитная подстановка;
- `quality` — `observed`, `derived`, `estimated` либо `unavailable`;
- `note` — пользовательски понятная причина подстановки.

`WeatherConfidence` агрегирует качество полей в `high`, `medium` или `low`. Отсутствующий UV не позволяет выставить высокую уверенность, потому что солнечная поправка не подтверждена.

### WeatherData (`Core/Models/WeatherData.swift`)

Legacy-контейнер скалярных значений сохранён только для изолированного CLO-конструктора и совместимости общего кода виджета. Новые сетевые сервисы и рекомендательный движок его не используют. В этом же файле находятся `PrecipType`, `HourlyForecast` и `RadarFrame`.

## ChildThermalProfile (`Core/Models/ChildThermalProfile.swift`)

Постоянная часть профиля:

- `name`, `gender`, `birthday`;
- `gestationalAgeWeeks` в диапазоне 22…40;
- `stableTraits: Set<StableThermalTrait>` — устойчивые особенности, а не самочувствие сегодня;
- `temperaturePreferenceOffset` в диапазоне −3…+3°C;
- вычисляемые возраст, возрастная группа и скорректированный возраст.

`StableThermalTrait`: `frequentIllness`, `coldSensitive`, `heatSensitive`, `anemia`, `atopicDermatitis`, `cardioRespiratory`.

## WalkContext (`Core/Models/WalkContext.swift`)

Временный вход для одной планируемой прогулки:

- `healthStatus` и необязательная `bodyTemperatureCelsius`;
- `activityLevel`, `walkType`, `transportMode`;
- капюшон, дождевик, конверт, плед и слинг под курткой;
- `availableGarmentIDs` — снимок личного гардероба для текущего расчёта.

`WalkContext` не реализует `Codable`. `WalkContextStore` хранит его только в памяти текущего запуска. Острая болезнь и выбор транспорта не попадают в `UserDefaults` и App Group.

## ChildProfile (`Core/Models/ChildProfile.swift`)

`ChildProfile` — миграционная обёртка над `ChildThermalProfile`. Схема v2 кодирует только `schemaVersion` и `thermalProfile`. При декодировании старого плоского JSON:

- устойчивые особенности и срок рождения мигрируют;
- лихорадка, ОРВИ, активность, тип прогулки и коляски намеренно отбрасываются.

Сохранение: `ChildProfileStore.shared.profile` → App Group (`child_profile`, JSON v2).

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

## OutfitRecommendation

`OutfitRecommendation` — единый Codable-результат для основного UI, журнала прогулок, виджета и Siri.

| Поле | Описание |
|---|---|
| `temperatures.outside` | Измеренная наружная температура |
| `temperatures.apparent` | Ощущаемая температура провайдера |
| `temperatures.effective` | Поправки ветра, влажности, осадков и солнца |
| `temperatures.microclimate` | Условия ребёнка в коляске, слинге или автокресле |
| `layers`, `accessories` | Слои из `OutfitSolver` без UI-адаптации |
| `missingGarments` | Необязательный для декодирования список подходящих, но отсутствующих вещей; UI показывает его как варианты замены |
| `totalTOG`, `targetTOG` | Сухое утепление комплекта и тепловая цель |
| `fit` | Эффективный TOG, погрешность, покрытие корпуса и уверенность |
| `warnings`, `checkHint`, `walkWindow` | Выход safety-движка |

## OutfitRecommendationSnapshot

`OutfitRecommendationSnapshot` оборачивает полный `OutfitRecommendation` и добавляет `schemaVersion`, `generatedAt`, `expiresAt`, имя/возраст ребёнка, город и optional `RecommendationSnapshotContext`. Контекст содержит описание погоды, источник, уверенность, транспорт, активность и тип прогулки; optional сохраняет декодирование снимков ранней схемы v2.

`generatedAt` соответствует моменту получения использованной погоды, а не любому локальному пересчёту комплекта. Поэтому смена гардероба, транспорта или персональной поправки сохраняет прежний `expiresAt` и не продлевает актуальность старого прогноза. `AppGroupRecommendationSnapshotStore` хранит снимок под ключом `outfit_recommendation_snapshot_v2`; TTL по умолчанию — два часа.

## Модели персонализации

`PersonalizationContext` сохраняет условия, в которых родитель оценил комплект: `microclimateTemperature`, `TempBand`, спокойный/активный сценарий, транспорт, активность, тип прогулки, одежду, целевой/фактический TOG и длительность.

`PersonalizationObservation` связывает контекст с `UserFeedback`, временем, источником и стабильным `sourceID`. Быстрый отзыв использует ID текущей сессии, а журнал — `WalkLog.id`; повторная запись с тем же ID заменяет прежнее наблюдение.

`PersonalizationProfileState` — Codable-схема v2:

| Поле | Назначение |
|---|---|
| `schemaVersion` | Версия сохранённого формата |
| `legacyOffsetsByBand` | Baseline, мигрированный из `tog_offset_v1` |
| `observations` | Не более 80 последних контекстных оценок |

`PersonalizationSummary` — read model для UI: текущая зона/сценарий, применённая поправка, число независимых направленных сигналов, подтверждения «Комфортно» и признак сохранённых данных.

`PersonalOffsetStore.feedbackHistory(for:limit:)` возвращает только наблюдения выбранного профиля за допустимый срок, от новых к старым. `FeedbackHistoryItemBuilder` переводит их в presentation-модель истории, не изменяя персонализацию.

`WalkLog` дополнительно хранит optional-контекст персонализации. Поля optional для обратной совместимости со старыми JSON-записями; при редактировании старой прогулки доступный контекст дополняется.

## ChildProfileStore (`Core/Models/ChildProfileStore.swift`)

`final class @unchecked Sendable` — singleton только в основном таргете (не в виджете).  
`profile { get/set }` проксирует вызовы в `AppGroup.load/save/deleteProfile()`.

## GarmentCatalog (`Features/Outfit/GarmentCatalog.swift`)

```swift
enum GarmentCatalog {
    static let all: [GarmentItem]                       // единственный каталог
    static let byID: [String: GarmentItem]              // O(1) lookup
    static let byLayer: [GarmentLayer: [GarmentItem]]   // O(1) по категории
}
```

`GarmentItem` хранит обе тепловые величины (`heatValue` для legacy CLO и `tog` для основного решателя), возрастную группу, назначение `GarmentUse`, `coveredZones`, анатомические слоты слоя и `exclusiveGroup`. `GarmentCompatibilityPolicy` является единственным местом проверки совместимости. Скрытых предметов с `catalogAgeGroup == nil` больше нет.

`BodyZone`: корпус, руки, ноги, голова, шея, кисти и стопы. `GarmentUse` отделяет прогулочную одежду, аксессуары, утепление коляски, сон и утилитарные предметы.

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
