import SwiftUI

/// Экран создания прогулки: короткий снапшот погоды, набор одежды и кнопка
/// «Начать прогулку». Редкие параметры остаются в меню «Дополнительно».
struct WalkSetupSheet: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var recommendation: OutfitRecommendation?
    var walkContext: WalkContext?
    var onStarted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(ActiveWalkStore.self) private var store
    @State private var plannedMinutes: Int? = nil
    @State private var selectedIDs: [String] = []

    private var suggestedIDs: [String] {
        recommendation?.allDisplayLayers.map(\.id) ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WalkWeatherSnapshotCard(weather: weather)
                    WalkOutfitChipsCard(
                        selectedIDs: $selectedIDs,
                        profile: profile,
                        targetTOG: recommendation?.targetTOG
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .skyKidBackground()
            .navigationTitle("Новая прогулка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    additionalOptionsMenu
                }
            }
            .safeAreaInset(edge: .bottom) { startButton }
            .onAppear {
                if selectedIDs.isEmpty { selectedIDs = suggestedIDs }
            }
        }
    }

    private var additionalOptionsMenu: some View {
        Menu {
            Button(L10n.text("Без цели")) {
                plannedMinutes = nil
            }
            ForEach([30, 60, 90, 120], id: \.self) { minutes in
                Button(WalkDurationFormatter.string(minutes: minutes)) {
                    plannedMinutes = minutes
                }
            }
        } label: {
            Image(systemName: plannedMinutes == nil ? "ellipsis.circle" : "target")
        }
        .accessibilityLabel(L10n.text("Дополнительные настройки"))
        .accessibilityValue(
            plannedMinutes.map(WalkDurationFormatter.string(minutes:)) ?? L10n.text("Без цели")
        )
    }

    private var startButton: some View {
        Button { startWalk() } label: {
            Label("Начать прогулку", systemImage: "figure.walk")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.32, blue: 0.96),
                                 Color(red: 0.44, green: 0.14, blue: 0.86)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: .blue.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func startWalk() {
        let walk = ActiveWalk(
            startDate: .now,
            plannedDurationMinutes: plannedMinutes,
            weatherTemperature: weather?.temperature ?? 12,
            apparentTemperature: weather?.apparentTemperature ?? weather?.temperature ?? 12,
            microclimateTemperature: recommendation?.temperatures.microclimate,
            weatherCode: weather?.weatherCode,
            weatherIconSymbol: weather?.conditionIcon,
            weatherDescription: weather?.conditionDescription,
            transportMode: walkContext?.transportMode,
            activityLevel: walkContext?.activityLevel,
            walkType: walkContext?.walkType,
            targetTOG: recommendation?.targetTOG,
            outfitItemIDs: selectedIDs,
            events: []
        )
        store.start(walk)
        onStarted()
        dismiss()
    }
}
