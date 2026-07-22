import Foundation

// MARK: - WeatherSafetyPolicy

/// Evaluates weather exposure against limits supplied by the age and medical
/// policies. It never changes clothing or makes a medical diagnosis.
enum WeatherSafetyPolicy {

    static func evaluate(
        _ context: SafetyAssessmentContext,
        limits: OutdoorSafetyLimits
    ) -> WeatherSafetyAssessment {
        var warnings: [SafetyWarning] = []
        var nextSaferWindow: DateInterval?

        if context.effectiveTemperature < limits.coldBelow {
            warnings.append(coldExposureWarning(context, limits: limits))
            nextSaferWindow = findNextSaferWindow(
                hourly: context.weather.hourly,
                limits: limits
            )
        } else if context.heatIndexTemperature > limits.hotAbove {
            warnings.append(heatExposureWarning(context, limits: limits))
            nextSaferWindow = findNextSaferWindow(
                hourly: context.weather.hourly,
                limits: limits
            )
        }

        warnings.append(contentsOf: windWarnings(context, limits: limits))
        warnings.append(contentsOf: precipitationWarnings(context))
        warnings.append(contentsOf: ultravioletWarnings(context))

        return WeatherSafetyAssessment(
            warnings: warnings,
            nextSaferWindow: nextSaferWindow
        )
    }
}

// MARK: - Temperature and wind

private extension WeatherSafetyPolicy {
    static func coldExposureWarning(
        _ context: SafetyAssessmentContext,
        limits: OutdoorSafetyLimits
    ) -> SafetyWarning {
        SafetyWarning(
            code: .coldExposureLimit,
            severity: .blocked,
            message: "По консервативному правилу SkyKid прогулку лучше отложить: расчётно "
                + String(format: "%.0f", context.effectiveTemperature)
                + "°C, возрастной ориентир приложения "
                + String(Int(limits.coldBelow))
                + "°C. Одежда не отменяет это ограничение.",
            systemImage: "snowflake.circle.fill"
        )
    }

    static func heatExposureWarning(
        _ context: SafetyAssessmentContext,
        limits: OutdoorSafetyLimits
    ) -> SafetyWarning {
        SafetyWarning(
            code: .heatExposureLimit,
            severity: .blocked,
            message: "По консервативному правилу SkyKid прогулку лучше перенести: с учётом жары около "
                + String(format: "%.0f", context.heatIndexTemperature)
                + "°C, возрастной ориентир приложения "
                + String(Int(limits.hotAbove))
                + "°C.",
            systemImage: "sun.max.trianglebadge.exclamationmark"
        )
    }

    static func windWarnings(
        _ context: SafetyAssessmentContext,
        limits: OutdoorSafetyLimits
    ) -> [SafetyWarning] {
        var warnings: [SafetyWarning] = []
        let isLongExposure = context.gearSetup.walkType == .long
            || context.gearSetup.walkType == .park
        let borderlineCold = context.effectiveTemperature >= limits.coldBelow
            && context.effectiveTemperature
                < limits.coldBelow + OutfitConfig.Safety.longWalkBorderlineTempMargin
        let alreadyBlockedByTemperature = context.effectiveTemperature < limits.coldBelow
            || context.heatIndexTemperature > limits.hotAbove

        if isLongExposure && borderlineCold && !alreadyBlockedByTemperature {
            warnings.append(SafetyWarning(
                code: .longWalkBorderlineTemp,
                severity: .caution,
                message: "Для длинной прогулки условия близки к холодовой границе приложения. Запланируйте короткий маршрут с возможностью быстро зайти в тепло.",
                systemImage: "timer"
            ))
        }

        if context.calculatedWindKmh > OutfitConfig.Safety.strongWindKmh {
            warnings.append(SafetyWarning(
                code: .windWarning,
                severity: .caution,
                message: "Сильный ветер "
                    + String(Int(context.calculatedWindKmh.rounded()))
                    + " км/ч. Сократите выход, избегайте открытых мест и следите за защитой лица без перекрытия дыхания.",
                systemImage: "wind"
            ))
        }

        return warnings
    }
}

// MARK: - Precipitation and UV

private extension WeatherSafetyPolicy {
    static func precipitationWarnings(
        _ context: SafetyAssessmentContext
    ) -> [SafetyWarning] {
        guard context.gearSetup.rainCover != .present_on else { return [] }

        var warnings: [SafetyWarning] = []
        if context.precipitation.needsRainCover {
            let isFreezing = context.microclimateTemperature < 5
            warnings.append(SafetyWarning(
                code: .needsRainCover,
                severity: isFreezing ? .danger : .caution,
                message: isFreezing
                    ? "Осадки и холод: перед выходом защитите коляску от воды. Если одежда намокла, вернитесь в сухое и тёплое место."
                    : "Идут осадки — используйте штатную защиту от дождя и сохраняйте вентиляцию.",
                systemImage: "cloud.rain.fill"
            ))
        }

        if context.precipitation.noWalkInRain {
            warnings.append(SafetyWarning(
                code: .heavyRainWithoutCover,
                severity: .danger,
                message: "Сильный дождь: не начинайте прогулку без штатной защиты или навеса.",
                systemImage: "cloud.heavyrain.fill"
            ))
        }

        return warnings
    }

    static func ultravioletWarnings(
        _ context: SafetyAssessmentContext
    ) -> [SafetyWarning] {
        guard context.weather.uvIndex >= 3 else { return [] }

        let isYoungInfant = context.profile.chronologicalAgeMonths < 6
        let uvValue = String(Int(context.weather.uvIndex))
        if context.weather.uvIndex >= 6 {
            return [SafetyWarning(
                code: .walkTimeWarning,
                severity: .caution,
                message: isYoungInfant
                    ? "Высокий UV " + uvValue + ": младенца до 6 месяцев держите вне прямого солнца; выбирайте тень, закрывающую одежду и панаму. Избегайте пиковых часов 11:00–16:00."
                    : "Высокий UV " + uvValue + ": выбирайте тень, закрывающую одежду и панаму; избегайте пиковых часов 11:00–16:00.",
                systemImage: "sun.max.fill"
            )]
        }

        return [SafetyWarning(
            code: .uvWarning,
            severity: .info,
            message: isYoungInfant
                ? "UV " + uvValue + ": младенца до 6 месяцев держите вне прямого солнца; используйте тень, лёгкую закрывающую одежду и панаму."
                : "UV " + uvValue + ": используйте тень, закрывающую одежду и панаму.",
            systemImage: "sun.haze.fill"
        )]
    }
}

// MARK: - Next safer window

private extension WeatherSafetyPolicy {
    static func findNextSaferWindow(
        hourly: [HourlyForecast],
        limits: OutdoorSafetyLimits
    ) -> DateInterval? {
        let now = Date()
        let horizon = now.addingTimeInterval(24 * 3_600)
        let candidates = hourly
            .filter { $0.time >= now && $0.time <= horizon }
            .sorted { $0.time < $1.time }

        func isWithinProductLimits(_ forecast: HourlyForecast) -> Bool {
            forecast.apparentTemperature > limits.coldBelow
                && forecast.apparentTemperature < limits.hotAbove
                && forecast.precipProbability < 50
        }

        for index in 0..<max(0, candidates.count - 1) {
            let first = candidates[index]
            let second = candidates[index + 1]
            guard second.time.timeIntervalSince(first.time) <= 3_601 else { continue }
            if isWithinProductLimits(first) && isWithinProductLimits(second) {
                return DateInterval(start: first.time, duration: 2 * 3_600)
            }
        }

        return nil
    }
}
