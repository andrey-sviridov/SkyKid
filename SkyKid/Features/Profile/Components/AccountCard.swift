import SwiftUI
import AuthenticationServices

struct AccountCard: View {
    /// Профиль приходит параметром, а не из `ChildProfileStore`: там
    /// `profile` — вычисляемое свойство поверх App Group, поэтому
    /// `@Observable` его изменения не отслеживает, а `@Binding` в
    /// `ProfileSummaryView` — отслеживает.
    let profile: ChildProfile?

    @Environment(SupabaseAuthService.self) private var authService
    @Environment(WalkLogStore.self) private var walkLogStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?
    @State private var isSigningIn = false
    @State private var isMigrating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Аккаунт", systemImage: "icloud.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if authService.isSignedIn {
                signedInContent
                if canMigrateLocalData {
                    Divider()
                    if authService.isMigrationOfferDismissed {
                        compactMigrationLink
                    } else {
                        migrationOffer
                    }
                }
            } else {
                signedOutContent
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Войдите, чтобы не терять данные при переустановке или смене устройства.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: signIn) {
                HStack(spacing: 10) {
                    if isSigningIn {
                        ProgressView()
                    } else {
                        Image(systemName: "globe")
                    }
                    Text("Войти через Google")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(colorScheme == .dark ? .white : .black)
            .foregroundStyle(colorScheme == .dark ? .black : .white)
            .disabled(isSigningIn)
        }
    }

    /// Под каким именно аккаунтом вошли — то же, что второй родитель видит о
    /// вас в карточке семьи. Без этого «Вы вошли» не отвечает на вопрос
    /// «а под кем?», когда у пользователя несколько аккаунтов Google.
    private var signedInContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(authService.accountTitle ?? L10n.text("Вы вошли"))
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let accountDetails {
                    Text(accountDetails)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if authService.isLocalDataLinkedToCurrentAccount {
                    Text("Данные синхронизируются")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button("Выйти") {
                Task { await authService.signOut() }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.red)
            .disabled(isMigrating)
        }
    }

    /// Почта и способ входа. Почта опускается, когда она же стоит
    /// заголовком — провайдер не дал имени.
    private var accountDetails: String? {
        let email = authService.accountDisplayName == nil ? nil : authService.accountEmail
        let parts = [email, SignInProvider(identifier: authService.accountProvider)?.label]
        let details = parts.compactMap { $0 }.joined(separator: " · ")
        return details.isEmpty ? nil : details
    }

    // MARK: - Перенос автономных данных

    /// Ненавязчиво и по месту: предложение живёт прямо под строкой входа и
    /// показывается, только когда на устройстве реально есть данные, ещё не
    /// привязанные к этому аккаунту.
    ///
    /// «Не сейчас» не закрывает дорогу назад: развёрнутое предложение
    /// сворачивается в одну строку (`compactMigrationLink`), но остаётся
    /// доступным, пока перенос имеет смысл. Иначе передумавшему пользователю
    /// пришлось бы выходить из аккаунта и входить заново.
    private var canMigrateLocalData: Bool {
        authService.isSignedIn
            && !authService.isLocalDataLinkedToCurrentAccount
            && hasLocalData
    }

    private var hasLocalData: Bool {
        profile != nil || !walkLogStore.logs.isEmpty
    }

    private var compactMigrationLink: some View {
        Button {
            Task { await migrate() }
        } label: {
            HStack(spacing: 6) {
                if isMigrating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle")
                }
                Text("Перенести данные в аккаунт")
                Spacer()
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isMigrating)
    }

    private var migrationOffer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localDataSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    Task { await migrate() }
                } label: {
                    HStack(spacing: 6) {
                        if isMigrating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.circle")
                        }
                        Text("Перенести в аккаунт")
                    }
                    .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isMigrating)

                Button("Не сейчас") {
                    authService.dismissMigrationOffer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .disabled(isMigrating)
            }
        }
    }

    private var localDataSummary: String {
        let walkCount = walkLogStore.logs.count
        if profile != nil, walkCount > 0 {
            return L10n.format(
                "На устройстве есть профиль ребёнка и прогулок: %lld. Перенести их в аккаунт?",
                walkCount
            )
        }
        if profile != nil {
            return L10n.text("На устройстве есть профиль ребёнка, созданный без аккаунта. Перенести его в аккаунт?")
        }
        return L10n.format(
            "На устройстве есть прогулок: %lld — они созданы без аккаунта. Перенести их?",
            walkCount
        )
    }

    private func migrate() async {
        isMigrating = true
        defer { isMigrating = false }

        let succeeded = await SupabaseSyncService.shared.migrateLocalDataToCurrentAccount(
            profile: profile,
            walkLogs: walkLogStore.logs
        )
        errorMessage = succeeded
            ? nil
            : L10n.text("Не удалось перенести данные. Попробуйте ещё раз.")
    }

    // MARK: - Sign in

    private func signIn() {
        Task {
            isSigningIn = true
            defer { isSigningIn = false }
            do {
                try await authService.signInWithGoogle()
                errorMessage = nil
            } catch let authError as ASWebAuthenticationSessionError
                where authError.code == .canceledLogin {
                // Пользователь сам закрыл системный диалог входа —
                // штатная отмена, не ошибка.
                errorMessage = nil
            } catch {
                errorMessage = L10n.text("Не удалось войти. Попробуйте ещё раз.")
            }
        }
    }
}
