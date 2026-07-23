import Foundation

// MARK: - CurrentHealthStatus

enum CurrentHealthStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case well
    case coldWithoutFever
    case fever

    var id: String { rawValue }

    var label: String {
        switch self {
        case .well:              return L10n.text("Чувствует себя хорошо")
        case .coldWithoutFever:  return L10n.text("ОРВИ без температуры")
        case .fever:             return L10n.text("Есть температура")
        }
    }

    var systemImage: String {
        switch self {
        case .well:              return "checkmark.circle.fill"
        case .coldWithoutFever:  return "facemask.fill"
        case .fever:             return "thermometer.high"
        }
    }
}

// MARK: - WalkContext

/// Ephemeral input for one planned walk. This value is intentionally kept out
/// of `ChildProfileStore`, so an illness or transport choice cannot leak into
/// future recommendations after the app restarts.
struct WalkContext: Equatable, Sendable {
    var healthStatus: CurrentHealthStatus
    var bodyTemperatureCelsius: Double?
    var activityLevel: BabyActivityLevel
    var transportMode: TransportMode
    var hoodUp: Bool
    var rainCover: RainCoverState
    var strollerConvertTOG: Double?
    var blanketTOG: Double?
    var walkType: WalkType
    var parentWearingCarrier: Bool
    var availableGarmentIDs: Set<String>

    var hasFever: Bool {
        healthStatus == .fever || (bodyTemperatureCelsius ?? 0) >= 38
    }

    var gearSetup: GearSetup {
        GearSetup(
            transportMode: transportMode,
            hoodUp: hoodUp,
            rainCover: rainCover,
            strollerConvertTOG: strollerConvertTOG,
            blanketTOG: blanketTOG,
            walkType: walkType,
            parentWearingCarrier: parentWearingCarrier
        )
    }

    static func standard(
        for profile: ChildThermalProfile,
        availableGarmentIDs: Set<String>
    ) -> WalkContext {
        let transport: TransportMode
        let activity: BabyActivityLevel

        switch profile.ageGroup {
        case .infant:
            transport = .pramBassinette
            activity = .calmAwake
        case .baby:
            transport = .pushchairSeat
            activity = .activeInStroller
        default:
            transport = .walking
            activity = .walkingCrawling
        }

        return WalkContext(
            healthStatus: .well,
            bodyTemperatureCelsius: nil,
            activityLevel: activity,
            transportMode: transport,
            hoodUp: false,
            rainCover: .notPresent,
            strollerConvertTOG: nil,
            blanketTOG: nil,
            walkType: .regular,
            parentWearingCarrier: false,
            availableGarmentIDs: availableGarmentIDs
        )
    }
}

// MARK: - Legacy migration

extension WalkContext {
    static func migrated(
        from profile: ChildProfile,
        gearSetup: GearSetup,
        availableGarmentIDs: Set<String>
    ) -> WalkContext {
        let healthStatus: CurrentHealthStatus
        if profile.healthConditions.contains(.fever) {
            healthStatus = .fever
        } else if profile.healthConditions.contains(.coldNoFever) {
            healthStatus = .coldWithoutFever
        } else {
            healthStatus = .well
        }

        return WalkContext(
            healthStatus: healthStatus,
            bodyTemperatureCelsius: nil,
            activityLevel: profile.babyActivityLevel,
            transportMode: gearSetup.transportMode,
            hoodUp: gearSetup.hoodUp,
            rainCover: gearSetup.rainCover,
            strollerConvertTOG: gearSetup.strollerConvertTOG,
            blanketTOG: gearSetup.blanketTOG,
            walkType: gearSetup.walkType,
            parentWearingCarrier: gearSetup.parentWearingCarrier,
            availableGarmentIDs: availableGarmentIDs
        )
    }
}
