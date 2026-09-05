import SwiftUI

// MARK: - WalkTimelineCard

/// Таймлайн отметок прогулки, свежие сверху.
///
/// `isEditable == false` — режим просмотра чужой прогулки: контекстное меню и
/// кнопка «Назначить» не показываются, потому что менять чужую запись нельзя.
struct WalkTimelineCard: View {
    let events: [WalkEvent]
    let startDate: Date
    var isEditable: Bool = true
    var onReclassify: (WalkEvent) -> Void = { _ in }
    var onDelete: (WalkEvent) -> Void = { _ in }
    var onUndoLast: (() -> Void)? = nil

    private var sortedEvents: [WalkEvent] {
        events.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        SectionCard(
            title: L10n.text("Отметки"),
            systemImage: "list.bullet.rectangle"
        ) {
            if sortedEvents.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "tray")
                        .foregroundStyle(.tertiary)
                    Text(L10n.text("Пока нет отметок"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                ForEach(sortedEvents) { event in
                    row(event)
                }
            }
        } trailing: {
            if isEditable && !sortedEvents.isEmpty, let onUndoLast {
                Button(action: onUndoLast) {
                    Text(L10n.text("Отменить"))
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.blue)
                .accessibilityLabel(L10n.text("Отменить последнюю отметку"))
            }
        }
        .accessibilityIdentifier("walk.timeline")
    }

    @ViewBuilder
    private func row(_ event: WalkEvent) -> some View {
        let eventRow = WalkEventRow(
            event: event,
            startDate: startDate,
            showsReclassifyButton: isEditable,
            onReclassify: { onReclassify(event) }
        )

        if isEditable {
            eventRow.contextMenu {
                Button {
                    onReclassify(event)
                } label: {
                    Label("Назначить действие", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete(event)
                } label: {
                    Label("Удалить отметку", systemImage: "trash")
                }
            }
        } else {
            eventRow
        }
    }
}
