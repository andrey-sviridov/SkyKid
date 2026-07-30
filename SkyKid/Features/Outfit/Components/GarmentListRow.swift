import SwiftUI

struct GarmentListRow: View {
    let item: GarmentItem
    let isSelected: Bool
    var isPinned: Bool = false
    let isLast: Bool
    let onTap: () -> Void

    @State private var isInfoPresented = false
    @State private var isPhotoPresented = false

    private var effectiveColor: Color { isPinned ? .purple : .blue }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GarmentIconView(
                    item: item,
                    isSelected: isSelected,
                    accentColor: effectiveColor,
                    size: 40
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
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? effectiveColor : .primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .center, spacing: 3) {
                    Button {
                        if !isPinned { onTap() }
                    } label: {
                        statusIcon
                    }
                    .buttonStyle(.plain)
                    .disabled(isPinned)

                    Text(String(format: "%.2g", item.tog))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .frame(width: 48)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(isSelected ? effectiveColor.opacity(0.04) : Color.clear)
            .sheet(isPresented: $isInfoPresented) {
                GarmentIconPreviewSheet(item: item)
            }
            .sheet(isPresented: $isPhotoPresented) {
                GarmentPhotoPreviewSheet(item: item)
            }

            if !isLast {
                Divider().padding(.leading, 66)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isPinned {
            Image(systemName: "pin.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.purple)
                .frame(width: 28, height: 28)
        } else if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
        } else {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .frame(width: 28, height: 28)
        }
    }
}
