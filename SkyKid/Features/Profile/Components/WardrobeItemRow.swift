import SwiftUI

struct WardrobeItemRow: View {
    let item: GarmentItem
    let isOwned: Bool
    let isLast: Bool
    let action: () -> Void

    @State private var isInfoPresented = false
    @State private var isPhotoPresented = false

    var body: some View {
        HStack(spacing: 12) {
            GarmentIconView(
                item: item,
                isSelected: isOwned,
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
                        .foregroundStyle(isOwned ? .primary : .secondary)
                    Text(String(format: "%.2g TOG", item.tog))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: action) {
                Image(systemName: isOwned ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOwned ? .green : Color.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
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
}
