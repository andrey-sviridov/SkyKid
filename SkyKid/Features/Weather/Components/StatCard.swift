import SwiftUI

/// Самостоятельная карточка-показатель на вкладке погоды.
struct StatCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    var iconRotation: Double = 0

    var body: some View {
        MetricTile(
            icon: icon,
            color: color,
            value: value,
            label: title,
            style: .prominent,
            iconRotation: iconRotation
        )
        .glassCard(cornerRadius: 18)
    }
}
