import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GarmentIconView: View {
    enum ContainerShape {
        case circle
        case roundedRectangle(CGFloat)
    }

    let item: GarmentItem
    var isSelected: Bool = false
    var accentColor: Color = .blue
    var size: CGFloat = 40
    var shape: ContainerShape = .circle

    var body: some View {
        ZStack {
            background
            icon
        }
        .frame(width: size, height: size)
        .accessibilityLabel(item.name)
    }

    @ViewBuilder
    private var background: some View {
        let fillColor = isSelected ? accentColor.opacity(0.13) : Color.primary.opacity(0.07)
        switch shape {
        case .circle:
            Circle().fill(fillColor)
        case .roundedRectangle(let radius):
            RoundedRectangle(cornerRadius: radius).fill(fillColor)
        }
    }

    @ViewBuilder
    private var icon: some View {
        #if canImport(UIKit)
        if let image = UIImage(named: item.imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(size * 0.14)
        } else {
            symbolIcon
        }
        #else
        symbolIcon
        #endif
    }

    private var symbolIcon: some View {
        Image(systemName: item.symbol)
            .font(.system(size: max(12, size * 0.42), weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isSelected ? accentColor : .secondary)
    }
}

// MARK: - RecommendedGarmentRow

struct RecommendedGarmentRow: View {
    let garment: OutfitGarmentPresentation
    var accentColor: Color = .indigo

    var body: some View {
        HStack(spacing: 12) {
            garmentImage
                .accessibilityHidden(true)

            Text(garment.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 13))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var garmentImage: some View {
        if let item = GarmentCatalog.byID[garment.id] {
            GarmentIconView(
                item: item,
                isSelected: true,
                accentColor: accentColor,
                size: 48,
                shape: .roundedRectangle(12)
            )
        } else {
            Image(systemName: garment.systemImage)
                .font(.system(size: 19, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accentColor)
                .frame(width: 48, height: 48)
                .background(accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
