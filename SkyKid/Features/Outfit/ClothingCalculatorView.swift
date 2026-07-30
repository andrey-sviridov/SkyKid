// ClothingCalculatorView.swift
// LEGACY: ручной CLO-конструктор, не источник прогноза.
// SRP: только SwiftUI-компоненты вкладки «Конструктор».
// Бизнес-логика — WardrobeModel.swift | Модели — GarmentCatalog.swift

import SwiftUI

struct ClothingCalculatorView: View {
    var profile: ChildProfile?
    var weather: NormalizedWeather?
    @State private var model: WardrobeModel

    init(profile: ChildProfile? = nil, weather: NormalizedWeather? = nil) {
        self.profile = profile
        self.weather = weather
        _model = State(initialValue: WardrobeModel(
            temperature: weather?.apparentTemperature ?? 12.0,
            ageGroup:    profile?.wardrobeAgeGroup ?? .earlyInfant
        ))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {

                LegacyConstructorNoticeCard()

                WeatherControlsCard(model: model)

                if model.isExtremeHeat || model.isExtremeCold {
                    TemperatureNoWalkCard(isHot: model.isExtremeHeat, temperature: model.temperature)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    RiskMeterCard(
                        riskLevel:     model.riskLevel,
                        meterProgress: model.meterProgress,
                        currentHeat:   model.currentHeat,
                        requiredHeat:  model.requiredHeat,
                        deviation:     model.heatDeviation,
                        riskLabel:     model.riskLabel,
                        riskDetail:    model.riskDetail
                    )

                    AutoSelectButton(
                        tempLabel: model.autoSelectLabel,
                        action: { model.autoSelect() }
                    )

                    ComfortCheckCard()

                    PinnedItemsCard(model: model)

                    ClothingConstructorSection(
                        ageGroup: model.ageGroup,
                        selectedItems: model.selectedItems,
                        pinnedIDs: model.pinnedItemIDs,
                        onToggle: { item in
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.65)) {
                                model.toggle(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .skyKidBackground()
        .navigationTitle("Конструктор одежды")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.25), value: model.showHeatAlert)
        .animation(.easeInOut(duration: 0.25), value: model.showColdAlert)
        .onAppear {
            if let profile {
                model.ageGroup = profile.wardrobeAgeGroup
            }
        }
        .onChange(of: weather?.apparentTemperature) { _, newTemp in
            if let t = newTemp {
                model.weatherTemperature = t
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let canReset = !(model.selectedItems.isEmpty &&
                                 model.temperature == model.weatherTemperature)
                Button {
                    model.resetTemperatureAndAutoSelect()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                }
                .tint(.blue)
                .disabled(!canReset)
                .opacity(canReset ? 1 : 0.35)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("🎛 Весна · 12°") {
    NavigationStack {
        ClothingCalculatorView(profile: .mock, weather: .mock)
    }
}

#Preview("🎛 Зима · −8°") {
    NavigationStack {
        ClothingCalculatorView(profile: .mockInfant, weather: .mockWinter)
    }
}
#endif
