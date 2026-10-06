import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreView: View {
    @State private var exportURL: URL?
    @State private var isImporting = false
    @State private var pendingBackup: SkyKidBackup?
    @State private var errorMessage: String?
    @State private var didRestore = false

    private let service: LocalBackupService
    private let onRestored: () -> Void

    init(
        service: LocalBackupService = .shared,
        onRestored: @escaping () -> Void = {}
    ) {
        self.service = service
        self.onRestored = onRestored
    }

    var body: some View {
        Form {
            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label(L10n.text("Поделиться резервной копией"), systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button(L10n.text("Создать резервную копию"), action: prepareExport)
                }
            } footer: {
                Text(L10n.text("Копия хранится только там, куда вы её сохраните. API-ключи и координаты не экспортируются."))
            }

            Section {
                Button {
                    isImporting = true
                } label: {
                    Label(L10n.text("Восстановить из файла"), systemImage: "square.and.arrow.down")
                }
            } footer: {
                Text(L10n.text("Восстановление заменит текущий профиль, прогулки, обучение и гардероб."))
            }

            if didRestore {
                Label(L10n.text("Данные восстановлены"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .navigationTitle(L10n.text("Резервная копия"))
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .confirmationDialog(
            L10n.text("Заменить текущие данные?"),
            isPresented: Binding(
                get: { pendingBackup != nil },
                set: { if !$0 { pendingBackup = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.text("Заменить и восстановить"), role: .destructive, action: restorePending)
            Button(L10n.text("Отмена"), role: .cancel) { pendingBackup = nil }
        }
        .alert(L10n.text("Не удалось выполнить операцию"), isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    private func prepareExport() {
        do { exportURL = try service.exportFileURL() }
        catch { errorMessage = error.localizedDescription }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            pendingBackup = try service.prepareRestore(from: Data(contentsOf: url))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restorePending() {
        guard let backup = pendingBackup else { return }
        do {
            try service.restore(backup, confirmed: true)
            pendingBackup = nil
            didRestore = true
            exportURL = nil
            onRestored()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
