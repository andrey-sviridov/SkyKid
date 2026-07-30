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
