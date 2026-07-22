# Соглашения кода SkyKid

## Swift / SwiftUI

- Нет `!` force-unwrap — только `guard let` / `if let`
- `async/await` везде, колбеков нет
- Долгоживущие VM с побочными эффектами: `@MainActor @Observable final class`; локальное состояние формы допускает value-type
- `@unchecked Sendable` допустим только на синглтонах поверх thread-safe хранилищ (как `ChildProfileStore`)
- Размеры в коде без констант; при рефакторинге выносить в `Design.swift` (не создан)
- Локализация не подключена — строки вшиты напрямую

## SOLID-специфичное

- Safety constraints в `WardrobeModel.riskLevel` — через guards `isExtremeHeat`/`isExtremeCold` **перед** зональной логикой. Порядок проверок не менять.
- Основная рекомендация одежды проходит только через `OutfitRecommendationService` и `OutfitSolver`; legacy CLO-подборщик не может подменять их результат
- UI, журнал, виджет и Siri получают результат только из `BuildOutfitRecommendationUseCase` / `OutfitRecommendationSnapshot`; запасный параллельный расчёт запрещён
- Температуры берутся из `OutfitRecommendation.temperatures`, а не из поиска `CalcStep` по текстовой метке
- Медицинские ограничения применяются после персонализации и имеют над ней приоритет
- Персонализация меняется только через `PersonalizationEngine`: одно нажатие не обучает, шаг не превышает 0,2 TOG, итоговый диапазон ограничен ±1,0 TOG
- `comfortable` является подтверждением и не уменьшает накопленный offset; журнал обязан replace/remove observation по стабильному `WalkLog.id`
- Постоянные данные ребёнка хранятся в `ChildThermalProfile`; самочувствие, температура тела, активность, транспорт и утепление всегда передаются отдельным `WalkContext`
- `WalkContext` нельзя делать `Codable` или сохранять в `UserDefaults`/App Group; перезапуск не должен переносить острую болезнь или выбор коляски в новую прогулку
- Основной расчёт принимает `ChildThermalProfile + WalkContext`; overload с `ChildProfile + GearSetup` считается только legacy-мостом
- Погодные адаптеры не создают `NormalizedWeather` напрямую: они сохраняют `nil` в `RawWeatherObservation` и вызывают единый `WeatherNormalizer`
- Отсутствующее погодное поле нельзя кодировать нулём; защитная подстановка обязана иметь `WeatherFieldStatus` с качеством и причиной
- Ветер, жара, влажность, осадки и солнце вычисляются один раз в `WeatherThermalEffects`; транспорт может только масштабировать готовые компоненты через `TransportExposureProfile`
- Конверт и плед учитываются только как TOG в `OutfitSolver`; запрещено дополнительно повышать ими `T_micro`
- Пороговые погодные функции должны быть непрерывными либо иметь зафиксированный тест на допустимый скачок
- SwiftUI-компоненты предупреждений размещаются отдельно от вычислителей и не меняют доменный результат
- Основной экран одежды начинает с `OutfitParentSummary`; техническая трассировка и промежуточные температуры по умолчанию свёрнуты
- Уверенность родительского ответа равна минимальной из уверенности погоды и точности доступного комплекта; UI не должен повышать её самостоятельно
- Недостающие вещи показываются как необязательные альтернативы с безопасным fallback-действием, а не как предметы уже выбранного комплекта
- `OutfitRecommendationSnapshot.generatedAt` привязан к моменту получения погоды; локальный пересчёт не может продлевать `expiresAt`
- Виджет и Siri обязаны показывать время/контекст снимка и не показывать одежду после истечения TTL
- Повторяющиеся уведомления не содержат конкретную одежду или температуру: они предлагают открыть приложение и обновить условия
- Формулировка погодного окна не может обещать, что условия «безопасны» или однозначно «подходят»
- `GarmentCatalog.byID` / `byLayer` — единственный источник данных гардероба; не создавать дублирующих lookup-таблиц
- `idealBandCLO = 0.2` — `private static let` в `WardrobeModel`; все ссылки через `Self.idealBandCLO`

## Accessibility

- Не ограничивать родительские и safety-тексты `lineLimit`; использовать вертикально расширяемый текст
- При `dynamicTypeSize.isAccessibilitySize` горизонтальные группы ключевых действий переводить в вертикальную раскладку
- Интерактивная область кнопок и строк выбора — не менее 44 pt; основное действие формы прогулки доступно у нижнего края
- Декоративные символы скрывать от VoiceOver, а визуально составные строки объединять в одно осмысленное accessibility-описание
- Подробная матрица и обязательная ручная проверка перед релизом описаны в `docs/accessibility.md`

## Виджет

- `ChildProfile.swift`, `ChildThermalProfile.swift`, `OutfitOutputModels.swift`, `OutfitRecommendationSnapshot.swift` и `RecommendationSnapshotStore.swift` должны быть в Target Membership обоих таргетов
- `ChildProfileStore.swift` — только основной таргет (виджет не использует)
- Новые файлы в `Core/` или `Features/` нужно добавлять в `project.pbxproj` вручную (pbxproj использует custom IDs F001–F021+)

## Производительность (ClothingCalculatorView)

- `ClothingConstructorSection` получает `selectedItems: Set<GarmentItem>` — value type; при сдвиге слайдера температуры секция **не** перерисовывается
- `RiskMeterCard` получает только примитивные типы — view identity стабильна
- `GarmentItem.id: String` (не UUID) — стабильный идентификатор между кадрами
- `RiskMeterBar.gradient` — `private static let`, создаётся один раз
