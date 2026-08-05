import XCTest
import CryptoKit
@testable import SkyKid

/// Regression coverage for the new Supabase Auth / sync integration
/// (`SupabaseAuthService`, `SupabaseSyncService`, `ChildNameCipher`).
///
/// These tests avoid any real network traffic: `SupabaseAuthService.shared`
/// is never actually signed in during the test run, so
/// `SupabaseClient.auth.signOut()` returns immediately without hitting the
/// network (see `AuthClient.signOut()` — it early-returns when
/// `currentSession` has no access token), and `SupabaseSyncService`'s
/// push/pull methods all early-return when `SupabaseAuthService.shared.userID`
/// is `nil`. This lets us exercise the *local* side-effects of these calls
/// deterministically.
@MainActor
final class AuthSyncTests: XCTestCase {

    // MARK: - Bug: signOut() does not clear locally cached ChildProfile

    /// Regression test for the account-switch data leak described in the
    /// task brief: `SupabaseAuthService.signOut()` used to only clear
    /// `isSignedIn`/`userID` and never touch `ChildProfileStore`. If a
    /// second user signed in on the same device afterwards (after an app
    /// relaunch, so `ContentView`'s local `@State childProfile` is
    /// re-seeded from the store), `ContentView.syncOnLaunch()` would see a
    /// non-nil local `childProfile` and *push* it (still user A's child)
    /// under user B's `auth.uid()`, silently overwriting user B's profile
    /// on the server.
    ///
    /// Fixed by having `signOut()` clear `ChildProfileStore.shared.profile`
    /// — see `SupabaseAuthService.clearLocallyCachedAccountData()`.
    func test_signOut_clearsLocallyCachedChildProfile() async {
        let originalProfile = ChildProfileStore.shared.profile
        addTeardownBlock {
            await MainActor.run {
                ChildProfileStore.shared.profile = originalProfile
            }
        }

        let leftoverProfile = ChildProfile(
            name: "УтечкаА",
            gender: .girl,
            birthday: Date(timeIntervalSince1970: 1_850_000_000)
        )
        ChildProfileStore.shared.profile = leftoverProfile
        XCTAssertEqual(ChildProfileStore.shared.profile?.name, "УтечкаА")

        // Not actually signed in -> no network call, purely exercises the
        // local cleanup (or lack thereof) performed by signOut().
        XCTAssertFalse(SupabaseAuthService.shared.isSignedIn)
        await SupabaseAuthService.shared.signOut()

        XCTAssertNil(
            ChildProfileStore.shared.profile,
            "signOut() must clear the locally cached ChildProfile to avoid " +
            "leaking it into the next signed-in account via syncOnLaunch()"
        )
    }

    /// Same leak, but for `WalkLogStore.shared`: without `clearAll()`,
    /// signOut() would never empty `logs`, so a second user's
    /// syncOnLaunch() (`walkLogStore.logs.isEmpty ? pull : push`) would push
    /// user A's walk history onto user B's account.
    func test_signOut_clearsSharedWalkLogStore() async {
        let originalLogs = WalkLogStore.shared.logs
        addTeardownBlock {
            await MainActor.run {
                for log in originalLogs {
                    WalkLogStore.shared.add(log, profile: nil)
                }
            }
        }
        // Start from a clean slate so this test is not order-dependent on
        // whatever earlier tests left behind.
        WalkLogStore.shared.clearAll()

        let leftoverLog = WalkLog(
            durationMinutes: 20,
            comfortLevel: .comfortable,
            weatherTemperature: 10,
            apparentTemperature: 9
        )
        WalkLogStore.shared.add(leftoverLog, profile: nil)
        XCTAssertEqual(WalkLogStore.shared.logs.count, 1)

        XCTAssertFalse(SupabaseAuthService.shared.isSignedIn)
        await SupabaseAuthService.shared.signOut()

        XCTAssertTrue(
            WalkLogStore.shared.logs.isEmpty,
            "signOut() must clear WalkLogStore.shared.logs to avoid leaking " +
            "them into the next signed-in account via syncOnLaunch()"
        )
    }

    // MARK: - ChildNameCipher: mismatched key must fail safely, not crash

    /// Simulates the iCloud-Keychain key-merge race from hypothesis 3: two
    /// devices independently create an AES key before iCloud Keychain sync
    /// converges, and the ciphertext produced with the losing key becomes
    /// undecryptable everywhere the winning key is now the ambient one.
    ///
    /// This does not reproduce the race itself (that needs two devices +
    /// iCloud), but proves the failure mode is a thrown, catchable error —
    /// not a crash and not garbage plaintext — which is what
    /// `SupabaseSyncService.pullProfile()` relies on (it wraps the decrypt
    /// call in `do { } catch { return nil }`).
    func test_decrypt_withMismatchedKey_throwsInsteadOfCrashingOrReturningGarbage() throws {
        let item = KeychainStore.Item(
            service: "com.skykid.app.child-name-key",
            account: "aes-gcm-key",
            synchronizable: true
        )
        let originalKeyData = KeychainStore.read(item)
        addTeardownBlock {
            if let originalKeyData {
                KeychainStore.save(originalKeyData, for: item)
            } else {
                KeychainStore.delete(item)
            }
        }

        // Ensure a known key exists, then encrypt with it ("device A").
        KeychainStore.delete(item)
        let ciphertext = try ChildNameCipher.encrypt("Секретное имя")

        // Simulate "device B" winning the iCloud Keychain merge with a
        // different key before device A's data could be re-encrypted.
        let conflictingKey = SymmetricKey(size: .bits256)
        let conflictingKeyData = conflictingKey.withUnsafeBytes { Data($0) }
        XCTAssertTrue(KeychainStore.save(conflictingKeyData, for: item))

        XCTAssertThrowsError(try ChildNameCipher.decrypt(ciphertext)) { error in
            // CryptoKit throws CryptoKitError.authenticationFailure for a
            // GCM tag mismatch — assert it's *some* thrown error, not that
            // decrypt silently produced a wrong-but-plausible name.
            XCTAssertTrue(error is CryptoKitError || error is ChildNameCipher.CipherError)
        }
    }

    // MARK: - restoreSession(): plausibility check (no live network mocking available)

    /// `restoreSession()` cannot be fully exercised without stubbing
    /// `SupabaseClientProvider.client` (it's a hardcoded `let`, not
    /// injectable), so this is a narrower check: with no session ever
    /// stored in the Keychain-backed `KeychainAuthLocalStorage`,
    /// `restoreSession()` must resolve to signed-out without hanging or
    /// throwing out of the function (the underlying `AuthError.sessionMissing`
    /// must be swallowed).
    func test_restoreSession_withNoStoredSession_resolvesSignedOut() async {
        await SupabaseAuthService.shared.restoreSession()
        XCTAssertFalse(SupabaseAuthService.shared.isSignedIn)
        XCTAssertNil(SupabaseAuthService.shared.userID)
    }

    // MARK: - Стартовый выбор входа (AuthGateView)

    /// Профиль ребёнка не создаётся, пока пользователь не сделал выбор:
    /// `ContentView` показывает `AuthGateView`, пока `hasPassedEntryGate`
    /// ложно. Выбор «без аккаунта» должен открывать гейт и переживать
    /// перезапуск — иначе онбординг будет требовать вход на каждом старте.
    func test_continueOffline_opensEntryGateAndPersists() async {
        restoreAuthPreferencesAfterTest()
        await SupabaseAuthService.shared.signOut()

        XCTAssertFalse(
            SupabaseAuthService.shared.hasPassedEntryGate,
            "без входа и без явного выбора автономного режима гейт закрыт"
        )

        SupabaseAuthService.shared.continueOffline()

        XCTAssertTrue(SupabaseAuthService.shared.hasPassedEntryGate)
        XCTAssertTrue(
            AuthPreferences.isOfflineModeChosen,
            "выбор должен пережить перезапуск — иначе гейт вернётся при " +
            "следующем запуске уже настроенного приложения"
        )
    }

    /// «Продолжить без аккаунта» — не билет в один конец: с экрана создания
    /// профиля (`ChildProfileSetupView`, кнопка «Вход») пользователь может
    /// передумать и вернуться к `AuthGateView`, не выходя из приложения и не
    /// переустанавливая его.
    func test_exitOfflineMode_returnsToEntryGate() {
        restoreAuthPreferencesAfterTest()

        SupabaseAuthService.shared.continueOffline()
        XCTAssertTrue(SupabaseAuthService.shared.hasPassedEntryGate)

        SupabaseAuthService.shared.exitOfflineMode()

        XCTAssertFalse(
            SupabaseAuthService.shared.hasPassedEntryGate,
            "гейт должен снова закрыться — ContentView показывает AuthGateView"
        )
        XCTAssertFalse(AuthPreferences.isOfflineModeChosen)
    }

    /// Выход возвращает пользователя к стартовому выбору: локальный кеш уже
    /// стёрт, поэтому пропускать его сразу во вкладки не на чем.
    func test_signOut_resetsEntryGate() async {
        restoreAuthPreferencesAfterTest()

        SupabaseAuthService.shared.continueOffline()
        XCTAssertTrue(SupabaseAuthService.shared.hasPassedEntryGate)

        await SupabaseAuthService.shared.signOut()

        XCTAssertFalse(SupabaseAuthService.shared.hasPassedEntryGate)
        XCTAssertFalse(AuthPreferences.isOfflineModeChosen)
    }

    // MARK: - Привязка локальных данных к аккаунту

    /// Ключевой инвариант переноса: пока локальные данные не привязаны к
    /// текущему `auth.uid()`, `SupabaseSyncService` не выгружает их. Без
    /// этого автономно созданный профиль улетал бы на сервер при первом же
    /// редактировании после входа — до того, как пользователь согласился на
    /// перенос в `AccountCard`.
    func test_localData_isNotLinkedWhileSignedOut() async {
        restoreAuthPreferencesAfterTest()
        await SupabaseAuthService.shared.signOut()

        XCTAssertFalse(SupabaseAuthService.shared.isLocalDataLinkedToCurrentAccount)

        // Привязка без аккаунта невозможна — иначе после входа под другим
        // пользователем чужие данные считались бы «своими».
        SupabaseAuthService.shared.linkLocalDataToCurrentAccount()
        XCTAssertNil(SupabaseAuthService.shared.linkedAccountID)
        XCTAssertFalse(SupabaseAuthService.shared.isLocalDataLinkedToCurrentAccount)
    }

    /// Выход отвязывает локальное хранилище: следующий вошедший аккаунт не
    /// должен унаследовать привязку предыдущего.
    func test_signOut_unlinksLocalData() async {
        restoreAuthPreferencesAfterTest()

        let previousAccount = UUID()
        AuthPreferences.linkedAccountID = previousAccount
        AuthPreferences.migrationOfferDismissedForAccountID = previousAccount

        await SupabaseAuthService.shared.signOut()

        XCTAssertNil(SupabaseAuthService.shared.linkedAccountID)
        XCTAssertNil(AuthPreferences.linkedAccountID)
        XCTAssertNil(AuthPreferences.migrationOfferDismissedForAccountID)
    }

    /// Перенос без аккаунта — не операция: он не должен «успешно» отчитаться
    /// и тем более оставить после себя привязку, из-за которой карточка
    /// аккаунта перестала бы предлагать перенос.
    func test_migrateLocalData_whileSignedOut_failsWithoutLinking() async {
        restoreAuthPreferencesAfterTest()
        await SupabaseAuthService.shared.signOut()

        let profile = ChildProfile(
            name: "Автономный",
            gender: .boy,
            birthday: Date(timeIntervalSince1970: 1_850_000_000)
        )
        let succeeded = await SupabaseSyncService.shared.migrateLocalDataToCurrentAccount(
            profile: profile,
            walkLogs: []
        )

        XCTAssertFalse(succeeded)
        XCTAssertNil(SupabaseAuthService.shared.linkedAccountID)
    }

    /// `AuthPreferences` — единственное место, где состояние входа переживает
    /// перезапуск; round-trip через App Group должен быть без потерь.
    func test_authPreferences_roundTripThroughAppGroup() {
        restoreAuthPreferencesAfterTest()

        let account = UUID()
        AuthPreferences.isOfflineModeChosen = true
        AuthPreferences.linkedAccountID = account
        AuthPreferences.migrationOfferDismissedForAccountID = account

        XCTAssertTrue(AuthPreferences.isOfflineModeChosen)
        XCTAssertEqual(AuthPreferences.linkedAccountID, account)
        XCTAssertEqual(AuthPreferences.migrationOfferDismissedForAccountID, account)

        AuthPreferences.linkedAccountID = nil
        AuthPreferences.migrationOfferDismissedForAccountID = nil

        XCTAssertNil(AuthPreferences.linkedAccountID)
        XCTAssertNil(AuthPreferences.migrationOfferDismissedForAccountID)
    }

    // MARK: - Дата рождения: колонка `date`, а не таймстемп

    /// Регрессия на «после входа приложение снова просит создать профиль,
    /// хотя в БД он есть»: `child_profiles.birthday` — колонка типа `date`,
    /// PostgREST отдаёт её как «2001-05-14». Пока строка декодировалась как
    /// `Date`, декодер supabase-swift (он принимает только полный
    /// ISO-таймстемп) падал, `pullProfile()` глотал ошибку и возвращал `nil`.
    func test_birthday_parsesDateOnlyStringFromPostgres() throws {
        let parsed = try BirthdayFormat.date(from: "2001-05-14")

        let components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: parsed
        )
        XCTAssertEqual(components.year, 2001)
        XCTAssertEqual(components.month, 5)
        XCTAssertEqual(components.day, 14)
    }

    /// Вторая половина той же ошибки: `Date` сериализуется в GMT, поэтому
    /// выбранная в UTC+5 полночь уезжала на сервер предыдущим днём и после
    /// приведения к `date` сохранялась со сдвигом на сутки. День рождения
    /// должен доезжать ровно тем календарным днём, который выбрал
    /// пользователь.
    func test_birthday_roundTripsWithoutTimeZoneShift() throws {
        let birthday = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2001, month: 5, day: 14))
        )

        let encoded = BirthdayFormat.string(from: birthday)
        XCTAssertEqual(encoded, "2001-05-14")

        let decoded = try BirthdayFormat.date(from: encoded)
        XCTAssertEqual(decoded, birthday)
    }

    func test_birthday_rejectsMalformedValueInsteadOfInventingADate() {
        XCTAssertThrowsError(try BirthdayFormat.date(from: "14.05.2001"))
    }

    // MARK: - Совместный доступ второго родителя

    /// Код приглашения — единственный канал, по которому ключ шифрования
    /// имени ребёнка попадает ко второму родителю (сервер его не видит),
    /// поэтому round-trip обязан быть точным.
    func test_familyInviteCode_roundTripsIDAndKey() throws {
        let inviteID = UUID()
        let key = "0jS/9Yy1kq+wCk3nDx8vQm5R2tZaB7cE4fG6hJ8kL0M="

        let code = FamilyInviteCode.make(inviteID: inviteID, keyBase64: key)
        let parsed = try FamilyInviteCode.parse(code)

        XCTAssertEqual(parsed.inviteID, inviteID)
        XCTAssertEqual(
            parsed.keyBase64,
            key,
            "base64-ключ содержит '+' и '/', и они не должны потеряться при разборе"
        )
    }

    /// Код приезжает из мессенджера — с переводами строк и лишними пробелами.
    func test_familyInviteCode_toleratesWhitespaceFromMessengers() throws {
        let inviteID = UUID()
        let code = FamilyInviteCode.make(inviteID: inviteID, keyBase64: "abc=")

        let parsed = try FamilyInviteCode.parse("  \n\(code)\n ")

        XCTAssertEqual(parsed.inviteID, inviteID)
    }

    func test_familyInviteCode_rejectsGarbageInsteadOfHittingTheNetwork() {
        XCTAssertThrowsError(try FamilyInviteCode.parse("12345"))
        XCTAssertThrowsError(try FamilyInviteCode.parse("skykid1:not-a-uuid.key"))
        XCTAssertThrowsError(try FamilyInviteCode.parse("skykid1:\(UUID().uuidString)"))
        XCTAssertThrowsError(try FamilyInviteCode.parse("skykid1:\(UUID().uuidString)."))
    }

    /// Присоединение к семье означает переход на её ключ: имя ребёнка,
    /// зашифрованное приглашающим, должно читаться на устройстве второго
    /// родителя.
    func test_importedFamilyKey_decryptsInvitersCiphertext() throws {
        let item = KeychainStore.Item(
            service: "com.skykid.app.child-name-key",
            account: "aes-gcm-key",
            synchronizable: true
        )
        let originalKeyData = KeychainStore.read(item)
        addTeardownBlock {
            if let originalKeyData {
                KeychainStore.save(originalKeyData, for: item)
            } else {
                KeychainStore.delete(item)
            }
        }

        // Устройство приглашающего: свой ключ, им шифруется имя.
        KeychainStore.delete(item)
        let inviterKey = try ChildNameCipher.exportKeyBase64()
        let ciphertext = try ChildNameCipher.encrypt("Алиса")

        // Устройство второго родителя: свой, другой ключ — чужое имя не
        // читается…
        KeychainStore.delete(item)
        _ = try ChildNameCipher.exportKeyBase64()
        XCTAssertThrowsError(try ChildNameCipher.decrypt(ciphertext))

        // …пока он не применит ключ из кода приглашения.
        try ChildNameCipher.importKey(base64: inviterKey)
        XCTAssertEqual(try ChildNameCipher.decrypt(ciphertext), "Алиса")
    }

    func test_importKey_rejectsWrongSizedKey() {
        XCTAssertThrowsError(try ChildNameCipher.importKey(base64: "c2hvcnQ="))
        XCTAssertThrowsError(try ChildNameCipher.importKey(base64: "не base64"))
    }

    // MARK: - Helpers

    /// Состояние входа лежит в общем App Group — восстанавливаем его, чтобы
    /// тесты не зависели от порядка и не ломали установленное приложение.
    private func restoreAuthPreferencesAfterTest() {
        let offlineMode = AuthPreferences.isOfflineModeChosen
        let linkedAccount = AuthPreferences.linkedAccountID
        let dismissedFor = AuthPreferences.migrationOfferDismissedForAccountID
        addTeardownBlock {
            AuthPreferences.isOfflineModeChosen = offlineMode
            AuthPreferences.linkedAccountID = linkedAccount
            AuthPreferences.migrationOfferDismissedForAccountID = dismissedFor
        }
    }
}
