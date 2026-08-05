import SwiftUI

/// Ввод кода приглашения от второго родителя.
struct JoinFamilySheet: View {
    /// Возвращает `true`, если код подошёл — тогда лист закрывается сам.
    let onSubmit: (String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Вставьте код, который прислал второй родитель. После этого вы будете видеть одного и того же ребёнка и общий журнал прогулок.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("skykid1:…", text: $code, axis: .vertical)
                        .font(.system(.footnote, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .lineLimit(3...6)
                        .padding(12)
                        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                    // Честное предупреждение: присоединение переключает
                    // устройство на данные чужой семьи.
                    Label(
                        "Если у вас уже заведён свой ребёнок, приложение переключится на общие данные. Ваши прежние записи останутся в аккаунте, но перестанут показываться.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Button {
                        Task {
                            isWorking = true
                            defer { isWorking = false }
                            if await onSubmit(code) { dismiss() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isWorking { ProgressView().controlSize(.small) }
                            Text("Присоединиться")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(20)
            }
            .skyKidBackground()
            .navigationTitle("Код приглашения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }
}
