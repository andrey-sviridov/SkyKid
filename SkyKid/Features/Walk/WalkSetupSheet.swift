import SwiftUI

/// Экран создания прогулки: дата/время, снапшот погоды, целевая длительность,
/// набор одежды с TOG-вердиктом и кнопка «Начать прогулку».
struct WalkSetupSheet: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var recommendation: OutfitRecommendation?
    var walkContext: WalkContext?
    var onStarted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(ActiveWalkStore.self) private var store
    @State private var startDate: Date = .now
    @State private var didEditStartDate = false
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
                    startTimeCard
                    PlannedDurationCard(minutes: $plannedMinutes)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Начать") { startWalk() }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) { startButton }
            .onAppear {
                if selectedIDs.isEmpty { selectedIDs = suggestedIDs }
            }
        }
    }

    private var startTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Начало прогулки", systemImage: "calendar.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            DatePicker(
                "",
                selection: Binding(
                    get: { startDate },
                    set: { startDate = $0; didEditStartDate = true }
                ),
                in: ...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
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
        // Если пользователь не трогал дату/время вручную, старт — это момент
        // нажатия «Начать», а не момент открытия этого экрана: иначе таймер
        // на старте уже «нёс» время, потраченное на настройку прогулки.
        let walk = ActiveWalk(
            startDate: didEditStartDate ? startDate : .now,
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
