import SwiftUI

struct LogWalkSheet: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var recommendation: OutfitRecommendation? = nil
    var walkContext: WalkContext? = nil
    var editingLog: WalkLog? = nil
    var onSaved: () -> Void = {}

    @Environment(WalkLogStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var walkDate: Date = .now
    @State private var durationMinutes: Int = 30
    @State private var comfortLevel: BabyComfortLevel = .comfortable
    @State private var selectedOutfitIDs: Set<String> = []
    @State private var walkTemperature: Double = 12

    private var isEditing: Bool { editingLog != nil }

    private var suggestedIDs: [String] {
        guard let recommendation else { return [] }
        return recommendation.allDisplayLayers.map(\.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WalkDateTimeCard(date: $walkDate)
                    WalkTemperatureCard(temperature: $walkTemperature)
                    DurationPickerCard(durationMinutes: $durationMinutes)
                    ComfortLevelCard(selected: $comfortLevel)
                    OutfitSummaryCard(
                        selectedIDs: $selectedOutfitIDs,
                        suggestedIDs: suggestedIDs,
                        profile: profile,
                        startInManual: isEditing
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .skyKidBackground()
            .navigationTitle(
                isEditing
                    ? L10n.text("Редактировать прогулку")
                    : L10n.text("Записать прогулку")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let log = editingLog {
                    walkDate           = log.date
                    walkTemperature    = log.weatherTemperature
                    durationMinutes    = log.durationMinutes
                    comfortLevel       = log.comfortLevel
                    selectedOutfitIDs  = Set(log.outfitItemIDs)
                } else {
                    walkTemperature   = weather?.apparentTemperature ?? weather?.temperature ?? 12
                    selectedOutfitIDs = Set(suggestedIDs)
                }
            }
        }
    }

    private func saveAndDismiss() {
        if var existing = editingLog {
            existing.date               = walkDate
            existing.weatherTemperature = walkTemperature
            existing.apparentTemperature = walkTemperature
            existing.durationMinutes    = durationMinutes
            existing.comfortLevel       = comfortLevel
            existing.outfitItemIDs      = Array(selectedOutfitIDs)
            existing.microclimateTemperature = existing.microclimateTemperature ?? walkTemperature
            existing.transportMode      = existing.transportMode ?? walkContext?.transportMode
            existing.activityLevel      = existing.activityLevel ?? walkContext?.activityLevel
            existing.walkType           = existing.walkType ?? walkContext?.walkType
            existing.targetTOG           = existing.targetTOG ?? recommendation?.targetTOG
            existing.effectiveOutfitTOG  = selectedOutfitTOG
            store.update(existing, profile: profile)
        } else {
            let log = WalkLog(
                date: walkDate,
                durationMinutes: durationMinutes,
                outfitItemIDs: Array(selectedOutfitIDs),
                comfortLevel: comfortLevel,
                weatherTemperature: walkTemperature,
                apparentTemperature: weather?.apparentTemperature ?? walkTemperature,
                microclimateTemperature: recommendation?.temperatures.microclimate ?? walkTemperature,
                transportMode: walkContext?.transportMode,
                activityLevel: walkContext?.activityLevel,
                walkType: walkContext?.walkType,
                targetTOG: recommendation?.targetTOG,
                effectiveOutfitTOG: selectedOutfitTOG
            )
            store.add(log, profile: profile)
        }
        onSaved()
        dismiss()
    }

    private var selectedOutfitTOG: Double? {
        let values = selectedOutfitIDs.compactMap { GarmentCatalog.byID[$0]?.tog }
        return values.isEmpty ? nil : values.reduce(0, +)
    }
}
