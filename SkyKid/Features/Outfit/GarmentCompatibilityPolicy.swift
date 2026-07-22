import Foundation

// MARK: - GarmentCompatibilityPolicy

/// Единые ограничения совместимости для нового TOG-решателя.
/// Старый Конструктор остаётся изолированным и не влияет на этот пайплайн.
enum GarmentCompatibilityPolicy {

    static func outdoorBodyItems(
        for ageGroup: WardrobeAgeGroup,
        availableIDs: Set<String>? = nil
    ) -> [GarmentItem] {
        GarmentCatalog.all.filter { item in
            item.id != "diaper"
                && item.use == .outdoorClothing
                && item.layer.occupiesBody
                && isSuitable(item, for: ageGroup)
                && (availableIDs?.contains(item.id) ?? true)
        }
    }

    static func accessoryItems(
        for ageGroup: WardrobeAgeGroup,
        availableIDs: Set<String>? = nil
    ) -> [GarmentItem] {
        GarmentCatalog.all.filter { item in
            item.use == .accessory
                && !item.coveredZones.isEmpty
                && isSuitable(item, for: ageGroup)
                && (availableIDs?.contains(item.id) ?? true)
        }
    }

    static func isSuitable(_ item: GarmentItem, for ageGroup: WardrobeAgeGroup) -> Bool {
        item.catalogAgeGroup?.matches(ageGroup) == true
    }

    static func canAdd(_ candidate: GarmentItem, to selected: [GarmentItem]) -> Bool {
        !selected.contains { conflicts(candidate, $0) }
    }

    static func conflicts(_ lhs: GarmentItem, _ rhs: GarmentItem) -> Bool {
        guard lhs.id != rhs.id else { return true }

        let overlappingSlots = !lhs.layer.bodySlots.isDisjoint(with: rhs.layer.bodySlots)
        if overlappingSlots { return true }

        guard let lhsGroup = lhs.exclusiveGroup,
              let rhsGroup = rhs.exclusiveGroup else {
            return false
        }
        return lhsGroup == rhsGroup
    }

    static func requiredBaseSlots(at temperature: Double) -> Set<BodySlot> {
        temperature >= OutfitConfig.TOG.ageAdjHotThreshold
            ? [.baseTop]
            : [.baseTop, .baseBottom]
    }

    static func missingBaseSlots(
        in items: [GarmentItem],
        temperature: Double
    ) -> Set<BodySlot> {
        let occupied = Set(items.flatMap { $0.layer.bodySlots })
        return requiredBaseSlots(at: temperature).subtracting(occupied)
    }

    static func orderedForDressing(_ items: [GarmentItem]) -> [GarmentItem] {
        items.sorted { lhs, rhs in
            let lhsRank = dressingRank(lhs.layer)
            let rhsRank = dressingRank(rhs.layer)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.layer != rhs.layer { return lhs.layer.rawValue < rhs.layer.rawValue }
            return lhs.tog < rhs.tog
        }
    }

    // MARK: - Private

    private static func dressingRank(_ layer: GarmentLayer) -> Int {
        switch layer {
        case .baseFull, .baseTop, .baseBottom: return 0
        case .midFull, .midTop, .midBottom: return 1
        case .outerwear: return 2
        case .accessory: return 3
        case .sleepwear: return 4
        }
    }
}
