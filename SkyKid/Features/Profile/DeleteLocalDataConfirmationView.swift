import SwiftUI

struct DeleteLocalDataConfirmationView: View {
    let onDeleted: () -> Void
    @State private var showConfirmation = false
    @State private var errorMessage: String?

    private let service: LocalDataResetService

    init(
        service: LocalDataResetService = .shared,
        onDeleted: @escaping () -> Void
    ) {
        self.service = service
        self.onDeleted = onDeleted
    }

    var body: some View {
        VStack(spacing: 20) {
            ContentUnavailableView(
                L10n.text("Удалить локальные данные"),
                systemImage: "trash",
                description: Text(L10n.text("Будут удалены профиль, прогулки, обучение, гардероб, активная прогулка и локальные кэши. Внешние резервные копии останутся без изменений."))
            )
            Button(L10n.text("Удалить все данные"), role: .destructive) {
                showConfirmation = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .navigationTitle(L10n.text("Удаление данных"))
        .confirmationDialog(
            L10n.text("Удалить все данные без возможности отмены?"),
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("Удалить все данные"), role: .destructive, action: reset)
            Button(L10n.text("Отмена"), role: .cancel) {}
        }
        .alert(L10n.text("Не удалось удалить данные"), isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func reset() {
        do {
            try service.reset(confirmed: true)
            onDeleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
