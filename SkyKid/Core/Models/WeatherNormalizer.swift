import Foundation

// MARK: - WeatherNormalizationError

enum WeatherNormalizationError: Error, Equatable {
    case missingTemperature
}

// MARK: - WeatherNormalizer

enum WeatherNormalizer {
    private static let fallbackHumidity = 80
    private static let fallbackWindSpeed = 3.0
    private static let fallbackCloudCover = 100.0

    static func normalize(_ raw: RawWeatherObservation) throws -> NormalizedWeather {
        guard let temperature = finite(raw.temperature) else {
            throw WeatherNormalizationError.missingTemperature
        }

        var statuses: [WeatherField: WeatherFieldStatus] = [:]
        statuses[.temperature] = observedStatus(for: .temperature, raw: raw)

        let apparentTemperature = normalizedApparentTemperature(
            raw.apparentTemperature,
            temperature: temperature,
            raw: raw,
            statuses: &statuses
        )
        let humidity = normalizedHumidity(raw.humidity, raw: raw, statuses: &statuses)
        let windSpeed = normalizedWindSpeed(raw.windSpeed, raw: raw, statuses: &statuses)
        let windGust = normalizedWindGust(
            raw.windGust,
            sustained: windSpeed,
            raw: raw,
            statuses: &statuses
        )
        let windDirection = normalizedWindDirection(
            raw.windDirection,
            raw: raw,
            statuses: &statuses
        )
        let precipitation = normalizedPrecipitation(
            raw.precipitation,
            weatherCode: raw.weatherCode,
            raw: raw,
            statuses: &statuses
        )
        let weatherCode = normalizedWeatherCode(
            raw.weatherCode,
            precipitation: precipitation,
            temperature: temperature,
            raw: raw,
            statuses: &statuses
        )
        let precipType = normalizedPrecipitationType(
            weatherCode: weatherCode,
            precipitation: precipitation,
            temperature: temperature,
            raw: raw,
            statuses: &statuses
        )
        let uvIndex = normalizedUV(raw.uvIndex, raw: raw, statuses: &statuses)
        let cloudCover = normalizedCloudCover(
            raw.cloudCover,
            raw: raw,
            statuses: &statuses
        )
        statuses[.hourlyForecast] = raw.hourly.isEmpty
            ? fallbackStatus(
                for: .hourlyForecast,
                raw: raw,
                quality: .unavailable,
                note: "Провайдер не вернул почасовой прогноз"
            )
            : suppliedStatus(for: .hourlyForecast, raw: raw)

        return NormalizedWeather(
            source: raw.source,
            temperature: temperature,
            apparentTemperature: apparentTemperature,
            humidity: humidity,
            windSpeed: windSpeed,
            windDirection: windDirection,
            precipitation: precipitation,
            weatherCode: weatherCode,
            windGust: windGust,
            uvIndex: uvIndex,
            cloudCover: cloudCover,
            precipType: precipType,
            hourly: raw.hourly,
            fieldStatuses: statuses
        )
    }
}

// MARK: - Field normalization

private extension WeatherNormalizer {
    static func normalizedApparentTemperature(
        _ value: Double?,
        temperature: Double,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> Double {
        guard let value = finite(value) else {
            statuses[.apparentTemperature] = fallbackStatus(
                for: .apparentTemperature,
                raw: raw,
                quality: .estimated,
                note: "Приравнена к температуре воздуха"
            )
            return temperature
        }
        statuses[.apparentTemperature] = suppliedStatus(for: .apparentTemperature, raw: raw)
        return value
    }

    static func normalizedHumidity(
        _ value: Int?,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> Int {
        guard let value else {
            statuses[.humidity] = fallbackStatus(
                for: .humidity,
                raw: raw,
                quality: .estimated,
                note: "Использована осторожная влажность \(fallbackHumidity)%"
            )
            return fallbackHumidity
        }
        statuses[.humidity] = suppliedStatus(for: .humidity, raw: raw)
        return min(max(value, 0), 100)
    }

    static func normalizedWindSpeed(
        _ value: Double?,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> Double {
        guard let value = finite(value), value >= 0 else {
            statuses[.windSpeed] = fallbackStatus(
                for: .windSpeed,
                raw: raw,
                quality: .estimated,
                note: "Использован осторожный ветер \(fallbackWindSpeed) м/с"
            )
            return fallbackWindSpeed
        }
        statuses[.windSpeed] = suppliedStatus(for: .windSpeed, raw: raw)
        return value
    }

    static func normalizedWindGust(
        _ value: Double?,
        sustained: Double,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> Double {
        guard let value = finite(value), value >= 0 else {
            statuses[.windGust] = fallbackStatus(
                for: .windGust,
                raw: raw,
                quality: .derived,
                note: "Порыв приравнен к устойчивому ветру"
            )
            return sustained
        }
        if value < sustained {
            statuses[.windGust] = fallbackStatus(
                for: .windGust,
                raw: raw,
                quality: .derived,
                note: "Порыв не может уменьшать устойчивый ветер"
            )
            return sustained
        }
        statuses[.windGust] = suppliedStatus(for: .windGust, raw: raw)
        return value
    }

    static func normalizedWindDirection(
        _ value: Int?,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> Int {
        guard let value else {
            statuses[.windDirection] = fallbackStatus(
                for: .windDirection,
                raw: raw,
                quality: .unavailable,
                note: "Направление ветра не получено"
            )
            return 0
        }
        statuses[.windDirection] = suppliedStatus(for: .windDirection, raw: raw)
        return ((value % 360) + 360) % 360
    }

    static func normalizedPrecipitation(
        _ value: Double?,
        weatherCode: Int?,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> Double {
        if let value = finite(value), value >= 0 {
            statuses[.precipitation] = suppliedStatus(for: .precipitation, raw: raw)
            return value
        }
        if let weatherCode {
            statuses[.precipitation] = fallbackStatus(
                for: .precipitation,
                raw: raw,
                quality: .derived,
                note: "Наличие осадков определено по коду погоды"
            )
            return PrecipType(wmoCode: weatherCode) == .none ? 0 : 0.1
        }
        statuses[.precipitation] = fallbackStatus(
            for: .precipitation,
            raw: raw,
            quality: .unavailable,
            note: "Осадки не получены"
        )
        return 0
    }

    static func normalizedWeatherCode(
        _ value: Int?,
        precipitation: Double,
        temperature: Double,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> Int {
        if let value {
            statuses[.weatherCode] = suppliedStatus(for: .weatherCode, raw: raw)
            return value
        }
        guard precipitation > 0 else {
            statuses[.weatherCode] = fallbackStatus(
                for: .weatherCode,
                raw: raw,
                quality: .unavailable,
                note: "Код условий не получен"
            )
            return -1
        }
        statuses[.weatherCode] = fallbackStatus(
            for: .weatherCode,
            raw: raw,
            quality: .estimated,
            note: "Код оценён по температуре и осадкам"
        )
        return temperature <= 0 ? 71 : 61
    }

    static func normalizedPrecipitationType(
        weatherCode: Int,
        precipitation: Double,
        temperature: Double,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> PrecipType {
        let fromCode = PrecipType(wmoCode: weatherCode)
        let type: PrecipType
        if fromCode != .none {
            type = fromCode
        } else if precipitation > 0 {
            type = temperature <= 0 ? .snow : .lightRain
        } else {
            type = .none
        }
        statuses[.precipitationType] = WeatherFieldStatus(
            field: .precipitationType,
            source: raw.source,
            origin: .derivedFromProvider,
            quality: statuses[.weatherCode]?.quality == .unavailable ? .estimated : .derived,
            note: "Тип осадков выведен из кода погоды"
        )
        return type
    }

    static func normalizedUV(
        _ value: Double?,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> Double {
        guard let value = finite(value), value >= 0 else {
            statuses[.uvIndex] = fallbackStatus(
                for: .uvIndex,
                raw: raw,
                quality: .unavailable,
                note: "UV не получен; солнечная прибавка отключена"
            )
            return 0
        }
        statuses[.uvIndex] = suppliedStatus(for: .uvIndex, raw: raw)
        return value
    }

    static func normalizedCloudCover(
        _ value: Double?,
        raw: RawWeatherObservation,
        statuses: inout [WeatherField: WeatherFieldStatus]
    ) -> Double {
        guard let value = finite(value) else {
            statuses[.cloudCover] = fallbackStatus(
                for: .cloudCover,
                raw: raw,
                quality: .unavailable,
                note: "Использована сплошная облачность, чтобы не добавлять неподтверждённое солнечное тепло"
            )
            return fallbackCloudCover
        }
        statuses[.cloudCover] = suppliedStatus(for: .cloudCover, raw: raw)
        return min(max(value, 0), 100)
    }
}

// MARK: - Status helpers

private extension WeatherNormalizer {
    static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    static func observedStatus(
        for field: WeatherField,
        raw: RawWeatherObservation
    ) -> WeatherFieldStatus {
        suppliedStatus(for: field, raw: raw)
    }

    static func suppliedStatus(
        for field: WeatherField,
        raw: RawWeatherObservation
    ) -> WeatherFieldStatus {
        let quality = raw.qualityOverrides[field] ?? .observed
        return WeatherFieldStatus(
            field: field,
            source: raw.source,
            origin: quality == .observed ? .provider : .derivedFromProvider,
            quality: quality,
            note: raw.notes[field]
        )
    }

    static func fallbackStatus(
        for field: WeatherField,
        raw: RawWeatherObservation,
        quality: WeatherFieldQuality,
        note: String
    ) -> WeatherFieldStatus {
        WeatherFieldStatus(
            field: field,
            source: raw.source,
            origin: quality == .derived ? .derivedFromProvider : .safetyFallback,
            quality: quality,
            note: note
        )
    }
}
