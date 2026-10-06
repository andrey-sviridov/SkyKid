import SwiftUI

struct WardrobeItemRow: View {
    let item: GarmentItem
    let ownership: WardrobeOwnership
    let isLast: Bool
    let action: (WardrobeOwnership) -> Void

    @State private var isInfoPresented = false
    @State private var isPhotoPresented = false

    var body: some View {
        HStack(spacing: 12) {
            GarmentIconView(
                item: item,
                isSelected: ownership == .owned,
                accentColor: .green,
                size: 34,
                shape: .roundedRectangle(8)
            )
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.30)
                    .onEnded { _ in
                        GarmentHaptics.previewTriggered()
                        isPhotoPresented = true
                    }
            )
            .onTapGesture {
                isInfoPresented = true
            }

            Button {
                isInfoPresented = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(ownership == .unavailable ? .secondary : .primary)
                    Text(statusLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                ownershipButton(.unknown, label: L10n.text("Не указано"), icon: "questionmark.circle")
                ownershipButton(.owned, label: L10n.text("Есть"), icon: "checkmark.circle")
                ownershipButton(.unavailable, label: L10n.text("Нет"), icon: "xmark.circle")
            } label: {
                Image(systemName: statusIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(statusColor)
                    .frame(width: 44, height: 44)
            }
        }
        .frame(height: 54)
        .sheet(isPresented: $isInfoPresented) {
            GarmentIconPreviewSheet(item: item)
        }
        .sheet(isPresented: $isPhotoPresented) {
            GarmentPhotoPreviewSheet(item: item)
        }

        if !isLast {
            Divider().padding(.leading, 46)
        }
    }

    private var statusLabel: String {
        switch ownership {
        case .unknown: return L10n.text("Не указано")
        case .owned: return L10n.text("Есть")
        case .unavailable: return L10n.text("Нет")
        }
    }

    private var statusIcon: String {
        switch ownership {
        case .unknown: return "questionmark.circle"
        case .owned: return "checkmark.circle.fill"
        case .unavailable: return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch ownership {
        case .unknown: return .secondary
        case .owned: return .green
        case .unavailable: return .orange
        }
    }

    private func ownershipButton(
        _ value: WardrobeOwnership,
        label: String,
        icon: String
    ) -> some View {
        Button { action(value) } label: {
            Label(label, systemImage: icon)
        }
    }
}
