import Foundation

// MARK: - OutfitCombinationSolver

/// Ищет наиболее близкую к целевому TOG совместимую комбинацию.
/// Перебор ограничен четырьмя слоями и небольшим возрастным каталогом.
enum OutfitCombinationSolver {

    struct Request: Sendable {
        let targetTOG: Double
        let temperature: Double
        let profile: ChildThermalProfile
        let transportMode: TransportMode
        let availableGarmentIDs: Set<String>?
    }

    struct Result: Sendable {
        let items: [GarmentItem]
        let totalTOG: Double
        let missingBaseSlots: Set<BodySlot>
    }

    static func solve(_ request: Request) -> Result {
        let diaper = GarmentCatalog.byID["diaper"]
        let fixedTOG = diaper?.tog ?? 0
        let candidates = GarmentCompatibilityPolicy.outdoorBodyItems(
            for: request.profile.wardrobeAgeGroup,
            availableIDs: request.availableGarmentIDs
        )

        var bestItems: [GarmentItem] = []
        var bestScore = score(items: [], fixedTOG: fixedTOG, request: request)

        search(
            candidates: candidates,
            startIndex: 0,
            selected: [],
            fixedTOG: fixedTOG,
            request: request,
            bestItems: &bestItems,
            bestScore: &bestScore
        )

        let ordered = GarmentCompatibilityPolicy.orderedForDressing(bestItems)
        let allItems = diaper.map { [$0] + ordered } ?? ordered
        return Result(
            items: allItems,
            totalTOG: allItems.reduce(0) { $0 + $1.tog },
            missingBaseSlots: GarmentCompatibilityPolicy.missingBaseSlots(
                in: ordered,
                temperature: request.temperature
            )
        )
    }

    // MARK: - Search

    private static func search(
        candidates: [GarmentItem],
        startIndex: Int,
        selected: [GarmentItem],
        fixedTOG: Double,
        request: Request,
        bestItems: inout [GarmentItem],
        bestScore: inout Double
    ) {
        let candidateScore = score(items: selected, fixedTOG: fixedTOG, request: request)
        if candidateScore < bestScore {
            bestItems = selected
            bestScore = candidateScore
        }

        guard selected.count < OutfitConfig.Solver.maxBodyLayers,
              startIndex < candidates.count else {
            return
        }

        for index in startIndex..<candidates.count {
            let item = candidates[index]
            guard GarmentCompatibilityPolicy.canAdd(item, to: selected) else { continue }

            let next = selected + [item]
            guard respectsCarSeatLimit(next, request: request) else { continue }

            search(
                candidates: candidates,
                startIndex: index + 1,
                selected: next,
                fixedTOG: fixedTOG,
                request: request,
                bestItems: &bestItems,
                bestScore: &bestScore
            )
        }
    }

    // MARK: - Scoring

    private static func score(
        items: [GarmentItem],
        fixedTOG: Double,
        request: Request
    ) -> Double {
        let achieved = fixedTOG + items.reduce(0) { $0 + $1.tog }
        let delta = achieved - request.targetTOG
        let thermalWeight: Double
        if delta > 0 {
            thermalWeight = request.temperature >= 24 ? 1.8 : 1.15
        } else {
            thermalWeight = request.temperature < 10 ? 1.35 : 1.1
        }

        let missingSlots = GarmentCompatibilityPolicy.missingBaseSlots(
            in: items,
            temperature: request.temperature
        )
        let coveragePenalty = Double(missingSlots.count) * 8.0
        let emptyBodyPenalty = items.isEmpty ? 8.0 : 0
        let atopicPenalty = atopicFabricPenalty(items, profile: request.profile)
        let complexityPenalty = Double(items.count) * 0.015
        let agePreferenceBonus = items.reduce(0.0) { partial, item in
            partial + (item.recommendationAgeGroups.contains(request.profile.wardrobeAgeGroup)
                ? OutfitConfig.Solver.agePreferenceBonus
                : 0)
        }

        return abs(delta) * thermalWeight
            + coveragePenalty
            + emptyBodyPenalty
            + atopicPenalty
            + complexityPenalty
            - agePreferenceBonus
    }

    private static func respectsCarSeatLimit(
        _ items: [GarmentItem],
        request: Request
    ) -> Bool {
        guard request.transportMode == .carSeat else { return true }
        let underHarnessTOG = items
            .filter { $0.layer != .outerwear }
            .reduce(0) { $0 + $1.tog }
        return underHarnessTOG <= OutfitConfig.Solver.carSeatMaxHarnessLayerTOG
    }

    private static func atopicFabricPenalty(
        _ items: [GarmentItem],
        profile: ChildThermalProfile
    ) -> Double {
        guard profile.stableTraits.contains(.atopicDermatitis) else { return 0 }
        return items.contains { $0.id == "fleece_overall" } ? 0.35 : 0
    }
}
