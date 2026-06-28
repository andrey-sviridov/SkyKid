import Foundation

// MARK: - SafetyRulesEngine §6

enum SafetyRulesEngine {

    struct Input: Sendable {
        let T_eff: Double             // §2 output
        let T_hi: Double              // §2 heat index
        let T_micro: Double           // §3 output
        let V_calc: Double            // blended wind speed km/h
        let TOG_required: Double      // §4 output
        let TOG_base: Double          // §4 base (for fever cap check)
        let strollerAdvice: StrollerAdvice?
        let precipFlags: EffectiveTemperatureCalculator.PrecipFlags
        let weather: WeatherData
        let profile: ChildProfile
        let gearSetup: GearSetup
    }

    struct Output: Sendable {
        let warnings: [SafetyWarning]
        let walkWindow: DateInterval?
        let checkHint: String
    }

    static func evaluate(_ input: Input) -> Output {
        var warnings: [SafetyWarning] = []
        var walkWindow: DateInterval? = nil

        let corrWeeks = input.profile.correctedAgeWeeks
        let isPreterm = input.profile.correctedAgeWeeks < 0
        let hasCardioResp = input.profile.healthConditions.contains(.cardioRespiratory)
        let hasFever = input.profile.healthConditions.contains(.fever)
        let hasColdNoFever = input.profile.healthConditions.contains(.coldNoFever)

        // Determine if preterm/cardioResp thresholds apply
        let usePreterm = (isPreterm || hasCardioResp)
                      && input.profile.correctedAgeWeeks <= (OutfitConfig.Safety.pretermCardioRespMaxCorrMonths * 4)

        // §6.1 No-Walk Thresholds
        let (coldBelow, hotAbove) = noWalkThresholds(corrWeeks: corrWeeks, usePreterm: usePreterm)

        if input.T_eff < coldBelow {
            warnings.append(SafetyWarning(
                code: .noWalkRecommended,
                severity: .danger,
                message: "Слишком холодно для прогулки (T_eff = \(String(format:"%.0f", input.T_eff))°C). Рекомендованный минимум: \(Int(coldBelow))°C.",
                systemImage: "snowflake.circle.fill"
            ))
            walkWindow = nextSaferWindow(hourly: input.weather.hourly,
                                         coldBelow: coldBelow, hotAbove: hotAbove)
        } else if input.T_hi > hotAbove {
            warnings.append(SafetyWarning(
                code: .noWalkRecommended,
                severity: .danger,
                message: "Слишком жарко для прогулки — \(String(format:"%.0f", input.T_hi))°C с учётом ощущений. Выходите до 11:00 или после 16:00.",
                systemImage: "sun.max.trianglebadge.exclamationmark"
            ))
            walkWindow = nextSaferWindow(hourly: input.weather.hourly,
                                         coldBelow: coldBelow, hotAbove: hotAbove)
        }

        // §6.7 Длинная прогулка + пограничная температура
        let isLongExposure = input.gearSetup.walkType == .long || input.gearSetup.walkType == .park
        let margin = OutfitConfig.Safety.longWalkBorderlineTempMargin
        let borderlineCold = input.T_eff >= coldBelow && input.T_eff < coldBelow + margin
        if isLongExposure && borderlineCold && !warnings.contains(where: { $0.code == .noWalkRecommended }) {
            warnings.append(SafetyWarning(
                code: .longWalkBorderlineTemp,
                severity: .caution,
                message: "Длинная прогулка при T_eff \(String(format:"%.0f", input.T_eff))°C: за 40–60 мин ребёнок может переохладиться. Планируйте прогрев или оденьте с запасом.",
                systemImage: "timer"
            ))
        }

        // §6.1 Strong wind
        if input.V_calc > OutfitConfig.Safety.strongWindKmh {
            warnings.append(SafetyWarning(
                code: .windWarning,
                severity: .caution,
                message: "Сильный ветер \(Int(input.V_calc)) км/ч — прогулка не рекомендуется.",
                systemImage: "wind"
            ))
        }

        // §6.3 Rain cover rules — always emit at least an info warning when cover is on
        if input.gearSetup.rainCover == .present_on {
            if input.T_micro >= OutfitConfig.Safety.rainCoverGreenhouseAbove {
                warnings.append(SafetyWarning(
                    code: .rainCoverGreenhouse,
                    severity: .danger,
                    message: "Парниковый эффект под дождевиком при T_micro ≥ 22°C. Используйте навес вместо плёнки.",
                    systemImage: "exclamationmark.triangle.fill"
                ))
            } else if input.T_micro >= OutfitConfig.Safety.rainCoverVentilationAbove {
                warnings.append(SafetyWarning(
                    code: .rainCoverVentilation,
                    severity: .caution,
                    message: "Проветривайте дождевик каждые 15–20 минут при T_micro ≥ 15°C.",
                    systemImage: "wind.snow"
                ))
            } else {
                // Always warn when rain cover is in use (§6.3 baseline)
                warnings.append(SafetyWarning(
                    code: .rainCoverVentilation,
                    severity: .info,
                    message: "Дождевик установлен. При потеплении или долгой прогулке проветривайте каждые 15–20 мин.",
                    systemImage: "cloud.rain.fill"
                ))
            }
        }

        // §2.4 / §5.5 Rain cover — эскалируем при холоде, т.к. мокрая одежда теряет ~35% TOG
        if input.precipFlags.needsRainCover && input.gearSetup.rainCover != .present_on {
            let isCold = input.T_micro < 15
            let isFreezing = input.T_micro < 5
            warnings.append(SafetyWarning(
                code: .needsRainCover,
                severity: isFreezing ? .danger : .caution,
                message: isCold
                    ? "Мокрая одежда теряет до 35% теплоизоляции при \(Int(input.T_micro.rounded()))°C — установите дождевик немедленно."
                    : "Идут осадки — установите дождевик.",
                systemImage: "cloud.rain.fill"
            ))
        }
        if input.precipFlags.noWalkInRain && input.gearSetup.rainCover != .present_on {
            warnings.append(SafetyWarning(
                code: .noWalkRecommended,
                severity: .danger,
                message: "Сильный дождь. Прогулка только под дождевиком/навесом.",
                systemImage: "cloud.heavyrain.fill"
            ))
        }

        // §4.5 Fever
        if hasFever {
            warnings.append(SafetyWarning(
                code: .feverShortWalk,
                severity: .caution,
                message: "У малыша температура. Прогулка короткая (15–20 мин), не кутайте.",
                systemImage: "thermometer.medium"
            ))
        }

        // §4.5 ОРВИ без температуры + мороз
        if hasColdNoFever && input.T_micro < 0 {
            warnings.append(SafetyWarning(
                code: .windWarning,
                severity: .caution,
                message: "ОРВИ + мороз: оденьте шарф / защитите дыхательные пути.",
                systemImage: "lungs.fill"
            ))
        }

        // §5 Wardrobe gap forwarded by solver — added externally in service
        // §6.5 Car seat
        if input.gearSetup.transportMode == .carSeat
            && input.TOG_required > OutfitConfig.Safety.carSeatMaxHarnessLayerTOG {
            warnings.append(SafetyWarning(
                code: .carSeatBulkyCoatWarning,
                severity: .caution,
                message: "В автокресле: не более 1.5 TOG под ремнями. Остальное — пледом поверх пристёгнутых ремней.",
                systemImage: "car.fill"
            ))
        }

        // §5.3 UV warning
        if input.weather.uvIndex >= 6 {
            warnings.append(SafetyWarning(
                code: .walkTimeWarning,
                severity: .caution,
                message: "UV-индекс \(Int(input.weather.uvIndex)): гуляйте до 11:00 или после 16:00.",
                systemImage: "sun.max.fill"
            ))
        } else if input.weather.uvIndex >= 3 {
            warnings.append(SafetyWarning(
                code: .uvWarning,
                severity: .info,
                message: "UV \(Int(input.weather.uvIndex)): панамка обязательна. Детям до 6 мес — только тень, без крема.",
                systemImage: "sun.haze.fill"
            ))
        }

        // §6.4 Sleep in stroller
        if input.profile.babyActivityLevel == .sleeping
            && input.gearSetup.transportMode != .carrier
            && input.gearSetup.rainCover == .present_on
            && input.gearSetup.hoodUp {
            warnings.append(SafetyWarning(
                code: .noWalkRecommended,
                severity: .caution,
                message: "Спящий малыш: убедитесь, что лицо открыто. Не создавайте замкнутый «карман» дождевик+капюшон.",
                systemImage: "zzz"
            ))
        }

        // §6.2 Check hint always shown
        let hint = OutfitConfig.Safety.overheatCheckHint

        return Output(warnings: warnings, walkWindow: walkWindow, checkHint: hint)
    }

    // MARK: - §6.1 Threshold lookup

    private static func noWalkThresholds(corrWeeks: Int, usePreterm: Bool) -> (coldBelow: Double, hotAbove: Double) {
        if usePreterm {
            return (OutfitConfig.Safety.pretermCardioRespColdBelow,
                    OutfitConfig.Safety.pretermCardioRespHotAbove)
        }
        let table = OutfitConfig.Safety.noWalkThresholds
        for entry in table {
            if corrWeeks <= entry.maxCorrWeeks {
                return (entry.coldBelow, entry.hotAbove)
            }
        }
        return (table.last?.coldBelow ?? -15, table.last?.hotAbove ?? 33)
    }

    // MARK: - §6.1 Walk window (P1-3)
    // Ищет ближайшие 2 последовательных часа в пределах суток, где ощущаемая
    // температура внутри безопасных порогов и вероятность осадков < 50 %.
    // apparent_temperature — приближение T_eff (полный §2 по часам не считаем).

    private static func nextSaferWindow(
        hourly: [HourlyForecast],
        coldBelow: Double,
        hotAbove: Double
    ) -> DateInterval? {
        let now = Date()
        let horizon = now.addingTimeInterval(24 * 3_600)
        let candidates = hourly
            .filter { $0.time >= now && $0.time <= horizon }
            .sorted { $0.time < $1.time }

        func isSafe(_ h: HourlyForecast) -> Bool {
            h.apparentTemperature > coldBelow
                && h.apparentTemperature < hotAbove
                && h.precipProbability < 50
        }

        for i in 0..<max(0, candidates.count - 1) {
            let a = candidates[i], b = candidates[i + 1]
            guard b.time.timeIntervalSince(a.time) <= 3_600 + 1 else { continue }
            if isSafe(a) && isSafe(b) {
                return DateInterval(start: a.time, duration: 2 * 3_600)
            }
        }
        return nil
    }
}
