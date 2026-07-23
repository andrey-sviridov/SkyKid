import Foundation

// MARK: - EffectiveTemperatureCalculator §2

enum EffectiveTemperatureCalculator {

    struct Input: Sendable {
        let weather: NormalizedWeather
    }

    struct Output: Sendable {
        let effects: WeatherThermalEffects
        let V_calc: Double
        let precipFlags: PrecipFlags
        let steps: [CalcStep]

        var T_eff: Double { effects.effectiveTemperature }
        var T_wc: Double { effects.windChillTemperature }
        var T_hi: Double { effects.heatIndexTemperature }
    }

    struct PrecipFlags: Equatable, Sendable {
        let needsRainCover: Bool
        let noWalkInRain: Bool
    }

    static func calculate(_ input: Input) -> Output {
        let weather = input.weather
        let temperature = weather.temperature
        let humidity = Double(weather.humidity)
        let windKmh = weather.windSpeed * 3.6
        let gustKmh = weather.windGust * 3.6
        let gustWeight = OutfitConfig.EffectiveTemp.gustBlendFactor
        let calculatedWind = windKmh * (1 - gustWeight) + gustKmh * gustWeight

        let windChill = computeWindChill(T: temperature, V_calc: calculatedWind)
        let heatIndex = computeHeatIndex(T: temperature, RH: humidity, V_calc: calculatedWind)
        let humidityEffect = humidityDelta(T: temperature, RH: humidity)
        let (precipitationEffect, precipFlags) = precipitationEffect(for: weather.precipType)
        let solarEffect = solarDelta(cloud: weather.cloudCover, uv: weather.uvIndex)

        let effects = WeatherThermalEffects(
            airTemperature: temperature,
            windChillTemperature: windChill,
            heatIndexTemperature: heatIndex,
            windDelta: windChill - temperature,
            heatDelta: heatIndex - temperature,
            humidityDelta: humidityEffect,
            precipitationDelta: precipitationEffect,
            solarDelta: solarEffect
        )

        return Output(
            effects: effects,
            V_calc: calculatedWind,
            precipFlags: precipFlags,
            steps: calculationSteps(effects: effects, calculatedWind: calculatedWind, humidity: humidity)
        )
    }
}

// MARK: - Wind chill

extension EffectiveTemperatureCalculator {
    /// Environment Canada formulas. The low-wind branch joins the standard
    /// branch at 5 km/h, avoiding a discontinuity around the old threshold.
    static func computeWindChill(T: Double, V_calc: Double) -> Double {
        guard V_calc > 0, T < OutfitConfig.EffectiveTemp.windChillFadeOutAbove else {
            return T
        }

        let rawWindChill: Double
        if V_calc < OutfitConfig.EffectiveTemp.windChillStandardSpeedKmh {
            rawWindChill = T
                + ((-1.59 + 0.1345 * T) / 5)
                * V_calc
        } else {
            let v016 = pow(V_calc, 0.16)
            rawWindChill = 13.12
                + 0.6215 * T
                - 11.37 * v016
                + 0.3965 * T * v016
        }

        let fade = 1 - smoothStep(
            from: OutfitConfig.EffectiveTemp.windChillFullEffectBelow,
            to: OutfitConfig.EffectiveTemp.windChillFadeOutAbove,
            value: T
        )
        return T + min(rawWindChill - T, 0) * fade
    }
}

// MARK: - Heat index

extension EffectiveTemperatureCalculator {
    static func computeHeatIndex(T: Double, RH: Double, V_calc: Double) -> Double {
        guard T > OutfitConfig.EffectiveTemp.heatIndexApplyAbove else { return T }

        let vaporPressure = (RH / 100)
            * OutfitConfig.EffectiveTemp.heatIndexVaporA
            * exp(
                OutfitConfig.EffectiveTemp.heatIndexVaporB * T
                    / (OutfitConfig.EffectiveTemp.heatIndexVaporC + T)
            )
        let rawHeatIndex = T
            + OutfitConfig.EffectiveTemp.heatIndexHumidFactor * vaporPressure
            - OutfitConfig.EffectiveTemp.heatIndexBaseDrop
            - OutfitConfig.EffectiveTemp.heatIndexWindCoolFactor * V_calc
        let activation = smoothStep(
            from: OutfitConfig.EffectiveTemp.heatIndexApplyAbove,
            to: OutfitConfig.EffectiveTemp.heatIndexFullEffectAbove,
            value: T
        )
        return T + max(rawHeatIndex - T, 0) * activation
    }
}

// MARK: - Humidity, precipitation and sun

private extension EffectiveTemperatureCalculator {
    static func humidityDelta(T: Double, RH: Double) -> Double {
        let humidityFactor = smoothStep(
            from: OutfitConfig.EffectiveTemp.humidEffectStartsAtRH,
            to: OutfitConfig.EffectiveTemp.humidEffectFullAtRH,
            value: RH
        )
        let coldEntry = smoothStep(
            from: OutfitConfig.EffectiveTemp.humidColdFadeInBelow,
            to: OutfitConfig.EffectiveTemp.humidColdFullAbove,
            value: T
        )
        let warmExit = 1 - smoothStep(
            from: OutfitConfig.EffectiveTemp.humidColdFadeOutStarts,
            to: OutfitConfig.EffectiveTemp.humidColdFadeOutEnds,
            value: T
        )
        return OutfitConfig.EffectiveTemp.humidMaxColdDelta
            * humidityFactor
            * min(coldEntry, warmExit)
    }

    static func precipitationEffect(
        for precipitation: PrecipType
    ) -> (Double, PrecipFlags) {
        switch precipitation {
        case .none:
            return (0, PrecipFlags(needsRainCover: false, noWalkInRain: false))
        case .drizzle, .lightRain:
            return (
                OutfitConfig.EffectiveTemp.precipRainDelta,
                PrecipFlags(needsRainCover: true, noWalkInRain: false)
            )
        case .rain:
            return (
                OutfitConfig.EffectiveTemp.precipRainDelta,
                PrecipFlags(needsRainCover: true, noWalkInRain: true)
            )
        case .snow:
            return (
                OutfitConfig.EffectiveTemp.precipSnowDelta,
                PrecipFlags(needsRainCover: false, noWalkInRain: false)
            )
        }
    }

    static func solarDelta(cloud: Double, uv: Double) -> Double {
        let uvFactor = smoothStep(
            from: OutfitConfig.EffectiveTemp.sunEffectStartsAtUV,
            to: OutfitConfig.EffectiveTemp.sunEffectFullAtUV,
            value: uv
        )
        let cloudFactor = 1 - smoothStep(
            from: OutfitConfig.EffectiveTemp.sunCloudFadeStartsPct,
            to: OutfitConfig.EffectiveTemp.sunCloudNoGainPct,
            value: cloud
        )
        return OutfitConfig.EffectiveTemp.sunMaximumBonus * uvFactor * cloudFactor
    }
}

// MARK: - Calculation trace

private extension EffectiveTemperatureCalculator {
    static func calculationSteps(
        effects: WeatherThermalEffects,
        calculatedWind: Double,
        humidity: Double
    ) -> [CalcStep] {
        var steps = [CalcStep(
            label: L10n.text("Итог внешней среды (§2)"),
            value: effects.effectiveTemperature,
            unit: "°C",
            note: L10n.text("Все погодные вклады рассчитаны один раз")
        )]

        appendStep(
            label: L10n.text("Ветер (§2.1)"),
            delta: effects.windDelta,
            note: L10n.format("V_calc = %.1f км/ч", calculatedWind),
            to: &steps
        )
        appendStep(
            label: L10n.text("Тепловой индекс (§2.2)"),
            delta: effects.heatDelta,
            note: "RH = \(Int(humidity))%",
            to: &steps
        )
        appendStep(
            label: L10n.text("Влажность (§2.3)"),
            delta: effects.humidityDelta,
            note: "RH = \(Int(humidity))%",
            to: &steps
        )
        appendStep(
            label: L10n.text("Осадки (§2.4)"),
            delta: effects.precipitationDelta,
            to: &steps
        )
        appendStep(
            label: L10n.text("Солнце (§2.5)"),
            delta: effects.solarDelta,
            to: &steps
        )
        return steps
    }

    static func appendStep(
        label: String,
        delta: Double,
        note: String? = nil,
        to steps: inout [CalcStep]
    ) {
        guard abs(delta) > 0.001 else { return }
        steps.append(CalcStep(label: label, value: delta, unit: "°C", note: note))
    }
}

// MARK: - Continuous interpolation

private extension EffectiveTemperatureCalculator {
    static func smoothStep(from lower: Double, to upper: Double, value: Double) -> Double {
        guard upper > lower else { return value >= upper ? 1 : 0 }
        let normalized = min(max((value - lower) / (upper - lower), 0), 1)
        return normalized * normalized * (3 - 2 * normalized)
    }
}
