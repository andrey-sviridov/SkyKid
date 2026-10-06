import Foundation

// MARK: - WeatherSnapshotProvider

/// Stable provider identity used by persisted weather snapshots.
///
/// This type intentionally does not depend on a provider transport model so
/// the snapshot can be shared by the app and widget targets.
enum WeatherSnapshotProvider: String, Codable, CaseIterable, Hashable, Sendable {
    case openMeteo
    case weatherKit
    case openWeatherMap
    case weatherAPI
    case yandex
    case manual
}

// MARK: - WeatherSnapshot fields

enum WeatherSnapshotField: String, Codable, CaseIterable, Hashable, Sendable {
    case temperature
    case apparentTemperature
    case humidity
    case windSpeed
    case windGust
    case windDirection
    case precipitation
    case precipitationType
    case weatherCode
    case uvIndex
    case cloudCover
    case hourlyForecast
}

enum WeatherSnapshotFieldQuality: String, Codable, Hashable, Sendable {
    case observed
    case derived
    case estimated
    case unavailable
}

enum WeatherSnapshotValueOrigin: String, Codable, Hashable, Sendable {
    case provider
    case derivedFromProvider
    case safetyFallback
}

struct WeatherSnapshotFieldStatus: Codable, Equatable, Hashable, Sendable {
    let origin: WeatherSnapshotValueOrigin
    let quality: WeatherSnapshotFieldQuality
    let note: String?
}

// MARK: - Freshness

enum WeatherSnapshotFreshness: String, Codable, Equatable, Hashable, Sendable {
    case fresh
    case stale
}

/// The inputs needed to classify a snapshot without consulting a clock hidden
/// inside the model. Persisting the capture time, rather than a one-time
/// boolean, keeps freshness deterministic after relaunch and across targets.
struct WeatherSnapshotFreshnessInput: Codable, Equatable, Hashable, Sendable {
    static let defaultStaleAfter: TimeInterval = 2 * 60 * 60

    let capturedAt: Date
    let staleAfter: TimeInterval

    init(
        capturedAt: Date,
        staleAfter: TimeInterval = Self.defaultStaleAfter
    ) {
        self.capturedAt = capturedAt
        self.staleAfter = staleAfter
    }

    var maxAge: TimeInterval { staleAfter }

    func age(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(capturedAt))
    }

    func state(at now: Date) -> WeatherSnapshotFreshness {
        guard capturedAt <= now else { return .stale }
        return age(at: now) < staleAfter ? .fresh : .stale
    }
}

// MARK: - WeatherSnapshot

/// Versioned, immutable weather provenance at a recommendation/walk
/// boundary. Only the air temperature is required for a valid snapshot;
/// optional measurements remain nil when they were not available.
struct WeatherSnapshot: Codable, Equatable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let freshnessInput: WeatherSnapshotFreshnessInput
    let provider: WeatherSnapshotProvider

    let temperature: Double?
    let apparentTemperature: Double?
    let humidity: Int?
    let windSpeed: Double?
    let windGust: Double?
    let windDirection: Int?
    let precipitation: Double?
    let precipitationType: String?
    let weatherCode: Int?
    let uvIndex: Double?
    let cloudCover: Double?

    let fieldStatuses: [WeatherSnapshotField: WeatherSnapshotFieldStatus]

    var capturedAt: Date { freshnessInput.capturedAt }

    init?(
        provider: WeatherSnapshotProvider,
        temperature: Double?,
        apparentTemperature: Double? = nil,
        humidity: Int? = nil,
        windSpeed: Double? = nil,
        windGust: Double? = nil,
        windDirection: Int? = nil,
        precipitation: Double? = nil,
        precipitationType: String? = nil,
        weatherCode: Int? = nil,
        uvIndex: Double? = nil,
        cloudCover: Double? = nil,
        fieldStatuses: [WeatherSnapshotField: WeatherSnapshotFieldStatus] = [:],
        capturedAt: Date,
        staleAfter: TimeInterval = WeatherSnapshotFreshnessInput.defaultStaleAfter
    ) {
        guard let temperature, temperature.isFinite else { return nil }
        guard capturedAt.timeIntervalSinceReferenceDate.isFinite,
              staleAfter.isFinite,
              staleAfter > 0,
              optionalMeasurementsAreFinite([
                  apparentTemperature,
                  windSpeed,
                  windGust,
                  precipitation,
                  uvIndex,
                  cloudCover
              ])
        else { return nil }

        self.schemaVersion = Self.currentSchemaVersion
        self.freshnessInput = WeatherSnapshotFreshnessInput(
            capturedAt: capturedAt,
            staleAfter: staleAfter
        )
        self.provider = provider
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windGust = windGust
        self.windDirection = windDirection
        self.precipitation = precipitation
        self.precipitationType = precipitationType
        self.weatherCode = weatherCode
        self.uvIndex = uvIndex
        self.cloudCover = cloudCover
        self.fieldStatuses = fieldStatuses
    }

    func freshness(at now: Date = .now) -> WeatherSnapshotFreshness {
        freshnessInput.state(at: now)
    }

    func isFresh(at now: Date = .now) -> Bool {
        schemaVersion == Self.currentSchemaVersion
            && freshness(at: now) == .fresh
    }

    func status(for field: WeatherSnapshotField) -> WeatherSnapshotFieldStatus? {
        fieldStatuses[field]
    }
}

private func optionalMeasurementsAreFinite(_ values: [Double?]) -> Bool {
    values.allSatisfy { value in
        value.map(\.isFinite) ?? true
    }
}
