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

    private var sortedEvents: [WalkEvent] {
        events.sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        if !events.isEmpty {
            SectionCard(title: L10n.text("Таймлайн"), systemImage: "list.bullet.rectangle") {
                ForEach(sortedEvents) { event in
                    row(event)
                }
            }
        }
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
