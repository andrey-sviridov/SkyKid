import SwiftUI

// P1-1: экран «Мой гардероб» — отметить, какие предметы каталога реально есть.
// OutfitSolver рекомендует только из отмеченного.

struct MyWardrobeView: View {
    @Environment(UserWardrobeStore.self) private var store

    // Подгузник считается всегда в наличии — не показываем
    private var togglableItems: [GarmentLayer: [GarmentItem]] {
        GarmentCatalog.byLayer.mapValues { items in
            items.filter { item in
                item.id != "diaper"
                    && (item.use == .outdoorClothing || item.use == .accessory)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hintCard
                ForEach(GarmentLayer.allCases) { layer in
                    if let items = togglableItems[layer], !items.isEmpty {
                        layerCard(layer: layer, items: items)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .skyKidBackground()
        .navigationTitle("Мой гардероб")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hintCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)
            Text("Снимите отметку с вещей, которых у вас нет, — SkyKid не будет их рекомендовать и подскажет, чего не хватает.")
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.blue.opacity(0.4), lineWidth: 1))
    }

    private func layerCard(layer: GarmentLayer, items: [GarmentItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(layer.displayName, systemImage: layer.icon)
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    WardrobeItemRow(
                        item: item,
                        isOwned: store.isOwned(item.id),
                        isLast: idx == items.count - 1
                    ) {
                        withAnimation(.spring(response: 0.28)) { store.toggle(item.id) }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("👕 Гардероб") {
    NavigationStack {
        MyWardrobeView()
            .environment(UserWardrobeStore.shared)
    }
}
#endif
