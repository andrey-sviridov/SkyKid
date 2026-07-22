import Foundation

// SRP: личный гардероб пользователя — какие предметы из GarmentCatalog реально есть.
// OutfitSolver фильтрует каталог по этому набору; экран «Мой гардероб» редактирует.

@MainActor
@Observable
final class UserWardrobeStore {
    static let shared = UserWardrobeStore()

    static let key        = "user_wardrobe"
    static let seenKey    = "user_wardrobe_seen"      // снимок ID каталога на момент сохранения
    static let versionKey = "user_wardrobe_schema_version"

    /// Версия единого каталога: скрытые solver-ID удалены, а реальные предметы
    /// получили зоны тела и ограничения совместимости.
    static let currentSchemaVersion = 4

    /// id предметов в наличии. По умолчанию (ключ отсутствует) — весь каталог.
    private(set) var ownedIDs: Set<String>

    private init() {
        let allIDs = Set(GarmentCatalog.all.map(\.id))
        ownedIDs = Self.migratedOwnedIDs(
            saved:         AppGroup.defaults.stringArray(forKey: Self.key).map(Set.init),
            seen:          AppGroup.defaults.stringArray(forKey: Self.seenKey).map(Set.init),
            storedVersion: AppGroup.defaults.integer(forKey: Self.versionKey),
            allIDs:        allIDs
        )
        persist(allIDs: allIDs)
    }

    /// Чистая функция миграции — без побочных эффектов, удобно тестировать.
    /// - при известном старом снимке сохраняет пользовательские отметки;
    /// - при неизвестной старой схеме безопасно включает весь каталог;
    /// - авто-владение предметами, добавленными после прошлого запуска;
    /// - отбрасывание мёртвых ID, которых больше нет в каталоге.
    static func migratedOwnedIDs(
        saved: Set<String>?,
        seen: Set<String>?,
        storedVersion: Int,
        allIDs: Set<String>
    ) -> Set<String> {
        guard let saved else {
            return allIDs
        }
        let canonicalSaved = Set(saved.map { canonicalID($0, availableIn: allIDs) })
        let validSaved = canonicalSaved.intersection(allIDs)

        if storedVersion < currentSchemaVersion, seen == nil {
            return allIDs
        }

        let canonicalSeen = Set((seen ?? []).map { canonicalID($0, availableIn: allIDs) })
        let newItems = allIDs.subtracting(canonicalSeen)
        return validSaved.union(newItems).union(["diaper"])
    }

    private static func canonicalID(_ id: String, availableIn allIDs: Set<String>) -> String {
        let canonical = GarmentCatalog.canonicalID(for: id)
        return allIDs.contains(canonical) ? canonical : id
    }

    private func persist(allIDs: Set<String>) {
        AppGroup.defaults.set(Array(ownedIDs).sorted(), forKey: Self.key)
        AppGroup.defaults.set(Array(allIDs).sorted(),   forKey: Self.seenKey)
        AppGroup.defaults.set(Self.currentSchemaVersion, forKey: Self.versionKey)
    }

    func isOwned(_ id: String) -> Bool { ownedIDs.contains(id) }

    func toggle(_ id: String) {
        if ownedIDs.contains(id) { ownedIDs.remove(id) }
        else { ownedIDs.insert(id) }
        persist(allIDs: Set(GarmentCatalog.all.map(\.id)))
    }
}
