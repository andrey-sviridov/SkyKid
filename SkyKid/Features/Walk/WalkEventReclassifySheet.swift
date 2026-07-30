import SwiftUI

// MARK: - WalkEventReclassifySheet
// Назначает контрольной точке (или любому другому событию) конкретное
// действие постфактум — время события не меняется, меняется только его
// смысл. Используется и во время активной прогулки, и в Истории.

struct WalkEventReclassifySheet: View {
    let event: WalkEvent
    let profile: ChildProfile?
    var onSave: (_ kind: WalkEventKind, _ garmentID: String?, _ note: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: WalkEventKind
    @State private var garmentID: String?
    @State private var note: String
    @State private var showGarmentPicker = false

    init(
        event: WalkEvent,
        profile: ChildProfile?,
        onSave: @escaping (_ kind: WalkEventKind, _ garmentID: String?, _ note: String?) -> Void
    ) {
        self.event = event
        self.profile = profile
        self.onSave = onSave
        _kind = State(initialValue: event.kind)
        _garmentID = State(initialValue: event.garmentID)
        _note = State(initialValue: event.note ?? "")
    }

    private var needsGarment: Bool { kind == .addedGarment || kind == .removedGarment }
    private var garmentItem: GarmentItem? { garmentID.flatMap { GarmentCatalog.byID[$0] } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L10n.format(
                        "Отметка в %@ — что там произошло на самом деле?",
                        event.timestamp.formatted(.dateTime.hour().minute())
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section(L10n.text("Что произошло?")) {
                    Picker("", selection: $kind) {
                        ForEach(WalkEventKind.allCases) { k in
                            Label(k.title, systemImage: k.icon).tag(k)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if needsGarment {
                    Section(L10n.text("Какая вещь?")) {
                        Button {
                            showGarmentPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                if let garmentItem {
                                    GarmentIconView(
                                        item: garmentItem,
                                        isSelected: true,
                                        accentColor: .blue,
                                        size: 30,
                                        shape: .roundedRectangle(7)
                                    )
                                    Text(garmentItem.name)
                                        .foregroundStyle(.primary)
                                } else {
                                    Text("Выбрать вещь")
                                        .foregroundStyle(.blue)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Section(L10n.text("Заметка (необязательно)")) {
                    TextField(L10n.text("Например: накинули одеяло"), text: $note)
                }
            }
            .navigationTitle("Контрольная точка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(kind, needsGarment ? garmentID : nil, note.isEmpty ? nil : note)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(needsGarment && garmentID == nil)
                }
            }
            .sheet(isPresented: $showGarmentPicker) {
                GarmentPickerSheet(
                    profile: profile,
                    selectedIDs: Binding(
                        get: { garmentID.map { [$0] } ?? [] },
                        set: { garmentID = $0.last }
                    )
                )
            }
        }
    }
}
