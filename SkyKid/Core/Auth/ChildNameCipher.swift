import Foundation
import CryptoKit

/// Шифрует/расшифровывает имя ребёнка перед отправкой в Supabase.
///
/// Ключ живёт только в iCloud Keychain (`kSecAttrSynchronizable`) —
/// автоматически доступен на всех устройствах того же Apple ID, но
/// Supabase его никогда не видит: сервер получает только base64
/// combined-блок (nonce + ciphertext + tag) в поле `encrypted_name`.
enum ChildNameCipher {
    enum CipherError: Error {
        case keyUnavailable
        case invalidData
    }

    private static let keychainItem = KeychainStore.Item(
        service: "com.skykid.app.child-name-key",
        account: "aes-gcm-key",
        synchronizable: true
    )

    static func encrypt(_ name: String) throws -> String {
        let key = try loadOrCreateKey()
        let sealed = try AES.GCM.seal(Data(name.utf8), using: key)
        guard let combined = sealed.combined else { throw CipherError.invalidData }
        return combined.base64EncodedString()
    }

    static func decrypt(_ base64: String) throws -> String {
        guard let data = Data(base64Encoded: base64) else { throw CipherError.invalidData }
        let key = try loadOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let plain = try AES.GCM.open(sealedBox, using: key)
        guard let name = String(data: plain, encoding: .utf8) else { throw CipherError.invalidData }
        return name
    }

    // MARK: - Общий ключ семьи

    /// Ключ для передачи второму родителю внутри кода приглашения.
    ///
    /// Ключ едет мимо сервера — в коде, который родители пересылают друг
    /// другу сами, поэтому Supabase по-прежнему видит только шифротекст.
    /// Обратная сторона: код приглашения — это и есть доступ к имени
    /// ребёнка, пересылать его стоит так же аккуратно, как пароль.
    static func exportKeyBase64() throws -> String {
        let key = try loadOrCreateKey()
        return key.withUnsafeBytes { Data($0) }.base64EncodedString()
    }

    /// Присоединение к семье: ключ приглашающего становится общим.
    ///
    /// Прежний ключ устройства перезаписывается — данные, зашифрованные им
    /// раньше, читаться перестанут. Для присоединяющегося это ожидаемо: он
    /// переходит на данные семьи, к которой присоединился.
    static func importKey(base64: String) throws {
        guard let data = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)),
              data.count == 32
        else {
            throw CipherError.invalidData
        }
        guard KeychainStore.save(data, for: keychainItem) else {
            throw CipherError.keyUnavailable
        }
    }

    private static func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = KeychainStore.read(keychainItem) {
            return SymmetricKey(data: existing)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        guard KeychainStore.save(keyData, for: keychainItem) else {
            throw CipherError.keyUnavailable
        }
        return newKey
    }
}
