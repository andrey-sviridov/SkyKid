import Foundation

// MARK: - WalkPreparationViewModel

struct WalkPreparationViewModel {
    private(set) var profile: ChildThermalProfile
    var context: WalkContext
    var includesBodyTemperature: Bool

    init(profile: ChildThermalProfile, context: WalkContext) {
        self.profile = profile
        self.context = context
        includesBodyTemperature = context.bodyTemperatureCelsius != nil
    }

    // MARK: - Health

    mutating func selectHealthStatus(_ status: CurrentHealthStatus) {
        context.healthStatus = status
        if status == .well {
            includesBodyTemperature = false
            context.bodyTemperatureCelsius = nil
        } else if status == .fever, context.bodyTemperatureCelsius == nil {
            includesBodyTemperature = true
            context.bodyTemperatureCelsius = 38
        }
    }

    mutating func setBodyTemperatureIncluded(_ isIncluded: Bool) {
        includesBodyTemperature = isIncluded
        context.bodyTemperatureCelsius = isIncluded
            ? context.bodyTemperatureCelsius ?? 38
            : nil
    }

    // MARK: - Transport

    mutating func selectTransport(_ transport: TransportMode) {
        context.transportMode = transport

        switch transport {
        case .walking:
            context.hoodUp = false
            context.rainCover = .notPresent
            context.strollerConvertTOG = nil
            context.blanketTOG = nil
            context.parentWearingCarrier = false
        case .carrier:
            context.hoodUp = false
            context.rainCover = .notPresent
            context.strollerConvertTOG = nil
            context.blanketTOG = nil
        case .carSeat:
            context.hoodUp = false
            context.rainCover = .notPresent
            context.strollerConvertTOG = nil
            context.blanketTOG = nil
            context.parentWearingCarrier = false
        case .pramBassinette, .pushchairSeat:
            context.parentWearingCarrier = false
        }
    }

    // MARK: - Output

    func finalizedContext() -> WalkContext {
        var result = context
        if !includesBodyTemperature {
            result.bodyTemperatureCelsius = nil
        }
        if result.healthStatus == .well {
            result.bodyTemperatureCelsius = nil
        }
        return result
    }
}
