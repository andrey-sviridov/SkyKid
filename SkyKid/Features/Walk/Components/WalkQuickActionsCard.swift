import SwiftUI

// MARK: - WalkQuickActionsCard

/// Быстрые переключатели состояния и нейтральная отметка для последующего
/// переназначения в таймлайне.
///
struct WalkQuickActionsCard: View {
    /// Нужен для тактильного отклика: считаем не нажатия, а реально
    /// появившиеся события — иначе отклик срабатывал бы и когда запись
    /// не прошла.
    let eventCount: Int
    let isSleeping: Bool
    var showsBassinette: Bool = true
    let onTap: (WalkEventKind) -> Void

    var body: some View {
        SectionCard(title: L10n.text("Быстрые отметки"), systemImage: "bolt.fill") {
            FlowLayout(spacing: 10) {
                stateButton(isSleeping ? .wake : .sleep)
                if showsBassinette {
                    stateButton(.openedBassinette)
                    stateButton(.closedBassinette)
                }
                stateButton(.checkpoint)
            }
        }
        .accessibilityIdentifier("walk.quickActions")
    }

    private func stateButton(_ kind: WalkEventKind) -> some View {
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
