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

    /// Каталог одежды переписан (анатомическая топология, новые ID). Старые
    /// сохранённые наборы ссылались на мёртвые ID → подбор схлопывался до
    /// «подгузник + боди». Bump версии один раз сбрасывает гардероб в
    /// «всё в наличии». Инкрементировать при любой смене ID каталога.
    static let currentSchemaVersion = 3

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
    /// - reseed к полному каталогу, если схема устарела (переименование ID);
    /// - авто-владение предметами, добавленными после прошлого запуска;
    /// - отбрасывание мёртвых ID, которых больше нет в каталоге.
    static func migratedOwnedIDs(
        saved: Set<String>?,
        seen: Set<String>?,
        storedVersion: Int,
        allIDs: Set<String>
    ) -> Set<String> {
        // Схема изменилась (или первый запуск) → весь гардероб считается в наличии.
        guard storedVersion >= currentSchemaVersion, let saved else {
            return allIDs
        }
        // Новые предметы каталога (появились после прошлого сохранения) — авто-владение.
        let newItems = allIDs.subtracting(seen ?? [])
        let canonicalSaved = Set(saved.map { GarmentCatalog.canonicalID(for: $0) })
        return canonicalSaved.intersection(allIDs).union(newItems)
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
