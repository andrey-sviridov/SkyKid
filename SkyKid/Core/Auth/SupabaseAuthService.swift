import Foundation
import Observation
import Supabase

/// Sign in with Google (OAuth через `ASWebAuthenticationSession`) → Supabase
/// Auth. Приложение и БД оперируют только `auth.uid()`.
@MainActor
@Observable
final class SupabaseAuthService {
    static let shared = SupabaseAuthService()

    private(set) var isSignedIn = false
    private(set) var userID: UUID?

    /// Как выглядит текущий аккаунт для самого пользователя и для второго
    /// родителя: почта, имя из профиля провайдера и способ входа. Второй
    /// родитель видит те же поля через `family_members_info()`.
    private(set) var accountEmail: String?
    private(set) var accountDisplayName: String?
    private(set) var accountProvider: String?

    /// Подпись для карточки аккаунта: имя, а если провайдер его не дал —
    /// почта. `nil` — оба поля пусты, и показывать нечего.
    var accountTitle: String? { accountDisplayName ?? accountEmail }

    /// Пользователь сознательно выбрал работу без аккаунта на стартовом
    /// экране (`AuthGateView`).
    private(set) var isOfflineMode = AuthPreferences.isOfflineModeChosen

    /// Аккаунт, которому принадлежат данные в локальном хранилище.
    /// `nil` — данные созданы автономно и ещё не перенесены (см.
    /// [AuthPreferences]).
    private(set) var linkedAccountID = AuthPreferences.linkedAccountID

    private(set) var migrationOfferDismissedForAccountID =
        AuthPreferences.migrationOfferDismissedForAccountID

    /// Семья, которой принадлежат данные ребёнка: она общая у обоих
    /// родителей, и запросы к Supabase фильтруются по ней, а не по `userID`.
    private(set) var familyID = AuthPreferences.familyID

    func setFamilyID(_ id: UUID?) {
        familyID = id
        AuthPreferences.familyID = id
    }

    private init() {}

    // MARK: - Стартовый выбор входа

    /// Профиль ребёнка не создаётся, пока пользователь не вошёл в аккаунт
    /// или явно не выбрал автономный режим.
    var hasPassedEntryGate: Bool { isSignedIn || isOfflineMode }

    func continueOffline() {
        isOfflineMode = true
        AuthPreferences.isOfflineModeChosen = true
    }

    /// Возврат к стартовому выбору: «без аккаунта» — не билет в один конец,
    /// с экрана создания профиля можно передумать и всё-таки войти.
    func exitOfflineMode() {
        isOfflineMode = false
        AuthPreferences.isOfflineModeChosen = false
    }

    // MARK: - Привязка локальных данных к аккаунту

    /// Локальные данные принадлежат текущему аккаунту — их можно
    /// синхронизировать без дополнительного согласия.
    var isLocalDataLinkedToCurrentAccount: Bool {
        guard let userID else { return false }
        return linkedAccountID == userID
    }

    func linkLocalDataToCurrentAccount() {
        guard let userID else { return }
        linkedAccountID = userID
        AuthPreferences.linkedAccountID = userID
        if migrationOfferDismissedForAccountID == userID {
            migrationOfferDismissedForAccountID = nil
            AuthPreferences.migrationOfferDismissedForAccountID = nil
        }
    }

    /// Откат привязки, если перенос не доехал до сервера — предложение
    /// вернётся, и пользователь сможет повторить (upsert идемпотентен).
    func unlinkLocalData() {
        linkedAccountID = nil
        AuthPreferences.linkedAccountID = nil
    }

    var isMigrationOfferDismissed: Bool {
        guard let userID else { return false }
        return migrationOfferDismissedForAccountID == userID
    }

    func dismissMigrationOffer() {
        guard let userID else { return }
        migrationOfferDismissedForAccountID = userID
        AuthPreferences.migrationOfferDismissedForAccountID = userID
    }

    // MARK: - Session restore

    func restoreSession() async {
        do {
            let session = try await SupabaseClientProvider.client.auth.session
            apply(user: session.user)
        } catch {
            isSignedIn = false
            userID = nil
            clearAccountIdentity()
        }
    }

    /// Google кладёт имя в `full_name`, часть провайдеров — в `name`.
    private func apply(user: User) {
        userID = user.id
        isSignedIn = true
        accountEmail = user.email
        accountDisplayName = Self.metadataString(user, keys: ["full_name", "name"])
        accountProvider = user.appMetadata["provider"]?.stringValue
    }

    private static func metadataString(_ user: User, keys: [String]) -> String? {
        for key in keys {
            let value = user.userMetadata[key]?.stringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let value, !value.isEmpty { return value }
        }
        return nil
    }

    private func clearAccountIdentity() {
        accountEmail = nil
        accountDisplayName = nil
        accountProvider = nil
    }

    // MARK: - Sign in with Google

    /// Redirect-схема `skykid://login-callback` должна быть зарегистрирована
    /// в Info.plist (`CFBundleURLTypes`) и добавлена в Supabase Dashboard →
    /// Authentication → URL Configuration → Redirect URLs.
    static let googleRedirectURL = URL(string: "skykid://login-callback")!

    func signInWithGoogle() async throws {
        let session = try await SupabaseClientProvider.client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: Self.googleRedirectURL,
            // Без `prompt=select_account` Google молча берёт единственный
            // залогиненный в браузере аккаунт, и войти под другим нельзя,
            // не разлогинившись в самом Google. С этим параметром выбор
            // аккаунта показывается всегда.
            queryParams: [(name: "prompt", value: "select_account")]
        )
        apply(user: session.user)
    }

    func signOut() async {
        try? await SupabaseClientProvider.client.auth.signOut()
        isSignedIn = false
        userID = nil
        clearAccountIdentity()
        // Стартовый выбор сбрасывается вместе с сессией: локальный кеш ниже
        // очищается, профиля больше нет, и пользователь снова выбирает —
        // войти в другой аккаунт или остаться автономным.
        isOfflineMode = false
        AuthPreferences.isOfflineModeChosen = false
        setFamilyID(nil)
        unlinkLocalData()
        migrationOfferDismissedForAccountID = nil
        AuthPreferences.migrationOfferDismissedForAccountID = nil
        clearLocallyCachedAccountData()
    }

    /// `ChildProfile`/`WalkLog` are account-scoped once synced, but they're
    /// cached locally in App Group storage independent of `isSignedIn`. If
    /// they survive sign-out, the next `ContentView.syncOnLaunch()` call
    /// (`childProfile == nil ? pull : push`) treats them as locally
    /// authoritative and pushes user A's data onto whichever account signs
    /// in next on this device, silently overwriting it server-side. Clearing
    /// here only touches the local cache — it must NOT delete anything on
    /// the server, since the signed-out account's own data should still be
    /// there the next time *that* account signs in (here or elsewhere).
    private func clearLocallyCachedAccountData() {
        ChildProfileStore.shared.profile = nil
        WalkLogStore.shared.clearAll()
        // Чужая идущая прогулка не должна пережить смену пользователя —
        // вместе с ней рвётся и Realtime-подписка на прежнюю семью.
        LiveWalkObserver.shared.reset()
    }
}
