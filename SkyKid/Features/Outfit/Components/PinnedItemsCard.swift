import SwiftUI

struct PinnedItemsCard: View {
    @Bindable var model: WardrobeModel
    @State private var showEdit = false

    private var pinnedItems: [GarmentItem] {
        GarmentCatalog.all
            .filter { model.pinnedItemIDs.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("Надевается всегда")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Изменить") { showEdit = true }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.purple)
            }

            if pinnedItems.isEmpty {
                Text("Нет закреплённых вещей")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(pinnedItems) { item in
                        HStack(spacing: 5) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.purple)
                            Text(item.name)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.10), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.purple.opacity(0.22), lineWidth: 1))
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.purple.opacity(0.22), lineWidth: 1))
        .sheet(isPresented: $showEdit) {
            EditPinnedItemsSheet(model: model)
        }
    }
}
