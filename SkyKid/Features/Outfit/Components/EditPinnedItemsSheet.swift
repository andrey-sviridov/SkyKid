import SwiftUI

struct EditPinnedItemsSheet: View {
    @Bindable var model: WardrobeModel
    @Environment(\.dismiss) private var dismiss

    private var itemsByLayer: [(GarmentLayer, [GarmentItem])] {
        let relevant = GarmentCatalog.all.filter {
            $0.catalogAgeGroup == nil || $0.catalogAgeGroup?.matches(model.ageGroup) == true
        }.sorted { $0.name < $1.name }
        return GarmentLayer.allCases.compactMap { layer in
            let items = relevant.filter { $0.layer == layer }
            return items.isEmpty ? nil : (layer, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Выбранные вещи всегда включаются в расчёт и не снимаются при сбросе.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                ForEach(itemsByLayer, id: \.0) { layer, items in
                    Section(layer.displayName) {
                        ForEach(items) { item in
                            let pinned = model.isPinned(item)
                            Button {
                                withAnimation {
                                    if pinned { model.unpin(item) } else { model.pin(item) }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.symbol)
                                        .frame(width: 26)
                                        .foregroundStyle(pinned ? .purple : .secondary)
                                    Text(item.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if pinned {
                                        Image(systemName: "pin.fill")
                                            .foregroundStyle(.purple)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Вещи по умолчанию")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
