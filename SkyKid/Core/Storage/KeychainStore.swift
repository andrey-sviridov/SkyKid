import Foundation
import Security

// MARK: - KeychainStore

/// Тонкая обёртка над Keychain Services для хранения секретов (ключ
/// шифрования имени ребёнка, сессия Supabase Auth) — ни то, ни другое не
/// должно лежать в обычном UserDefaults/App Group.
enum KeychainStore {

    /// Координаты элемента в Keychain.
    struct Item {
        let service: String
        let account: String
        /// `true` — элемент синхронизируется через iCloud Keychain и
        /// становится доступен на всех устройствах того же Apple ID
        /// (нужно для ключа шифрования имени: тот же ключ должен быть
        /// доступен и на новом устройстве после входа, без участия сервера).
        var synchronizable: Bool = false
    }

    static func read(_ item: Item) -> Data? {
        var query = baseQuery(for: item)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Добавляет элемент либо обновляет существующий (upsert).
    @discardableResult
    static func save(_ data: Data, for item: Item) -> Bool {
        var query = baseQuery(for: item)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess { return true }

        guard addStatus == errSecDuplicateItem else { return false }

        let updateQuery = baseQuery(for: item)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        return updateStatus == errSecSuccess
    }

    @discardableResult
    static func delete(_ item: Item) -> Bool {
        let query = baseQuery(for: item)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static func baseQuery(for item: Item) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: item.service,
            kSecAttrAccount as String: item.account,
            kSecAttrSynchronizable as String: item.synchronizable,
        ]
    }
}
