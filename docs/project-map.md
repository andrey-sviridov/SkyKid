# SkyKid — карта проекта

> Актуализировано: 13 сентября 2026 года. Стек: SwiftUI · iOS 17+ · Swift 6 · Observation · WidgetKit · AppIntents.

## Пользовательский поток

```text
SkyKidApp
└── ContentView (тонкая точка входа)
    └── AppComposition (единый composition root)
        └── RootFlow
            ├── ChildProfileSetupView — первый запуск
            ├── PermissionView / DeniedView — геолокация или ручной город
            └── MainTabView — ровно три вкладки
                ├── Сегодня — погода, комплект, окно и активная прогулка
                ├── История — завершённые прогулки и наблюдения
                └── Профиль — ребёнок, гардероб, язык, данные и методика
```

Приложение работает локально и не требует аккаунта. Профиль, гардероб, прогулки, персонализация, активная прогулка и снимок рекомендации хранятся на устройстве или в App Group. Сетевой обмен ограничен запросами погодным провайдерам и геокодированием города.

## Основные каталоги

```text
SkyKid/
├── App/
│   ├── SkyKidApp.swift
│   ├── ContentView.swift
│   ├── AppComposition.swift
│   ├── RootFlow.swift
│   └── MainTabView.swift
├── Features/
│   ├── Today/          — агрегированный главный экран и его небольшие карточки
│   ├── Weather/        — погодное представление и WeatherViewModel
│   ├── Outfit/         — TOG-пайплайн, safety-политики и presentation-компоненты
│   ├── Walk/           — подготовка, таймер, погода и одежда активной прогулки
│   ├── History/        — журнал, детали, итог и аналитика прогулок
│   └── Profile/        — профиль, гардероб, расписание, backup/reset и MethodologyView
├── Core/
│   ├── Backup/         — локальный экспорт, валидация и миграция резервной копии
│   ├── LiveActivity/   — ActivityKit-контроллер и App Intents
│   ├── Localization/   — язык приложения и L10n
│   ├── Location/       — Core Location, ручной город и геокодирование
│   ├── Models/         — погодные, профильные и прогулочные модели
│   ├── Network/        — WeatherService и адаптеры погодных API
│   ├── Notifications/  — безопасные локальные напоминания
│   └── Storage/        — локальные store и атомарный reset
└── Resources/          — пять каталогов локализации

SkyKidWidget/
├── ClothingStatusProvider.swift
├── ClothingStatusWidgetView.swift
├── WidgetClothingCalculator.swift
├── WalkLiveActivityWidget.swift
└── <locale>.lproj/Localizable.strings
```

## Поток погоды и рекомендации

```text
LocationManager / LocationSelectionStore
  → WeatherViewModel
  → any WeatherService
  → RawWeatherObservation
  → WeatherNormalizer
  → NormalizedWeather + WeatherSnapshot
  → BuildOutfitRecommendationUseCase
       ├── OutfitRecommendationService
       │    ├── EffectiveTemperatureCalculator
       │    ├── MicroclimateCalculator
       │    ├── TOGCalculator
       │    ├── OutfitSolver
       │    └── SafetyRulesEngine
       └── RecommendationSnapshotStore
            ├── TodayView
            ├── Widget
            └── Siri/AppIntent
```

`NormalizedWeather` — единый вход расчёта. Неизвестные поля сохраняют provenance и не маскируются под измеренный ноль. Время рекомендации привязано ко времени погоды; локальный пересчёт не продлевает срок свежести. Виджет и Siri читают готовый снимок и не выполняют собственный подбор одежды.

## Прогулка и персонализация

`WalkSetupSheet` создаёт локальную `ActiveWalk`. `ActiveWalkView` показывает таймер, погодный снимок и надетые вещи; завершение создаёт `WalkLog`, после чего `WalkCompletionView` принимает оценку комфорта. Персонализация учитывает только повторяющиеся наблюдения завершённых отслеживаемых прогулок с достоверным контекстом. Legacy-поля событий продолжают декодироваться, но новый UI их не создаёт.

## Состояние интеграций

- По умолчанию используется Open-Meteo; доступны адаптеры провайдеров с API-ключом.
- WeatherKit остаётся заглушкой до появления entitlement и отдельной реализации.
- AQI и StoreKit не входят в текущую реализацию.
- Клинический release-gate остаётся обязательным и до внешнего sign-off имеет статус `pending`.

## Итог cleanup фазы 13

Удалены только кандидаты с доказанным отсутствием live-ссылок: старый авто-подборщик, три неиспользуемые карточки комплекта, устаревшие event/timeline views и legacy-контейнер погоды. `PrecipType` и `HourlyForecast` перенесены в `NormalizedWeather.swift`.

`WalkEventUndo` и `WalkEventReclassifier` сохранены: их вызывает `ActiveWalkStore`. Legacy event-поля сохранены для декодирования старых payload. Перед удалением каждого кандидата проверены Swift-ссылки, project membership и тесты; ссылки на удалённые файлы исключены из `project.pbxproj`.
