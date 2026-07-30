import SwiftUI
import UIKit

struct DeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Доступ к геолокации запрещён")
                .font(.headline)
            Text("Откройте Настройки → SkyKid → Геолокация")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Открыть настройки") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
    }
}
