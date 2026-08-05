import XCTest
@testable import SkyKid

final class ChildNameCipherTests: XCTestCase {

    /// Mirrors the private coordinates `ChildNameCipher` uses internally, so
    /// tests can reset the encryption key between runs instead of leaking a
    /// test-generated key into the simulator's persistent Keychain.
    private let cipherKeyItem = KeychainStore.Item(
        service: "com.skykid.app.child-name-key",
        account: "aes-gcm-key",
        synchronizable: true
    )

    override func setUp() {
        super.setUp()
        KeychainStore.delete(cipherKeyItem)
    }

    override func tearDown() {
        KeychainStore.delete(cipherKeyItem)
        super.tearDown()
    }

    // MARK: - Round trip

    func test_encryptThenDecrypt_returnsOriginalName() throws {
        let name = "Александр"
        let encrypted = try ChildNameCipher.encrypt(name)
        let decrypted = try ChildNameCipher.decrypt(encrypted)

        XCTAssertEqual(decrypted, name)
    }

    func test_encryptThenDecrypt_handlesUnicodeAndEmoji() throws {
        let name = "Süß 👶🏻 Ёжик"
        let encrypted = try ChildNameCipher.encrypt(name)
        let decrypted = try ChildNameCipher.decrypt(encrypted)

        XCTAssertEqual(decrypted, name)
    }

    func test_encryptThenDecrypt_handlesEmptyString() throws {
        let encrypted = try ChildNameCipher.encrypt("")
        let decrypted = try ChildNameCipher.decrypt(encrypted)

        XCTAssertEqual(decrypted, "")
    }

    // MARK: - Key persistence across calls

    func test_secondEncryptCall_reusesSamePersistedKey() throws {
        // First call creates and persists the key; the second call must load
        // the SAME key rather than silently minting a new one (which would
        // make previously-encrypted names permanently undecryptable).
        let first = try ChildNameCipher.encrypt("Мария")
        let second = try ChildNameCipher.encrypt("Иван")

        // Both ciphertexts must be decryptable by whatever key is currently
        // in the Keychain, proving the key did not rotate between calls.
        XCTAssertEqual(try ChildNameCipher.decrypt(first), "Мария")
        XCTAssertEqual(try ChildNameCipher.decrypt(second), "Иван")
    }

    // MARK: - Privacy: no plaintext leakage

    func test_encryptedOutput_neverContainsPlaintextName() throws {
        let name = "Екатерина"
        let encrypted = try ChildNameCipher.encrypt(name)

        XCTAssertFalse(encrypted.contains(name))
        // Also guard against the raw UTF-8 bytes appearing unencoded.
        XCTAssertFalse(encrypted.data(using: .utf8)?.contains(Data(name.utf8)) ?? false)
    }

    func test_encryptingSameNameTwice_producesDifferentCiphertext() throws {
        // AES-GCM must use a fresh random nonce per call; identical
        // ciphertext for identical plaintext would indicate nonce reuse,
        // which breaks GCM's confidentiality/integrity guarantees.
        let name = "Дмитрий"
        let first = try ChildNameCipher.encrypt(name)
        let second = try ChildNameCipher.encrypt(name)

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try ChildNameCipher.decrypt(first), name)
        XCTAssertEqual(try ChildNameCipher.decrypt(second), name)
    }

    // MARK: - Error handling

    func test_decrypt_withInvalidBase64_throwsInvalidData() {
        XCTAssertThrowsError(try ChildNameCipher.decrypt("not-valid-base64!!!")) { error in
            XCTAssertEqual(error as? ChildNameCipher.CipherError, .invalidData)
        }
    }

    func test_decrypt_withTamperedCiphertext_throwsRatherThanReturningGarbage() throws {
        let encrypted = try ChildNameCipher.encrypt("Наталья")
        guard var data = Data(base64Encoded: encrypted) else {
            return XCTFail("Expected valid base64 from encrypt()")
        }
        // Flip a byte in the middle of the combined nonce+ciphertext+tag blob.
        data[data.count / 2] ^= 0xFF
        let tampered = data.base64EncodedString()

        XCTAssertThrowsError(try ChildNameCipher.decrypt(tampered))
    }

    func test_decrypt_withTruncatedData_throwsInvalidData() {
        XCTAssertThrowsError(try ChildNameCipher.decrypt("QQ==")) // 1 byte, too short for nonce+tag
    }
}

extension ChildNameCipher.CipherError: Equatable {
    public static func == (lhs: ChildNameCipher.CipherError, rhs: ChildNameCipher.CipherError) -> Bool {
        switch (lhs, rhs) {
        case (.keyUnavailable, .keyUnavailable), (.invalidData, .invalidData):
            return true
        default:
            return false
        }
    }
}
