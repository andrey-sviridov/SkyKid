import SwiftUI

struct WalkScheduleView: View {
    @Environment(NotificationService.self) private var notificationService
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [WalkScheduleEntry] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Приложение напомнит обновить погоду и проверить самочувствие ребёнка. Сохранённый комплект не будет выдаваться за актуальный.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section("Напоминания") {
                    ForEach($entries) { $entry in
                        HStack {
                            Toggle(isOn: $entry.isEnabled) {
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            Calendar.current.date(
                                                from: DateComponents(hour: entry.hour, minute: entry.minute)
                                            ) ?? .now
                                        },
                                        set: { date in
                                            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                                            entry.hour = c.hour ?? entry.hour
                                            entry.minute = c.minute ?? entry.minute
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .disabled(!entry.isEnabled)
                                .opacity(entry.isEnabled ? 1 : 0.4)
                            }
                            .tint(.teal)
                        }
                    }
                    .onDelete { offsets in entries.remove(atOffsets: offsets) }

                    if entries.count < 4 {
                        Button {
                            withAnimation { entries.append(WalkScheduleEntry(hour: 10, minute: 0)) }
                        } label: {
                            Label("Добавить время", systemImage: "plus.circle.fill")
                                .foregroundStyle(.teal)
                        }
                    }
                }
            }
            .navigationTitle("Расписание прогулок")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { entries = notificationService.loadWalkSchedule() }
        }
    }

    private func save() {
        notificationService.saveWalkSchedule(entries)
        Task { await notificationService.syncWalkSchedule(entries) }
        dismiss()
    }
}
