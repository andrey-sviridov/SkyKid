import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct GarmentPhotoPreviewSheet: View {
    let item: GarmentItem

    var body: some View {
        photo
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 36)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.clear)
    }

    @ViewBuilder
    private var photo: some View {
        #if canImport(UIKit)
        if let image = UIImage(named: item.imageAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            fallbackSymbol
        }
        #else
        fallbackSymbol
        #endif
    }

    private var fallbackSymbol: some View {
        Image(systemName: item.symbol)
            .font(.system(size: 140, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white.opacity(0.92))
    }
}
