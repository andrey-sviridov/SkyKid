import XCTest
@testable import SkyKid

// MARK: - WeatherNormalizerTests

@MainActor
final class WeatherNormalizerTests: XCTestCase {

    // MARK: - Missing values

    func test_missingTemperature_throwsInsteadOfInventingWeather() {
        let raw = RawWeatherObservation(source: .openMeteo, temperature: nil)

        XCTAssertThrowsError(try WeatherNormalizer.normalize(raw)) { error in
            XCTAssertEqual(error as? WeatherNormalizationError, .missingTemperature)
        }
    }

    // MARK: - Durable weather provenance

    func test_completeNormalizedWeather_createsVersionedSnapshotWithQuality() throws {
        let weather = try WeatherNormalizer.normalize(
            completeObservation(source: .openMeteo)
        )
        let capturedAt = Date(timeIntervalSince1970: 1_755_000_000)
        let snapshot = try XCTUnwrap(
            WeatherSnapshot(
                normalizedWeather: weather,
                capturedAt: capturedAt,
                staleAfter: 7_200
            )
        )

        XCTAssertEqual(snapshot.schemaVersion, WeatherSnapshot.currentSchemaVersion)
        XCTAssertEqual(snapshot.provider, .openMeteo)
        XCTAssertEqual(snapshot.capturedAt, capturedAt)
        XCTAssertEqual(snapshot.temperature ?? .nan, 12, accuracy: 0.001)
        XCTAssertEqual(snapshot.apparentTemperature, 10)
        XCTAssertEqual(snapshot.status(for: .temperature)?.quality, .observed)
        XCTAssertEqual(snapshot.status(for: .hourlyForecast)?.quality, .observed)
    }

    func test_partialNormalizedWeather_preservesOptionalUnknownsAndQuality() throws {
        let weather = try WeatherNormalizer.normalize(
            RawWeatherObservation(source: .weatherAPI, temperature: 20)
        )
        let snapshot = try XCTUnwrap(
            WeatherSnapshot(
                normalizedWeather: weather,
                capturedAt: Date(timeIntervalSince1970: 1_755_000_000)
            )
        )

        XCTAssertNil(snapshot.uvIndex)
        XCTAssertNil(snapshot.cloudCover)
        XCTAssertEqual(snapshot.status(for: .uvIndex)?.quality, .unavailable)
        XCTAssertEqual(snapshot.status(for: .cloudCover)?.quality, .unavailable)
        XCTAssertEqual(snapshot.status(for: .apparentTemperature)?.quality, .estimated)
        XCTAssertEqual(snapshot.apparentTemperature, 20)
    }

    func test_missingCoreTemperature_cannotCreateSnapshot() {
        XCTAssertNil(
            WeatherSnapshot(
                provider: .openMeteo,
                temperature: nil,
                capturedAt: Date(timeIntervalSince1970: 1_755_000_000)
            )
        )
    }

    func test_snapshotRoundTrip_preservesProvenance() throws {
        let snapshot = try XCTUnwrap(
            WeatherSnapshot(
                provider: .yandex,
                temperature: 4,
                apparentTemperature: 1,
                humidity: nil,
                weatherCode: 61,
                fieldStatuses: [
                    .temperature: WeatherSnapshotFieldStatus(
                        origin: .provider,
                        quality: .observed,
                        note: nil
                    ),
                    .humidity: WeatherSnapshotFieldStatus(
                        origin: .safetyFallback,
                        quality: .unavailable,
                        note: "not returned"
                    )
                ],
                capturedAt: Date(timeIntervalSince1970: 1_755_000_000),
                staleAfter: 600
            )
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WeatherSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.status(for: .humidity)?.note, "not returned")
        XCTAssertEqual(decoded.freshnessInput.staleAfter, 600)
    }

    func test_snapshotFreshness_isDeterministicAtBoundary() throws {
        let capturedAt = Date(timeIntervalSince1970: 1_755_000_000)
        let snapshot = try XCTUnwrap(
            WeatherSnapshot(
                provider: .manual,
                temperature: 10,
                capturedAt: capturedAt,
                staleAfter: 120
            )
        )

        XCTAssertEqual(
            snapshot.freshness(at: capturedAt.addingTimeInterval(119.999)),
            .fresh
        )
        XCTAssertEqual(
            snapshot.freshness(at: capturedAt.addingTimeInterval(120)),
            .stale
        )
    }

    func test_snapshotWithFutureCaptureTime_isNotFresh() throws {
        let now = Date(timeIntervalSince1970: 1_755_000_000)
        let snapshot = try XCTUnwrap(
            WeatherSnapshot(
                provider: .openMeteo,
                temperature: 10,
                capturedAt: now.addingTimeInterval(60)
            )
        )

        XCTAssertEqual(snapshot.freshness(at: now), .stale)
        XCTAssertFalse(snapshot.isFresh(at: now))
    }

    func test_missingGust_usesSustainedWindAndMarksValueDerived() throws {
        let weather = try WeatherNormalizer.normalize(
            completeObservation(source: .openWeatherMap, windSpeed: 5, windGust: nil)
        )

        XCTAssertEqual(weather.windGust, 5, accuracy: 0.001)
        XCTAssertEqual(weather.status(for: .windGust).quality, .derived)
        XCTAssertEqual(weather.status(for: .windGust).origin, .derivedFromProvider)
    }

    func test_missingUVAndCloudCover_disableUnconfirmedSolarBonus() throws {
        let raw = RawWeatherObservation(
            source: .weatherAPI,
            temperature: 20,
            apparentTemperature: 20,
            humidity: 60,
            windSpeed: 0,
            windDirection: 0,
            precipitation: 0,
            weatherCode: 0,
            windGust: 0,
            uvIndex: nil,
            cloudCover: nil
        )
        let weather = try WeatherNormalizer.normalize(raw)
        let output = EffectiveTemperatureCalculator.calculate(.init(weather: weather))

        XCTAssertEqual(weather.uvIndex, 0, accuracy: 0.001)
        XCTAssertEqual(weather.cloudCover, 100, accuracy: 0.001)
        XCTAssertEqual(weather.status(for: .uvIndex).quality, .unavailable)
        XCTAssertEqual(weather.status(for: .cloudCover).quality, .unavailable)
        XCTAssertEqual(output.T_eff, 20, accuracy: 0.001)
        XCTAssertFalse(output.steps.contains { $0.label.contains("Солнечная поправка") })
    }

    func test_missingPrecipitation_derivesConservativeAmountFromRainCode() throws {
        let raw = completeObservation(
            source: .yandex,
            precipitation: nil,
            weatherCode: 61
        )
        let weather = try WeatherNormalizer.normalize(raw)

        XCTAssertGreaterThan(weather.precipitation, 0)
        XCTAssertEqual(weather.precipType, .lightRain)
        XCTAssertEqual(weather.status(for: .precipitation).quality, .derived)
    }

    // MARK: - Real zero values

    func test_observedZeroValues_areNotTreatedAsMissing() throws {
        let weather = try WeatherNormalizer.normalize(
            completeObservation(
                source: .openMeteo,
                windSpeed: 0,
                windGust: 0,
                precipitation: 0,
                uvIndex: 0,
                cloudCover: 0
            )
        )

        XCTAssertEqual(weather.windSpeed, 0, accuracy: 0.001)
        XCTAssertEqual(weather.windGust, 0, accuracy: 0.001)
        XCTAssertEqual(weather.precipitation, 0, accuracy: 0.001)
        XCTAssertEqual(weather.uvIndex, 0, accuracy: 0.001)
        XCTAssertEqual(weather.cloudCover, 0, accuracy: 0.001)
        XCTAssertEqual(weather.status(for: .windGust).quality, .observed)
        XCTAssertEqual(weather.status(for: .precipitation).quality, .observed)
        XCTAssertEqual(weather.status(for: .uvIndex).quality, .observed)
    }

    // MARK: - Provider parity

    func test_identicalProviderValues_produceIdenticalRecommendationInputs() throws {
        let openMeteo = try WeatherNormalizer.normalize(
            completeObservation(source: .openMeteo)
        )
        let weatherAPI = try WeatherNormalizer.normalize(
            completeObservation(source: .weatherAPI)
        )

        XCTAssertEqual(openMeteo.temperature, weatherAPI.temperature)
        XCTAssertEqual(openMeteo.apparentTemperature, weatherAPI.apparentTemperature)
        XCTAssertEqual(openMeteo.windGust, weatherAPI.windGust)
        XCTAssertEqual(openMeteo.precipType, weatherAPI.precipType)
        XCTAssertEqual(openMeteo.confidence.level, weatherAPI.confidence.level)
    }

    // MARK: - Recommendation safety

    func test_degradedWeather_addsDataQualityWarning() throws {
        let weather = try WeatherNormalizer.normalize(
            RawWeatherObservation(source: .openWeatherMap, temperature: 10)
        )
        let birthday = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let profile = ChildProfile(name: "Тест", gender: .girl, birthday: birthday)
        let recommendation = OutfitRecommendationService.shared.recommend(
            weather: weather,
            profile: profile,
            gearSetup: makeExposedPushchair()
        )

        XCTAssertEqual(weather.confidence.level, .low)
        XCTAssertTrue(recommendation.warnings.contains { $0.code == .weatherDataQuality })
    }
}

// MARK: - Fixtures

private extension WeatherNormalizerTests {
    func completeObservation(
        source: WeatherSource,
        windSpeed: Double? = 3,
        windGust: Double? = 5,
        precipitation: Double? = 0,
        weatherCode: Int? = 1,
        uvIndex: Double? = 2,
        cloudCover: Double? = 40
    ) -> RawWeatherObservation {
        RawWeatherObservation(
            source: source,
            temperature: 12,
            apparentTemperature: 10,
            humidity: 70,
            windSpeed: windSpeed,
            windDirection: 180,
            precipitation: precipitation,
            weatherCode: weatherCode,
            windGust: windGust,
            uvIndex: uvIndex,
            cloudCover: cloudCover,
            hourly: [HourlyForecast(
                time: Date(),
                temperature: 12,
                apparentTemperature: 10,
                precipProbability: 0,
                weatherCode: weatherCode ?? 1
            )]
        )
    }

    func makeExposedPushchair() -> GearSetup {
        GearSetup(
            transportMode: .pushchairSeat,
            hoodUp: false,
            rainCover: .notPresent,
            strollerConvertTOG: nil,
            blanketTOG: nil,
            walkType: .regular,
            parentWearingCarrier: false
        )
    }
}
