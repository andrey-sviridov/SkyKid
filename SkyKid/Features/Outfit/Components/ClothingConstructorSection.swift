import SwiftUI

struct ClothingConstructorSection: View {
    let ageGroup: WardrobeAgeGroup
    let selectedItems: Set<GarmentItem>
    var pinnedIDs: Set<String> = []
    let onToggle: (GarmentItem) -> Void

    @State private var displayedSelectedItems: Set<GarmentItem> = []
    @State private var displayedItemsUpdateTask: Task<Void, Never>?

    var body: some View {
        let itemsByLayer = GarmentCatalog.displayItems(for: ageGroup)
        let allSelected = displayedSelectedItems.sorted { $0.name < $1.name }

        VStack(spacing: 12) {
            if !allSelected.isEmpty {
                autoSelectedSection(items: allSelected)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            ForEach(GarmentLayer.allCases) { layer in
                let items = itemsByLayer[layer] ?? []
                if !items.isEmpty {
                    layerSection(layer: layer, items: items)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: allSelected.map(\.id))
        .onAppear {
            displayedSelectedItems = selectedItems
        }
        .onChange(of: selectedItems) { _, newItems in
            updateDisplayedSelectedItems(newItems)
        }
        .onDisappear {
            displayedItemsUpdateTask?.cancel()
        }
    }

    private func updateDisplayedSelectedItems(_ newItems: Set<GarmentItem>) {
        displayedItemsUpdateTask?.cancel()

        let hasNewItemsForSummary = !newItems.isSubset(of: displayedSelectedItems)
        guard hasNewItemsForSummary else {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                displayedSelectedItems = newItems
            }
            return
        }

        displayedItemsUpdateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                displayedSelectedItems = newItems
            }
        }
    }

    private func autoSelectedSection(items: [GarmentItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars").font(.caption)
                Text("Подобрано автоматически").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(items.count) вещей")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1), in: Capsule())
            }
            .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    GarmentListRow(
                        item: item,
                        isSelected: true,
                        isPinned: pinnedIDs.contains(item.id),
                        isLast: idx == items.count - 1,
                        onTap: { onToggle(item) }
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.blue.opacity(0.22), lineWidth: 1))
    }

    private func layerSection(layer: GarmentLayer, items: [GarmentItem]) -> some View {
        let selCount = items.filter { selectedItems.contains($0) }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: layer.icon).font(.caption)
                Text(layer.displayName).font(.subheadline.weight(.semibold))
                Spacer()
                if selCount > 0 {
                    Text("\(selCount) выбрано")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                }
            }
            .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    GarmentListRow(
                        item: item,
                        isSelected: selectedItems.contains(item),
                        isPinned: pinnedIDs.contains(item.id),
                        isLast: idx == items.count - 1,
                        onTap: { onToggle(item) }
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}
