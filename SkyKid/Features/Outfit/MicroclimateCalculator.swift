import Foundation

// MARK: - MicroclimateCalculator §3

enum MicroclimateCalculator {

    struct Input: Sendable {
        let T: Double          // air temperature °C (for wind chill recalculation)
        let T_eff: Double      // effective temperature from §2
        let V_calc: Double     // blended wind speed km/h from §2.1
        let gearSetup: GearSetup
    }

    struct Output: Sendable {
        let T_micro: Double
        let carrierUnderJacket: Bool   // when true, torso TOG solver is skipped
        let strollerAdvice: StrollerAdvice?
        let steps: [CalcStep]
    }

    static func calculate(_ input: Input) -> Output {
        var steps: [CalcStep] = []

        // Special mode: carrier under parent jacket — torso treated as indoor
        if input.gearSetup.transportMode == .carrier,
           input.gearSetup.parentWearingCarrier {
            let T_micro = OutfitConfig.Microclimate.carrierUnderJacketTorsoTemp
            steps.append(CalcStep(label: "Слинг под курткой (§3)",
                                   value: T_micro, unit: "°C",
                                   note: "Фиксированная температура корпуса"))
            return Output(T_micro: T_micro, carrierUnderJacket: true,
                          strollerAdvice: nil, steps: steps)
        }

        // §3: Determine V_eff multiplier and flat offsets
        let (shieldMult, flatOffset, advice) = shieldConfig(input.gearSetup)

        let V_eff = input.V_calc * shieldMult
        // Re-evaluate wind chill with reduced V_eff
        let T_wc_micro = EffectiveTemperatureCalculator.computeWindChill(T: input.T, V_calc: V_eff)

        // base_micro: use re-evaluated wind chill if conditions met, otherwise T_eff
        let base_micro: Double
        if input.T <= OutfitConfig.EffectiveTemp.windChillApplyBelow,
           V_eff >= OutfitConfig.EffectiveTemp.windChillMinSpeedKmh {
            base_micro = T_wc_micro
        } else {
            base_micro = input.T_eff
        }

        let T_micro = base_micro + flatOffset

        steps.append(CalcStep(label: "Микроклимат коляски (§3)",
                               value: T_micro, unit: "°C",
                               note: "V_eff = \(String(format:"%.1f", V_eff)) км/ч, offset = \(String(format:"+%.1f", flatOffset))°C"))

        return Output(T_micro: T_micro, carrierUnderJacket: false,
                      strollerAdvice: advice, steps: steps)
    }

    // MARK: - §3 Shield configuration table

    private static func shieldConfig(_ gear: GearSetup) -> (multiplier: Double, flatOffset: Double, advice: StrollerAdvice?) {
        // Rain cover takes priority
        if gear.rainCover == .present_on {
            let advice = StrollerAdvice(
                recommendation: "Дождевик установлен — парниковый эффект. Снимайте каждые 15–20 мин для проветривания.",
                isSafetyWarning: true
            )
            return (OutfitConfig.Microclimate.rainCoverOnShield,
                    OutfitConfig.Microclimate.rainCoverOnGreenhouseOffset,
                    advice)
        }

        switch gear.transportMode {
        case .pramBassinette:
            if gear.hoodUp {
                // Check if leg cover also present (strollerConvertTOG signals footmuff = leg cover)
                if gear.strollerConvertTOG != nil {
                    return (OutfitConfig.Microclimate.pramHoodPlusLegCoverShield,
                            OutfitConfig.Microclimate.pramHoodPlusLegCoverFlatOffset,
                            nil)
                }
                return (OutfitConfig.Microclimate.pramHoodUpShield, 0.0, nil)
            }
            return (OutfitConfig.Microclimate.pushchairOpenShield, 0.0, nil)

        case .pushchairSeat:
            return gear.hoodUp
                ? (OutfitConfig.Microclimate.pushchairHoodUpShield, 0.0, nil)
                : (OutfitConfig.Microclimate.pushchairOpenShield, 0.0, nil)

        case .carrier:
            let offset = OutfitConfig.Microclimate.carrierBodyHeatOffset
            return (1.0, offset, nil)  // V not reduced; body heat flat offset

        case .carSeat:
            return (OutfitConfig.Microclimate.pushchairOpenShield, 0.0, nil)
        }
    }
}
