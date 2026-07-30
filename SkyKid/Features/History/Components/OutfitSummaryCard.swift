import SwiftUI

struct OutfitSummaryCard: View {
    @Binding var selectedIDs: Set<String>
    let suggestedIDs: [String]
    let profile: ChildProfile?
    var startInManual: Bool = false

    @Environment(UserWardrobeStore.self) private var wardrobeStore
    @State private var mode: PickMode = .auto

    private enum PickMode: String, CaseIterable {
        case auto   = "Рекомендация"
        case manual = "Гардероб"
    }

    private var autoItems: [GarmentItem] {
        suggestedIDs.compactMap { GarmentCatalog.byID[$0] }
    }

    private var manualItems: [GarmentItem] {
        let ageGroup = profile?.wardrobeAgeGroup
        return GarmentCatalog.catalogItems.filter { item in
            wardrobeStore.isOwned(item.id) &&
            (ageGroup == nil || item.catalogAgeGroup?.matches(ageGroup!) == true)
        }
    }

    private var displayItems: [GarmentItem] {
        mode == .auto ? autoItems : manualItems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Во что был одет", systemImage: "hanger")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Необязательно")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Picker("", selection: $mode) {
                ForEach(PickMode.allCases, id: \.self) { m in
                    Text(L10n.text(m.rawValue)).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, newMode in
                if newMode == .auto {
                    selectedIDs = Set(suggestedIDs)
                }
            }

            if displayItems.isEmpty {
                Text(
                    mode == .auto
                        ? L10n.text("Нет данных о погоде или профиле ребёнка")
                        : L10n.text("В гардеробе нет вещей для этого возраста")
                )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(displayItems) { item in
                        let on = selectedIDs.contains(item.id)
                        Button {
                            withAnimation(.spring(response: 0.2)) {
                                if on { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
                            }
                        } label: {
                            Text(item.name)
                                .font(.caption.weight(on ? .semibold : .regular))
                                .foregroundStyle(on ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    on ? Color.blue : Color.primary.opacity(0.09),
                                    in: Capsule()
                                )
                                .overlay(Capsule().strokeBorder(on ? Color.clear : Color.primary.opacity(0.18), lineWidth: 1))
                                .scaleEffect(on ? 1.04 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: on)
                        .sensoryFeedback(.selection, trigger: on)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        .onAppear {
            if startInManual { mode = .manual }
        }
    }
}
