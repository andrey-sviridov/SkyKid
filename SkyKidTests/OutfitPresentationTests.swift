import XCTest
@testable import SkyKid

@MainActor
final class OutfitPresentationTests: XCTestCase {
    // MARK: - Parent summary

    func test_parentSummary_startsWithOutfitReasonCheckAndAgeRange() {
        let profile = makeProfile(ageMonths: 24)
        let weather = makeWeather()
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let recommendation = makeRecommendation(
            weather: weather,
            profile: profile,
            context: context
        )

        let summary = OutfitParentSummaryBuilder.make(
            recommendation: recommendation,
            weather: weather,
            profile: profile,
            walkContext: context
        )

        XCTAssertFalse(summary.outfit.isEmpty)
        XCTAssertTrue(summary.reason.contains("в условиях ребёнка"))
        XCTAssertTrue(summary.check.contains("ше"), "Check must mention the neck check")
        XCTAssertTrue(summary.ageContext.contains("1–3 года"))
    }

    func test_parentSummary_usesLowestWeatherAndFitConfidence() {
        let profile = makeProfile(ageMonths: 24)
        let weather = makeWeather(quality: .unavailable)
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let recommendation = makeRecommendation(
            weather: weather,
            profile: profile,
            context: context
        )

        let summary = OutfitParentSummaryBuilder.make(
            recommendation: recommendation,
            weather: weather,
            profile: profile,
            walkContext: context
        )

        XCTAssertEqual(summary.confidence, .low)
        XCTAssertTrue(summary.confidenceReason.contains("погодные данные"))
    }

    // MARK: - Wardrobe alternatives

    func test_recommendationExposesMissingGarmentsAsAlternatives() {
        let profile = makeProfile(ageMonths: 8)
        let weather = makeWeather(temperature: 6)
        let context = WalkContext.standard(for: profile, availableGarmentIDs: [])

        let recommendation = makeRecommendation(
            weather: weather,
            profile: profile,
            context: context
        )

        XCTAssertFalse(recommendation.suggestedAlternatives.isEmpty)
        XCTAssertTrue(recommendation.warnings.contains { $0.code == .wardrobeGap })
    }

    func test_legacyRecommendationJSON_decodesWithoutMissingGarmentsField() throws {
        let profile = makeProfile(ageMonths: 24)
        let weather = makeWeather()
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let recommendation = makeRecommendation(
            weather: weather,
            profile: profile,
            context: context
        )
        let encoded = try JSONEncoder().encode(recommendation)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "missingGarments")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(OutfitRecommendation.self, from: legacyData)

        XCTAssertTrue(decoded.suggestedAlternatives.isEmpty)
    }

    // MARK: - Walk preparation

    func test_selectingCarSeat_clearsAllStrollerInsulation() {
        let profile = makeProfile(ageMonths: 8)
        var context = WalkContext.standard(for: profile, availableGarmentIDs: [])
        context.strollerConvertTOG = 2
        context.blanketTOG = 1
        var viewModel = WalkPreparationViewModel(profile: profile, context: context)

        viewModel.selectTransport(.carSeat)

        XCTAssertNil(viewModel.context.strollerConvertTOG)
        XCTAssertNil(viewModel.context.blanketTOG)
    }

    // MARK: - Fixtures

    private func makeProfile(ageMonths: Int) -> ChildThermalProfile {
        let birthday = Calendar.current.date(
            byAdding: .month,
            value: -ageMonths,
            to: Date()
        ) ?? Date()
        return ChildThermalProfile(
            name: "UX-\(UUID().uuidString.prefix(6))",
            gender: .girl,
            birthday: birthday
        )
    }

    private func makeWeather(
        temperature: Double = 14,
        quality: WeatherFieldQuality = .observed
    ) -> NormalizedWeather {
        let statuses = Dictionary(uniqueKeysWithValues: WeatherField.allCases.map { field in
            (field, WeatherFieldStatus(
                field: field,
                source: .manual,
                origin: quality == .observed ? .provider : .safetyFallback,
                quality: quality,
                note: quality == .observed ? nil : "Test fallback"
            ))
        })

        return NormalizedWeather(
            source: .manual,
            temperature: temperature,
            apparentTemperature: temperature,
            humidity: 55,
            windSpeed: 3,
            windDirection: 180,
            precipitation: 0,
            weatherCode: 1,
            windGust: 3,
            uvIndex: 2,
            cloudCover: 30,
            precipType: PrecipType.none,
            hourly: [],
            fieldStatuses: statuses
        )
    }

    private func makeRecommendation(
        weather: NormalizedWeather,
        profile: ChildThermalProfile,
        context: WalkContext
    ) -> OutfitRecommendation {
        OutfitRecommendationService.shared.recommend(
            weather: weather,
            profile: profile,
            walkContext: context
        )
    }
}
