import XCTest
@testable import SkyKid

@MainActor
final class OutfitPresentationTests: XCTestCase {
    func test_shareComposerFullContextIsConciseAndExcludesSensitiveFields() {
        let snapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_750_000_000))
        let profile = makeProfile(ageMonths: 5)
        let weather = makeWeather()
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        let summary = OutfitParentSummaryBuilder.make(
            recommendation: snapshot.recommendation,
            weather: weather,
            profile: profile,
            walkContext: context
        )

        let text = ShareOutfitComposer.compose(
            summary: summary,
            childName: "Лиза",
            weather: weather,
            weatherUpdatedAt: snapshot.generatedAt,
            walkContext: context,
            now: snapshot.generatedAt
        )

        XCTAssertTrue(text.contains("Лиза"))
        XCTAssertTrue(text.contains("Погода актуальна"))
        XCTAssertTrue(text.contains(context.transportMode.walkLabel))
        XCTAssertFalse(text.contains("TOG"))
        XCTAssertFalse(text.contains("healthStatus"))
        XCTAssertFalse(text.contains("latitude"))
        XCTAssertLessThan(text.count, 1_000)
    }

    func test_shareComposerLabelsStaleAndMissingContextHonestly() {
        let snapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_750_000_000))
        let profile = makeProfile(ageMonths: 5)
        let weather = makeWeather()
        let context = WalkContext.standard(for: profile, availableGarmentIDs: [])
        let summary = OutfitParentSummaryBuilder.make(
            recommendation: snapshot.recommendation,
            weather: weather,
            profile: profile,
            walkContext: context
        )
        let stale = ShareOutfitComposer.compose(
            summary: summary,
            childName: " ", weather: nil,
            weatherUpdatedAt: snapshot.generatedAt,
            walkContext: nil,
            now: snapshot.generatedAt.addingTimeInterval(3 * 60 * 60)
        )

        XCTAssertTrue(stale.contains("Рекомендация SkyKid"))
        XCTAssertTrue(stale.contains("Погода могла устареть"))
        XCTAssertTrue(stale.contains("Сценарий прогулки не указан"))
    }

    func test_learningInsightsShowsHonestNoDataAndInsufficientStates() {
        let noData = WalkHistoryInsights.learning(from: nil)
        let insufficient = WalkHistoryInsights.learning(
            from: makePersonalizationSummary(
                similarCount: 1,
                directionalCount: 1,
                netScore: 1,
                explanation: .insufficientEvidence(similarWalkCount: 1)
            )
        )

        XCTAssertEqual(noData.learningState, .noData)
        XCTAssertTrue(noData.adaptation.contains("нескольких похожих прогулок"))
        XCTAssertEqual(insufficient.learningState, .insufficient)
        XCTAssertEqual(insufficient.similarWalkCountText, "1 похожая прогулка")
        XCTAssertTrue(insufficient.adaptation.contains("недостаточно"))
    }

    func test_learningInsightsMapsConsistentAndMixedEvidenceWithoutPercentages() {
        let warmer = WalkHistoryInsights.learning(
            from: makePersonalizationSummary(
                similarCount: 3,
                directionalCount: 2,
                netScore: 2,
                explanation: .prefersWarmer(evidenceCount: 2)
            )
        )
        let mixed = WalkHistoryInsights.learning(
            from: makePersonalizationSummary(
                similarCount: 4,
                directionalCount: 2,
                netScore: 0,
                explanation: .balanced(evidenceCount: 4)
            )
        )

        XCTAssertEqual(warmer.learningState, .warmer)
        XCTAssertEqual(warmer.similarWalkCountText, "3 похожих прогулок")
        XCTAssertTrue(warmer.adaptation.contains("более тёплый"))
        XCTAssertEqual(mixed.learningState, .mixed)
        XCTAssertTrue(mixed.adaptation.contains("базовый расчёт"))
        XCTAssertFalse((warmer.comfortPattern + warmer.adaptation).contains("%"))
    }

    func test_feedbackHistoryItemPresentsRecordedClothingAdjustment() {
        let context = PersonalizationContext(
            microclimateTemperature: 5,
            transportMode: .pushchairSeat,
            activityLevel: .calmAwake,
            walkType: .regular,
            clothingAdjustment: .removedLayer
        )
        let observation = PersonalizationObservation(
            sourceID: UUID(),
            recordedAt: Date(),
            feedback: .comfortable,
            source: .walkLog,
            context: context
        )

        let item = FeedbackHistoryItemBuilder.make(from: [observation]).first

        XCTAssertEqual(item?.clothingAdjustment, "Сняли слой во время прогулки")
    }
    // MARK: - Parent summary

    func test_snapshotFreshnessUsesTheSharedPolicyAtBoundary() {
        let snapshot = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_750_000_000))
        let generatedAt = snapshot.generatedAt

        XCTAssertEqual(
            snapshot.freshness(at: generatedAt.addingTimeInterval(WeatherFreshness.defaultStaleAfter - 1)),
            .fresh
        )
        XCTAssertEqual(
            snapshot.freshness(at: generatedAt.addingTimeInterval(WeatherFreshness.defaultStaleAfter)),
            .stale
        )
    }

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

    func test_parentSummary_listsEveryRecommendedGarmentWithoutCollapsedRemainder() {
        let profile = makeProfile(ageMonths: 5)
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

        XCTAssertGreaterThan(recommendation.allDisplayLayers.count, 4)
        XCTAssertEqual(summary.garments.map(\.id), recommendation.allDisplayLayers.map(\.id))
        XCTAssertEqual(summary.garmentNames.count, recommendation.allDisplayLayers.count)
        XCTAssertTrue(summary.garmentNames.allSatisfy(summary.outfit.contains))
        XCTAssertFalse(summary.outfit.contains("и ещё"))
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

    func test_outfitFitPresentation_mapsInternalValuesToPlainLanguage() {
        XCTAssertEqual(makeFitPresentation(delta: -1.1), .addWarmLayer)
        XCTAssertEqual(makeFitPresentation(delta: -0.5), .addLightLayer)
        XCTAssertEqual(makeFitPresentation(delta: 0), .suitable)
        XCTAssertEqual(makeFitPresentation(delta: 0.5), .removeLightLayer)
        XCTAssertEqual(makeFitPresentation(delta: 1.1), .removeWarmLayer)
        XCTAssertEqual(OutfitFitPresentation(fit: nil), .unknown)
    }

    func test_consumerOutfitPresentation_containsNoNumericTOGPrecision() {
        let labels = [
            OutfitFitPresentation.suitable.label,
            OutfitFitPresentation.addLightLayer.label,
            OutfitFitPresentation.addWarmLayer.label,
            OutfitFitPresentation.removeLightLayer.label,
            OutfitFitPresentation.removeWarmLayer.label,
            OutfitFitPresentation.unknown.label,
            WalkTOGVerdict.densityLabel(for: 0.25),
            WalkTOGVerdict.densityLabel(for: 1.0),
            WalkTOGVerdict.densityLabel(for: 2.5),
            OutfitFitPresentation.consumerGarmentName("Спальный мешок (тёплый, 2.5 TOG)")
        ]

        XCTAssertEqual(labels.last, "Спальный мешок")
        XCTAssertTrue(labels.allSatisfy { text in
            text.range(of: #"\d+(?:[.,]\d+)?\s*TOG"#, options: [.regularExpression, .caseInsensitive]) == nil
        })
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

    private func makeSnapshot(generatedAt: Date) -> OutfitRecommendationSnapshot {
        let profile = makeProfile(ageMonths: 8)
        let weather = makeWeather()
        let context = WalkContext.standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
        return OutfitRecommendationSnapshot(
            recommendation: makeRecommendation(weather: weather, profile: profile, context: context),
            childName: profile.name,
            childAgeLabel: profile.ageLabel,
            childBirthday: profile.birthday,
            cityName: "Алматы",
            generatedAt: generatedAt
        )
    }

    private func makeFitPresentation(delta: Double) -> OutfitFitPresentation {
        OutfitFitPresentation(fit: OutfitFit(
            targetTOG: 2,
            effectiveTOG: 2 + delta,
            deltaTOG: delta,
            confidence: .high,
            hasRequiredBodyCoverage: true
        ))
    }

    private func makePersonalizationSummary(
        similarCount: Int,
        directionalCount: Int,
        netScore: Int,
        explanation: PersonalizationExplanation
    ) -> PersonalizationSummary {
        let context = PersonalizationContext(
            microclimateTemperature: 5,
            transportMode: .pushchairSeat,
            activityLevel: .calmAwake,
            walkType: .regular
        )
        return PersonalizationSummary(
            temperatureBand: context.temperatureBand,
            scenario: context.scenario,
            appliedOffset: netScore > 0 ? 0.2 : (netScore < 0 ? -0.2 : 0),
            independentDirectionalCount: directionalCount,
            netDirectionalScore: netScore,
            comfortableConfirmationCount: max(0, similarCount - directionalCount),
            totalProfileObservationCount: similarCount,
            hasLegacyBaseline: false,
            similarObservationCount: similarCount,
            evidenceContext: PersonalizationEvidenceContext(context: context),
            explanation: explanation
        )
    }
}
