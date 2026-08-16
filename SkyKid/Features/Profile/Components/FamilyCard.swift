import SwiftUI

/// Совместный доступ второго родителя: приглашение и статус семьи.
///
/// Живёт под карточкой аккаунта — совместный доступ возможен только у
/// вошедшего пользователя, и без входа карточка не показывается вовсе.
struct FamilyCard: View {
    @Environment(SupabaseAuthService.self) private var authService
    @Environment(WalkLogStore.self) private var walkLogStore

    @State private var members: [FamilyMember] = []
    @State private var inviteCode: String?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showJoinSheet = false

    private var isShared: Bool { members.count > 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Второй родитель", systemImage: "person.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if !members.isEmpty {
                membersList
            }

            if isShared {
                sharedStatus
            } else {
                invitation
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        .task { await refreshMembers() }
        .sheet(isPresented: $showJoinSheet) {
            JoinFamilySheet { await join(code: $0) }
        }
    }

    // MARK: - Кто в семье

    /// Состав семьи показывается и до приглашения — тогда в нём одна строка,
    /// и пользователь видит, каким аккаунтом он делится.
    private var membersList: some View {
        VStack(spacing: 10) {
            ForEach(members) { member in
                FamilyMemberRow(
                    member: member,
                    isCurrentUser: member.userID == authService.userID
                )
            }
        }
    }

    // MARK: - Уже вместе

    private var sharedStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Данные о ребёнке и прогулках общие для двух родителей")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Приглашение

    private var invitation: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Пригласите второго родителя — профиль ребёнка и журнал прогулок будут общими: что добавит один, увидит другой.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let inviteCode {
                shareableCode(inviteCode)
            } else {
                HStack(spacing: 10) {
                    Button {
                        Task { await createInvite() }
                    } label: {
                        HStack(spacing: 6) {
                            if isWorking {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "person.badge.plus")
                            }
                            Text("Пригласить")
                        }
                        .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isWorking)

                    Button("У меня есть код") { showJoinSheet = true }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .disabled(isWorking)
                }
            }
        }
    }

    private func shareableCode(_ code: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Код действует 7 дней и сработает один раз. Отправьте его второму родителю — он введёт код у себя.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Код длинный, потому что внутри него едет ключ шифрования имени
            // ребёнка — сервер этот ключ не получает. Поэтому код передают
            // шерингом, а не диктуют голосом.
            Text(code)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 10) {
                ShareLink(item: code) {
                    Label("Отправить код", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Скрыть") { inviteCode = nil }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Действия

    private func refreshMembers() async {
        guard authService.isSignedIn else { return }
        members = await SupabaseSyncService.shared.familyMembers()
    }

    private func createInvite() async {
        isWorking = true
        defer { isWorking = false }
        do {
            inviteCode = try await SupabaseSyncService.shared.createFamilyInvite()
            errorMessage = nil
        } catch {
            errorMessage = L10n.text("Не удалось создать приглашение. Попробуйте ещё раз.")
        }
    }

    private func join(code: String) async -> Bool {
        do {
            // Данные семьи подтягиваются сразу, не дожидаясь перезапуска.
            try await SupabaseSyncService.shared.joinFamilyAndPullData(code: code)
            await refreshMembers()
            errorMessage = nil
            return true
        } catch {
            errorMessage = L10n.text("Код не подошёл. Проверьте, что он скопирован целиком и ещё не использован.")
            return false
        }
    }
}
