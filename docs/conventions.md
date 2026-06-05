# Соглашения кода SkyKid

## Swift / SwiftUI

- Нет `!` force-unwrap — только `guard let` / `if let`
- `async/await` везде, колбеков нет
- Все VM: `@MainActor @Observable final class`
- `@unchecked Sendable` допустим только на синглтонах поверх thread-safe хранилищ (как `ChildProfileStore`)
- Размеры в коде без констант; при рефакторинге выносить в `Design.swift` (не создан)
- Локализация не подключена — строки вшиты напрямую

## SOLID-специфичное

- Safety constraints в `WardrobeModel.riskLevel` — через guards `isExtremeHeat`/`isExtremeCold` **перед** зональной логикой. Порядок проверок не менять.
- `OutfitRule` — `fileprivate` протокол; конкретные правила — `private struct` в `OutfitAdvisor.swift`
- `GarmentCatalog.byID` / `byLayer` — единственный источник данных гардероба; не создавать дублирующих lookup-таблиц
- `idealBandCLO = 0.2` — `private static let` в `WardrobeModel`; все ссылки через `Self.idealBandCLO`

## Виджет

- `ChildProfile.swift` должен быть в Target Membership обоих таргетов
- `ChildProfileStore.swift` — только основной таргет (виджет не использует)
- Новые файлы в `Core/` или `Features/` нужно добавлять в `project.pbxproj` вручную (pbxproj использует custom IDs F001–F021+)

## Производительность (ClothingCalculatorView)

- `ClothingConstructorSection` получает `selectedItems: Set<GarmentItem>` — value type; при сдвиге слайдера температуры секция **не** перерисовывается
- `RiskMeterCard` получает только примитивные типы — view identity стабильна
- `GarmentItem.id: String` (не UUID) — стабильный идентификатор между кадрами
- `RiskMeterBar.gradient` — `private static let`, создаётся один раз
