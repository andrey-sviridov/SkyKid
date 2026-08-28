# SkyKid — CLAUDE.md

iOS-приложение (SwiftUI, iOS 17+, Swift 6). Показывает погоду, рекомендует одежду для ребёнка с учётом его возраста и отслеживает прогулки (живой таймер, журнал, Live Activity).

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
| [docs/models.md](docs/models.md) | WeatherData, ChildProfile, AgeGroup, AppGroup, GarmentCatalog, WardrobeModel, склонение |
| [docs/algorithms.md](docs/algorithms.md) | OutfitAdvisor (OCP-правила), WardrobeModel.riskLevel, autoSelect() |
| [docs/api.md](docs/api.md) | Open-Meteo, WeatherService протокол |
| [docs/conventions.md](docs/conventions.md) | Соглашения кода, SOLID-специфика, производительность, виджет |

---

## Карта файлов

Правило проекта — **1 файл = 1 логическая единица** (view/класс/enum) + DI
через `.environment(_:)` для `@Observable`-сторов (см.
[docs/conventions.md](docs/conventions.md), раздел «Структура файлов и DI»).
Каждая фича с 2+ переиспользуемыми/самостоятельными View-компонентами имеет
подпапку `Components/`.

```
SkyKid/
├── App/
│   ├── SkyKidApp.swift              @main → ContentView
│   ├── ContentView.swift            Композиционный корень: создаёт все @Observable
│   │                                сторы и пробрасывает их вниз через .environment(_:);
│   │                                роутер онбординг → геолокация → нативный
│   │                                TabView (5 вкладок, .tabItem + Liquid Glass);
│   │                                tabSelection перехватывает вкладку «Прогулка» (пропускает,
│   │                                если нет своей, но есть live-прогулка второго родителя);
│   │                                жизненный цикл LiveWalkObserver: start()/stop() на
│   │                                scenePhase, plus start() в конце syncOnLaunch()
│   ├── PermissionView.swift / DeniedView.swift   Экраны геолокации
│   ├── SkyKidIntents.swift          AppIntents (Siri): рекомендация из кеша AppGroup
│   └── Theme.swift                  SkyKidTheme, weather-градиенты
│
├── Features/
│   ├── Weather/
│   │   ├── WeatherView.swift        Вкладка «Погода»: hero + statsGrid
│   │   ├── WeatherViewModel.swift   @MainActor @Observable; init(service:outfitUseCase:)
│   │   └── Components/              HourlyForecastCard, ProviderPickerView,
│   │                                 StatCard, WeatherDataQualityCard
│   │
│   ├── Outfit/                      ── TOG-пайплайн §2→§6 (вкладка «Одежда») ──
│   │   ├── OutfitView.swift         UI: hero, warnings, walkWindow, слои, фидбек
│   │   ├── OutfitViewModel.swift    presentation state + личный TOG-фидбек
│   │   ├── BuildOutfitRecommendationUseCase.swift  application-level оркестратор
│   │   ├── OutfitRecommendationService.swift       §2→§6 TOG-пайплайн (сервис, DI через init)
│   │   ├── OutfitConfig.swift, GearModels.swift, OutfitOutputModels.swift,
│   │   │   EffectiveTemperatureCalculator/MicroclimateCalculator/TOGCalculator/
│   │   │   OutfitSolver/SafetyRulesEngine.swift и др. — §2–§6 калькуляторы/policy,
│   │   │   по 1 доменному типу на файл (не дробить дальше)
│   │   │   ⚠️ GearModels.swift и OutfitOutputModels.swift — Target Membership
│   │   │      SkyKid + SkyKidWidgetExtension (сознательное исключение из
│   │   │      «1 файл = 1 тип», см. conventions.md — риск для сборки виджета)
│   │   │
│   │   │                            ── Старый CLO-движок (вкладка «Конструктор») ──
│   │   ├── GarmentCatalog.swift     Доменные enum/модели (GarmentLayer, GarmentItem,
│   │   │                            byID/byLayer — единственный источник каталога)
│   │   ├── WardrobeModel.swift      @MainActor @Observable; CLO-логика, riskLevel, autoSelect()
│   │   ├── ClothingRecommendationEngine.swift  старые правила рекомендаций
│   │   ├── ClothingCalculatorView.swift  Вкладка «Конструктор» — только корневой view
│   │   ├── WalkPreparation/         WalkPreparationView, WalkPreparationViewModel
│   │   └── Components/              ~25 карточек/sheet'ов: WeatherControlsCard,
│   │                                 RiskMeterCard, GarmentListRow, GarmentIconView,
│   │                                 ParentOutfitSummaryCard, OutfitFitCard, …
│   │
│   ├── Profile/
│   │   ├── ChildProfileSetupView.swift  Онбординг + редактирование (вкл. TOG-карточку)
│   │   ├── MyWardrobeView.swift         «Мой гардероб» — чек-лист GarmentCatalog (P1-1)
│   │   ├── ProfileSummaryView.swift     Сводка, уведомления, тема, Siri
│   │   ├── WalkScheduleView.swift       Расписание напоминаний о прогулке
│   │   ├── ChildWeatherPerception.swift summary, ageContextNote, comfortScore/Label
│   │   └── Components/                  AppLanguagePickerCard, StableThermalTraitRow,
│   │                                     GenderButton, WardrobeItemRow, AccountCard,
│   │                                     FamilyCard, FamilyMemberRow, JoinFamilySheet,
│   │                                     LiveWalkNotificationsCard (тумблер уведомлений
│   │                                     о живой прогулке второго родителя)
│   │
│   ├── Walk/                        Вкладка «Прогулка» — живая прогулка + Live Activity
│   │   ├── WalkTabView.swift         Роутер: своя прогулка → ActiveWalkView, чужая →
│   │   │                             LiveWalkDetailView, ничего → ContentUnavailableView
│   │   ├── ActiveWalkView.swift      Экран идущей своей прогулки — сборка из
│   │   │                             Components/Walk* + Core/UI
│   │   ├── LiveWalkDetailView.swift  Read-only экран прогулки второго родителя — та же
│   │   │                             сборка с isEditable: false; @Environment(LiveWalkObserver.self)
│   │   ├── WalkSetupSheet.swift      Старт новой прогулки
│   │   ├── GarmentPickerSheet.swift, WalkTOGVerdict.swift, WalkEventReclassifySheet.swift
│   │   └── Components/               ComfortLevelSheet, CancelWalkSheet, WalkEventRow,
│   │                                  GarmentChip, WalkOutfitChipsCard (isEditable:),
│   │                                  PlannedDurationCard, WalkWeatherSnapshotCard,
│   │                                  WalkTimerHeaderCard, WalkTimelineCard (isEditable:),
│   │                                  WalkQuickActionsCard, LiveWalkStatusFooter —
│   │                                  общие блоки для ActiveWalkView и LiveWalkDetailView
│   │
│   └── History/                     Вкладка «История» — журнал прогулок
│       ├── WalkHistoryView.swift     Список записей + FAB; секция идущих прогулок
│       │                             (своя + partner) над журналом
│       ├── LogWalkSheet.swift        Запись/редактирование прогулки
│       ├── WalkLogDetailView.swift   Детальный экран + таймлайн событий
│       ├── AddWalkEventSheet.swift, WalkDurationFormatter.swift
│       ├── FeedbackHistoryItem.swift, FeedbackHistorySection.swift
│       └── Components/               StatsHeaderCard, EmptyHistoryCard, WalkLogRow,
│                                      WalkDateTimeCard, WalkTemperatureCard,
│                                      DurationPickerCard, ComfortLevelCard, OutfitSummaryCard,
│                                      LiveWalkInProgressRow («идёт сейчас», своя/чужая)
│
├── Core/
│   ├── Network/                     WeatherServiceProtocol, OpenMeteoService,
│   │                                OpenWeatherMapService, WeatherAPIService,
│   │                                YandexWeatherService, WeatherKitService (заглушка)
│   ├── Location/                    LocationManager (@Observable CLLocationManager)
│   ├── Auth/                        SupabaseAuthService (@Observable, .environment),
│   │                                SupabaseClientProvider, SupabaseConfig,
│   │                                AuthPreferences, ChildNameCipher, SignInProvider
│   ├── Sync/                        SupabaseSyncService (family-scoped pull/push),
│   │                                FamilyInviteCode, FamilyMember,
│   │                                LiveWalkSnapshot (модель строки live_walks + isStale()),
│   │                                SupabaseSyncService+LiveWalk (upsert/delete/pull),
│   │                                LiveWalkPublisher (дебаунс-публикатор своей прогулки),
│   │                                LiveWalkObserver (@Observable singleton; Realtime-
│   │                                подписка на чужую прогулку, .environment)
│   ├── Notifications/                NotificationService (@Observable, DI через .environment),
│   │                                 LiveWalkNotifier, LiveWalkNotificationPreferences,
│   │                                 LiveWalkNotificationContent
│   ├── LiveActivity/                 WalkLiveActivityController, WalkQuickMarkIntents
│   ├── Storage/                      ActiveWalkStore (публикует live_walks из save/start/
│   │                                 cancel/refresh через LiveWalkPublisher), WalkLogStore,
│   │                                 RecommendationSnapshotStore, WalkEventReclassifier
│   ├── UI/                           Примитивы без доменных зависимостей: FlowLayout,
│   │                                 SectionCard, ElapsedTimeText, CountdownLabel,
│   │                                 StatusDotLabel, MetricTile (.compact/.prominent)
│   └── Models/
│       ├── ChildProfile.swift            ChildProfile, ChildGender, AgeGroup, AppGroup (enum)
│       │                                 ⚠️ Target Membership: SkyKid + SkyKidWidget
│       ├── ChildProfileStore.swift       @Observable singleton; только таргет SkyKid
│       ├── UserWardrobeStore.swift       @Observable singleton; user_wardrobe в AppGroup
│       ├── WalkContextStore.swift        текущий контекст прогулки (не Codable)
│       ├── PersonalOffsetStore.swift     §8 TOG-обучение
│       └── BiasStore.swift               °C-обучение (старый движок, сейчас не используется)
│
└── Info.plist

SkyKidWidget/
├── SkyKidWidgetBundle.swift         @main WidgetBundle
├── WidgetClothingCalculator.swift   ClothingWidgetStatus, WidgetOutfitRecommendation
├── ClothingStatusProvider.swift     TimelineProvider (30 мин); читает AppGroup
├── ClothingStatusWidgetView.swift   Small, Medium, Circular, Rectangular views
└── WalkLiveActivityWidget.swift     Live Activity для идущей прогулки
```

Все `@Observable`-сторы (кроме `WalkContextStore`, который используется только
в `ContentView`, и `BiasStore`, сейчас не используемого) создаются один раз в
`ContentView` и пробрасываются через `.environment(_:)`; остальной код читает
их через `@Environment(XStore.self)`, а не через `XStore.shared` напрямую.
