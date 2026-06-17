import Foundation

// SRP: личный гардероб пользователя — какие предметы из GarmentCatalog реально есть.
// OutfitSolver фильтрует каталог по этому набору; экран «Мой гардероб» редактирует.

@MainActor
@Observable
final class UserWardrobeStore {
    static let shared = UserWardrobeStore()

    static let key = "user_wardrobe"

    /// id предметов в наличии. По умолчанию (ключ отсутствует) — весь каталог.
    private(set) var ownedIDs: Set<String>

    private init() {
        if let saved = AppGroup.defaults.stringArray(forKey: Self.key) {
            ownedIDs = Set(saved)
        } else {
            ownedIDs = Set(GarmentCatalog.all.map(\.id))
        }
    }

    func isOwned(_ id: String) -> Bool { ownedIDs.contains(id) }

    func toggle(_ id: String) {
        if ownedIDs.contains(id) { ownedIDs.remove(id) }
        else { ownedIDs.insert(id) }
        AppGroup.defaults.set(Array(ownedIDs).sorted(), forKey: Self.key)
    }
}
