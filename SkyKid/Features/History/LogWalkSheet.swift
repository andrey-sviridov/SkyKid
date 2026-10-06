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
    // A manual log has no captured weather by default. The scalar is retained
    // for legacy consumers; it is not provenance and is never filled from the
    // current screen context.
    @State private var walkTemperature: Double?

    private var isEditing: Bool { editingLog != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    WalkDateTimeCard(date: $walkDate)
                    if isEditing {
                        WalkTemperatureCard(temperature: $walkTemperature)
                    } else {
                        WalkWeatherSnapshotCard(weather: nil)
                    }
                    DurationPickerCard(durationMinutes: $durationMinutes)
                    ComfortLevelCard(selected: $comfortLevel)
                    OutfitSummaryCard(
                        selectedIDs: $selectedOutfitIDs,
                        suggestedIDs: [],
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
                    walkTemperature   = nil
                    selectedOutfitIDs = []
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
            existing.effectiveOutfitTOG  = selectedOutfitTOG
            store.update(existing, profile: profile)
        } else {
            let log = Self.makeManualLog(
                date: walkDate,
                durationMinutes: durationMinutes,
                outfitItemIDs: Array(selectedOutfitIDs),
                comfortLevel: comfortLevel,
                temperature: walkTemperature,
                effectiveOutfitTOG: selectedOutfitTOG
            )
            store.add(log, profile: profile)
        }
        onSaved()
        dismiss()
    }

    // MARK: - Log factory

    /// Manual history is deliberately detached from the current weather and
    /// recommendation context. A temperature is only the user's explicit
    /// legacy scalar input; it is not persisted as weather provenance.
    static func makeManualLog(
        date: Date,
        durationMinutes: Int,
        outfitItemIDs: [String],
        comfortLevel: BabyComfortLevel,
        temperature: Double?,
        effectiveOutfitTOG: Double?
    ) -> WalkLog {
        WalkLog(
            date: date,
            durationMinutes: durationMinutes,
            outfitItemIDs: outfitItemIDs,
            comfortLevel: comfortLevel,
            weatherTemperature: temperature,
            apparentTemperature: temperature,
            microclimateTemperature: nil,
            transportMode: nil,
            activityLevel: nil,
            walkType: nil,
            targetTOG: nil,
            effectiveOutfitTOG: effectiveOutfitTOG,
            weatherSnapshot: nil
        )
    }

    private var selectedOutfitTOG: Double? {
        let values = selectedOutfitIDs.compactMap { GarmentCatalog.byID[$0]?.tog }
        return values.isEmpty ? nil : values.reduce(0, +)
    }
}
