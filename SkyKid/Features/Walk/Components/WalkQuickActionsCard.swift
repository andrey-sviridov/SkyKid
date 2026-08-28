import SwiftUI

// MARK: - WalkQuickActionsCard

/// Ряд быстрых отметок: одно нажатие — одно событие на таймлайне.
///
/// Набор здесь фиксированный и совпадает по смыслу с кнопками Live Activity,
/// но не по форме: на локскрине сон и люлька — тумблеры, а тут пять
/// самостоятельных кнопок.
struct WalkQuickActionsCard: View {
    /// Нужен для тактильного отклика: считаем не нажатия, а реально
    /// появившиеся события — иначе отклик срабатывал бы и когда запись
    /// не прошла.
    let eventCount: Int
    let onTap: (WalkEventKind) -> Void

    private let kinds: [WalkEventKind] = [
        .openedBassinette, .closedBassinette, .sleep, .wake, .checkpoint
    ]

    var body: some View {
        SectionCard(title: L10n.text("Быстрые отметки"), systemImage: "bolt.fill") {
            FlowLayout(spacing: 10) {
                ForEach(kinds) { kind in
                    button(kind)
                }
            }
        }
    }

    private func button(_ kind: WalkEventKind) -> some View {
        let color = kind.color

        return Button {
            withAnimation(.spring(response: 0.25)) { onTap(kind) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: kind.icon)
                Text(kind.title)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: eventCount)
    }
}
