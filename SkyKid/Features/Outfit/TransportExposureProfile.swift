import Foundation

// MARK: - TransportExposureProfile

/// Fraction of each outdoor thermal effect that reaches the child.
/// Clothing, blankets and footmuffs are deliberately excluded: their TOG is
/// accounted for by `OutfitSolver` and must not warm the child twice.
struct TransportExposureProfile: Equatable, Sendable {
    let wind: Double
    let precipitation: Double
    let solar: Double
    let bodyHeatGain: Double
    let jacketRetention: Double
    let isEnclosed: Bool

    static func resolve(for gear: GearSetup) -> TransportExposureProfile {
        var profile = baseProfile(for: gear)

        if gear.rainCover == .present_on {
            profile = TransportExposureProfile(
                wind: profile.wind * OutfitConfig.Microclimate.rainCoverWindExposureFactor,
                precipitation: 0,
                solar: profile.solar,
                bodyHeatGain: profile.bodyHeatGain,
                jacketRetention: profile.jacketRetention,
                isEnclosed: true
            )
        }

        return profile
    }
}

// MARK: - Base profiles

private extension TransportExposureProfile {
    static func baseProfile(for gear: GearSetup) -> TransportExposureProfile {
        switch gear.transportMode {
        case .walking:
            return exposedProfile()

        case .pramBassinette:
            return TransportExposureProfile(
                wind: gear.hoodUp
                    ? OutfitConfig.Microclimate.pramHoodWindExposure
                    : OutfitConfig.Microclimate.pramOpenWindExposure,
                precipitation: 1,
                solar: gear.hoodUp
                    ? OutfitConfig.Microclimate.hoodSolarExposure
                    : OutfitConfig.Microclimate.pramOpenSolarExposure,
                bodyHeatGain: 0,
                jacketRetention: 0,
                isEnclosed: false
            )

        case .pushchairSeat:
            return TransportExposureProfile(
                wind: gear.hoodUp
                    ? OutfitConfig.Microclimate.pushchairHoodWindExposure
                    : 1,
                precipitation: 1,
                solar: gear.hoodUp ? OutfitConfig.Microclimate.hoodSolarExposure : 1,
                bodyHeatGain: 0,
                jacketRetention: 0,
                isEnclosed: false
            )

        case .carrier:
            return TransportExposureProfile(
                wind: gear.parentWearingCarrier
                    ? OutfitConfig.Microclimate.carrierJacketWindExposure
                    : 1,
                precipitation: gear.parentWearingCarrier
                    ? OutfitConfig.Microclimate.carrierJacketPrecipitationExposure
                    : 1,
                solar: gear.parentWearingCarrier
                    ? OutfitConfig.Microclimate.carrierJacketSolarExposure
                    : 1,
                bodyHeatGain: OutfitConfig.Microclimate.carrierBodyHeatGain,
                jacketRetention: gear.parentWearingCarrier
                    ? OutfitConfig.Microclimate.carrierJacketRetention
                    : 0,
                isEnclosed: gear.parentWearingCarrier
            )

        case .carSeat:
            return TransportExposureProfile(
                wind: OutfitConfig.Microclimate.carSeatWindExposure,
                precipitation: 1,
                solar: OutfitConfig.Microclimate.carSeatSolarExposure,
                bodyHeatGain: 0,
                jacketRetention: 0,
                isEnclosed: false
            )
        }
    }

    static func exposedProfile() -> TransportExposureProfile {
        TransportExposureProfile(
            wind: 1,
            precipitation: 1,
            solar: 1,
            bodyHeatGain: 0,
            jacketRetention: 0,
            isEnclosed: false
        )
    }
}
