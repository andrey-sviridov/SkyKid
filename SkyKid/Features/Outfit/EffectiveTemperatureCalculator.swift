import Foundation

// MARK: - EffectiveTemperatureCalculator §2

enum EffectiveTemperatureCalculator {

    struct Input: Sendable {
        let weather: WeatherData
        let gearSetup: GearSetup
    }

    struct Output: Sendable {
        let T_eff: Double       // final effective temperature (°C)
        let T_wc: Double        // wind chill value used (may equal T if condition not met)
        let T_hi: Double        // heat index value used (may equal T if condition not met)
        let V_calc: Double      // blended wind speed (km/h) for §3 reuse
        let precipFlags: PrecipFlags
        let steps: [CalcStep]
    }

    struct PrecipFlags: Sendable {
        let needsRainCover: Bool
        let noWalkInRain: Bool
    }

    static func calculate(_ input: Input) -> Output {
        let T  = input.weather.temperature
        let RH = Double(input.weather.humidity)
        // Convert m/s → km/h for wind chill formula
        let V_ms   = input.weather.windSpeed
        let Vg_ms  = input.weather.windGust
        let V_kmh  = V_ms * 3.6
        let Vg_kmh = Vg_ms * 3.6
        let V_calc = V_kmh * (1 - OutfitConfig.EffectiveTemp.gustBlendFactor)
                   + Vg_kmh * OutfitConfig.EffectiveTemp.gustBlendFactor  // §2.1

        var steps: [CalcStep] = []

        // §2.1 Wind Chill
        let T_wc = computeWindChill(T: T, V_calc: V_calc)
        if T_wc < T {
            steps.append(CalcStep(label: "Ветро-холодовой индекс (§2.1)",
                                  value: T_wc, unit: "°C",
                                  note: "V_calc = \(String(format: "%.1f", V_calc)) км/ч"))
        }

        // §2.2 Heat Index
        let T_hi = computeHeatIndex(T: T, RH: RH, V_calc: V_calc)
        if T_hi > T {
            steps.append(CalcStep(label: "Тепловой индекс (§2.2)",
                                  value: T_hi, unit: "°C",
                                  note: "RH = \(Int(RH))%"))
        }

        // §2.6 base
        let base: Double
        if T <= OutfitConfig.EffectiveTemp.windChillApplyBelow {
            base = T_wc
        } else if T >= OutfitConfig.EffectiveTemp.heatIndexApplyAbove {
            base = T_hi
        } else {
            base = T
        }

        // §2.3 Humidity-Cold Penalty
        let dtHumid = humidityDelta(T: T, RH: RH)
        if dtHumid != 0 {
            steps.append(CalcStep(label: "Влажный холод (§2.3)",
                                  value: dtHumid, unit: "°C",
                                  note: "RH = \(Int(RH))%"))
        }

        // §2.4 Precipitation
        let (dtPrecip, precipFlags) = precipDelta(precip: input.weather.precipType,
                                                   rainCover: input.gearSetup.rainCover)
        if dtPrecip != 0 {
            steps.append(CalcStep(label: "Осадки (§2.4)",
                                  value: dtPrecip, unit: "°C", note: nil))
        }

        // §2.5 Sun Bonus
        let dtSun = sunBonus(cloud: input.weather.cloudCover,
                             uv: input.weather.uvIndex,
                             gearSetup: input.gearSetup)
        if dtSun != 0 {
            steps.append(CalcStep(label: "Солнечная поправка (§2.5)",
                                  value: dtSun, unit: "°C", note: nil))
        }

        let T_eff = base + dtHumid + dtPrecip + dtSun
        steps.insert(CalcStep(label: "База T_eff (§2.6)",
                               value: T_eff, unit: "°C",
                               note: "T=\(String(format:"%.1f",T))°C → T_eff"), at: 0)

        return Output(T_eff: T_eff, T_wc: T_wc, T_hi: T_hi,
                      V_calc: V_calc, precipFlags: precipFlags, steps: steps)
    }

    // MARK: - §2.1 Wind Chill formula (Environment Canada / NWS)

    static func computeWindChill(T: Double, V_calc: Double) -> Double {
        guard T <= OutfitConfig.EffectiveTemp.windChillApplyBelow,
              V_calc >= OutfitConfig.EffectiveTemp.windChillMinSpeedKmh else { return T }
        let v016 = pow(V_calc, 0.16)
        let wc = 13.12 + 0.6215 * T - 11.37 * v016 + 0.3965 * T * v016
        return min(wc, T) // wind chill never warmer than air temp
    }

    // MARK: - §2.2 Heat Index (Steadman simplified)

    static func computeHeatIndex(T: Double, RH: Double, V_calc: Double) -> Double {
        guard T >= OutfitConfig.EffectiveTemp.heatIndexApplyAbove else { return T }
        let e = (RH / 100.0) * OutfitConfig.EffectiveTemp.heatIndexVaporA
              * exp(OutfitConfig.EffectiveTemp.heatIndexVaporB * T
                    / (OutfitConfig.EffectiveTemp.heatIndexVaporC + T))
        var hi = T + OutfitConfig.EffectiveTemp.heatIndexHumidFactor * e
                   - OutfitConfig.EffectiveTemp.heatIndexBaseDrop
        hi -= OutfitConfig.EffectiveTemp.heatIndexWindCoolFactor * V_calc
        return max(hi, T) // wind never lowers heat index below air temp
    }

    // MARK: - §2.3 Humidity-Cold Penalty

    private static func humidityDelta(T: Double, RH: Double) -> Double {
        guard T >= OutfitConfig.EffectiveTemp.humidColdApplyMinTemp,
              T <= OutfitConfig.EffectiveTemp.humidColdApplyMaxTemp else { return 0 }
        if RH >= OutfitConfig.EffectiveTemp.humidHighRHThreshold {
            return OutfitConfig.EffectiveTemp.humidHighDelta
        } else if RH >= OutfitConfig.EffectiveTemp.humidModRHThreshold {
            return OutfitConfig.EffectiveTemp.humidModDelta
        }
        return 0
    }

    // MARK: - §2.4 Precipitation

    private static func precipDelta(precip: PrecipType, rainCover: RainCoverState) -> (Double, PrecipFlags) {
        let covered = (rainCover == .present_on)
        switch precip {
        case .none:
            return (0, PrecipFlags(needsRainCover: false, noWalkInRain: false))
        case .drizzle:
            if covered { return (0, PrecipFlags(needsRainCover: false, noWalkInRain: false)) }
            return (OutfitConfig.EffectiveTemp.precipRainDelta, PrecipFlags(needsRainCover: true, noWalkInRain: false))
        case .lightRain:
            if covered { return (0, PrecipFlags(needsRainCover: false, noWalkInRain: false)) }
            return (OutfitConfig.EffectiveTemp.precipRainDelta, PrecipFlags(needsRainCover: true, noWalkInRain: false))
        case .rain:
            if covered { return (0, PrecipFlags(needsRainCover: false, noWalkInRain: false)) }
            return (OutfitConfig.EffectiveTemp.precipRainDelta, PrecipFlags(needsRainCover: true, noWalkInRain: true))
        case .snow:
            return (OutfitConfig.EffectiveTemp.precipSnowDelta, PrecipFlags(needsRainCover: false, noWalkInRain: false))
        }
    }

    // MARK: - §2.5 Sun Bonus

    private static func sunBonus(cloud: Double, uv: Double, gearSetup: GearSetup) -> Double {
        // Only applies if child is actually exposed: hood down OR active walk (pushchair open)
        let isExposed = !gearSetup.hoodUp || gearSetup.transportMode == .pushchairSeat
        guard isExposed else {
            // Pram bassinet with hood up: halve the value
            let full = sunBonusFull(cloud: cloud, uv: uv)
            return full * OutfitConfig.EffectiveTemp.sunHoodHalveFactor
        }
        return sunBonusFull(cloud: cloud, uv: uv)
    }

    private static func sunBonusFull(cloud: Double, uv: Double) -> Double {
        if cloud <= OutfitConfig.EffectiveTemp.sunBrightCloudMaxPct,
           uv >= OutfitConfig.EffectiveTemp.sunMinUV {
            return OutfitConfig.EffectiveTemp.sunBrightBonus
        } else if cloud <= OutfitConfig.EffectiveTemp.sunPartCloudMaxPct {
            return OutfitConfig.EffectiveTemp.sunPartBonus
        }
        return 0
    }
}
