import Foundation

// MARK: - OutfitConfig
// Single source of truth for all calculation constants.
// Every constant is tagged with the spec section it comes from.

enum OutfitConfig {

    // MARK: §2 — Effective Temperature

    enum EffectiveTemp {
        // §2.1 Wind Chill. Low and standard wind formulas meet at 5 km/h;
        // the temperature effect fades continuously between 10 and 12°C.
        static let windChillFullEffectBelow: Double = 10.0  // °C
        static let windChillFadeOutAbove: Double = 12.0     // °C
        static let windChillStandardSpeedKmh: Double = 5.0  // km/h
        static let gustBlendFactor: Double = 0.3            // V_calc = 0.7*V + 0.3*V_gust

        // §2.2 Heat Index (T ≥ heatIndexApplyAbove)
        static let heatIndexApplyAbove: Double = 26.0       // °C
        static let heatIndexFullEffectAbove: Double = 28.0  // °C
        static let heatIndexVaporA: Double = 6.105          // hPa
        static let heatIndexVaporB: Double = 17.27
        static let heatIndexVaporC: Double = 237.7          // °C
        static let heatIndexHumidFactor: Double = 0.33
        static let heatIndexBaseDrop: Double = 4.0
        static let heatIndexWindCoolFactor: Double = 0.07   // wind cooling at high temp

        // §2.3 Humidity-Cold Penalty. Smooth ranges prevent a 1°C jump when
        // humidity changes by a fraction around a threshold.
        static let humidEffectStartsAtRH: Double = 60.0
        static let humidEffectFullAtRH: Double = 90.0
        static let humidColdFadeInBelow: Double = -10.0
        static let humidColdFullAbove: Double = 0.0
        static let humidColdFadeOutStarts: Double = 12.0
        static let humidColdFadeOutEnds: Double = 18.0
        static let humidMaxColdDelta: Double = -1.5          // °C

        // §2.4 Precipitation
        static let precipRainDelta: Double = -1.5           // drizzle / lightRain
        static let precipSnowDelta: Double = -0.5           // snow

        // §2.5 Sun Bonus. UV and cloud effects are continuous.
        static let sunEffectStartsAtUV: Double = 1.0
        static let sunEffectFullAtUV: Double = 5.0
        static let sunCloudFadeStartsPct: Double = 20.0
        static let sunCloudNoGainPct: Double = 90.0
        static let sunMaximumBonus: Double = 2.0             // °C
    }

    // MARK: §3 — Microclimate

    enum Microclimate {
        // Fractions of outdoor exposure that reach the child.
        static let pramOpenWindExposure: Double = 0.75
        static let pramHoodWindExposure: Double = 0.40
        static let pushchairHoodWindExposure: Double = 0.60
        static let carSeatWindExposure: Double = 0.80
        static let hoodSolarExposure: Double = 0.50
        static let pramOpenSolarExposure: Double = 0.85
        static let carSeatSolarExposure: Double = 0.80

        // A fitted rain cover compounds the base transport protection.
        // Heat gains are bounded product heuristics, not a clinical model or
        // a direct measurement for every stroller and cover combination.
        static let rainCoverWindExposureFactor: Double = 0.25
        static let rainCoverMinimumHeatGain: Double = 1.0
        static let rainCoverWarmAdditionalGain: Double = 1.0
        static let rainCoverSolarAmplification: Double = 0.75
        static let rainCoverMaximumHeatGain: Double = 3.5
        static let rainCoverWarmGainStarts: Double = 10.0
        static let rainCoverWarmGainFullAbove: Double = 30.0

        // Parent heat and jacket protection are gradual, never a fixed 19°C.
        static let carrierBodyHeatGain: Double = 4.0
        static let carrierJacketWindExposure: Double = 0.30
        static let carrierJacketPrecipitationExposure: Double = 0.20
        static let carrierJacketSolarExposure: Double = 0.20
        static let carrierJacketRetention: Double = 0.75
        static let carrierJacketTargetTemperature: Double = 19.0
    }

    // MARK: §4 — Required TOG

    enum TOG {
        // §4.1 Base curve anchor points (T_micro °C → TOG_base), ordered hot→cold
        static let baseCurveAnchors: [(temp: Double, tog: Double)] = [
            ( 27.0, 0.2),
            ( 24.0, 0.5),
            ( 21.0, 1.0),
            ( 18.0, 1.5),
            ( 15.0, 2.0),
            ( 10.0, 3.0),
            (  5.0, 4.0),
            (  0.0, 5.0),
            ( -5.0, 6.0),
            (-10.0, 7.0),
            (-15.0, 8.0),
        ]

        // §4.2 Age Adjustment — (correctedAgeWeeks upper bound, coldDelta, hotDelta)
        // coldDelta when T_micro < 18; hotDelta when T_micro >= 24; interpolated 18–24
        static let ageAdjTable: [(maxWeeks: Int, cold: Double, hot: Double)] = [
            ( 4, +1.0, -0.2),   // 0–4 weeks
            (12, +0.7,  0.0),   // 1–3 months (up to ~12 weeks)
            (26, +0.3,  0.0),   // 3–6 months
            (39, +0.1,  0.0),   // 6–9 months
            (52,  0.0,  0.0),   // 9–12 months
        ]
        static let ageAdjColdThreshold: Double = 18.0
        static let ageAdjHotThreshold: Double = 24.0

        // §4.3 Prematurity
        static let pretermDelta: Double = 0.5
        static let pretermGestationThreshold: Int = 34       // weeks
        static let pretermChronoMonthsThreshold: Int = 3     // months

        // §4.4 Activity
        static let actSleepingDelta: Double = 0.5
        static let actCalmDelta: Double = 0.0
        static let actActiveInStrollerDelta: Double = -0.3
        static let actWalkingCrawlingDelta: Double = -1.2    // ASSUMPTION: using spec value; use -1.0 for cautious mode
        static let errandsInOutDelta: Double = -0.5

        // §4.5 Health
        static let feverDelta: Double = -0.5
        static let anemiaOutDelta: Double = 0.3
        // Legacy HealthFeature bridge
        static let legacyFreqIllnessDelta: Double = -0.2
        static let legacyColdSensitiveDelta: Double = 0.3
        static let legacyPrematureDelta: Double = 0.3
        static let legacyHeatSensitiveDelta: Double = -0.3

        // §4.6 Clamp
        static let minTOG: Double = 0.2
        static let maxTOG: Double = 9.0

        // §8 Personal Offset
        static let feedbackStepTOG: Double = 0.2
        static let maxPersonalOffsetTOG: Double = 1.0
    }

    // MARK: §5 — Outfit Solver

    enum Solver {
        static let maxBodyLayers: Int = 4
        static let togAccuracyTolerance: Double = 0.4
        static let mediumConfidenceTolerance: Double = 0.9
        static let agePreferenceBonus: Double = 0.12
        static let carSeatMaxHarnessLayerTOG: Double = 1.5
        // §5.5 Мокрая одежда: хлопок теряет ~70%, флис ~40%, в среднем ~35%
        static let wetClothingRetentionFactor: Double = 0.65
        // TOG конверта, при котором снимается обязательный защитный слой (slip)
        static let footmuffSlipProtectionThreshold: Double = 2.0
        // §5.6 «Тяжёлый» комбез: с этого TOG второй слой верхней одежды
        // (или меховой конверт-гир) трактуется как двойное утепление → перегрев.
        static let heavyOuterTOGThreshold: Double = 3.0
    }

    // MARK: §6 — Safety Rules

    enum Safety {
        // §6.1 No-walk thresholds (correctedAgeWeeks upper bound, cold T_eff below, hot T_hi above)
        static let noWalkThresholds: [(maxCorrWeeks: Int, coldBelow: Double, hotAbove: Double)] = [
            ( 4, -5.0, 30.0),
            (12, -10.0, 32.0),
            (52, -15.0, 33.0),
        ]
        static let pretermCardioRespColdBelow: Double = 0.0    // up to 3 months corrected
        static let pretermCardioRespHotAbove: Double = 28.0
        static let pretermCardioRespMaxCorrMonths: Int = 3

        static let strongWindKmh: Double = 40.0
        // §6.7 Длинная прогулка + пограничная температура
        static let longWalkBorderlineTempMargin: Double = 5.0  // °C ниже порога → зона риска

        // §6.3 Rain Cover
        static let rainCoverVentilationAbove: Double = 15.0    // T_micro threshold
        static let rainCoverGreenhouseAbove: Double = 22.0

    }
}
