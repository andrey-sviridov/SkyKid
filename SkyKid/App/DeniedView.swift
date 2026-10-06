import SwiftUI
import UIKit

struct DeniedView: View {
    let onManualCity: (ManualLocation) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("Геолокация недоступна")
                    .font(.headline)
                Text("Можно выбрать город вручную или разрешить геолокацию позже.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)

                PermissionView(
                    showsCurrentLocationOption: false,
                    onAllow: {},
                    onManualCity: onManualCity
                )
            }
            .padding(32)
        }
    }
}
