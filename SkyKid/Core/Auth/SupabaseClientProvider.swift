import Foundation
import Supabase

/// Единая точка создания `SupabaseClient`. Сессия (access/refresh token)
/// хранится в Keychain через `KeychainAuthLocalStorage`, а не в дефолтном
/// UserDefaults — токены не должны лежать открыто.
enum SupabaseClientProvider {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.projectURL,
        supabaseKey: SupabaseConfig.anonKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                storage: KeychainAuthLocalStorage()
            )
        )
    )
}

/// Мост между `KeychainStore` и `AuthLocalStorage` supabase-swift.
struct KeychainAuthLocalStorage: AuthLocalStorage {
    private static let service = "com.skykid.app.supabase-auth"

    func store(key: String, value: Data) throws {
        KeychainStore.save(value, for: item(for: key))
    }

    func retrieve(key: String) throws -> Data? {
        KeychainStore.read(item(for: key))
    }

    func remove(key: String) throws {
        KeychainStore.delete(item(for: key))
    }

    private func item(for key: String) -> KeychainStore.Item {
        KeychainStore.Item(service: Self.service, account: key)
    }
}
