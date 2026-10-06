import XCTest
@testable import SkyKid

final class WalkWindowScorerTests: XCTestCase {
    private let limits = OutdoorSafetyLimits(
        coldBelow: -10,
        hotAbove: 32,
        usesAdditionalMedicalCaution: false
    )

    func test_windRainAndUVTradeoffsChooseLowestCombinedPenalty() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let current = candidate(now, temperature: 34, rain: 70, wind: 30, gust: 45, uv: 8)
        let rainy = candidate(now.addingTimeInterval(3_600), temperature: 20, rain: 80, wind: 4, gust: 6, uv: 1)
        let rainy2 = candidate(now.addingTimeInterval(7_200), temperature: 20, rain: 80, wind: 4, gust: 6, uv: 1)
        let balanced = candidate(now.addingTimeInterval(10_800), temperature: 18, rain: 5, wind: 8, gust: 10, uv: 2)
        let balanced2 = candidate(now.addingTimeInterval(14_400), temperature: 18, rain: 5, wind: 8, gust: 10, uv: 2)

        let result = suggestion(current: current, hourly: [rainy, rainy2, balanced, balanced2], now: now)

        XCTAssertEqual(result?.interval.start, balanced.time)
        XCTAssertEqual(result?.reasons, [.milderTemperature, .lessRain, .lighterWind, .lowerUV])
    }

    func test_staleOrLowConfidenceForecastReturnsNoResult() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let values = validPair(now: now)

        XCTAssertNil(suggestion(current: values.current, hourly: values.hourly, now: now,
                                updatedAt: now.addingTimeInterval(-10_801)))
        XCTAssertNil(suggestion(current: values.current, hourly: values.hourly, now: now,
                                confidence: .low))
    }

    func test_tieUsesEarliestInterval() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let first = candidate(now.addingTimeInterval(3_600), temperature: 12, rain: 0)
        let second = candidate(now.addingTimeInterval(7_200), temperature: 12, rain: 0)
        let third = candidate(now.addingTimeInterval(10_800), temperature: 12, rain: 0)

        let result = suggestion(
            current: candidate(now, temperature: -15, rain: 0),
            hourly: [first, second, third],
            now: now
        )

        XCTAssertEqual(result?.interval.start, first.time)
    }

    func test_missingOptionalFieldsAreNotInventedButTemperatureAndRainAreEnough() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let values = validPair(now: now)
        let result = suggestion(current: values.current, hourly: values.hourly, now: now)

        XCTAssertNotNil(result)
        XCTAssertFalse(result?.reasons.contains(.lighterWind) == true)
        XCTAssertFalse(result?.reasons.contains(.lowerUV) == true)
    }

    func test_insufficientFieldsReturnNoResult() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let sparse = WalkWindowCandidate(
            time: now.addingTimeInterval(3_600), apparentTemperature: 12,
            windKmh: nil, gustKmh: nil, precipitationProbability: nil, uvIndex: nil
        )
        let sparse2 = WalkWindowCandidate(
            time: now.addingTimeInterval(7_200), apparentTemperature: 12,
            windKmh: nil, gustKmh: nil, precipitationProbability: nil, uvIndex: nil
        )

        XCTAssertNil(suggestion(
            current: candidate(now, temperature: -15, rain: 0),
            hourly: [sparse, sparse2], now: now
        ))
    }

    func test_missingOptionalFieldsLowerEvidenceInsteadOfWinningAsZeroes() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let sparse = candidate(now.addingTimeInterval(3_600), temperature: 11, rain: 0)
        let sparse2 = candidate(now.addingTimeInterval(7_200), temperature: 11, rain: 0)
        let known = candidate(now.addingTimeInterval(10_800), temperature: 12, rain: 0, wind: 2, gust: 3, uv: 1)
        let known2 = candidate(now.addingTimeInterval(14_400), temperature: 12, rain: 0, wind: 2, gust: 3, uv: 1)

        let result = suggestion(
            current: candidate(now, temperature: -15, rain: 50),
            hourly: [sparse, sparse2, known, known2],
            now: now
        )

        XCTAssertEqual(result?.interval.start, known.time)
    }

    func test_absoluteInstantsDoNotDependOnCalendarTimezone() {
        let formatter = ISO8601DateFormatter()
        let now = formatter.date(from: "2033-05-18T23:30:00-07:00")!
        let values = validPair(now: now)
        let result = suggestion(current: values.current, hourly: values.hourly, now: now)

        XCTAssertEqual(result?.interval.start.timeIntervalSince1970,
                       now.addingTimeInterval(3_600).timeIntervalSince1970)
    }

    private func validPair(now: Date) -> (current: WalkWindowCandidate, hourly: [WalkWindowCandidate]) {
        (
            candidate(now, temperature: -15, rain: 60),
            [
                candidate(now.addingTimeInterval(3_600), temperature: 12, rain: 10),
                candidate(now.addingTimeInterval(7_200), temperature: 12, rain: 10),
            ]
        )
    }

    private func suggestion(
        current: WalkWindowCandidate,
        hourly: [WalkWindowCandidate],
        now: Date,
        updatedAt: Date? = nil,
        confidence: WeatherConfidenceLevel = .high
    ) -> WalkWindowSuggestion? {
        WalkWindowScorer.suggestion(
            current: current,
            hourly: hourly,
            limits: limits,
            forecastUpdatedAt: updatedAt ?? now,
            confidence: confidence,
            now: now
        )
    }

    private func candidate(
        _ time: Date,
        temperature: Double,
        rain: Double?,
        wind: Double? = nil,
        gust: Double? = nil,
        uv: Double? = nil
    ) -> WalkWindowCandidate {
        WalkWindowCandidate(
            time: time,
            apparentTemperature: temperature,
            windKmh: wind,
            gustKmh: gust,
            precipitationProbability: rain,
            uvIndex: uv
        )
    }
}
