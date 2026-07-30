import SwiftUI

/// Карточка «Во что одет»: чипы одежды + «＋», суммарный TOG и вердикт.
struct WalkOutfitChipsCard: View {
    @Binding var selectedIDs: [String]
    let profile: ChildProfile?
    let targetTOG: Double?
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Во что одет", systemImage: "hanger")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L10n.format("%.1f TOG", effectiveTOG))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            FlowLayout(spacing: 8) {
                ForEach(items) { item in
                    GarmentChip(item: item) {
                        withAnimation(.spring(response: 0.2)) {
                            selectedIDs.removeAll { $0 == item.id }
                        }
                        onRemove(item.id)
                    }
                }
                addChip
            }

            verdictBar
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        .sheet(isPresented: $showPicker) {
            GarmentPickerSheet(profile: profile, selectedIDs: $selectedIDs, onAdd: onAdd)
        }
    }

    private var addChip: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                Text("Добавить")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.blue.opacity(0.10), in: Capsule())
            .overlay(
                Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.blue.opacity(0.5))
            )
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
