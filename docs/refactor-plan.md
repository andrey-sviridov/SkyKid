# SkyKid Refactoring Plan

Canonical planning document for the local-first product, safety, and architecture refactor. This document records the repository state verified on 2026-09-06. It authorizes no implementation by itself. Production changes must be executed as separate `SKY-xxx` tickets with the listed file whitelist.

## Product invariants

- SkyKid remains an informational clothing assistant, not a medical device, sleep tracker, GPS tracker, family CRM, or weather app.
- The primary loop is weather + walk context + this child's honest tracked-walk history → recommendation.
- During a walk, zero input is valid. After a walk, one comfort answer is sufficient; “not sure” and skip are valid.
- Unknown data stays unknown. Synthetic weather and current-weather substitution for historical walks are prohibited.
- Basic recommendation, safety guidance, feedback, local history, export, and restore are never paywalled.
- Child data, walks, wardrobe, and personalization remain local in v1. Weather requests receive only location/provider credentials.
- TOG is an internal deterministic implementation detail and is not presented as consumer precision.
- Safety-critical behavior changes require regression tests, algorithm versioning, documentation, and external review under the existing release gate.
- Single-child v1 is intentional, but stable UUID identity must permit a later multi-child design.
- No new DI framework, analytics SDK, ad SDK, AI/LLM, or backend dependency is introduced.
- Every implementation ticket ends with build, relevant tests, diff review, and no unrelated edits.

## A. Baseline

| Item | Verified state |
|---|---|
| Date/environment | 2026-09-06, macOS/Xcode environment, iOS Simulator `iPhone 17 Pro` available |
| Branch | `main` |
| Commit | `1949fc9fadc428ece9465342af27382d60546094` (`промежуточное сохранение`) |
| Worktree | Clean; 0 modified/deleted/untracked files before this planning file; diff stat `0 / 0` |
| Previous “67 changed files” claim | No longer true for this checkout |
| Source size | 172 production Swift files across app/widget; 14 Swift test files |
| Deployment/toolchain | iOS 17.0+, Swift 6.0; app bundle `com.skykid.app`; App Group `group.com.skykid.app` |
| Direct dependency | `supabase-swift` 2.54.1 only |
| Resolved transitives | swift-clocks 1.1.0, swift-http-types 1.6.0, swift-crypto 4.5.1, swift-concurrency-extras 1.4.1, swift-asn1 1.7.1, xctest-dynamic-overlay 1.11.0 |
| Build | `xcodebuild -project SkyKid.xcodeproj -scheme SkyKid -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` → succeeded |
| Tests | Same destination with `test` → 161 tests, 0 failures, test duration about 2.8 s |
| Test artifact | `/Users/northarion/Library/Developer/Xcode/DerivedData/SkyKid-dkdeulmagiidrpffbxkdtxwyitni/Logs/Test/Test-SkyKid-2026.09.06_02-51-07-+0500.xcresult` |
| Release gate | `scripts/validate-clinical-release.sh`; clinical status is pending and scope is 0–12 months. It must not be bypassed. |

The first sandboxed Xcode invocation could not access normal Xcode caches; the same exact commands were rerun with approved host access. The successful results above are real, not inferred.

## B. Verified findings

Line numbers below are evidence pointers for this commit, not durable API references.

| Finding | Status | Files | Evidence | Risk |
|---|---|---|---|---|
| Root composition is oversized and cross-layer | Confirmed | `App/ContentView.swift` | 550 lines combine session restore, auth, sync, family observers, location, weather, five-tab navigation, walk setup/completion | High blast radius |
| Five tabs conflict with target three-tab product | Confirmed, with changed detail | `ContentView.swift` | Weather, Assistant, Walk, History, Profile are separate tabs. There is no current radar/map tab. | Medium UX complexity |
| Auth blocks the lightweight first-result flow | Confirmed with nuance | `ContentView.swift`, `Features/Auth/AuthGateView.swift` | Auth gate precedes profile/recommendation, although “continue without account” means login is not technically mandatory | High activation friction |
| Location permission is mandatory | Confirmed | `ContentView.swift`, `App/PermissionView.swift`, `App/DeniedView.swift`, `Core/Location/LocationManager.swift` | Denial routes to settings-only dead end; no manual city/location model | High availability/UX |
| Supabase is a deep production dependency | Confirmed | `project.pbxproj`, `Package.resolved`, `Core/Auth/*`, `Core/Sync/*`, profile/walk UI, stores | Auth, family, remote profile/history, live walk and 24-target build graph are connected to Supabase | High architecture/operating cost |
| Local mutations hide network side effects | Confirmed | `ChildProfileStore.swift`, `WalkLogStore.swift`, `ActiveWalkStore.swift` | Profile setter and walk mutations trigger sync/publish through concrete Supabase collaborators | High determinism/testability |
| Signing out can erase local data | Confirmed | `SupabaseAuthService.swift` | Sign-out path clears local profile and walk logs | High data loss during removal |
| Child identity is name + birthday | Confirmed | `ChildProfile.swift`, `ChildThermalProfile.swift`, `PersonalOffsetStore.swift:180` | No UUID; normalized name plus birthday timestamp is the personalization key | P0 migration/collision |
| Temperature preference UI is illusory | Confirmed | `ChildProfileSetupView.swift`, `ProfileSummaryView.swift`, `ChildThermalProfile.swift` | Value persists/appears/syncs, but searches find no consumption by the current TOG recommendation pipeline | High trust/product correctness |
| Long walks reuse a negative errands delta | Confirmed | `TOGCalculator.swift:214`, `OutfitConfig.swift:123` | `.long` applies `errandsInOutDelta == -0.5`; no explicit long-walk regression test | P0 thermal correctness |
| Medical conditions apply numeric TOG deltas | Confirmed | `TOGCalculator.swift:199-255`, `OutfitConfig.swift:113-128`, `MedicalSafetyPolicy.swift` | Prematurity +0.5, fever -0.5, anemia +0.3 and other health/trait deltas exist. Fever also has a blocking safety rule, but calculation still occurs. | P0 medical positioning |
| Supported-age UI exceeds reviewed scope | Confirmed | `ChildProfileSetupView.swift:394`, `AgeSafetyPolicy.swift`, `clinical-review-status.plist` | UI accepts up to 18 years while clinical review scope is 0–12 months and pending | P0 safety scope |
| Walk start invents 12°C | Confirmed | `Features/Walk/WalkSetupSheet.swift:94-110` | Missing temperature/apparent temperature falls back to 12 | P0 data integrity |
| Historical manual logs use present context | Confirmed | `Features/History/LogWalkSheet.swift:17,68,75-105` | Default 12°C and current weather/microclimate/context/target TOG can be attached to a past walk | P0 training contamination |
| Every saved walk may train personalization | Confirmed | `WalkLogStore.swift:84-116` | Defaults fill missing context; neither manual origin nor weather provenance gates training | P0 model integrity |
| Outfit-screen feedback trains without a walk | Confirmed | `OutfitViewModel.swift:73-95`, `OutfitFeedbackSection.swift` | `.outfitScreen` observations directly enter thermal personalization | P0 model integrity |
| Current personalization is already conservative | Changed from a broad “unsafe learner” assumption | `PersonalizationEngine.swift`, `PersonalizationModels.swift` | Requires repeated directional signals, 4-hour independence, bounded ±1 offset, 0.2 steps, 120-day/80-item limits | Keep strengths; input quality remains high risk |
| Post-walk feedback is too rigid and too detailed elsewhere | Confirmed | `ComfortLevelSheet.swift`, `ActiveWalkStore.swift`, `WalkCompletionView.swift` | Finish requires one of four comfort levels and lacks not-sure/skip plus simple clothing-change question | Medium UX/data bias |
| Walk UI is an event journal | Confirmed | `ActiveWalkView.swift`, `WalkQuickActionsCard.swift`, `WalkTimelineCard.swift`, history event editing, Live Activity intents | Sleep, bassinet, checkpoint, editable/reclassifiable timeline are primary UI | High product drift |
| Active walk is persisted across relaunch | Changed: concern already addressed | `ActiveWalkStore.swift`, `ActiveWalk.swift`, `WalkLiveActivityController.swift` | Codable active walk in App Group is loaded on init and Live Activity is reattached | Keep; test harder |
| Duplicate active walk protection is authoritative | Not confirmed | `ActiveWalkStore.swift` | `start` overwrites current state; UI interception is not a store invariant | Medium state loss |
| Duration survives timezone/DST changes | Partially confirmed | `ActiveWalk.swift`, `ActiveWalkStore.swift` | Absolute `Date` subtraction handles timezone/DST display changes; manual clock rollback is only clamped, not modeled | Low/medium edge case |
| Weather provenance is complete | Not confirmed | `RawWeatherObservation.swift`, `NormalizedWeather.swift`, `ActiveWalk.swift`, `WalkLog.swift` | Normalized data tracks provider/field status, but captured-at/freshness/origin/eligibility do not cross into walk records | P0 data integrity |
| Normalizer invents missing core temperature | Not confirmed | `WeatherNormalizer.swift`, `WeatherNormalizerTests.swift` | Missing core temperature is rejected and regression-tested | Existing safeguard |
| Secondary weather fallbacks exist | Confirmed with nuance | `WeatherNormalizer.swift`, `NormalizedWeather.swift` | Conservative humidity/wind/precipitation/UV fallbacks retain field status, but derived values can still reach calculation/training | Medium eligibility risk |
| Freshness is absent | Changed: fragmented rather than absent | `WeatherFreshness.swift`, `WeatherViewModel.swift`, `RecommendationSnapshotStore.swift`, widget/provider | 2-hour rules exist in several places; in-memory outfit can remain visibly “current” after expiry | High stale recommendation |
| Weather failure is clearly surfaced | Not confirmed | `WeatherView.swift`, `WeatherViewModel.swift` | Error may retain old data; nil-weather branch can show indefinite progress; cache is not a coherent main-screen fallback | High availability/trust |
| Consumer can choose weather provider/API keys | Confirmed | `WeatherView.swift`, `ProviderPickerView.swift`, `WeatherServiceSettings.swift` | Provider picker is in production toolbar | Medium product complexity |
| WeatherKit is production-ready | Not confirmed | `WeatherKitService.swift`, entitlements | It delegates to Open-Meteo; returned source remains Open-Meteo, so it does not falsely label Apple data, but selected-provider UI can disagree | Medium future integration |
| Weather providers receive child/private history | Not confirmed | `Core/Network/*` | Requests use coordinates and provider credentials only; child data goes to Supabase, not weather APIs | Privacy boundary currently good |
| TOG is visible to consumers | Confirmed | active-walk cards, garment previews, Live Activity widget, feedback copy | Current/target/garment TOG values appear in consumer surfaces | High false precision |
| Every named TOG component is live | Changed | `OutfitCalculationDetailsCard.swift`, `OutfitFitCard.swift`, `PersonalizationStatusCard.swift` | These compile but have no production call site; main Outfit screen no longer shows them | Cleanup candidate only |
| Wardrobe starts as “everything owned” | Confirmed | `UserWardrobeStore.swift` | Missing state seeds all garment IDs and later catalog additions can be auto-owned | High recommendation honesty |
| Solver cannot handle missing garments | Not confirmed | `OutfitSolver.swift`, `WardrobeAlternativesCard.swift`, solver tests | Restricted wardrobe supports unavailable items, closest result, and alternatives | Preserve behavior |
| Walk-window logic is sufficient | Not confirmed | `WeatherSafetyPolicy.swift:176-205` | Private two-slot search uses apparent temperature and rain probability only, `Date()` internally, no wind/gust/UV/freshness/reasons/score | Medium misleading guidance |
| UV advice is contextual | Not confirmed | `WeatherSafetyPolicy.swift`, `OutfitConfig.swift` | Uses measured UV thresholds but copy contains fixed 10:00–16:00 interval; clinical review flags this | High safety copy |
| Dense stroller sun-cover warning exists | Not confirmed | safety policies/copy | Rain-cover ventilation exists, but no explicit dense blanket/sun-cover ventilation guidance | Medium safety gap |
| AQI exists | Not confirmed | weather/domain sources | No AQI model/provider/policy; appropriate P2 defer | Low current scope |
| Car-seat guidance is missing | Not confirmed | `TransportSafetyPolicy.swift` | Existing warning correctly favors thin layers and blanket over fastened straps | Preserve/refine |
| Live Activity requires backend | Not confirmed | `WalkLiveActivityController.swift`, widget Live Activity | ActivityKit experience is local; remote family publishing is a separable layer | Preserve local feature |
| Backup/export exists | Not confirmed | storage/profile sources | No versioned export/import/validation service | High post-cloud data durability |
| Share-outfit alternative exists | Not confirmed | profile/outfit sources | Only family invite uses ShareLink; no recommendation share model | P1 convenience |
| Delete-all-local-data exists | Not confirmed | stores/profile UI | Walks-only clear and account sign-out do not atomically clear all local domains | High privacy/control |
| Recommendation algorithm is versioned | Not confirmed | `WalkLog.swift`, `OutfitRecommendationSnapshot.swift` | Schema versions exist, algorithm version does not | High history interpretability |
| Methodology/intended-purpose UI exists | Not confirmed | docs/profile UI | Safety docs exist; no consumer methodology screen | Medium transparency |
| History centers learning | Not confirmed | `WalkHistoryView.swift`, `WalkHistoryInsights.swift` | Current summaries emphasize count, duration, sleep, and comfort percentage | Medium product value |
| Map/radar is a current feature | Changed: stale documentation | `docs/project-map.md`, `docs/architecture.md` | Tracked production tree contains no Map/RainViewer files despite older docs/AGENTS map | Documentation risk |
| Old wardrobe constructor is active | Changed | `LegacyWardrobeAutoSelector.swift`, tests | Selector is test-referenced only; old WardrobeModel/calculator UI are absent | Late cleanup candidate |
| `WeatherData` can be deleted wholesale | Not confirmed | `WeatherData.swift`, `NormalizedWeather.swift` | Legacy presentation bridge and shared hourly/precip/radar types still depend on it | Migration required first |
| Safety infrastructure is expendable | Not confirmed | `docs/safety.md`, `docs/clinical-review.md`, status plist, release script | Review digest and release gate are intentional and must remain | Critical invariant |
| StoreKit/paywall exists | Not confirmed | project search | No StoreKit product or paywall; it is correctly deferred until core stability | P2 hypothesis |
| Ads, analytics, or AI SDKs exist | Not confirmed | dependencies/project search | None found | Keep absent |
| Localization/accessibility infrastructure exists | Confirmed with gaps | `L10n.swift`, five localization folders, `docs/accessibility.md` | Infrastructure and some accessible components exist; many hardcoded Russian strings remain | Preserve; incremental remediation |

## C. Current architecture map

```text
SkyKidApp
  └─ ContentView (composition + routing + orchestration)
      ├─ Supabase session/auth gate
      ├─ profile onboarding
      ├─ mandatory CLLocation permission
      └─ TabView (Weather / Assistant / Walk / History / Profile)

Weather provider adapters → RawWeatherObservation → WeatherNormalizer
  → NormalizedWeather → WeatherViewModel
  → BuildOutfitRecommendationUseCase
      → EffectiveTemperatureCalculator → MicroclimateCalculator
      → TOGCalculator → OutfitSolver
      → SafetyRulesEngine (age/medical/weather/transport/comfort policies)
      → OutfitRecommendation + RecommendationSnapshot

WalkSetupSheet → ActiveWalkStore → ActiveWalk (App Group UserDefaults)
  → event journal + ActivityKit + Supabase live publisher
  → finish → WalkLogStore → WalkLog (App Group UserDefaults)
      → PersonalizationEngine / PersonalOffsetStore
      → Supabase history sync

ChildProfileStore / UserWardrobeStore / PersonalOffsetStore /
WalkLogStore / ActiveWalkStore / RecommendationSnapshotStore
  → App Group UserDefaults

SupabaseAuthService + SupabaseSyncService + live observer/publisher
  → auth, remote profile, family membership, history, remote active walk

RecommendationSnapshotStore → Widget + Siri App Intent
ActiveWalkStore/ActivityKit → Live Activity widget and quick-mark intents
```

Notable boundaries:

- The calculation pipeline is already decomposed into deterministic calculators/policies and should be evolved, not replaced.
- `ContentView` is the composition bottleneck.
- Stores conflate local persistence with remote side effects.
- `NormalizedWeather` is useful but not a durable walk-time provenance record.
- App Group storage already supports app/widget sharing and active-walk restoration.

## D. Target architecture

Use lightweight constructor composition and protocol boundaries; do not add a framework.

```text
SkyKidApp → AppComposition
  └─ RootFlow
      ├─ LightweightOnboarding (birthday + current/manual location)
      └─ MainTabView
          ├─ TodayFeature
          │   ├─ weather summary + freshness
          │   ├─ recommendation + context + reason + one useful item
          │   ├─ optional walk-window guidance
          │   └─ inline ActiveWalkState / start CTA
          ├─ LearningHistoryFeature
          └─ ProfileFeature

LocationSelectionStore: currentLocation | manualCity(geocoded coordinate)
WeatherRepository: WeatherService → NormalizedWeather → WeatherSnapshot
RecommendationUseCase: existing deterministic thermal pipeline
WalkRepository: exactly one durable active walk + completed records
PersonalizationRepository: eligible tracked observations only
LocalBackupService: versioned aggregate export/import/validation
LocalDataResetService: explicit atomic domain reset
ShareOutfitComposer: pure share text/model

Widget/Siri ← versioned fresh RecommendationSnapshot
Local ActivityKit ← active walk; no remote account/family dependency
```

Minimal new domain contracts:

- `ChildProfile.id: UUID`, generated once and migrated from legacy storage.
- `WeatherSnapshot`: captured-at, provider, core/optional values, field quality, freshness classification; no synthetic values.
- `WalkOrigin`: tracked or manual; manual v1 is never personalization-eligible.
- Explicit `PersonalizationEligibility` with auditable exclusion reasons, computed rather than user-editable.
- `recommendationAlgorithmVersion` on recommendation and recorded walk context.
- `ClothingAdjustment`: none, removedLayer, addedLayer, unknown; comfort adds unsure/skip.
- `LocationSelection`: current coordinate or persisted manually selected city.

## E. Removal map

| Action | Scope | Timing/condition |
|---|---|---|
| Remove | Supabase auth/sync/live-walk services, family models/UI, auth gate, SQL directory, package product/dependency, auth/sync tests | Only after stores are local-only and local data semantics are regression-tested |
| Remove | Consumer temperature-preference slider and display | Preserve decode/migration compatibility for legacy payloads until migration policy is proven |
| Hide/remove from consumer UI | Provider/API-key picker and all TOG numbers | Provider diagnostics may remain under `#if DEBUG` |
| Remove from primary walk UI | checkpoint, bassinet actions, sleep journal, editable event timeline/reclassification | Preserve old model decoding until existing records migrate; local ActivityKit remains |
| Rewrite | Startup/location flow, five-tab shell, Today composition, feedback flow, history purpose, wardrobe discovery, walk-window logic | Incrementally, without replacing calculation engine |
| Keep | WeatherService abstraction, normalizer core-temperature rejection, deterministic outfit calculators/solver, safety policy orchestration, car-seat guidance | Strengthen tests and boundaries |
| Keep | App Group local storage, single-child scope, widget/Siri snapshot, local active-walk persistence, local Live Activity | Add versioning/freshness and state invariants |
| Keep and improve | Safety docs, clinical review packet/status, release gate, localization and accessibility conventions | Required for each safety-facing phase |
| Migrate before delete | Event models, legacy `WeatherData` bridge/shared types, legacy profile/offset keys | Delete only after call-site and decoding audits |
| Defer | Production WeatherKit entitlement, AQI, StoreKit Lifetime, advanced charts/planning/multi-child | P2; not core-refactor blockers |
| Do not build | Account, cloud/family realtime, ads, analytics SDK, AI chat, GPS routes, sleep tracker, required outing journal | Product invariant |

## F. Dependency graph and removal order

### Supabase graph

```text
Package: supabase-swift
  ├─ SupabaseClientProvider / SupabaseConfig
  │   ├─ SupabaseAuthService
  │   │   ├─ AuthGateView
  │   │   ├─ AccountCard
  │   │   └─ ContentView session routing
  │   └─ SupabaseSyncService
  │       ├─ ChildProfileStore hidden push
  │       ├─ WalkLogStore push/delete/pull
  │       ├─ FamilyCard / FamilyMember / invites
  │       └─ LiveWalkObserver + LiveWalkPublisher
  │           ├─ ActiveWalkStore hidden publish
  │           ├─ ContentView observer lifecycle
  │           ├─ LiveWalkDetailView / footer
  │           └─ remote notification preferences/content
  └─ package transitives
```

Ordered removal:

1. Land identity/provenance migrations and local-store regression coverage; never use sign-out as a data migration.
2. Make `ChildProfileStore`, `WalkLogStore`, and `ActiveWalkStore` deterministic local-only stores; remove concrete sync/publisher injections and hidden effects.
3. Remove session-dependent startup routing and family/live-remote UI/orchestration while retaining local ActivityKit.
4. Delete unused auth/sync/family/remote-notification production types and their dedicated tests/SQL.
5. Remove the Xcode Supabase package product/dependency and resolve transitives.
6. Build app/widget and run the full test suite; search for `Supabase`, `family`, auth/session, remote-live symbols.
7. Perform dead-code/doc cleanup only after the build graph is package-free.

### Phase dependency graph

```text
Phase 0 baseline
  → Phase 1 correctness/safety foundation
      → Phase 2 local-only removal
      → Phase 4 location/weather
      → Phase 6 walk simplification
          → Phase 7 personalization
              → Phase 8 learning history
      → Phase 3 information architecture → Phase 5 outfit UX
      → Phase 9 wardrobe
      → Phase 10 walk-window guidance
  → Phases 3–10 converge
      → Phase 11 backup/export/share
      → Phase 13 docs/cleanup/release review
  → Phase 12 business hypotheses only after core stabilization
```

## G. Ordered phase plan

| Phase | Outcome | Tickets | Gate |
|---|---|---|---|
| 0. Baseline and verified audit | This document, clean baseline, risks and dependency map | Planning complete | Canonical plan reviewed; no production change |
| 1. Correctness and safety P0 | Stable identity, honest weather/training provenance, explicit semantics/scope/version | SKY-001–SKY-010 | Astra architecture/safety review; all focused + full tests |
| 2. Local-only architecture | Deterministic stores and complete Supabase/account/family removal | SKY-011–SKY-013 | No Supabase symbol/package; local data preserved; full build/tests |
| 3. Information architecture | Root composition and Today/History/Profile navigation | SKY-014–SKY-015 | Three-tab smoke/accessibility review; no calculation change |
| 4. Location and weather | Manual city, coherent cache/failure flow, developer-only providers | SKY-016–SKY-017 | Location denial is usable; freshness states tested |
| 5. Outfit UX | Human recommendation with no consumer TOG precision | SKY-018 | Snapshot/widget consistency and presentation tests |
| 6. Walk simplification | Passive durable active walk and seconds-long post-walk flow | SKY-019–SKY-020 | Restore/duplicate/background tests; zero-input journey verified |
| 7. Thermal fingerprint | Conservative, eligible, explainable deterministic similarity | SKY-021 | Astra review; bounded/reversible tests |
| 8. History insights | “What SkyKid learned” replaces sleep-heavy metrics | SKY-022 | Honest insufficient-data states; no false precision |
| 9. Progressive wardrobe | Unknown ownership, natural yes/no discovery, substitutions | SKY-023 | Solver remains honest for all availability states |
| 10. Walk window and contextual guidance | Testable score/reasons, contextual UV and stroller ventilation | SKY-024 | Safety copy/clinical digest review |
| 11. Local durability and sharing | Versioned backup, reset, and backend-free sharing | SKY-025–SKY-027 | Roundtrip/corruption/future-version/destructive confirmation tests |
| 12. Deferred product hypotheses | WeatherKit, AQI seam, Lifetime Plus | SKY-028–SKY-030 | Separate business/privacy/entitlement approval; no core paywall |
| 13. Final cleanup and transparency | Dead code, methodology/legal/privacy/accessibility/localization/docs alignment | SKY-031–SKY-032 | Full tests/build; clinical status remains enforced |

At every phase gate: review `git diff`, verify only ticket-whitelisted files changed, run focused tests and the full suite, update architecture/safety docs affected by behavior, and stop on unexplained regressions.

## H. Atomic tickets

Whitelist aliases used below are exact file sets, not open-ended directory permission:

- **APP_COPY:** `SkyKid/Core/Localization/L10n.swift`; `SkyKid/Resources/en.lproj/Localizable.strings`; `SkyKid/Resources/fr.lproj/Localizable.strings`; `SkyKid/Resources/kk.lproj/Localizable.strings`; `SkyKid/Resources/ru.lproj/Localizable.strings`; `SkyKid/Resources/zh-Hans.lproj/Localizable.strings`.
- **WIDGET_COPY:** `SkyKidWidget/en.lproj/Localizable.strings`; `SkyKidWidget/fr.lproj/Localizable.strings`; `SkyKidWidget/kk.lproj/Localizable.strings`; `SkyKidWidget/ru.lproj/Localizable.strings`; `SkyKidWidget/zh-Hans.lproj/Localizable.strings`.
- **CLINICAL_REVIEW_SET:** `docs/clinical-review.md`; `docs/clinical-review-status.plist`; `scripts/validate-clinical-release.sh`. The script may be read and run, but changed only when the established digest format itself legitimately changes; status may never be marked approved without real external sign-off.
- **XCODE_PROJECT:** `SkyKid.xcodeproj/project.pbxproj`; `SkyKid.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

No wildcard or phrase in `Files possibly relevant` authorizes edits. It identifies read-only discovery candidates. A newly discovered edit must first be added to `Files allowed` with a ticket-plan amendment.

### SKY-001 — Stable child UUID

- **ID:** SKY-001
- **Priority:** P0
- **Goal:** Give the single local child a stable UUID and migrate personalization identity without losing rename history.
- **Why:** Name + birthday changes/collides and can orphan or merge learned history.
- **Files allowed:** `SkyKid/Core/Models/ChildProfile.swift`; `SkyKid/Core/Models/ChildProfileStore.swift`; `SkyKid/Core/Models/PersonalOffsetStore.swift`; `SkyKidTests/PersonalizationTests.swift`; `docs/models.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/ChildThermalProfile.swift`; `SkyKid/Core/Storage/RecommendationSnapshotStore.swift`; `SkyKidTests/BackgroundScenarioTests.swift`.
- **Do not touch:** UI, TOG formulas, Supabase removal, multi-child UI.
- **Current behavior:** Personalization key is derived from normalized name and birthday; profile has no UUID.
- **Target behavior:** UUID is generated once for legacy/current profile, survives encode/decode and rename, and is the only new personalization identity; legacy observations migrate exactly once.
- **Invariants:** No profile/history loss; deterministic idempotent migration; one-child v1; legacy decode remains supported.
- **Implementation notes:** Design migration before code; retain legacy-key lookup only as a migration input, never ongoing identity.
- **Tests required:** Legacy profile gets UUID; UUID persists; rename retains observations; distinct legacy identities do not collide; repeated migration is idempotent.
- **Acceptance criteria:** Tests prove all cases; existing stored profile loads; no display behavior changes; full suite passes.
- **Dependencies:** None.
- **Recommended model:** Astra design/review → Luna high implementation → Astra phase review.
- **Context pack:** Product invariants; findings on identity; `docs/models.md`; allowed/possibly relevant files only.
- **Estimated risk:** high.

### SKY-002 — Durable weather provenance model

- **ID:** SKY-002
- **Priority:** P0
- **Goal:** Introduce one versioned weather snapshot/provenance value used at the recommendation and walk boundary.
- **Why:** Provider/status exists during normalization but captured-at, freshness, and eligibility evidence are lost in persisted walks.
- **Files allowed:** `SkyKid/Core/Models/WeatherSnapshot.swift` (new); `SkyKid/Core/Models/NormalizedWeather.swift`; `SkyKid/Core/Models/ActiveWalk.swift`; `SkyKid/Core/Models/WalkLog.swift`; `SkyKidTests/WeatherNormalizerTests.swift`; `SkyKidTests/LiveWalkTests.swift`; `docs/models.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/RawWeatherObservation.swift`; `SkyKid/Core/Models/WeatherData.swift`; `SkyKid/Features/Weather/WeatherFreshness.swift`; `SkyKidTests/BackgroundScenarioTests.swift`.
- **Do not touch:** Provider implementations, UI, personalization rules, Supabase.
- **Current behavior:** Walks persist scalar temperatures and weather code without provider/captured-at/freshness/quality.
- **Target behavior:** Optional immutable snapshot preserves captured-at, provider, required/optional measurements, field quality, and freshness input; legacy walks decode with nil provenance.
- **Invariants:** Missing core temperature cannot create a valid snapshot; optional fields remain optional/qualified; no arbitrary defaults; Codable migration is backward-compatible.
- **Implementation notes:** Prefer a domain value independent of network DTOs; freshness classification may be computed with injected `now`.
- **Tests required:** Complete/partial snapshot; missing core rejection; legacy walk decode; roundtrip; deterministic freshness boundary.
- **Acceptance criteria:** Both active/completed walk models can preserve provenance; old payload fixtures decode; no provider behavior changes; full suite passes.
- **Dependencies:** SKY-001 may run in parallel; design must precede SKY-003/004/009.
- **Recommended model:** Astra design/review → Luna high implementation.
- **Context pack:** Sections B–D weather map; `docs/api.md`; `docs/models.md`; listed files.
- **Estimated risk:** high.

### SKY-003 — Eliminate synthetic walk weather

- **ID:** SKY-003
- **Priority:** P0
- **Goal:** Remove 12°C and current-context fallbacks from tracked and manually logged walks.
- **Why:** Invented weather creates false recommendations and corrupts training.
- **Files allowed:** `SkyKid/Features/Walk/WalkSetupSheet.swift`; `SkyKid/Features/History/LogWalkSheet.swift`; `SkyKid/Core/Storage/ActiveWalkStore.swift`; `SkyKid/Core/Models/ActiveWalk.swift`; `SkyKid/Core/Models/WalkLog.swift`; `SkyKidTests/WalkFlowPresentationTests.swift`; `SkyKidTests/LiveWalkTests.swift`.
- **Files possibly relevant:** `SkyKid/Core/Models/WeatherSnapshot.swift`; `SkyKid/Core/Storage/WalkLogStore.swift`; `SkyKid/Features/Walk/Components/WalkWeatherSnapshotCard.swift`; `SkyKid/Features/History/Components/WalkTemperatureCard.swift`.
- **Do not touch:** Normalizer fallback policy, TOG formulas, historical weather API, broad walk UI cleanup.
- **Current behavior:** Missing walk-start weather and manual logs can receive 12°C/current weather/current recommendation context.
- **Target behavior:** Walk timer/logging works with nil weather; manual records never borrow present context; UI labels unknown honestly.
- **Invariants:** No forced network; walk can start offline; no synthetic core weather; old walks still render.
- **Implementation notes:** Keep the change narrow; eligibility is finalized in SKY-004.
- **Tests required:** Start with nil weather; manual log with nil context; no serialized 12 fallback; legacy render.
- **Acceptance criteria:** Searches find no arbitrary walk weather fallback; both flows complete offline; focused/full tests pass.
- **Dependencies:** SKY-002.
- **Recommended model:** Luna high; Astra reviews Phase 1 aggregate.
- **Context pack:** Findings fake/manual weather; SKY-002 model contract; allowed files.
- **Estimated risk:** high.

### SKY-004 — Walk origin and personalization eligibility

- **ID:** SKY-004
- **Priority:** P0
- **Goal:** Make training eligibility explicit so only valid tracked walks create thermal observations.
- **Why:** Manual and context-poor walks currently train after default substitution.
- **Files allowed:** `SkyKid/Core/Models/WalkLog.swift`; `SkyKid/Core/Models/PersonalizationModels.swift`; `SkyKid/Core/Storage/WalkLogStore.swift`; `SkyKid/Core/Models/PersonalizationEngine.swift`; `SkyKidTests/PersonalizationTests.swift`; `SkyKidTests/WalkSummaryTests.swift`; `docs/models.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/WeatherSnapshot.swift`; `SkyKid/Core/Models/ActiveWalk.swift`; `SkyKid/Core/Models/OutfitFeedback.swift`.
- **Do not touch:** Similarity algorithm, history UI, backup, Supabase removal.
- **Current behavior:** All added/updated walks can train; missing context is defaulted; origin is only loosely represented by `isLiveTracked`.
- **Target behavior:** Codable origin and computed eligibility/exclusion reason are auditable; manual v1 and invalid/stale/unknown provenance never train; tracked valid snapshots may train.
- **Invariants:** Manual records remain in history; eligibility cannot be toggled by UI; re-save cannot duplicate observations; legacy walks default ineligible unless evidence is sufficient.
- **Implementation notes:** Centralize policy in a pure evaluator and avoid stored booleans that can drift from evidence.
- **Tests required:** Manual history yes/training no; tracked valid training yes; unknown/stale no; update/delete synchronization; legacy conservative behavior.
- **Acceptance criteria:** Observation creation has one gate; no context defaults in training mapper; exclusion reason is testable; full suite passes.
- **Dependencies:** SKY-001–SKY-003.
- **Recommended model:** Astra design/review → Luna high implementation.
- **Context pack:** Product data levels; findings on manual training; `docs/algorithms.md`; listed files.
- **Estimated risk:** high.

### SKY-005 — Feedback provenance and training boundary

- **ID:** SKY-005
- **Priority:** P0
- **Goal:** Prevent recommendation-screen opinions from modifying thermal personalization.
- **Why:** A user can currently train “hot/cold” from home without a real walk.
- **Files allowed:** `SkyKid/Features/Outfit/OutfitViewModel.swift`; `SkyKid/Features/Outfit/Components/OutfitFeedbackSection.swift`; `SkyKid/Core/Models/OutfitFeedback.swift`; `SkyKid/Core/Models/PersonalizationModels.swift`; `SkyKidTests/PersonalizationTests.swift`; `SkyKidTests/OutfitPresentationTests.swift`.
- **Files possibly relevant:** `SkyKid/Core/Storage/WalkLogStore.swift`; `SkyKid/Features/Outfit/OutfitView.swift`; APP_COPY.
- **Do not touch:** Post-walk UI redesign, similarity, solver, TOG values.
- **Current behavior:** `.outfitScreen` comfort feedback directly creates personalization observations.
- **Target behavior:** Thermal feedback originates only from eligible tracked walks; optional recommendation usefulness feedback is separate and non-training, or hidden until separately designed.
- **Invariants:** Existing eligible observations remain; no fake walk creation; copy does not imply medical learning.
- **Implementation notes:** Remove source cases only with decode migration; a distinct product-feedback model need not be persisted in v1.
- **Tests required:** Outfit screen produces no thermal observation; eligible tracked walk does; legacy source decode is harmless.
- **Acceptance criteria:** No UI action outside a completed eligible walk changes thermal offset; full suite passes.
- **Dependencies:** SKY-004.
- **Recommended model:** Luna high with Astra Phase 1 review.
- **Context pack:** Feedback provenance finding; product levels 2/3; listed files.
- **Estimated risk:** high.

### SKY-006 — Long-walk semantics regression

- **ID:** SKY-006
- **Priority:** P0
- **Goal:** Define and implement clinically reviewed long-walk thermal semantics without reusing errands behavior.
- **Why:** `.long` currently subtracts 0.5 TOG through an unrelated legacy constant.
- **Files allowed:** `SkyKid/Features/Outfit/TOGCalculator.swift`; `SkyKid/Features/Outfit/OutfitConfig.swift`; `SkyKidTests/OutfitCalculatorTests.swift`; `docs/algorithms.md`; `docs/clinical-review.md`; `docs/clinical-review-status.plist` only through the established digest workflow.
- **Files possibly relevant:** `SkyKid/Core/Models/WalkContext.swift`; `SkyKidTests/SafetyPolicyTests.swift`; `scripts/validate-clinical-release.sh`.
- **Do not touch:** Other TOG constants, UI, personalization, safety release bypass.
- **Current behavior:** Long walk applies `errandsInOutDelta = -0.5`; semantic intent is untested.
- **Target behavior:** A separately named, documented behavior is selected from evidence/review; no accidental negative reuse.
- **Invariants:** Do not guess by flipping sign; deterministic monotonic tests cover regular vs long; release remains blocked pending valid external review.
- **Implementation notes:** First add a failing characterization/regression test, then implement the reviewed rule; algorithm version bump is SKY-010.
- **Tests required:** Regular/long comparison across representative contexts; errands stays independent; boundary cases.
- **Acceptance criteria:** No `.long` reference to errands constant; semantics documented/reviewed; focused/full tests pass.
- **Dependencies:** Astra decision; coordinate with SKY-010.
- **Recommended model:** Astra safety design → Luna high implementation → Astra diff review.
- **Context pack:** Finding long walk; `docs/algorithms.md`, `docs/safety.md`, clinical packet; listed files.
- **Estimated risk:** high.

### SKY-007 — Remove medical numeric adaptation

- **ID:** SKY-007
- **Priority:** P0
- **Goal:** Replace unverified diagnosis/prematurity/fever TOG arithmetic with explicit recommendation limitations and safety gates.
- **Why:** Numeric medical adjustments imply unsupported medical precision beyond current review scope.
- **Files allowed:** `SkyKid/Features/Outfit/TOGCalculator.swift`; `SkyKid/Features/Outfit/OutfitConfig.swift`; `SkyKid/Features/Outfit/MedicalSafetyPolicy.swift`; `SkyKid/Features/Outfit/SafetyRulesEngine.swift`; `SkyKid/Features/Outfit/OutfitOutputModels.swift`; `SkyKidTests/OutfitCalculatorTests.swift`; `SkyKidTests/SafetyPolicyTests.swift`; `docs/algorithms.md`; `docs/safety.md`; CLINICAL_REVIEW_SET.
- **Files possibly relevant:** `SkyKid/Core/Models/ChildThermalProfile.swift`; `SkyKid/Features/Profile/ChildProfileSetupView.swift`; `SkyKid/Features/Outfit/Components/OutfitBlockedScenarioView.swift`; APP_COPY.
- **Do not touch:** General weather/transport calculations, medical diagnosis UI expansion, release gate.
- **Current behavior:** Prematurity, fever, anemia, illness and thermal traits can add/subtract TOG; some cases also warn/block.
- **Target behavior:** Unreviewed medical states do not alter thermal arithmetic; policy either allows ordinary non-medical recommendation or clearly limits/blocks it with calm copy.
- **Invariants:** No diagnosis/treatment claim; user-provided states only; existing fever escalation copy is not weakened; safety output precedes consumer recommendation.
- **Implementation notes:** Separate stable non-medical preference traits from medical conditions; default conservatively when evidence is absent.
- **Tests required:** Each medical state has no silent numeric delta; blocking/limitation matrix; combined states; copy snapshot; normal profile unchanged.
- **Acceptance criteria:** Medical constant search finds no unreviewed arithmetic; policies are deterministic/documented; clinical workflow updated; tests pass.
- **Dependencies:** Coordinate with SKY-008 and SKY-010.
- **Recommended model:** Astra safety design/review → Luna high implementation → Astra diff review.
- **Context pack:** Medical findings; `docs/safety.md`, `docs/clinical-review.md`, `docs/algorithms.md`; exact files.
- **Estimated risk:** high.

### SKY-008 — Enforce supported age scope

- **ID:** SKY-008
- **Priority:** P0
- **Goal:** Align onboarding, editing, and runtime behavior with the externally reviewed 0–12-month v1 scope.
- **Why:** UI accepts up to 18 years while the current clinical package covers infants only.
- **Files allowed:** `SkyKid/Features/Profile/ChildProfileSetupView.swift`; `SkyKid/Features/Outfit/AgeSafetyPolicy.swift`; `SkyKid/App/ContentView.swift`; `SkyKidTests/SafetyPolicyTests.swift`; `SkyKidTests/BackgroundScenarioTests.swift`; APP_COPY; `docs/safety.md`; `docs/models.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/ChildThermalProfile.swift`; `SkyKid/Features/Profile/ProfileSummaryView.swift`; CLINICAL_REVIEW_SET.
- **Do not touch:** Age-expansion rules, multi-child, unrelated onboarding redesign.
- **Current behavior:** Date picker allows age through 18 and domain rules include toddler through teen.
- **Target behavior:** New/edited profile accepts reviewed ages only; existing out-of-scope profile loads safely and sees a limitation instead of unreviewed recommendation.
- **Invariants:** No crash/data deletion at birthday transition; exact upper-bound semantics are injectable/testable; do not claim clinical safety.
- **Implementation notes:** Centralize supported range in one domain policy; avoid duplicating calendar math in UI.
- **Tests required:** newborn/lower boundary; 12-month boundary; just over boundary; legacy older profile; birthday transition.
- **Acceptance criteria:** UI/domain use one range; out-of-range recommendation is blocked/limited consistently; full suite passes.
- **Dependencies:** SKY-007 policy direction.
- **Recommended model:** Astra safety checkpoint → Luna high implementation.
- **Context pack:** Supported-age finding; clinical scope/status; listed files.
- **Estimated risk:** high.

### SKY-009 — Central freshness and stale-recommendation gate

- **ID:** SKY-009
- **Priority:** P0
- **Goal:** Apply one freshness policy so stale data cannot masquerade as a current recommendation.
- **Why:** Multiple two-hour rules exist and the in-memory outfit may outlive them without transition.
- **Files allowed:** `SkyKid/Features/Weather/WeatherFreshness.swift`; `SkyKid/Features/Weather/WeatherViewModel.swift`; `SkyKid/Core/Storage/RecommendationSnapshotStore.swift`; `SkyKid/Core/Models/OutfitRecommendationSnapshot.swift`; `SkyKid/Features/Outfit/OutfitViewModel.swift`; `SkyKidWidget/ClothingStatusProvider.swift`; `SkyKidTests/BackgroundScenarioTests.swift`; `SkyKidTests/OutfitPresentationTests.swift`.
- **Files possibly relevant:** `SkyKid/Features/Weather/WeatherView.swift`; `SkyKid/App/ContentView.swift`; `SkyKidWidget/ClothingStatusWidgetView.swift`; `SkyKidWidget/WidgetClothingCalculator.swift`; `SkyKid/App/SkyKidIntents.swift`.
- **Do not touch:** Provider selection, manual location, thermal formulas.
- **Current behavior:** Fragmented 2-hour TTLs protect widget/Siri but not all live app presentation paths.
- **Target behavior:** One injected-clock policy classifies fresh/stale/unavailable and gates app/widget/Siri consistently; UI preserves stale metadata but does not issue a fresh-looking recommendation.
- **Invariants:** No fake refresh timestamp; partial optional fields need not block when core data is fresh; cached data age is visible.
- **Implementation notes:** Avoid wall-clock calls inside pure policy; keep threshold configurable in one place.
- **Tests required:** Before/at/after threshold; clock advance while screen remains open; app/widget/Siri parity; missing timestamp.
- **Acceptance criteria:** One threshold source; stale transition is observable; all surfaces agree; full suite passes.
- **Dependencies:** SKY-002.
- **Recommended model:** Astra design review → Luna high implementation.
- **Context pack:** Freshness finding; weather architecture sections; listed files.
- **Estimated risk:** high.

### SKY-010 — Recommendation algorithm versioning

- **ID:** SKY-010
- **Priority:** P0
- **Goal:** Persist a lightweight explicit algorithm version with recommendations and walk records.
- **Why:** Historical results otherwise appear calculated under current formulas after safety/thermal changes.
- **Files allowed:** `SkyKid/Core/Models/OutfitRecommendationSnapshot.swift`; `SkyKid/Core/Models/WalkLog.swift`; `SkyKid/Features/Outfit/BuildOutfitRecommendationUseCase.swift`; `SkyKid/Core/Storage/RecommendationSnapshotStore.swift`; `SkyKidTests/BackgroundScenarioTests.swift`; `SkyKidTests/OutfitCalculatorTests.swift`; `docs/algorithms.md`; `docs/models.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/ActiveWalk.swift`; `SkyKidWidget/WidgetClothingCalculator.swift`; `SkyKidWidget/ClothingStatusProvider.swift`; `SkyKid/App/SkyKidIntents.swift`.
- **Do not touch:** Formula changes, remote schema, marketing version.
- **Current behavior:** Storage schemas are versioned, recommendation behavior is not.
- **Target behavior:** One semantic/internal version constant is captured at calculation and copied into active/completed records; legacy value is explicitly unknown/legacy.
- **Invariants:** No distributed migration framework; old payload decode; widget/Siri continue to render.
- **Implementation notes:** Version only on behavior-changing releases; document bump protocol and coordinate SKY-006/007.
- **Tests required:** Capture/roundtrip; legacy decode; propagation through walk completion; version change fixture.
- **Acceptance criteria:** Every new logged recommendation has a version; no inference from app version; full suite passes.
- **Dependencies:** Design after SKY-006/007 decisions; can implement model earlier.
- **Recommended model:** Astra architecture review → Luna high implementation.
- **Context pack:** Versioning finding; `docs/algorithms.md`, `docs/models.md`; listed files.
- **Estimated risk:** medium-high.

### SKY-011 — Deterministic local stores

- **ID:** SKY-011
- **Priority:** P1
- **Goal:** Remove hidden remote side effects from profile, walk-log, and active-walk local mutations.
- **Why:** Local-first persistence must behave deterministically before cloud code can be deleted safely.
- **Files allowed:** `SkyKid/Core/Models/ChildProfileStore.swift`; `SkyKid/Core/Storage/WalkLogStore.swift`; `SkyKid/Core/Storage/ActiveWalkStore.swift`; `SkyKid/App/ContentView.swift`; `SkyKidTests/BackgroundScenarioTests.swift`; `SkyKidTests/LiveWalkTests.swift`; `SkyKidTests/PersonalizationTests.swift`.
- **Files possibly relevant:** `SkyKid/Core/Sync/SupabaseSyncService.swift`; `SkyKid/Core/Sync/LiveWalkPublisher.swift`; `SkyKid/Features/Walk/WalkSetupSheet.swift`; `SkyKid/Features/History/LogWalkSheet.swift`; `SkyKid/Features/Profile/ChildProfileSetupView.swift`.
- **Do not touch:** Delete Supabase files/package, redesign store technology, walk UI.
- **Current behavior:** Store writes can push/sync/publish remotely through concrete services.
- **Target behavior:** Stores synchronously/actor-safely mutate local persistence only; optional external orchestration has no store ownership and is removed next.
- **Invariants:** Existing local keys/data persist; personalization synchronization remains deterministic; local Live Activity stays functional.
- **Implementation notes:** Characterize local mutation before detaching; do not clear data on session changes.
- **Tests required:** Add/update/delete/profile write offline; no remote collaborator required; restart roundtrip; personalization sync.
- **Acceptance criteria:** Store initializers have no Supabase/publisher dependency; mutation tests pass; app builds before service deletion.
- **Dependencies:** Phase 1, especially SKY-001/004.
- **Recommended model:** Luna high with Astra Phase 2 checkpoint.
- **Context pack:** Supabase graph/order; local data invariant; listed stores/tests.
- **Estimated risk:** high.

### SKY-012 — Remove account, family, and remote-live product flows

- **ID:** SKY-012
- **Priority:** P1
- **Goal:** Make startup and profile/walk experience account-free while retaining local ActivityKit.
- **Why:** Auth/family/realtime are outside v1 and create activation, cost, and privacy complexity.
- **Files allowed:** `SkyKid/App/ContentView.swift`; `SkyKid/Features/Auth/AuthGateView.swift` (delete); `SkyKid/Features/Profile/Components/AccountCard.swift` (delete); `SkyKid/Features/Profile/Components/FamilyCard.swift` (delete); `SkyKid/Features/Profile/Components/FamilyMemberRow.swift` (delete); `SkyKid/Features/Profile/Components/JoinFamilySheet.swift` (delete); `SkyKid/Features/Profile/Components/LiveWalkNotificationsCard.swift` (delete); `SkyKid/Features/Walk/LiveWalkDetailView.swift` (delete); `SkyKid/Features/Walk/Components/LiveWalkStatusFooter.swift` (delete or local rewrite); `SkyKid/Core/Notifications/LiveWalkNotificationContent.swift` (delete if zero local call sites); `SkyKid/Core/Notifications/LiveWalkNotificationPreferences.swift` (delete if zero local call sites); `SkyKid/Core/Notifications/LiveWalkNotifier.swift` (delete if zero local call sites); APP_COPY; `SkyKidTests/AuthSyncTests.swift`; `SkyKidTests/ChildNameCipherTests.swift`; `SkyKidTests/LiveWalkTests.swift`.
- **Files possibly relevant:** `SkyKid/App/SkyKidApp.swift`; `SkyKid/Features/Profile/ProfileSummaryView.swift`; `SkyKid/Features/Walk/ActiveWalkView.swift`; `SkyKid/Features/Walk/WalkTabView.swift`; `SkyKid/Core/Auth/AuthPreferences.swift`; `SkyKid/Core/Auth/ChildNameCipher.swift`; `SkyKid/Core/Auth/SignInProvider.swift`; `SkyKid/Core/Auth/SupabaseAuthService.swift`; `SkyKid/Core/Auth/SupabaseClientProvider.swift`; `SkyKid/Core/Auth/SupabaseConfig.swift`; `SkyKid/Core/Sync/FamilyInviteCode.swift`; `SkyKid/Core/Sync/FamilyMember.swift`; `SkyKid/Core/Sync/LiveWalkObserver.swift`; `SkyKid/Core/Sync/LiveWalkPublisher.swift`; `SkyKid/Core/Sync/LiveWalkSnapshot.swift`; `SkyKid/Core/Sync/SupabaseSyncService+LiveWalk.swift`; `SkyKid/Core/Sync/SupabaseSyncService.swift`.
- **Do not touch:** Supabase package/services deletion (SKY-013), local active walk, local ActivityKit widget, backup.
- **Current behavior:** Auth gate, family cards/invites, remote live walk and notification settings are consumer flows.
- **Target behavior:** App opens to local onboarding/app; profile has no account/family surface; walk has no partner controls; local Live Activity still works.
- **Invariants:** Never call sign-out clearing logic; local profile/walks survive upgrade; no loss of notification service used for local safety reminders.
- **Implementation notes:** Prove each notification type’s ownership before deletion; update target membership through Xcode project.
- **Tests required:** Existing-user upgrade retains local data; fresh launch bypasses auth; local Live Activity; no remote UI snapshot/call site.
- **Acceptance criteria:** No account/family gate in UI; local data intact; app/widget build; tests pass.
- **Dependencies:** SKY-011.
- **Recommended model:** Luna high; Astra reviews phase boundary, not each deletion.
- **Context pack:** Removal map and Supabase graph; target startup; listed UI/orchestration.
- **Estimated risk:** high.

### SKY-013 — Remove Supabase implementation and package

- **ID:** SKY-013
- **Priority:** P1
- **Goal:** Delete unused backend code and remove `supabase-swift` from the build graph.
- **Why:** The local-only app should have no paid backend dependency or unused transitives.
- **Files allowed:** `SkyKid/Core/Auth/AuthPreferences.swift`; `SkyKid/Core/Auth/ChildNameCipher.swift`; `SkyKid/Core/Auth/SignInProvider.swift`; `SkyKid/Core/Auth/SupabaseAuthService.swift`; `SkyKid/Core/Auth/SupabaseClientProvider.swift`; `SkyKid/Core/Auth/SupabaseConfig.swift`; `SkyKid/Core/Sync/FamilyInviteCode.swift`; `SkyKid/Core/Sync/FamilyMember.swift`; `SkyKid/Core/Sync/LiveWalkObserver.swift`; `SkyKid/Core/Sync/LiveWalkPublisher.swift`; `SkyKid/Core/Sync/LiveWalkSnapshot.swift`; `SkyKid/Core/Sync/SupabaseSyncService+LiveWalk.swift`; `SkyKid/Core/Sync/SupabaseSyncService.swift`; `supabase/migrations/2026-08-04-family-sharing.sql`; `supabase/migrations/2026-08-16-family-member-identity.sql`; `supabase/migrations/2026-08-17-live-walks.sql`; `supabase/schema.sql`; XCODE_PROJECT; `SkyKidTests/AuthSyncTests.swift`; `SkyKidTests/ChildNameCipherTests.swift`; `SkyKidTests/KeychainStoreTests.swift`; `docs/api.md`; `docs/architecture.md`; `docs/project-map.md`.
- **Files possibly relevant:** `SkyKid/App/ContentView.swift`; `SkyKid/Core/Models/ChildProfileStore.swift`; `SkyKid/Core/Storage/WalkLogStore.swift`; `SkyKid/Core/Storage/ActiveWalkStore.swift`; `SkyKid/Core/Notifications/LiveWalkNotificationContent.swift`; `SkyKid/Core/Notifications/LiveWalkNotificationPreferences.swift`; `SkyKid/Core/Notifications/LiveWalkNotifier.swift`; `SkyKid/SkyKid.entitlements`; `SkyKidWidgetExtension.entitlements`.
- **Do not touch:** Local Keychain if still generally useful, weather APIs, local ActivityKit, unrelated packages/code.
- **Current behavior:** Supabase package and auth/sync services compile into production with transitive dependencies.
- **Target behavior:** No Supabase package product, import, symbol, SQL/backend artifact, or remote runtime path.
- **Invariants:** App Group/local persistence and existing user data remain; no replacement backend; full build/test succeeds.
- **Implementation notes:** Delete only after zero call-site search; edit project references narrowly; confirm resolved package graph.
- **Tests required:** Full test suite; app/widget build; launch smoke; repository searches for Supabase/auth/family/remote-live leftovers.
- **Acceptance criteria:** `xcodebuild -resolvePackageDependencies` has no Supabase; package transitives disappear; no production reference; 161-equivalent surviving suite green.
- **Dependencies:** SKY-011, SKY-012.
- **Recommended model:** Luna high; Luna xhigh only for unexpected project/package graph issue; Astra Phase 2 review.
- **Context pack:** Exact dependency graph/removal order; project package files; zero-call-site search results.
- **Estimated risk:** medium-high.

### SKY-014 — Root composition and three-tab shell

- **ID:** SKY-014
- **Priority:** P1
- **Goal:** Split root responsibilities and establish Today/History/Profile navigation without changing domain behavior.
- **Why:** `ContentView` couples unrelated lifecycle concerns and exposes five competing top-level tasks.
- **Files allowed:** `SkyKid/App/ContentView.swift`; `SkyKid/App/AppComposition.swift` (new); `SkyKid/App/RootFlow.swift` (new); `SkyKid/App/MainTabView.swift` (new); `SkyKid/App/SkyKidApp.swift`; `SkyKidTests/BackgroundScenarioTests.swift`; APP_COPY; `docs/architecture.md`.
- **Files possibly relevant:** `SkyKid/Features/Weather/WeatherView.swift`; `SkyKid/Features/Outfit/OutfitView.swift`; `SkyKid/Features/History/WalkHistoryView.swift`; `SkyKid/Features/Profile/ProfileSummaryView.swift`; `SkyKid/Features/Walk/WalkTabView.swift`; `SkyKid/Core/Models/ChildProfileStore.swift`; `SkyKid/Core/Storage/ActiveWalkStore.swift`; `SkyKid/App/Theme.swift`.
- **Do not touch:** Calculator/safety logic, feature internals, style system rewrite, DI dependency.
- **Current behavior:** One 550-line view owns startup, orchestration, and five tabs.
- **Target behavior:** Small explicit composition root, startup router, and three tabs; existing screens are temporarily embedded/adapted.
- **Invariants:** Same local state instances across tabs; onboarding and restored active walk work; no duplicate weather fetch; tab accessibility labels.
- **Implementation notes:** Extract by responsibility, not generic coordinator ceremony; use initializer/environment injection already idiomatic in project.
- **Tests required:** Root state matrix; three-tab selection; profile/no-profile; active-walk restoration smoke.
- **Acceptance criteria:** Three tabs only; `ContentView` is a thin entry adapter or removed; build/full tests pass.
- **Dependencies:** SKY-012, SKY-013.
- **Recommended model:** Astra architecture checkpoint → Luna high implementation.
- **Context pack:** Current/target architecture; `docs/architecture.md`; current root and feature entry views.
- **Estimated risk:** high.

### SKY-015 — Today vertical slice

- **ID:** SKY-015
- **Priority:** P1
- **Goal:** Compose the primary “what to wear now” answer and active-walk entry on one Today screen.
- **Why:** Weather, recommendation, context, and walk CTA are fragmented across tabs.
- **Files allowed:** `SkyKid/Features/Today/TodayView.swift` (new); `SkyKid/Features/Today/TodayViewModel.swift` (new); `SkyKid/Features/Today/Components/TodayWeatherSummaryCard.swift` (new); `SkyKid/Features/Today/Components/TodayOutfitCard.swift` (new); `SkyKid/Features/Today/Components/TodayWalkStateCard.swift` (new); `SkyKid/Features/Today/Components/TodayWalkWindowCard.swift` (new); `SkyKid/Features/Today/Components/TodayTakeAlongCard.swift` (new); `SkyKid/App/MainTabView.swift`; `SkyKid/Features/Weather/WeatherViewModel.swift`; `SkyKid/Features/Outfit/OutfitViewModel.swift`; `SkyKid/Features/Outfit/WalkPreparation/WalkPreparationView.swift`; `SkyKidTests/OutfitPresentationTests.swift`; `SkyKidTests/WalkFlowPresentationTests.swift`; `SkyKidTests/BackgroundScenarioTests.swift`; APP_COPY.
- **Files possibly relevant:** `SkyKid/Features/Weather/WeatherView.swift`; `SkyKid/Features/Outfit/OutfitView.swift`; `SkyKid/Features/Outfit/OutfitParentSummary.swift`; `SkyKid/Features/Walk/WalkTabView.swift`; `SkyKid/Core/UI/SectionCard.swift`.
- **Do not touch:** Calculation formulas, persistence schemas, walk simplification, global visual redesign.
- **Current behavior:** User moves between separate Weather/Assistant/Walk tabs.
- **Target behavior:** Today shows city/weather/update time, concrete outfit, context, short why, at most 1–2 useful items, optional walk window, and start/active state.
- **Invariants:** Blocked/stale/unknown states remain honest; no TOG added; Dynamic Type/VoiceOver/touch targets supported.
- **Implementation notes:** Reuse existing builders/cards where they fit; view model orchestrates presentation only.
- **Tests required:** Fresh/stale/loading/error/blocked/active states; ordering; accessibility identifiers/labels where established.
- **Acceptance criteria:** Core answer is visible in one scroll; CTA works; no duplicate business logic in view; build/tests pass.
- **Dependencies:** SKY-009, SKY-014; works with SKY-018.
- **Recommended model:** Luna high with Astra phase design review.
- **Context pack:** Target Today example; sections D/G; existing weather/outfit/walk presentation files.
- **Estimated risk:** medium-high.

### SKY-016 — Optional current or manual location

- **ID:** SKY-016
- **Priority:** P1
- **Goal:** Allow full use with either current location or a persisted manually selected city.
- **Why:** Permission denial is currently a dead end.
- **Files allowed:** `SkyKid/Core/Location/LocationSelection.swift` (new); `SkyKid/Core/Location/LocationSelectionStore.swift` (new); `SkyKid/Core/Location/LocationManager.swift`; `SkyKid/App/PermissionView.swift`; `SkyKid/App/DeniedView.swift`; `SkyKid/App/RootFlow.swift`; `SkyKid/Features/Weather/WeatherViewModel.swift`; `SkyKidTests/LocationSelectionTests.swift` (new); `SkyKidTests/BackgroundScenarioTests.swift`; APP_COPY; `docs/architecture.md`.
- **Files possibly relevant:** `SkyKid/App/ContentView.swift`; `SkyKid/Features/Weather/WeatherViewModel.swift`; `SkyKid/Info.plist`.
- **Do not touch:** Add geocoding vendor/dependency, continuous GPS, provider implementations, multi-location planner.
- **Current behavior:** Only CLLocation current coordinate is accepted; denial points to Settings.
- **Target behavior:** User chooses current location or searches/selects city; last manual selection persists and drives weather without permission.
- **Invariants:** Store coordinates, not child data, for weather; denied is a normal state; permission can be requested later; location name/coordinate stay coherent.
- **Implementation notes:** Isolate Apple geocoding behind a small protocol for deterministic tests; define ambiguity/offline errors.
- **Tests required:** Denied→manual; persisted manual relaunch; switch current/manual; geocode failure; permission later granted.
- **Acceptance criteria:** First recommendation is reachable without CLLocation authorization; no dead end; full tests pass.
- **Dependencies:** SKY-014; coordinate with SKY-017.
- **Recommended model:** Astra architecture review → Luna high implementation.
- **Context pack:** Location findings/target; existing manager/root/weather VM.
- **Estimated risk:** medium-high.

### SKY-017 — Coherent weather failure and provider diagnostics

- **ID:** SKY-017
- **Priority:** P1
- **Goal:** Present usable loading/cache/stale/error states and move provider selection out of consumer UI.
- **Why:** Nil/error can look like endless loading, retained weather may look current, and provider/API keys are developer concerns.
- **Files allowed:** `SkyKid/Features/Weather/WeatherViewModel.swift`; `SkyKid/Features/Weather/WeatherView.swift`; `SkyKid/Features/Weather/Components/WeatherDataQualityCard.swift`; `SkyKid/Features/Weather/Components/ProviderPickerView.swift`; `SkyKid/Core/Network/WeatherServiceSettings.swift`; `SkyKidTests/WeatherNormalizerTests.swift`; `SkyKidTests/OutfitPresentationTests.swift`; `SkyKidTests/BackgroundScenarioTests.swift`; APP_COPY; `docs/api.md`.
- **Files possibly relevant:** `SkyKid/Features/Weather/WeatherFreshness.swift`; `SkyKid/Features/Today/TodayViewModel.swift`; `SkyKid/Core/Models/ChildProfile.swift`.
- **Do not touch:** Provider API implementations, WeatherKit production work, freshness semantics from SKY-009.
- **Current behavior:** Generic errors, fragmented cache use, production provider picker.
- **Target behavior:** Explicit fresh/cached-stale/unavailable states with friendly copy and diagnostics; provider picker is `#if DEBUG` or removed from consumer navigation.
- **Invariants:** Missing UV alone does not block core weather; raw API error not shown; provider/source remains diagnosable in DEBUG.
- **Implementation notes:** Model UI state as a finite enum instead of correlated booleans where feasible.
- **Tests required:** Network unavailable with fresh/stale/no cache; partial fields; provider failure; DEBUG visibility.
- **Acceptance criteria:** No indefinite spinner on terminal error; stale age shown; consumer cannot enter API keys; tests pass.
- **Dependencies:** SKY-009, SKY-015/016 contracts.
- **Recommended model:** Luna high.
- **Context pack:** Weather failure/provider findings; `docs/api.md`; listed files.
- **Estimated risk:** medium.

### SKY-018 — Human outfit presentation, internal TOG

- **ID:** SKY-018
- **Priority:** P1
- **Goal:** Remove consumer TOG numbers and present fit, reasons, context, substitutions, and one useful item in plain language.
- **Why:** Numeric TOG implies false precision and distracts from the parent decision.
- **Files allowed:** `SkyKid/Features/Outfit/OutfitView.swift`; `SkyKid/Features/Outfit/OutfitViewModel.swift`; `SkyKid/Features/Outfit/OutfitParentSummary.swift`; `SkyKid/Features/Walk/Components/WalkOutfitChipsCard.swift`; `SkyKid/Features/Walk/Components/WalkWeatherSnapshotCard.swift`; `SkyKid/Features/Outfit/Components/GarmentIconPreviewSheet.swift`; `SkyKid/Features/Walk/WalkTOGVerdict.swift`; `SkyKidWidget/WalkLiveActivityWidget.swift`; `SkyKidWidget/ClothingStatusWidgetView.swift`; `SkyKidTests/OutfitPresentationTests.swift`; `SkyKidTests/WalkFlowPresentationTests.swift`; APP_COPY; WIDGET_COPY.
- **Files possibly relevant:** `SkyKid/Features/Outfit/OutfitOutputModels.swift`; `SkyKid/Features/Outfit/Components/ParentOutfitSummaryCard.swift`; `SkyKid/Features/Outfit/Components/WardrobeAlternativesCard.swift`; `SkyKid/Features/Outfit/Components/OutfitSafetyWarningsSection.swift`; `SkyKid/Features/Today/TodayView.swift`.
- **Do not touch:** Internal TOG calculator/solver, garment catalog values, DEBUG diagnostics.
- **Current behavior:** Active walk, previews, feedback copy and Live Activity show current/target/item TOG.
- **Target behavior:** Consumer surfaces say suitable/add/remove/light/heavy with short reason and at most two take-alongs; numeric diagnostics are DEBUG-only.
- **Invariants:** Safety warning precedence; exact garments/substitutions remain; accessibility/localization; widget size constraints.
- **Implementation notes:** Centralize presentation mapping; do not duplicate fit thresholds in views.
- **Tests required:** No localized consumer output contains TOG numeric pattern; fit mappings; blocked/stale/widget/Live Activity snapshots.
- **Acceptance criteria:** No visible TOG in release UI; internal engine unchanged; full tests/build pass.
- **Dependencies:** SKY-015; coordinate with SKY-023.
- **Recommended model:** Luna high.
- **Context pack:** TOG findings; target Today/outfit UX; presentation files/tests.
- **Estimated risk:** medium.

### SKY-019 — Passive active-walk UI and feedback flow

- **ID:** SKY-019
- **Priority:** P1
- **Goal:** Replace event-journal interaction with passive walk status and a seconds-long optional completion survey.
- **Why:** Current sleep/bassinet/checkpoint/timeline workflow exceeds parent attention budget and product scope.
- **Files allowed:** `SkyKid/Features/Walk/ActiveWalkView.swift`; `SkyKid/Features/Walk/WalkTabView.swift`; `SkyKid/Features/Walk/Components/ComfortLevelSheet.swift`; `SkyKid/Features/Walk/Components/WalkEventRow.swift`; `SkyKid/Features/Walk/Components/WalkQuickActionsCard.swift`; `SkyKid/Features/Walk/Components/WalkTimelineCard.swift`; `SkyKid/Features/Walk/Components/WalkTimerHeaderCard.swift`; `SkyKid/Features/Walk/Components/WalkOutfitChipsCard.swift`; `SkyKid/Features/Walk/Components/WalkWeatherSnapshotCard.swift`; `SkyKid/Features/Walk/GarmentPickerSheet.swift`; `SkyKid/Features/Walk/WalkEventReclassifySheet.swift`; `SkyKid/Features/History/AddWalkEventSheet.swift`; `SkyKid/Features/History/WalkCompletionView.swift`; `SkyKid/Features/History/WalkLogDetailView.swift`; `SkyKid/Features/History/WalkSummary.swift`; `SkyKid/Features/History/WalkSummaryView.swift`; `SkyKid/Core/LiveActivity/WalkQuickMarkIntents.swift`; `SkyKidWidget/WalkLiveActivityWidget.swift`; `SkyKid/Core/Models/ActiveWalk.swift`; `SkyKid/Core/Models/WalkLog.swift`; `SkyKidTests/WalkFlowPresentationTests.swift`; `SkyKidTests/WalkSummaryTests.swift`; `SkyKidTests/LiveWalkTests.swift`; APP_COPY; WIDGET_COPY.
- **Files possibly relevant:** `SkyKid/Core/Storage/ActiveWalkStore.swift`; `SkyKid/Features/History/WalkSummary.swift`; `SkyKid/Features/History/WalkSummaryView.swift`; `SkyKid/Core/Storage/WalkEventReclassifier.swift`; `SkyKid/Core/Storage/WalkEventUndo.swift`.
- **Do not touch:** Delete legacy event model/storage before migration proof, thermal training policy, weather provider, broad history redesign.
- **Current behavior:** Quick actions and editable timeline prioritize sleep, bassinet, checkpoint; finish requires categorical comfort and summarizes sleep.
- **Target behavior:** Duration/current conditions/current outfit/change notice/finish; optional comfort cold-comfortable-hot-unsure/skip; optional clothing none/removed/added/don’t remember; exact garment optional.
- **Invariants:** Zero during-walk input is valid; old logs decode/render without journal controls; car-seat guidance remains scenario-based, not runtime logging.
- **Implementation notes:** Preserve compatibility fields as deprecated until SKY-031; remove remote quick intents but keep useful local ActivityKit entry/finish behavior.
- **Tests required:** Start→no input→finish→one/zero answer; unsure/skip; adjustment mapping; legacy event payload; accessibility.
- **Acceptance criteria:** No required journal, sleep, checkpoint, bassinet, or event-edit control in primary flow; completion takes seconds; tests pass.
- **Dependencies:** SKY-003–005, SKY-014/015.
- **Recommended model:** Astra UX/data checkpoint → Luna high implementation.
- **Context pack:** Data levels, active-walk target, removal map; current walk/history components.
- **Estimated risk:** high.

### SKY-020 — Authoritative active-walk state and passive updates

- **ID:** SKY-020
- **Priority:** P1
- **Goal:** Guarantee one durable active walk across background/relaunch and model passive weather changes without mutating start provenance.
- **Why:** Persistence exists, but store-level duplicate protection and clock/weather-change semantics are incomplete.
- **Files allowed:** `SkyKid/Core/Storage/ActiveWalkStore.swift`; `SkyKid/Core/Models/ActiveWalk.swift`; `SkyKid/Core/LiveActivity/WalkLiveActivityController.swift`; `SkyKid/Core/Models/WalkActivityAttributes.swift`; `SkyKid/Features/Walk/Components/WalkWeatherSnapshotCard.swift`; `SkyKid/Features/Walk/Components/WalkTimerHeaderCard.swift`; `SkyKidTests/LiveWalkTests.swift`; `SkyKidTests/BackgroundScenarioTests.swift`; `docs/models.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/WeatherSnapshot.swift`; `SkyKid/Core/Notifications/NotificationService.swift`; `SkyKid/Core/Notifications/SafeReminderContent.swift`; `SkyKid/Core/UI/ElapsedTimeText.swift`.
- **Do not touch:** GPS tracking, remote push, route journal, provider polling architecture beyond necessary hook.
- **Current behavior:** Active walk restores, but `start` can overwrite; duration uses wall-clock dates; only start scalar weather is durable.
- **Target behavior:** Start returns explicit already-active result; restore offers continue/finish; duration is nonnegative and documented; start snapshot immutable; optional later snapshots/significant passive changes are separate.
- **Invariants:** Exactly one active record; app termination does not lose start time; no constant background location; alerts calm/non-blocking; local Live Activity remains.
- **Implementation notes:** Store raw dates plus monotonic in-process timing only if useful; define significance in a pure policy and inject time.
- **Tests required:** Duplicate start; crash/relaunch restore; background; timezone/DST display; clock rollback; immutable start snapshot; significant/no-significant update.
- **Acceptance criteria:** Store enforces state machine; no overwrite; tests use deterministic clocks; app/widget build.
- **Dependencies:** SKY-002, SKY-003, SKY-011, SKY-019.
- **Recommended model:** Astra architecture review → Luna high implementation.
- **Context pack:** Active walk findings; target walk architecture; listed model/store/controller files.
- **Estimated risk:** high.

### SKY-021 — Explainable thermal fingerprint

- **ID:** SKY-021
- **Priority:** P1
- **Goal:** Learn conservatively from eligible similar walks and produce human explanations without exposing offsets.
- **Why:** Current learner is bounded but similarity is coarse and accepts low-quality sources.
- **Files allowed:** `SkyKid/Core/Models/PersonalizationModels.swift`; `SkyKid/Core/Models/PersonalizationEngine.swift`; `SkyKid/Core/Models/PersonalOffsetStore.swift`; `SkyKid/Core/Storage/WalkLogStore.swift`; `SkyKid/Features/Outfit/OutfitParentSummary.swift`; `SkyKidTests/PersonalizationTests.swift`; `docs/algorithms.md`; `docs/models.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/WalkLog.swift`; `SkyKid/Core/Models/WalkContext.swift`; `SkyKid/Features/Outfit/OutfitRecommendationService.swift`; `SkyKid/Features/Outfit/OutfitViewModel.swift`.
- **Do not touch:** ML/AI, cloud, complex confidence percentages, history UI, raw TOG consumer UI.
- **Current behavior:** Temperature band + scenario drive bounded offset after repeated signals; source quality and clothing adjustment are limited.
- **Target behavior:** Deterministic features include effective-temperature band, transport/activity/age/weather class, insulation band, duration and optional clothing change; only eligible independent walks count; output contains bounded adjustment plus explanation evidence.
- **Invariants:** One observation cannot sharply change result; reversible/limited/expiring; sparse-data fallback says insufficient evidence; no medical confidence language.
- **Implementation notes:** Characterize current engine first; use small typed buckets and injected time, not a generic feature platform.
- **Tests required:** Independence/dedupe; bounds; opposing signals; decay; similar/dissimilar contexts; clothing adjustments; insufficient data; rename continuity.
- **Acceptance criteria:** Pure deterministic evaluator; exact eligibility input; explanation cites counts/conditions without false precision; full suite passes.
- **Dependencies:** SKY-001, SKY-004, SKY-005, SKY-010, SKY-019.
- **Recommended model:** Astra design/review → Luna high implementation → Astra diff review.
- **Context pack:** Personalization philosophy/findings; `docs/algorithms.md`; relevant models/engine/tests only.
- **Estimated risk:** high.

### SKY-022 — Learning-centered history

- **ID:** SKY-022
- **Priority:** P1
- **Goal:** Reframe History around what SkyKid learned from similar eligible walks.
- **Why:** Counts, average duration and sleep totals do not explain personalization value.
- **Files allowed:** `SkyKid/Features/History/WalkHistoryView.swift`; `SkyKid/Features/History/WalkHistoryInsights.swift`; `SkyKid/Features/History/Components/WalkHistoryInsightsCard.swift`; `SkyKid/Features/History/FeedbackHistorySection.swift`; `SkyKid/Features/History/FeedbackHistoryItem.swift`; `SkyKid/Features/History/Components/ThermalLearningCard.swift` (new); `SkyKidTests/WalkSummaryTests.swift`; `SkyKidTests/OutfitPresentationTests.swift`; APP_COPY.
- **Files possibly relevant:** `SkyKid/Core/Models/WalkLog.swift`; `SkyKid/Core/Models/PersonalizationModels.swift`; `SkyKid/Features/History/WalkLogDetailView.swift`; `SkyKid/Features/History/WalkSummary.swift`.
- **Do not touch:** Personalization calculations, walk persistence, charts framework, delete/edit semantics.
- **Current behavior:** Weekly operational statistics and sleep dominate; feedback list is secondary.
- **Target behavior:** Similar-walk count, comfort pattern, relevant clothing change, current adaptation explanation, and honest insufficient-data state lead the screen; chronological records remain accessible.
- **Invariants:** Manual/ineligible records never appear as learning evidence; no medical confidence/complex chart; values derive from one tested presentation builder.
- **Implementation notes:** Consume SKY-021 explanation output instead of recomputing similarity in UI.
- **Tests required:** No data; insufficient data; mixed eligibility; consistent/mixed feedback; localization/pluralization.
- **Acceptance criteria:** “What SkyKid learned” is primary; sleep totals removed from primary insights; evidence matches engine; tests pass.
- **Dependencies:** SKY-019, SKY-021.
- **Recommended model:** Luna high.
- **Context pack:** History target; thermal fingerprint UX; existing History files and SKY-021 output contract.
- **Estimated risk:** medium.

### SKY-023 — Progressive wardrobe truth

- **ID:** SKY-023
- **Priority:** P1
- **Goal:** Represent unknown garment ownership and let recommendations gradually collect “have/don’t have” facts.
- **Why:** Treating the entire catalog as owned makes recommendations dishonest; full wardrobe onboarding is excessive.
- **Files allowed:** `SkyKid/Core/Models/UserWardrobeStore.swift`; `SkyKid/Features/Profile/MyWardrobeView.swift`; `SkyKid/Features/Profile/Components/WardrobeItemRow.swift`; `SkyKid/Features/Outfit/Components/WardrobeAlternativesCard.swift`; `SkyKid/Features/Outfit/OutfitSolver.swift`; `SkyKid/Features/Outfit/OutfitView.swift`; `SkyKid/Features/Today/Components/TodayOutfitCard.swift`; `SkyKidTests/OutfitCalculatorTests.swift`; `SkyKidTests/OutfitPresentationTests.swift`; APP_COPY; `docs/models.md`.
- **Files possibly relevant:** `SkyKid/Features/Outfit/GarmentCatalog.swift`; `SkyKid/Features/Outfit/OutfitCombinationSolver.swift`; `SkyKid/Features/Outfit/OutfitOutputModels.swift`.
- **Do not touch:** Catalog-wide rewrite, onboarding checklist, TOG formulas, purchase links.
- **Current behavior:** No saved key means every catalog garment is owned; solver already supports restricted wardrobe alternatives.
- **Target behavior:** Ownership is unknown/owned/unavailable; recommended items offer lightweight yes/no; unavailable gets substitution/closest honest result; catalog additions stay unknown.
- **Invariants:** No required setup; unknown does not equal owned or unavailable; exact-no-solution remains readable; migration does not erase explicit choices.
- **Implementation notes:** Preserve solver strengths and adapt input semantics deliberately; do not add ternary state everywhere if a compact set-based model suffices.
- **Tests required:** Fresh install unknown; legacy all-seeded migration; owned/unavailable; catalog addition; exact/no exact solution; substitution.
- **Acceptance criteria:** Fresh user is not assumed to own all; recommendation flow learns naturally; tests pass.
- **Dependencies:** SKY-018.
- **Recommended model:** Astra data-model checkpoint → Luna high implementation.
- **Context pack:** Wardrobe findings/target; solver/model/store/tests.
- **Estimated risk:** medium-high.

### SKY-024 — Walk-window scorer and contextual safety guidance

- **ID:** SKY-024
- **Priority:** P1
- **Goal:** Extract a deterministic “better walk window” scorer with reasons and contextual UV/stroller guidance.
- **Why:** Current private two-slot method omits major factors and uses misleading/fixed safety copy.
- **Files allowed:** `SkyKid/Features/Outfit/WalkWindowScorer.swift` (new); `SkyKid/Features/Outfit/WeatherSafetyPolicy.swift`; `SkyKid/Features/Outfit/OutfitConfig.swift`; `SkyKid/Features/Outfit/OutfitOutputModels.swift`; `SkyKid/Features/Today/Components/TodayWalkWindowCard.swift`; `SkyKidTests/SafetyPolicyTests.swift`; `SkyKidTests/WalkWindowScorerTests.swift` (new); APP_COPY; `docs/algorithms.md`; `docs/safety.md`; CLINICAL_REVIEW_SET.
- **Files possibly relevant:** `SkyKid/Features/Weather/Components/HourlyForecastCard.swift`; `SkyKid/Core/Models/WeatherData.swift`; `SkyKid/Core/Models/NormalizedWeather.swift`; `SkyKid/Features/Outfit/AgeSafetyPolicy.swift`.
- **Do not touch:** AQI, new provider, medical calculator, percentage safety score.
- **Current behavior:** `findNextSaferWindow` checks apparent-temperature range and rain probability for adjacent hours using `Date()`; fixed UV hours; no dense sun-cover note.
- **Target behavior:** Pure injected-time scorer considers available apparent temperature, wind/gust, precipitation, UV, freshness/confidence and outputs interval/relative reasons or no result; copy says “better”, not “safe”; measured UV drives shade guidance; dense-cover ventilation reminder is calm.
- **Invariants:** Missing optional data lowers evidence rather than being invented; no safety percentage; age/medical policies remain authoritative; adult observation reminder remains.
- **Implementation notes:** Keep weights few, named, testable, and clinically/product-reviewed; distinguish environmental score from safety gate.
- **Tests required:** Wind/rain/UV tradeoffs; stale/low-confidence no result; ties; timezone; missing fields; high UV copy; stroller cover copy; no fixed global hours.
- **Acceptance criteria:** Old private method removed; reasons match inputs; wording review complete; algorithm version/digest updated as applicable; tests pass.
- **Dependencies:** SKY-002, SKY-009, SKY-010, SKY-015.
- **Recommended model:** Astra safety/algorithm design → Luna high implementation → Astra diff review.
- **Context pack:** Walk-window/UV/stroller requirements; safety/algorithm docs; listed policy/forecast files.
- **Estimated risk:** high.

### SKY-025 — Versioned local backup and restore

- **ID:** SKY-025
- **Priority:** P1
- **Goal:** Export, validate, migrate, and explicitly restore all user-owned local data in a versioned file.
- **Why:** Removing cloud sync otherwise makes reinstall/device migration a months-of-history loss risk.
- **Files allowed:** `SkyKid/Core/Backup/SkyKidBackup.swift` (new); `SkyKid/Core/Backup/LocalBackupService.swift` (new); `SkyKid/Core/Backup/BackupMigration.swift` (new); `SkyKid/Core/Backup/BackupValidation.swift` (new); `SkyKid/Features/Profile/BackupRestoreView.swift` (new); `SkyKid/Features/Profile/ProfileSummaryView.swift`; `SkyKid/Core/Models/ChildProfile.swift`; `SkyKid/Core/Models/ChildProfileStore.swift`; `SkyKid/Core/Models/WalkLog.swift`; `SkyKid/Core/Storage/WalkLogStore.swift`; `SkyKid/Core/Models/PersonalizationModels.swift`; `SkyKid/Core/Models/PersonalOffsetStore.swift`; `SkyKid/Core/Models/UserWardrobeStore.swift`; `SkyKidTests/BackupTests.swift` (new); APP_COPY; `docs/models.md`; `docs/architecture.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/ActiveWalk.swift`; `SkyKid/Core/Storage/ActiveWalkStore.swift`; `SkyKid/Core/Storage/RecommendationSnapshotStore.swift`; `SkyKid/Core/Models/ChildThermalProfile.swift`; `SkyKid/Core/Models/OutfitRecommendationSnapshot.swift`; `SkyKid/Info.plist`.
- **Do not touch:** iCloud/custom backend, paywall, auto-upload, user-created files outside sandbox, unrelated store internals.
- **Current behavior:** No export/import; data is fragmented across App Group UserDefaults stores.
- **Target behavior:** `SkyKidBackup` includes schemaVersion/exportedAt/profile/walks/personalization/wardrobe/relevant settings; service validates fully before an explicit destructive replace and reports corrupt/future-version errors.
- **Invariants:** Backup/export is free; failed import changes nothing; secrets/provider keys are excluded unless explicitly justified; child UUID and algorithm/weather provenance persist; import is user-confirmed.
- **Implementation notes:** Two-phase decode/validate then atomic-enough commit with rollback snapshot; document merge-vs-replace decision (v1 prefer replace).
- **Tests required:** Roundtrip; corrupt/truncated; unsupported future schema; legacy schema migration; validation failure no mutation; rollback on write failure; UUID/history integrity.
- **Acceptance criteria:** Export shares a file; valid restore reproduces domain state; destructive confirmation shown; failures preserve current data; full tests pass.
- **Dependencies:** SKY-001–004, SKY-010, SKY-011, SKY-023; Astra schema checkpoint before implementation.
- **Recommended model:** Astra schema/migration design → Luna high implementation → Astra diff review.
- **Context pack:** Backup requirements; persistence map; final versions of every included model/store; `docs/models.md`.
- **Estimated risk:** high.

### SKY-026 — Atomic local data reset

- **ID:** SKY-026
- **Priority:** P1
- **Goal:** Add one confirmed command that clears all app-owned local personal data consistently.
- **Why:** Current walks-only clear/sign-out paths are incomplete and account-coupled.
- **Files allowed:** `SkyKid/Core/Storage/LocalDataResetService.swift` (new); `SkyKid/Core/Models/ChildProfileStore.swift`; `SkyKid/Core/Storage/WalkLogStore.swift`; `SkyKid/Core/Storage/ActiveWalkStore.swift`; `SkyKid/Core/Models/PersonalOffsetStore.swift`; `SkyKid/Core/Models/UserWardrobeStore.swift`; `SkyKid/Core/Storage/RecommendationSnapshotStore.swift`; `SkyKid/Core/Models/WalkContextStore.swift`; `SkyKid/Features/Profile/ProfileSummaryView.swift`; `SkyKid/Features/Profile/DeleteLocalDataConfirmationView.swift` (new); `SkyKidTests/LocalDataResetTests.swift` (new); APP_COPY; `docs/architecture.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/ChildProfile.swift`; `SkyKid/Core/Models/WalkLog.swift`; `SkyKid/Core/Models/OutfitRecommendationSnapshot.swift`; `SkyKid/Core/LiveActivity/WalkLiveActivityController.swift`; `SkyKid/Core/Notifications/LiveWalkNotificationPreferences.swift`; `SkyKid/Core/Network/WeatherServiceSettings.swift`.
- **Do not touch:** External backup files, system permissions, app language unless specified as app-owned setting, keychain unrelated to removed auth.
- **Current behavior:** No atomic all-data command; sign-out incompletely and unexpectedly clears some domains.
- **Target behavior:** Explicit confirmation stops local active/Live Activity state and clears profile, walks, personalization, wardrobe, recommendation/cache and relevant settings, then routes to onboarding.
- **Invariants:** No external file deletion; cancellation is no-op; partial failure is surfaced/recoverable; definition of “relevant settings” is documented.
- **Implementation notes:** One orchestrator owns ordered clear, not UI; test every registered domain key.
- **Tests required:** Cancel; complete reset; active walk reset; relaunch empty; no orphan personalization/snapshot; failure handling.
- **Acceptance criteria:** One user action with confirmation clears documented scope; no account concept; tests/full build pass.
- **Dependencies:** SKY-011–SKY-013; preferably after SKY-025 so users can export first.
- **Recommended model:** Luna high with Astra persistence review.
- **Context pack:** Delete-data requirement; storage map; all local store clear contracts.
- **Estimated risk:** high.

### SKY-027 — Backend-free outfit sharing

- **ID:** SKY-027
- **Priority:** P1
- **Goal:** Share the current recommendation through the standard iOS share sheet using a pure localized summary.
- **Why:** It supplies the useful family handoff without accounts/realtime backend.
- **Files allowed:** `SkyKid/Features/Outfit/ShareOutfitComposer.swift` (new); `SkyKid/Features/Today/Components/TodayOutfitCard.swift`; `SkyKid/Features/Outfit/OutfitView.swift`; `SkyKidTests/OutfitPresentationTests.swift`; APP_COPY.
- **Files possibly relevant:** `SkyKid/Core/Models/OutfitRecommendationSnapshot.swift`; `SkyKid/Features/Outfit/OutfitParentSummary.swift`; `SkyKid/Features/Profile/Components/FamilyCard.swift`.
- **Do not touch:** Contacts/messaging integrations, family models, cloud storage, analytics.
- **Current behavior:** Recommendation cannot be shared; only obsolete family invitation has ShareLink.
- **Target behavior:** User shares child display name if present, weather/freshness context, garment list, scenario and short reason through system sheet.
- **Invariants:** No hidden child health data, coordinates, TOG, IDs or history; stale/unknown context labeled; neutral when name absent.
- **Implementation notes:** Composer must be pure/testable; UI uses system share presentation.
- **Tests required:** Full/partial/stale data; missing name; no sensitive fields; localization.
- **Acceptance criteria:** Share action works offline without backend; output is concise and contains no prohibited data; tests pass.
- **Dependencies:** SKY-015, SKY-018.
- **Recommended model:** Luna medium.
- **Context pack:** Share-sheet requirement; Today/outfit presentation model; localized strings conventions.
- **Estimated risk:** low.

### SKY-028 — Production WeatherKit integration (deferred)

- **ID:** SKY-028
- **Priority:** P2
- **Goal:** Replace the WeatherKit stub with an entitlement-backed production adapter after commercial/Apple account approval.
- **Why:** Current `WeatherKitService` delegates to Open-Meteo and is not an Apple WeatherKit implementation.
- **Files allowed:** `SkyKid/Core/Network/WeatherKitService.swift`; `SkyKid/Core/Network/WeatherServiceProtocol.swift`; `SkyKid/Core/Network/WeatherServiceSettings.swift`; `SkyKid/SkyKid.entitlements`; `SkyKid.xcodeproj/project.pbxproj`; `SkyKidTests/WeatherKitServiceTests.swift` (new); `SkyKidTests/WeatherNormalizerTests.swift`; `docs/api.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/RawWeatherObservation.swift`; `SkyKid/Core/Models/WeatherNormalizer.swift`; `SkyKid/Info.plist`.
- **Do not touch:** Child/walk data, recommendation formulas, provider consumer UI, unapproved entitlement.
- **Current behavior:** WeatherKit selection is a fallback wrapper around Open-Meteo.
- **Target behavior:** Real WeatherKit data maps to raw observation with correct source/timestamps/partial fields/failures; fallback policy is explicit and commercially reviewed.
- **Invariants:** No false provider label; coordinates only; no forced commercial API dependency; Open-Meteo terms reviewed before production use.
- **Implementation notes:** Ticket stays blocked until entitlement and product decision exist; never simulate WeatherKit in production.
- **Tests required:** Mapping fixture; partial/missing core; freshness; authorization/provider failure; source attribution.
- **Acceptance criteria:** Entitled device/simulator strategy documented; normalized parity tests pass; provider/source agree.
- **Dependencies:** SKY-002, SKY-009, SKY-017; external entitlement approval.
- **Recommended model:** Astra architecture/security checkpoint → Luna high implementation.
- **Context pack:** WeatherKit requirement; `docs/api.md`; provider/normalizer contracts.
- **Estimated risk:** high.

### SKY-029 — AQI extension seam (deferred)

- **ID:** SKY-029
- **Priority:** P2
- **Goal:** Define only the minimal environment-data seam needed to add AQI later without rewriting weather/outfit boundaries.
- **Why:** AQI is useful but brings new APIs, costs, regional thresholds and safety review beyond v1.
- **Files allowed:** `docs/architecture.md`; `docs/api.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/WeatherSnapshot.swift`; `SkyKid/Features/Today/TodayViewModel.swift`; `SkyKid/Features/Outfit/WeatherSafetyPolicy.swift`.
- **Do not touch:** Fetch AQI, invent thresholds, UI warning, dependency/package, premium gate.
- **Current behavior:** No AQI.
- **Target behavior:** Architecture note identifies optional environment observations and future policy boundary; no runtime behavior in this ticket.
- **Invariants:** Weather core remains simple; missing AQI never blocks clothing recommendation; no medical claim.
- **Implementation notes:** Prefer documentation-only until provider/safety requirements are approved.
- **Tests required:** None for documentation-only; compile/unit coverage if any model is approved.
- **Acceptance criteria:** AQI remains deferred; future integration point is clear and does not generalize the entire engine.
- **Dependencies:** SKY-002 and Phase 4 stabilized.
- **Recommended model:** Astra checkpoint for scope; Luna medium documentation.
- **Context pack:** AQI requirement; target architecture weather boundary.
- **Estimated risk:** low now, high if activated.

### SKY-030 — Lifetime Plus hypothesis (deferred)

- **ID:** SKY-030
- **Priority:** P2
- **Goal:** Validate and, only after approval, isolate a StoreKit 2 non-consumable Lifetime entitlement without gating core/safety/data ownership.
- **Why:** A one-time unlock may fund advanced features without backend, but premature paywall work distracts from correctness.
- **Files allowed:** `docs/business-model.md` (new); after explicit product approval: `SkyKid/Core/Purchases/PurchaseProduct.swift` (new); `SkyKid/Core/Purchases/StoreKitPurchaseService.swift` (new); `SkyKid/Core/Purchases/EntitlementStore.swift` (new); `SkyKid/Features/Profile/LifetimePlusView.swift` (new); `SkyKid/SkyKid.storekit` (new); `SkyKidTests/StoreKitPurchaseTests.swift` (new); `SkyKid.xcodeproj/project.pbxproj`; APP_COPY.
- **Files possibly relevant:** `SkyKid.xcodeproj/project.pbxproj`; `SkyKid/Features/Outfit/WalkWindowScorer.swift`; `SkyKid/Features/History/WalkHistoryInsights.swift`; `SkyKidWidget/SkyKidWidgetBundle.swift`.
- **Do not touch:** Basic recommendation, safety warnings, feedback, basic personalization/history, backup/export/reset, account/backend, subscription, ads/analytics.
- **Current behavior:** No StoreKit/paywall.
- **Target behavior:** Approved `skykid.plus.lifetime`-style non-consumable with verified transaction, restore/pending/failure/cancel/offline behavior and centralized product ID/config.
- **Invariants:** Core stays free/offline-capable; entitlement failure never hides safety/data access; no hardcoded identifiers scattered in UI.
- **Implementation notes:** Split product decision from implementation; StoreKit security/entitlement review is mandatory.
- **Tests required:** Entitled/not entitled; purchase/restore/pending/cancel/failure/offline/unverified; core availability.
- **Acceptance criteria:** Product matrix approved first; implementation is isolated/tested; no prohibited paywall; full suite passes.
- **Dependencies:** Phases 1–11 stable; external product approval.
- **Recommended model:** Astra product/security checkpoint → Luna high implementation → Astra diff review.
- **Context pack:** Business model/Do-not-paywall sections; final feature map; StoreKit config if approved.
- **Estimated risk:** high.

### SKY-031 — Proven dead-code and legacy cleanup

- **ID:** SKY-031
- **Priority:** P2
- **Goal:** Delete only artifacts proven unreferenced after the core refactor and finish backward-data migrations.
- **Why:** Named legacy files include both true dead code and still-shared types; early deletion risks compatibility.
- **Files allowed:** `SkyKid/Features/Outfit/Components/PersonalizationStatusCard.swift`; `SkyKid/Features/Outfit/Components/OutfitCalculationDetailsCard.swift`; `SkyKid/Features/Outfit/Components/OutfitFitCard.swift`; `SkyKid/Features/Outfit/LegacyWardrobeAutoSelector.swift`; `SkyKid/Features/History/AddWalkEventSheet.swift`; `SkyKid/Features/Walk/Components/WalkEventRow.swift`; `SkyKid/Features/Walk/Components/WalkQuickActionsCard.swift`; `SkyKid/Features/Walk/Components/WalkTimelineCard.swift`; `SkyKid/Features/Walk/WalkEventReclassifySheet.swift`; `SkyKid/Core/Storage/WalkEventReclassifier.swift`; `SkyKid/Core/Storage/WalkEventUndo.swift`; `SkyKid/Core/Models/WeatherData.swift`; `SkyKid/Core/Models/NormalizedWeather.swift`; `SkyKidTests/OutfitCalculatorTests.swift`; `SkyKidTests/LiveWalkTests.swift`; `SkyKid.xcodeproj/project.pbxproj`; `docs/project-map.md`; `docs/models.md`.
- **Files possibly relevant:** `SkyKid/Core/Models/NormalizedWeather.swift`; `SkyKid/Core/Models/WeatherData.swift`; `SkyKidTests/WeatherNormalizerTests.swift`; `SkyKidTests/BackgroundScenarioTests.swift`; `docs/project-map.md`.
- **Do not touch:** Live production call sites, safety engine, unrelated formatting/rename, current data before decode window policy.
- **Current behavior:** Several components are uncalled; legacy selector is test-only; `WeatherData` still hosts shared/bridge types; walk event fields preserve data.
- **Target behavior:** Each candidate has evidence (production refs, tests, migration dependency); only safe candidates are deleted or split; no stale project/docs refs.
- **Invariants:** Old supported payloads decode; no feature regression; cleanup is not a redesign.
- **Implementation notes:** Produce a per-file zero-reference/migration checklist in the ticket diff; split shared types before deleting container.
- **Tests required:** Full suite/build; legacy fixtures; `rg` call-site proof; widget build.
- **Acceptance criteria:** Every deletion has evidence; no dangling Xcode/docs reference; no drive-by changes.
- **Dependencies:** Phases 1–11, especially SKY-019/023/025.
- **Recommended model:** Luna medium; Luna high for model migration; Astra unnecessary unless migration ambiguity appears.
- **Context pack:** Removal map; dead-code findings; current project map and candidate files.
- **Estimated risk:** medium.

### SKY-032 — Methodology, positioning, localization and release documentation

- **ID:** SKY-032
- **Priority:** P1
- **Goal:** Align consumer methodology and repository documentation with the final local-first behavior and safety limits.
- **Why:** Current docs contain stale radar/auth/navigation claims and the app lacks a transparent intended-purpose screen.
- **Files allowed:** `SkyKid/Features/Profile/MethodologyView.swift` (new); `SkyKid/Features/Profile/ProfileSummaryView.swift`; APP_COPY; `docs/architecture.md`; `docs/models.md`; `docs/algorithms.md`; `docs/api.md`; `docs/project-map.md`; `docs/safety.md`; `docs/accessibility.md`; `docs/localization.md`; CLINICAL_REVIEW_SET.
- **Files possibly relevant:** `SkyKid/Features/Outfit/OutfitParentSummary.swift`; `SkyKid/Features/Weather/WeatherFreshness.swift`; `SkyKid/Core/Models/OutfitRecommendationSnapshot.swift`.
- **Do not touch:** Proprietary formula disclosure, release-gate bypass, wholesale localization rewrite, new legal claim without review.
- **Current behavior:** Safety infrastructure exists, but user methodology is absent and architecture/project maps are stale.
- **Target behavior:** “How SkyKid works” covers inputs, internal TOG concept, personalization, freshness, algorithm version, limitations and sources; consistent informational-assistant copy appears in onboarding/About/support docs; all architecture maps match code.
- **Invariants:** Avoid guaranteed/safe/medical precision wording; clinical status remains pending until genuine external sign-off; Dynamic Type/VoiceOver/contrast/Reduce Motion checklist applies.
- **Implementation notes:** Audit new user strings through existing L10n; do not claim disclaimer alone mitigates unsafe behavior.
- **Tests required:** Localization key parity; presentation/accessibility smoke; release validation script expected result; link validation where practical.
- **Acceptance criteria:** No stale five-tab/radar/Supabase description; methodology accessible from Profile; algorithm/freshness/limits visible; external gate intact; full build/tests pass.
- **Dependencies:** All behavior phases; update incrementally at phase gates, finalize last.
- **Recommended model:** Luna medium for docs/localization, Astra final safety/architecture checkpoint.
- **Context pack:** Entire canonical plan conclusions; final code boundaries; safety/clinical/accessibility/localization docs.
- **Estimated risk:** medium-high.

## I. Model plan

| Tier | Tickets | Usage |
|---|---|---|
| Astra design/review checkpoints | SKY-001, 002, 004, 006–010, 014, 016, 019–021, 023–026, 028–030, 032 | Architecture, migrations, weather provenance, thermal/medical/safety behavior, backup schema, StoreKit security; batch review at phase boundaries |
| Luna high implementation | SKY-001–026 except the simple share-only portion, plus SKY-028/030 if activated | Default for meaningful Swift behavior, state, persistence, tests, and UI extraction |
| Luna medium | SKY-027, SKY-029 documentation, SKY-031 mechanical deletions, SKY-032 docs/localization | Straightforward presentation/docs/cleanup after contracts are fixed |
| Luna xhigh | None planned | Escalate only after a concrete high-tier compiler or dependency-graph blocker; never by default |

Economy rule: one Astra checkpoint establishes the phase contract, multiple Luna tickets implement it, then one Astra phase-diff review. Astra is not a permanent per-file foreman.

Executor context must include only this ticket, its dependencies’ resulting contracts, named documentation sections, and the whitelisted files. If a file outside `Files allowed` is required, stop, explain why, and amend the whitelist before editing.

Executor report format:

```text
Changed:
- file

Behavior:
brief

Tests:
commands and result

Risks:
remaining risks

Not touched:
intentional exclusions
```

## J. Risk register

| Risk | Likelihood / impact | Mitigation / gate |
|---|---|---|
| Thermal correctness regression | Medium / critical | Characterization first; SKY-006/007/021/024 Astra review; algorithm version; focused + full tests; clinical gate |
| Unsupported medical positioning | High / critical | Remove diagnosis arithmetic, explicit limitation policy, calm copy audit, external clinical review; never bypass status plist/script |
| Child/profile/personalization migration loss | Medium / critical | Idempotent UUID migration, legacy fixtures, rename/collision tests, backup before destructive reset/import |
| Walk/weather schema backward compatibility | Medium / high | Optional versioned provenance, conservative legacy eligibility, Codable fixtures, delayed dead-code deletion |
| Hidden data deletion during Supabase removal | Medium / critical | Detach stores first, never invoke sign-out cleanup, upgrade tests with populated local state, phase diff review |
| Persistence partial write/import | Medium / critical | Validate-first, rollback snapshot, explicit replace confirmation, failure-injection tests |
| Weather/provider unavailable | High / high | Manual location, coherent fresh/cache/stale/unavailable state, no core-temperature synthesis, offline walk support |
| Stale recommendation shown as current | Medium / high | One injected-clock freshness policy across app/widget/Siri; time-advance tests |
| Active walk overwritten/lost | Medium / high | Store-level state machine, duplicate-start result, relaunch/background/clock tests, immutable start snapshot |
| Personalization poisoned by manual/false feedback | High / high | Explicit origin and pure eligibility evaluator; tracked-walk-only training; dedupe/bounds/reversal tests |
| Backup leaks secrets/health detail unnecessarily | Medium / high | Explicit schema review, exclude provider credentials/secrets, user-owned file, no auto-upload, privacy documentation |
| Backup future/corrupt version destroys current data | Medium / critical | Decode/validate before mutation, unsupported-version error, rollback, exhaustive tests |
| UI refactor hides safety warnings | Medium / critical | Warning precedence invariant, presentation tests, accessibility review, Astra phase review |
| Accessibility/localization regression | Medium / medium | Existing L10n, key parity, Dynamic Type/VoiceOver/touch target checks on each new surface |
| Supabase project cleanup breaks build graph | Medium / medium | Ordered zero-call-site removal, narrow pbx edits, app+widget build, package resolution check |
| WeatherKit/commercial terms unresolved | High / medium | Keep SKY-028 deferred until entitlement and terms decision; never mislabel fallback source |
| StoreKit distracts/paywalls core | Medium / high | Phase 12 only after stabilization; explicit do-not-paywall matrix and external product approval |
| Stale documentation drives wrong edits | High / medium | Update docs at each phase gate; SKY-032 final code-to-doc audit; remove radar/five-tab/backend claims |
| Scope creep into tracker/CRM/medical app | Medium / high | Product test and attention budget in every ticket; removal map and `Do not touch` lists |

## K. Plan status

- Phase 0: complete as a planning/baseline exercise.
- Implementation phases 1–13: not started.
- Ticket inventory: 32 total — P0: 10, P1: 18, P2: 4.
- Recommended first implementation ticket: SKY-001, because stable identity is a prerequisite for trustworthy personalization and later backup/migration work.
- Current working-tree change created by this pass: only `docs/refactor-plan.md`.
- No production Swift, project dependency, entitlement, test source, or existing documentation file was changed during this pass.
