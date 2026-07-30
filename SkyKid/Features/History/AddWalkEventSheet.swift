import SwiftUI

/// Добавление пропущенной отметки задним числом: тип события + время.
struct AddWalkEventSheet: View {
    let walkStart: Date
    var onAdd: (WalkEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: WalkEventKind = .checkpoint
    @State private var timestamp: Date

    init(walkStart: Date, onAdd: @escaping (WalkEvent) -> Void) {
        self.walkStart = walkStart
        self.onAdd = onAdd
        _timestamp = State(initialValue: walkStart)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Тип отметки")) {
                    Picker("", selection: $kind) {
                        ForEach(WalkEventKind.allCases) { k in
                            Label(k.title, systemImage: k.icon).tag(k)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section(L10n.text("Время")) {
                    DatePicker("", selection: $timestamp, in: walkStart...Date.now,
                               displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                }
            }
            .navigationTitle("Новая отметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        onAdd(WalkEvent(timestamp: timestamp, kind: kind))
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
        }
    }
}
