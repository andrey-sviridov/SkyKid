import Foundation

// MARK: - WeatherThermalEffects

/// Independent thermal contributions calculated once from weather data.
/// Transport protection combines these values without re-running formulas or
/// dropping an unrelated contribution.
struct WeatherThermalEffects: Equatable, Sendable {
    let airTemperature: Double
    let windChillTemperature: Double
    let heatIndexTemperature: Double
    let windDelta: Double
    let heatDelta: Double
    let humidityDelta: Double
    let precipitationDelta: Double
    let solarDelta: Double

    var effectiveTemperature: Double {
        airTemperature
            + windDelta
            + heatDelta
            + humidityDelta
            + precipitationDelta
            + solarDelta
    }
}
