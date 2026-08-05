import Foundation

/// Состояние входа, переживающее перезапуск приложения:
/// пройден ли стартовый выбор «аккаунт или автономно» и какому аккаунту
/// принадлежат данные, лежащие сейчас в локальном хранилище.
///
/// `linkedAccountID` — ключевой инвариант всей синхронизации: данные,
/// созданные автономно, не привязаны ни к какому `auth.uid()`, и до явного
/// согласия пользователя (`AccountCard` → «Перенести») ничего не выгружается
/// на сервер, даже если вход уже выполнен.
enum AuthPreferences {
    static let offlineModeKey = "auth_offline_mode_chosen"
    static let linkedAccountKey = "auth_linked_account_id"
    static let dismissedMigrationKey = "auth_migration_offer_dismissed_for"
    static let familyKey = "auth_family_id"

    private static var defaults: UserDefaults { AppGroup.defaults }

    static var isOfflineModeChosen: Bool {
        get { defaults.bool(forKey: offlineModeKey) }
        set { defaults.set(newValue, forKey: offlineModeKey) }
    }

    static var linkedAccountID: UUID? {
        get { uuid(forKey: linkedAccountKey) }
        set { setUUID(newValue, forKey: linkedAccountKey) }
    }

    static var migrationOfferDismissedForAccountID: UUID? {
        get { uuid(forKey: dismissedMigrationKey) }
        set { setUUID(newValue, forKey: dismissedMigrationKey) }
    }

    /// Семья, которой принадлежат данные ребёнка. Одна на обоих родителей —
    /// именно по ней, а не по `auth.uid()`, RLS отдаёт профиль и прогулки.
    static var familyID: UUID? {
        get { uuid(forKey: familyKey) }
        set { setUUID(newValue, forKey: familyKey) }
    }

    private static func uuid(forKey key: String) -> UUID? {
        defaults.string(forKey: key).flatMap(UUID.init(uuidString:))
    }

    private static func setUUID(_ value: UUID?, forKey key: String) {
        if let value {
            defaults.set(value.uuidString, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
