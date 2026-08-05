import SwiftUI
import AuthenticationServices

/// Стартовый выбор до создания профиля ребёнка: войти в аккаунт (данные
/// переживут переустановку и смену устройства) или остаться автономным.
///
/// Автономный выбор ничего не закрывает: войти можно позже из профиля, и
/// тогда `AccountCard` предложит перенести уже накопленные данные.
///
/// Вход через Apple ID здесь сознательно отсутствует — провайдер пока
/// отключён (нет capability Sign in with Apple), кнопка вернётся сюда же
/// рядом с Google, когда его включат.
struct AuthGateView: View {
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            header
            Spacer(minLength: 24)
            actions
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .skyKidBackground()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 64))
                .symbolRenderingMode(.multicolor)

            Text("Добро пожаловать в SkyKid")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("Осталось выбрать, где хранить данные о ребёнке и прогулках.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 14) {
            googleButton

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            divider

            offlineButton
        }
    }

    private var googleButton: some View {
        VStack(spacing: 6) {
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
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(colorScheme == .dark ? .white : .black)
            .foregroundStyle(colorScheme == .dark ? .black : .white)
            .disabled(isSigningIn)

            Text("Данные не потеряются при переустановке и смене устройства")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(.primary.opacity(0.12)).frame(height: 1)
            Text("или")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Rectangle().fill(.primary.opacity(0.12)).frame(height: 1)
        }
    }

    private var offlineButton: some View {
        VStack(spacing: 6) {
            Button {
                authService.continueOffline()
            } label: {
                Text("Продолжить без аккаунта")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.bordered)
            .disabled(isSigningIn)

            Text("Всё останется только на этом устройстве. Войти можно будет позже в профиле.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
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
                // Пользователь сам закрыл системный диалог — штатная отмена.
                errorMessage = nil
            } catch {
                errorMessage = L10n.text("Не удалось войти. Попробуйте ещё раз.")
            }
        }
    }
}

#if DEBUG
#Preview("🔐 Стартовый выбор входа") {
    AuthGateView()
        .environment(SupabaseAuthService.shared)
}
#endif
