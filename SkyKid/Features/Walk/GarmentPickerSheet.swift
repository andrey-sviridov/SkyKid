import SwiftUI

/// Всплывающий выбор вещи с поиском и фильтром по гардеробу.
struct GarmentPickerSheet: View {
    let profile: ChildProfile?
    @Binding var selectedIDs: [String]
    var onAdd: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(UserWardrobeStore.self) private var wardrobeStore
    @State private var search = ""
    @State private var ownedOnly = true

    private var filtered: [GarmentItem] {
        let ageGroup = profile?.wardrobeAgeGroup
        return GarmentCatalog.catalogItems.filter { item in
            let matchesAge = ageGroup == nil || item.catalogAgeGroup?.matches(ageGroup!) != false
            let matchesOwned = !ownedOnly || wardrobeStore.isOwned(item.id)
            let matchesSearch = search.isEmpty
                || item.name.localizedCaseInsensitiveContains(search)
            return matchesAge && matchesOwned && matchesSearch
        }
        .sorted { lhs, rhs in
            let l = selectedIDs.contains(lhs.id)
            let r = selectedIDs.contains(rhs.id)
            if l != r { return l && !r }
            return lhs.tog < rhs.tog
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Toggle(isOn: $ownedOnly) {
                    Label("Только мой гардероб", systemImage: "checkmark.seal")
                        .font(.subheadline)
                }
                .listRowBackground(Color.clear)

                ForEach(filtered) { item in
                    let on = selectedIDs.contains(item.id)
                    Button {
                        withAnimation(.spring(response: 0.2)) { toggle(item.id) }
                    } label: {
                        HStack(spacing: 12) {
                            GarmentIconView(
                                item: item,
                                isSelected: on,
                                accentColor: .blue,
                                size: 34,
                                shape: .roundedRectangle(8)
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.subheadline)
                                Text(L10n.format("%.2f TOG", item.tog))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(on ? Color.blue : Color.secondary.opacity(0.4))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .skyKidBackground()
            .searchable(text: $search, prompt: L10n.text("Поиск одежды"))
            .navigationTitle("Выбор одежды")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if let idx = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: idx)
        } else {
            selectedIDs.append(id)
            onAdd(id)
        }
    }
}
