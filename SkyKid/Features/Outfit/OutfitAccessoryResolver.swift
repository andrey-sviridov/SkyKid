import Foundation

// MARK: - OutfitAccessoryResolver

enum OutfitAccessoryResolver {

    struct Request: Sendable {
        let temperature: Double
        let heatIndex: Double
        let uvIndex: Double
        let correctedAgeWeeks: Int
        let ageGroup: WardrobeAgeGroup
        let availableGarmentIDs: Set<String>?
    }

    struct Selection: Sendable {
        let item: GarmentItem
        let reason: String
    }

    struct Result: Sendable {
        let selections: [Selection]
        let missingZones: Set<BodyZone>
    }

    static func resolve(_ request: Request) -> Result {
        let candidates = GarmentCompatibilityPolicy.accessoryItems(
            for: request.ageGroup,
            availableIDs: request.availableGarmentIDs
        )
        let requirements = requirements(for: request)

        var selected: [Selection] = []
        var missingZones: Set<BodyZone> = []

        for requirement in requirements {
            let currentItems = selected.map(\.item)
            let match = candidates
                .filter { $0.coveredZones.contains(requirement.zone) }
                .filter { GarmentCompatibilityPolicy.canAdd($0, to: currentItems) }
                .min { lhs, rhs in
                    let lhsError = abs(lhs.tog - requirement.targetTOG)
                    let rhsError = abs(rhs.tog - requirement.targetTOG)
                    if lhsError != rhsError { return lhsError < rhsError }
                    return lhs.tog < rhs.tog
                }

            if let match {
                selected.append(Selection(item: match, reason: requirement.reason))
            } else {
                missingZones.insert(requirement.zone)
            }
        }

        return Result(selections: selected, missingZones: missingZones)
    }

    // MARK: - Requirements

    private struct Requirement {
        let zone: BodyZone
        let targetTOG: Double
        let reason: String
    }

    private static func requirements(for request: Request) -> [Requirement] {
        var result: [Requirement] = []

        if request.temperature < 20 || request.correctedAgeWeeks < 4 {
            let targetTOG: Double
            if request.temperature < -5 {
                targetTOG = 0.8
            } else if request.temperature < 10 {
                targetTOG = 0.5
            } else {
                targetTOG = 0.15
            }
            let reason = request.temperature < 20
                ? L10n.text("Защита головы при прохладной погоде")
                : L10n.text("Для малыша младше месяца")
            result.append(Requirement(zone: .head, targetTOG: targetTOG, reason: reason))
        } else if request.uvIndex >= 3, request.heatIndex >= 18 {
            result.append(Requirement(
                zone: .head,
                targetTOG: 0.1,
                reason: L10n.text("Лёгкая защита головы от солнца")
            ))
        }

        if request.temperature < 5 {
            result.append(Requirement(
                zone: .hands,
                targetTOG: 0.3,
                reason: L10n.text("Защита рук при температуре ниже +5°C")
            ))
            result.append(Requirement(
                zone: .feet,
                targetTOG: 0.4,
                reason: L10n.text("Дополнительная защита стоп при температуре ниже +5°C")
            ))
        }

        return result
    }
}
