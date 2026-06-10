import Foundation

// BabyActivityLevel, HealthCondition, TempBand are defined in ChildProfile.swift
// (shared with SkyKidWidget target).

// MARK: - TransportMode §3

enum TransportMode: String, Codable, CaseIterable, Sendable {
    case pramBassinette   // люлька коляски с высокими бортами
    case pushchairSeat    // прогулочный блок (сидячая позиция)
    case carrier          // эргорюкзак / слинг
    case carSeat          // автокресло на шасси коляски
}

// MARK: - RainCoverState §3

enum RainCoverState: String, Codable, CaseIterable, Sendable {
    case notPresent   // дождевика нет
    case present_off  // есть, не установлен
    case present_on   // установлен (парниковый эффект!)
}

// MARK: - GearSetup §3

struct GearSetup: Sendable {
    let transportMode: TransportMode
    let hoodUp: Bool
    let rainCover: RainCoverState
    let strollerConvertTOG: Double?   // footmuff/convert TOG; nil = не используется
    let blanketTOG: Double?
    let walkType: WalkType            // reuse existing WalkType from ChildProfile
    let parentWearingCarrier: Bool    // эргорюкзак под курткой родителя

    // MARK: Bridge from ChildProfile.strollerType for backward compat
    static func from(profile: ChildProfile) -> GearSetup {
        let transport: TransportMode
        switch profile.strollerType {
        case .open:       transport = .pushchairSeat
        case .deepWinter: transport = .pramBassinette
        case .covered:    transport = .pushchairSeat
        }
        let rainCover: RainCoverState = (profile.strollerType == .covered) ? .present_on : .notPresent
        let hoodUp = (profile.strollerType == .deepWinter || profile.strollerType == .covered)
        return GearSetup(
            transportMode: transport,
            hoodUp: hoodUp,
            rainCover: rainCover,
            strollerConvertTOG: nil,
            blanketTOG: nil,
            walkType: profile.walkType,
            parentWearingCarrier: false
        )
    }
}
