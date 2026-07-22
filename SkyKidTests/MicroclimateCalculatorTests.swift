import XCTest
@testable import SkyKid

// MARK: - MicroclimateCalculatorTests

@MainActor
final class MicroclimateCalculatorTests: XCTestCase {

    // MARK: - Continuous environmental effects

    func test_heatIndex_isContinuousAtActivationTemperature() {
        let below = EffectiveTemperatureCalculator.computeHeatIndex(
            T: 25.99,
            RH: 90,
            V_calc: 3
        )
        let above = EffectiveTemperatureCalculator.computeHeatIndex(
            T: 26.01,
            RH: 90,
            V_calc: 3
        )

        XCTAssertLessThan(abs(above - below), 0.05)
    }

    func test_humidityEffect_isContinuousAroundFormerThreshold() {
        let below = environment(weather(T: 8, RH: 69))
        let above = environment(weather(T: 8, RH: 70))

        XCTAssertLessThan(abs(above.T_eff - below.T_eff), 0.1)
    }

    func test_solarEffect_isContinuousAroundFormerCloudThreshold() {
        let below = environment(weather(T: 20, cloud: 29.99, uv: 5))
        let above = environment(weather(T: 20, cloud: 30.01, uv: 5))

        XCTAssertLessThan(abs(above.T_eff - below.T_eff), 0.01)
    }

    // MARK: - Composed transport protection

    func test_pramHood_reducesWindPenaltyWithoutDroppingOtherEffects() {
        let environment = environment(
            weather(T: 4, V: 8, RH: 90, precip: .snow, cloud: 100)
        )
        let open = microclimate(
            environment: environment,
            gear: gear(transport: .pramBassinette, hoodUp: false)
        )
        let hooded = microclimate(
            environment: environment,
            gear: gear(transport: .pramBassinette, hoodUp: true)
        )
        let effects = environment.effects
        let expectedHooded = effects.airTemperature
            + effects.windDelta * OutfitConfig.Microclimate.pramHoodWindExposure
            + effects.heatDelta
            + effects.humidityDelta
            + effects.precipitationDelta
            + effects.solarDelta * OutfitConfig.Microclimate.hoodSolarExposure

        XCTAssertGreaterThan(hooded.T_micro, open.T_micro)
        XCTAssertEqual(hooded.T_micro, expectedHooded, accuracy: 0.001)
    }

    func test_footmuffTOG_doesNotWarmMicroclimateTwice() {
        let environment = environment(weather(T: 0, V: 5, RH: 75))
        let withoutFootmuff = microclimate(
            environment: environment,
            gear: gear(transport: .pramBassinette, hoodUp: true)
        )
        let withFootmuff = microclimate(
            environment: environment,
            gear: gear(
                transport: .pramBassinette,
                hoodUp: true,
                strollerConvertTOG: 4
            )
        )

        XCTAssertEqual(withFootmuff.T_micro, withoutFootmuff.T_micro, accuracy: 0.001)
    }

    func test_rainCover_composesWindAndPrecipitationProtection() {
        let environment = environment(
            weather(T: 8, V: 7, RH: 85, precip: .lightRain, precipitation: 1)
        )
        let uncovered = microclimate(
            environment: environment,
            gear: gear(transport: .pushchairSeat, hoodUp: true)
        )
        let covered = microclimate(
            environment: environment,
            gear: gear(transport: .pushchairSeat, hoodUp: true, rainCover: .present_on)
        )

        XCTAssertEqual(covered.exposure.precipitation, 0)
        XCTAssertLessThan(covered.exposure.wind, uncovered.exposure.wind)
        XCTAssertGreaterThan(covered.rainCoverHeatGain, 0)
        XCTAssertGreaterThan(covered.T_micro, uncovered.T_micro)
    }

    func test_rainCoverHeatGain_increasesInWarmSunnyConditions() {
        let cold = microclimate(
            environment: environment(weather(T: 0, cloud: 100, uv: 0)),
            gear: gear(transport: .pushchairSeat, hoodUp: true, rainCover: .present_on)
        )
        let warmSunny = microclimate(
            environment: environment(weather(T: 24, cloud: 0, uv: 6)),
            gear: gear(transport: .pushchairSeat, hoodUp: true, rainCover: .present_on)
        )

        XCTAssertGreaterThan(warmSunny.rainCoverHeatGain, cold.rainCoverHeatGain)
        XCTAssertLessThanOrEqual(
            warmSunny.rainCoverHeatGain,
            OutfitConfig.Microclimate.rainCoverMaximumHeatGain
        )
    }

    // MARK: - Carrier and safety

    func test_carrierUnderJacket_usesOutdoorExposureForAccessories() {
        let weather = weather(T: 0, V: 8, RH: 75)
        let environment = environment(weather)
        let carrierGear = gear(
            transport: .carrier,
            hoodUp: false,
            parentWearingCarrier: true
        )
        let microclimate = microclimate(environment: environment, gear: carrierGear)
        let profile = ChildProfile(
            name: "Тест",
            gender: .girl,
            birthday: Date().addingTimeInterval(-90 * 24 * 60 * 60)
        )
        let recommendation = OutfitRecommendationService.shared.recommend(
            weather: weather,
            profile: profile,
            gearSetup: carrierGear
        )

        XCTAssertGreaterThan(microclimate.T_micro, environment.T_eff)
        XCTAssertEqual(microclimate.accessoryTemperature, environment.T_eff, accuracy: 0.001)
        XCTAssertTrue(recommendation.layers.isEmpty)
        let warmHeadwear = recommendation.accessories.first { layer in
            GarmentCatalog.byID[layer.id]?.coveredZones.contains(.head) == true
                && layer.tog >= 0.5
        }
        XCTAssertNotNil(warmHeadwear)
        XCTAssertTrue(recommendation.accessories.contains { $0.id == "mittens" })
    }

    func test_warmRainCover_escalatesGreenhouseWarning() {
        let warmWeather = weather(T: 24, cloud: 0, uv: 6)
        let profile = ChildProfile(
            name: "Тест",
            gender: .boy,
            birthday: Date().addingTimeInterval(-120 * 24 * 60 * 60)
        )
        let recommendation = OutfitRecommendationService.shared.recommend(
            weather: warmWeather,
            profile: profile,
            gearSetup: gear(
                transport: .pushchairSeat,
                hoodUp: true,
                rainCover: .present_on
            )
        )
        let warning = recommendation.warnings.first { $0.code == .rainCoverGreenhouse }

        XCTAssertEqual(warning?.severity, .danger)
        XCTAssertTrue(
            warning?.message.localizedCaseInsensitiveContains("снимите") == true
        )
    }
}

// MARK: - Fixtures

private extension MicroclimateCalculatorTests {
    func weather(
        T: Double,
        V: Double = 0,
        RH: Int = 60,
        precip: PrecipType = .none,
        precipitation: Double = 0,
        cloud: Double = 50,
        uv: Double = 0
    ) -> NormalizedWeather {
        NormalizedWeather(
            temperature: T,
            apparentTemperature: T,
            humidity: RH,
            windSpeed: V,
            windDirection: 0,
            precipitation: precipitation,
            weatherCode: weatherCode(for: precip),
            windGust: V,
            uvIndex: uv,
            cloudCover: cloud,
            precipType: precip
        )
    }

    func weatherCode(for precipitation: PrecipType) -> Int {
        switch precipitation {
        case .none:      return 0
        case .drizzle:   return 51
        case .lightRain: return 61
        case .rain:      return 63
        case .snow:      return 71
        }
    }

    func environment(_ weather: NormalizedWeather) -> EffectiveTemperatureCalculator.Output {
        EffectiveTemperatureCalculator.calculate(.init(weather: weather))
    }

    func microclimate(
        environment: EffectiveTemperatureCalculator.Output,
        gear: GearSetup
    ) -> MicroclimateCalculator.Output {
        MicroclimateCalculator.calculate(.init(environment: environment, gearSetup: gear))
    }

    func gear(
        transport: TransportMode,
        hoodUp: Bool,
        rainCover: RainCoverState = .notPresent,
        strollerConvertTOG: Double? = nil,
        parentWearingCarrier: Bool = false
    ) -> GearSetup {
        GearSetup(
            transportMode: transport,
            hoodUp: hoodUp,
            rainCover: rainCover,
            strollerConvertTOG: strollerConvertTOG,
            blanketTOG: nil,
            walkType: .regular,
            parentWearingCarrier: parentWearingCarrier
        )
    }
}
