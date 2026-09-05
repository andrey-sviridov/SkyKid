import SwiftUI

/// Карточка «Во что одет»: список одежды, снятие вещей, суммарный TOG и вердикт.
struct WalkOutfitChipsCard: View {
    @Binding var selectedIDs: [String]
    let profile: ChildProfile?
    let targetTOG: Double?
    /// `false` — просмотр чужой прогулки: ни «＋», ни крестиков на чипах.
    var isEditable: Bool = true
    var onAdd: (String) -> Void = { _ in }
    var onRemove: (String) -> Void = { _ in }

    @State private var showPicker = false

    private var items: [GarmentItem] {
        selectedIDs.compactMap { GarmentCatalog.byID[$0] }
    }

    private var effectiveTOG: Double {
        items.map(\.tog).reduce(0, +)
    }

    private var verdict: WalkTOGVerdict {
        WalkTOGVerdict(effective: effectiveTOG, target: targetTOG)
    }

    var body: some View {
        SectionCard(
            title: L10n.text("Во что одет"),
            systemImage: "hanger",
            spacing: 12
        ) {
            ForEach(items) { item in
                garmentRow(item)
                if item.id != items.last?.id {
                    Divider().padding(.leading, 40)
                }
            }

            if items.isEmpty {
                Text(L10n.text("Одежда не выбрана"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            if isEditable {
                addRow
            }

            if !items.isEmpty {
                verdictBar
            }
        } trailing: {
            Text(L10n.format("%.1f TOG", effectiveTOG))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .sheet(isPresented: $showPicker) {
            GarmentPickerSheet(profile: profile, selectedIDs: $selectedIDs, onAdd: onAdd)
        }
    }

    private func remove(_ item: GarmentItem) {
        withAnimation(.spring(response: 0.2)) {
            selectedIDs.removeAll { $0 == item.id }
        }
        onRemove(item.id)
    }

    private func garmentRow(_ item: GarmentItem) -> some View {
        HStack(spacing: 10) {
            GarmentIconView(
                item: item,
                isSelected: true,
                accentColor: .blue,
                size: 30,
                shape: .roundedRectangle(8)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(L10n.format("%.2f TOG", item.tog))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isEditable {
                Button {
                    remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.format("Снять %@", item.name))
            }
        }
        .contentShape(Rectangle())
    }

    private var addRow: some View {
        Button { showPicker = true } label: {
            Label(L10n.text("Добавить одежду"), systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var verdictBar: some View {
        let level = verdict.level
        HStack(spacing: 10) {
            Image(systemName: level.icon)
                .font(.system(size: 18))
                .foregroundStyle(level.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(level.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(level.color)
                if let target = targetTOG {
                    Text(L10n.format("Цель ~%.1f TOG", target))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Нет данных о рекомендации")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(level.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}
