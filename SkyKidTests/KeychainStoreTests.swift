import XCTest
@testable import SkyKid

final class KeychainStoreTests: XCTestCase {

    private func makeItem(synchronizable: Bool = false) -> KeychainStore.Item {
        KeychainStore.Item(
            service: "KeychainStoreTests.\(UUID().uuidString)",
            account: "test-account",
            synchronizable: synchronizable
        )
    }

    // MARK: - Basic save/read

    func test_save_thenRead_returnsSameData() {
        let item = makeItem()
        defer { KeychainStore.delete(item) }
        let payload = Data("hello-keychain".utf8)

        XCTAssertTrue(KeychainStore.save(payload, for: item))
        XCTAssertEqual(KeychainStore.read(item), payload)
    }

    func test_read_withoutSave_returnsNil() {
        let item = makeItem()
        XCTAssertNil(KeychainStore.read(item))
    }

    // MARK: - Upsert semantics

    func test_save_calledTwice_overwritesPreviousValue() {
        let item = makeItem()
        defer { KeychainStore.delete(item) }

        XCTAssertTrue(KeychainStore.save(Data("first".utf8), for: item))
        XCTAssertTrue(KeychainStore.save(Data("second".utf8), for: item))

        XCTAssertEqual(KeychainStore.read(item), Data("second".utf8))
    }

    // MARK: - Delete

    func test_delete_removesItem() {
        let item = makeItem()
        XCTAssertTrue(KeychainStore.save(Data("to-delete".utf8), for: item))

        XCTAssertTrue(KeychainStore.delete(item))
        XCTAssertNil(KeychainStore.read(item))
    }

    func test_delete_onMissingItem_stillReturnsTrue() {
        // KeychainStore.delete treats errSecItemNotFound as success —
        // regression guard for that behavior.
        let item = makeItem()
        XCTAssertTrue(KeychainStore.delete(item))
    }

    // MARK: - Isolation between distinct accounts/services

    func test_itemsWithDifferentAccounts_doNotCollide() {
        let service = "KeychainStoreTests.\(UUID().uuidString)"
        let itemA = KeychainStore.Item(service: service, account: "account-a")
        let itemB = KeychainStore.Item(service: service, account: "account-b")
        defer {
            KeychainStore.delete(itemA)
            KeychainStore.delete(itemB)
        }

        XCTAssertTrue(KeychainStore.save(Data("A".utf8), for: itemA))
        XCTAssertTrue(KeychainStore.save(Data("B".utf8), for: itemB))

        XCTAssertEqual(KeychainStore.read(itemA), Data("A".utf8))
        XCTAssertEqual(KeychainStore.read(itemB), Data("B".utf8))
    }

    func test_synchronizableFlag_isPartOfItemIdentity() {
        // An item saved as non-synchronizable should not be found through a
        // query for the synchronizable variant of the same service/account —
        // the two are treated as distinct Keychain entries.
        let service = "KeychainStoreTests.\(UUID().uuidString)"
        let nonSync = KeychainStore.Item(service: service, account: "shared-account", synchronizable: false)
        let sync = KeychainStore.Item(service: service, account: "shared-account", synchronizable: true)
        defer {
            KeychainStore.delete(nonSync)
            KeychainStore.delete(sync)
        }

        XCTAssertTrue(KeychainStore.save(Data("non-sync".utf8), for: nonSync))
        XCTAssertNil(KeychainStore.read(sync))
        XCTAssertEqual(KeychainStore.read(nonSync), Data("non-sync".utf8))
    }
}
