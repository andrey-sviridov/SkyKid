import Foundation

// MARK: - MicroclimateCalculator §3

enum MicroclimateCalculator {

    struct Input: Sendable {
        let environment: EffectiveTemperatureCalculator.Output
        let gearSetup: GearSetup
    }

    struct Output: Sendable {
        let T_micro: Double
        let accessoryTemperature: Double
        let carrierUnderJacket: Bool
        let rainCoverHeatGain: Double
        let exposure: TransportExposureProfile
        let strollerAdvice: StrollerAdvice?
        let steps: [CalcStep]
    }

    static func calculate(_ input: Input) -> Output {
        let environment = input.environment
        let effects = environment.effects
        let exposure = TransportExposureProfile.resolve(for: input.gearSetup)

        let windDelta = effects.windDelta * exposure.wind
        let precipitationDelta = effects.precipitationDelta * exposure.precipitation
        let solarDelta = effects.solarDelta * exposure.solar
        let reducedVentilationGain = heatRetentionGain(
            environment: environment,
            windExposure: exposure.wind
        )

        var microclimate = effects.airTemperature
            + windDelta
            + effects.heatDelta
            + effects.humidityDelta
            + precipitationDelta
            + solarDelta
            + reducedVentilationGain
            + exposure.bodyHeatGain

        let rainCoverHeatGain = exposure.isEnclosed && input.gearSetup.rainCover == .present_on
            ? enclosureHeatGain(baseTemperature: microclimate, solarDelta: solarDelta)
            : 0
        microclimate += rainCoverHeatGain

        let jacketGain = max(
            0,
            OutfitConfig.Microclimate.carrierJacketTargetTemperature - microclimate
        ) * exposure.jacketRetention
        microclimate += jacketGain

        let carrierUnderJacket = input.gearSetup.transportMode == .carrier
            && input.gearSetup.parentWearingCarrier
        let accessoryTemperature = carrierUnderJacket
            ? effects.effectiveTemperature
            : microclimate

        return Output(
            T_micro: microclimate,
            accessoryTemperature: accessoryTemperature,
            carrierUnderJacket: carrierUnderJacket,
            rainCoverHeatGain: rainCoverHeatGain,
            exposure: exposure,
            strollerAdvice: strollerAdvice(for: input.gearSetup),
            steps: calculationSteps(
                microclimate: microclimate,
                windDelta: windDelta,
                precipitationDelta: precipitationDelta,
                solarDelta: solarDelta,
                bodyHeatGain: exposure.bodyHeatGain,
                rainCoverHeatGain: rainCoverHeatGain,
                jacketGain: jacketGain,
                exposure: exposure
            )
        )
    }
}

// MARK: - Heat retention

private extension MicroclimateCalculator {
    static func heatRetentionGain(
        environment: EffectiveTemperatureCalculator.Output,
        windExposure: Double
    ) -> Double {
        guard environment.effects.heatDelta > 0 else { return 0 }
        return OutfitConfig.EffectiveTemp.heatIndexWindCoolFactor
            * environment.V_calc
            * (1 - windExposure)
    }

    static func enclosureHeatGain(baseTemperature: Double, solarDelta: Double) -> Double {
        let warmFactor = smoothStep(
            from: OutfitConfig.Microclimate.rainCoverWarmGainStarts,
            to: OutfitConfig.Microclimate.rainCoverWarmGainFullAbove,
            value: baseTemperature
        )
        let gain = OutfitConfig.Microclimate.rainCoverMinimumHeatGain
            + OutfitConfig.Microclimate.rainCoverWarmAdditionalGain * warmFactor
            + max(solarDelta, 0) * OutfitConfig.Microclimate.rainCoverSolarAmplification
        return min(gain, OutfitConfig.Microclimate.rainCoverMaximumHeatGain)
    }
}

// MARK: - Advice and trace

private extension MicroclimateCalculator {
    static func strollerAdvice(for gear: GearSetup) -> StrollerAdvice? {
        guard gear.rainCover == .present_on else { return nil }
        return StrollerAdvice(
            recommendation: L10n.text(
                "Дождевик удерживает тепло и ограничивает вентиляцию. Используйте только от осадков и регулярно проверяйте ребёнка."
            ),
            isSafetyWarning: true
        )
    }

    static func calculationSteps(
        microclimate: Double,
        windDelta: Double,
        precipitationDelta: Double,
        solarDelta: Double,
        bodyHeatGain: Double,
        rainCoverHeatGain: Double,
        jacketGain: Double,
        exposure: TransportExposureProfile
    ) -> [CalcStep] {
        var steps = [CalcStep(
            label: L10n.text("Микроклимат транспорта (§3)"),
            value: microclimate,
            unit: "°C",
            note: L10n.format(
                "ветер %@, осадки %@, солнце %@",
                percent(exposure.wind),
                percent(exposure.precipitation),
                percent(exposure.solar)
            )
        )]

        appendGain(label: L10n.text("Ветер после защиты (§3.1)"), value: windDelta, to: &steps)
        appendGain(label: L10n.text("Осадки после защиты (§3.2)"), value: precipitationDelta, to: &steps)
        appendGain(label: L10n.text("Солнце после защиты (§3.3)"), value: solarDelta, to: &steps)
        appendGain(label: L10n.text("Тепло взрослого (§3.4)"), value: bodyHeatGain, to: &steps)
        appendGain(label: L10n.text("Дождевик и вентиляция (§3.5)"), value: rainCoverHeatGain, to: &steps)
        appendGain(label: L10n.text("Слинг под курткой (§3.6)"), value: jacketGain, to: &steps)
        return steps
    }

    static func appendGain(label: String, value: Double, to steps: inout [CalcStep]) {
        guard abs(value) > 0.001 else { return }
        steps.append(CalcStep(label: label, value: value, unit: "°C", note: nil))
    }

    static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

// MARK: - Continuous interpolation

private extension MicroclimateCalculator {
    static func smoothStep(from lower: Double, to upper: Double, value: Double) -> Double {
        guard upper > lower else { return value >= upper ? 1 : 0 }
        let normalized = min(max((value - lower) / (upper - lower), 0), 1)
        return normalized * normalized * (3 - 2 * normalized)
    }
}
