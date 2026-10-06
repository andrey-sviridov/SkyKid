import XCTest
@testable import SkyKid

// MARK: - SafetyPolicyTests

final class SafetyPolicyTests: XCTestCase {

    // MARK: - Supported age scope

    func test_ageScope_acceptsNewbornAndExactTwelveMonthBoundary() {
        let calendar = fixedCalendar
        let now = date("2026-09-06")

        XCTAssertEqual(
            AgeSafetyPolicy.scope(for: date("2026-09-06"), now: now, calendar: calendar),
            .supported
        )
        XCTAssertEqual(
            AgeSafetyPolicy.scope(for: date("2025-09-06"), now: now, calendar: calendar),
            .supported
        )
    }

    func test_ageScope_rejectsJustOverTwelveMonthsAndFutureBirthdays() {
        let calendar = fixedCalendar
        let now = date("2026-09-06")

        XCTAssertEqual(
            AgeSafetyPolicy.scope(for: date("2025-09-05"), now: now, calendar: calendar),
            .olderThanMaximum
        )
        XCTAssertEqual(
            AgeSafetyPolicy.scope(for: date("2026-09-07"), now: now, calendar: calendar),
            .futureBirthDate
        )
    }

    func test_ageScope_birthdayRangeUsesSameCalendarBoundary() {
        let calendar = fixedCalendar
        let now = date("2026-09-06")
        let range = AgeSafetyPolicy.supportedBirthdayRange(now: now, calendar: calendar)

        XCTAssertEqual(range.lowerBound, date("2025-09-06"))
        XCTAssertTrue(range.upperBound >= now)
        XCTAssertEqual(
            AgeSafetyPolicy.scope(for: range.lowerBound, now: now, calendar: calendar),
            .supported
        )
    }

    func test_ageScope_legacyOlderProfileIsLimitedWithoutMutation() {
        let calendar = fixedCalendar
        let now = date("2026-09-06")
        let birthday = date("2024-09-06")
        let profile = ChildThermalProfile(
            name: "Старший",
            gender: .boy,
            birthday: birthday
        )

        XCTAssertFalse(AgeSafetyPolicy.isSupported(profile, now: now, calendar: calendar))
        XCTAssertEqual(profile.birthday, birthday)
    }

    // MARK: - Age and medical limits

    func test_agePolicy_usesCorrectedAgeTable() {
        let newborn = makeProfile(ageMonths: 0)
        let olderInfant = makeProfile(ageMonths: 10)

        XCTAssertEqual(AgeSafetyPolicy.limits(for: newborn).coldBelow, -5)
        XCTAssertEqual(AgeSafetyPolicy.limits(for: newborn).hotAbove, 30)
        XCTAssertEqual(AgeSafetyPolicy.limits(for: olderInfant).coldBelow, -15)
        XCTAssertEqual(AgeSafetyPolicy.limits(for: olderInfant).hotAbove, 33)
    }

    func test_medicalPolicy_pretermEarlyInfantUsesConservativeLimits() {
        let profile = makeProfile(ageMonths: 2, gestationalAgeWeeks: 28)
        let context = makeContext(profile: profile)
        let result = MedicalSafetyPolicy.evaluate(
            context,
            ageLimits: AgeSafetyPolicy.limits(for: profile)
        )

        XCTAssertEqual(result.exposureLimits.coldBelow, 0)
        XCTAssertEqual(result.exposureLimits.hotAbove, 28)
        XCTAssertTrue(result.exposureLimits.usesAdditionalMedicalCaution)
        XCTAssertTrue(result.warnings.contains { $0.code == .medicalPlanPriority })
    }

    func test_medicalPolicy_diagnosisExplainsTOGLimitationWithoutBlocking() {
        let profile = makeProfile(
            ageMonths: 8,
            stableTraits: [.anemia]
        )
        let result = MedicalSafetyPolicy.evaluate(
            makeContext(profile: profile),
            ageLimits: AgeSafetyPolicy.limits(for: profile)
        )

        let warning = result.warnings.first {
            $0.code == .medicalRecommendationLimited
        }
        XCTAssertEqual(warning?.severity, .info)
        XCTAssertTrue(warning?.message.contains("не меняют числовой расчёт") == true)
        XCTAssertTrue(warning?.message.contains("врача") == true)
        XCTAssertFalse(warning?.blocksScenario == true)
        XCTAssertFalse(result.blocksWalk)
    }

    // MARK: - Blocking scenarios

    func test_fever_underThreeMonthsBlocksWalkAndHasHighestPriority() {
        let profile = makeProfile(ageMonths: 2)
        var walkContext = makeWalkContext(for: profile)
        walkContext.healthStatus = .fever
        walkContext.bodyTemperatureCelsius = 38
        let context = makeContext(
            effectiveTemperature: -20,
            heatIndexTemperature: 10,
            microclimateTemperature: -15,
            profile: profile,
            walkContext: walkContext
        )

        let result = SafetyRulesEngine.evaluate(context)

        XCTAssertEqual(result.warnings.first?.code, .feverMedicalAttention)
        XCTAssertEqual(result.warnings.first?.severity, .blocked)
        XCTAssertTrue(result.warnings.first?.message.contains("38°C") == true)
        XCTAssertNil(result.walkWindow)
    }

    func test_fever_olderChildBlocksWalkWithoutPredictingDuration() {
        let profile = makeProfile(ageMonths: 8)
        var walkContext = makeWalkContext(for: profile)
        walkContext.healthStatus = .fever
        let result = SafetyRulesEngine.evaluate(makeContext(
            profile: profile,
            walkContext: walkContext
        ))

        let warning = result.warnings.first { $0.code == .feverStayHome }
        XCTAssertEqual(warning?.severity, .blocked)
        XCTAssertTrue(warning?.blocksScenario == true)
        XCTAssertFalse(warning?.message.contains("минут") == true)
    }

    func test_weatherPolicy_marksColdLimitAsProductGuardrail() {
        let profile = makeProfile(ageMonths: 4)
        let context = makeContext(
            effectiveTemperature: -20,
            heatIndexTemperature: -10,
            microclimateTemperature: -15,
            profile: profile
        )

        let result = WeatherSafetyPolicy.evaluate(
            context,
            limits: AgeSafetyPolicy.limits(for: profile)
        )
        let warning = result.warnings.first { $0.code == .coldExposureLimit }

        XCTAssertEqual(warning?.severity, .blocked)
        XCTAssertTrue(warning?.message.contains("ориентира помощника") == true)
        XCTAssertTrue(warning?.blocksScenario == true)
    }

    func test_cautionDoesNotBlockScenario() {
        let warning = SafetyWarning(
            code: .windWarning,
            severity: .caution,
            message: "Test",
            systemImage: "wind"
        )

        XCTAssertFalse(warning.blocksScenario)
    }

    func test_legacyFeverWarningStillBlocksScenario() {
        let legacyWarning = SafetyWarning(
            code: .feverStayHome,
            severity: .caution,
            message: "Legacy snapshot",
            systemImage: "thermometer.high"
        )

        XCTAssertTrue(legacyWarning.blocksScenario)
    }

    // MARK: - Weather and transport copy

    func test_uvGuidanceForYoungInfantDoesNotBanSunscreen() {
        let profile = makeProfile(ageMonths: 2)
        let context = makeContext(
            profile: profile,
            weather: makeWeather(uvIndex: 6)
        )
        let result = WeatherSafetyPolicy.evaluate(
            context,
            limits: AgeSafetyPolicy.limits(for: profile)
        )
        let message = result.warnings
            .first(where: { $0.code == .walkTimeWarning })?
            .message ?? ""

        XCTAssertTrue(message.contains("вне прямого солнца"))
        XCTAssertFalse(message.contains("без крема"))
    }

    func test_highUVGuidanceUsesMeasuredValueWithoutFixedGlobalHours() {
        let profile = makeProfile(ageMonths: 8)
        let result = WeatherSafetyPolicy.evaluate(
            makeContext(
                profile: profile,
                weather: makeWeather(uvIndex: 7)
            ),
            limits: AgeSafetyPolicy.limits(for: profile)
        )
        let message = result.warnings
            .first(where: { $0.code == .walkTimeWarning })?
            .message ?? ""

        XCTAssertTrue(message.contains("Высокий UV 7"))
        XCTAssertTrue(message.contains("тень"))
        XCTAssertFalse(message.contains("10:00"))
        XCTAssertFalse(message.contains("16:00"))
    }

    func test_rainCoverGuidanceCalmlyRequiresVentilation() {
        let profile = makeProfile(ageMonths: 8)
        var walkContext = makeWalkContext(for: profile)
        walkContext.rainCover = .present_on
        let warnings = TransportSafetyPolicy.evaluate(makeContext(
            microclimateTemperature: 18,
            profile: profile,
            walkContext: walkContext
        ))
        let message = warnings.first { $0.code == .rainCoverVentilation }?.message ?? ""

        XCTAssertTrue(message.contains("вентиляц"))
        XCTAssertFalse(message.contains("безопас"))
    }

    func test_carSeatWarningUsesHarnessActionInsteadOfInventedTOGLimit() {
        let profile = makeProfile(ageMonths: 4)
        var walkContext = makeWalkContext(for: profile)
        walkContext.transportMode = .carSeat
        let warnings = TransportSafetyPolicy.evaluate(makeContext(
            profile: profile,
            walkContext: walkContext
        ))
        let message = warnings
            .first(where: { $0.code == .carSeatBulkyCoatWarning })?
            .message ?? ""

        XCTAssertTrue(message.contains("под ремни"))
        XCTAssertTrue(message.contains("поверх пристёгнутых ремней"))
        XCTAssertFalse(message.contains("1.5 TOG"))
    }

    func test_thermalCheckHintContainsObservationAndLayerActions() {
        let hint = ThermalComfortCheckPolicy.instruction

        XCTAssertTrue(hint.contains("живот"))
        XCTAssertTrue(hint.contains("заднюю поверхность шеи"))
        XCTAssertTrue(hint.contains("снимите один лёгкий слой"))
        XCTAssertTrue(hint.contains("добавьте слой"))
    }
}

// MARK: - Fixtures

private extension SafetyPolicyTests {
    func makeProfile(
        ageMonths: Int,
        gestationalAgeWeeks: Int = 40,
        stableTraits: Set<StableThermalTrait> = []
    ) -> ChildThermalProfile {
        ChildThermalProfile(
            name: "Тест",
            gender: .boy,
            birthday: Calendar.current.date(
                byAdding: .month,
                value: -ageMonths,
                to: Date()
            ) ?? Date(),
            gestationalAgeWeeks: gestationalAgeWeeks,
            stableTraits: stableTraits
        )
    }

    func makeWalkContext(
        for profile: ChildThermalProfile
    ) -> WalkContext {
        .standard(
            for: profile,
            availableGarmentIDs: Set(GarmentCatalog.all.map(\.id))
        )
    }

    func makeWeather(uvIndex: Double = 0) -> NormalizedWeather {
        NormalizedWeather(
            temperature: 10,
            apparentTemperature: 10,
            humidity: 60,
            windSpeed: 0,
            windDirection: 0,
            precipitation: 0,
            weatherCode: 0,
            windGust: 0,
            uvIndex: uvIndex,
            cloudCover: 50,
            precipType: .none
        )
    }

    func makeContext(
        effectiveTemperature: Double = 10,
        heatIndexTemperature: Double = 10,
        microclimateTemperature: Double = 10,
        calculatedWindKmh: Double = 0,
        profile: ChildThermalProfile,
        walkContext: WalkContext? = nil,
        weather: NormalizedWeather? = nil
    ) -> SafetyAssessmentContext {
        SafetyAssessmentContext(
            effectiveTemperature: effectiveTemperature,
            heatIndexTemperature: heatIndexTemperature,
            microclimateTemperature: microclimateTemperature,
            calculatedWindKmh: calculatedWindKmh,
            precipitation: .init(
                needsRainCover: false,
                noWalkInRain: false
            ),
            weather: weather ?? makeWeather(),
            profile: profile,
            walkContext: walkContext ?? makeWalkContext(for: profile)
        )
    }

    var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: "\(value)T00:00:00Z")!
    }
}
