# Алгоритмы SkyKid

## OutfitAdvisor (`Features/Outfit/OutfitAdvisor.swift`)

**OCP-архитектура:** `fileprivate protocol OutfitRule: Sendable`.  
`recommend()` = `rules.flatMap { $0.apply(effectiveTemp:weather:ageGroup:) }`.

Входные данные: `weather.apparentTemperature + ageGroup.temperatureOffset` = `t`

### Порядок правил

| # | Тип | Срабатывает |
|---|---|---|
| 1 | `InfantLayeringRule` | только `.infant` → боди + конверт |
| 2 | `BaseTemperatureRule` | всегда → базовый набор по температуре |
| 3 | `AgeExtrasRule` | `.baby` → носочки; `.toddler` при t < 10 → носки |
| 4 | `NeckProtectionRule` | t < 5 → бафф/снуд/шарф (зависит от возраста) |
| 5 | `WindRule` | windSpeed > 7 м/с → ветровка |
| 6 | `PrecipitationRule` | снег (71–77) → сапоги; дождь (51–82 / >0.1мм) → дождевик + резиновые сапоги |

### BaseTemperatureRule

| t (°C) | Рекомендации |
|---|---|
| < −10 | Зимний комбинезон, термобельё, варежки, зимняя шапка |
| −10…0 | Зимняя куртка, перчатки, шапка |
| 0…5 | Тёплая куртка, перчатки, шапка |
| 5…15 | Куртка, кофта |
| 15…22 | Лёгкая куртка, футболка |
| > 22 | Лёгкая одежда, панамка |

### NeckProtectionRule (t < 5°C)

| Возраст | Рекомендация |
|---|---|
| infant / baby / toddler | Бафф / снуд — шарф опасен (риск удушения на площадке) |
| preschool | Бафф или короткий шарф |
| schoolAge / teen | Шарф |

### Добавить новое правило

1. Создать `private struct MyRule: OutfitRule` в `OutfitAdvisor.swift`
2. Реализовать `func apply(effectiveTemp:weather:ageGroup:) → [OutfitItem]`
3. Вставить в массив `OutfitAdvisor.rules` на нужную позицию

Существующий код не трогать.

---

## WardrobeModel.riskLevel — правила безопасности

Проверки `isExtremeHeat`/`isExtremeCold` выполняются **первыми** — не менять порядок.

### Rule 1 — Extreme Heat (temperature ≥ 30°C)

- `riskLevel` → `.criticalOverheat`
- `riskLabel` → `"ОПАСНО: КРИТИЧЕСКИЙ ПЕРЕГРЕВ"` (красный)
- `riskDetail` → «Не выходите в пиковые часы. Только подгузник...»
- `autoSelect()` → только подгузник, ранний return

### Rule 2 — Extreme Cold (temperature ≤ −10°C)

- `riskLevel` → `.dangerouslyCold`
- `showColdAlert` → баннер «Ограничьте прогулку до 15-20 минут»
- `autoSelect()` → принудительно добавляет `warm_blanket` после жадного цикла

### Rule 3 — Ideal Range Tuning

«Идеально» — **только при** `|heatDeviation| < idealBandCLO` (= 0.2 CLO).  
`private static let idealBandCLO: Double = 0.2` — единственная точка изменения.

- `d > +0.2` → `.warm`
- `d < −0.2` → `.slightlyCold`

### Rule 4 — Layer Limitation

`heavyOuterIDs = ["demi", "winter"]` — взаимоисключающие внешние слои.  
Жадный цикл пропускает второй heavy outer при наличии первого.

### Зональные пороги ThermalRisk

| Зона | criticalOverheat | hot | warm | optimal | slightlyCold | cold | dangerouslyCold |
|---|---|---|---|---|---|---|---|
| A (≥22°C) | d≥1.5 | d>0.5 | Rule3 | d≤0.2 | Rule3 | — | — |
| B (10–22°C) | d≥3.0 | d≥1.5 | Rule3 | ±0.2 | Rule3 | d<−2.5 | — |
| C (<10°C) | — | d≥5.0 | d≥2.0 | ±0.2 | Rule3 | — | d<−4.0 |

### autoSelect() — жадный алгоритм

```
1. Добавить "diaper" (всегда)
2. Если уже optimal → return
3. Выбрать orderedIDs по температурному диапазону (6 диапазонов, isNewborn учитывается)
4. Для каждого id:
   - Пропустить если heavyOuter уже есть
   - Пропустить если добавление → criticalOverheat
   - Пропустить если isOnColdSide && добавление → hot (перепрыгнуть optimal)
   - Добавить; если result == .optimal || .warm → break
5. Если isExtremeCold → force-add "warm_blanket"
```

Граница `case (-10)..<0 where t > -10` исключает −10.0 из тёплого arm (попадает в default → extreme cold список).
