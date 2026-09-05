import SwiftUI

// MARK: - WalkPreparationView

struct WalkPreparationView: View {
    let onSave: (WalkContext) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: WalkPreparationViewModel

    init(
        profile: ChildThermalProfile,
        context: WalkContext,
        onSave: @escaping (WalkContext) -> Void
    ) {
        self.onSave = onSave
        _viewModel = State(initialValue: WalkPreparationViewModel(
            profile: profile,
            context: context
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                healthSection
                activitySection
                transportSection
                insulationSection
            }
            .accessibilityIdentifier("walkPreparation.form")
            .navigationTitle("Собираемся гулять")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                applyButton
            }
        }
    }

    // MARK: - Health

    private var healthSection: some View {
        Section {
            ForEach(CurrentHealthStatus.allCases) { status in
                SelectionRow(
                    title: status.label,
                    systemImage: status.systemImage,
                    isSelected: viewModel.context.healthStatus == status
                ) {
                    viewModel.selectHealthStatus(status)
                }
            }

            if viewModel.context.healthStatus != .well {
                Toggle(
                    "Температура измерена",
                    isOn: Binding(
                        get: { viewModel.includesBodyTemperature },
                        set: { viewModel.setBodyTemperatureIncluded($0) }
                    )
                )

                if viewModel.includesBodyTemperature {
                    Stepper(value: bodyTemperatureBinding, in: 35...42, step: 0.1) {
                        LabeledContent(
                            "Температура тела",
                            value: String(format: "%.1f°C", bodyTemperatureBinding.wrappedValue)
                        )
                    }
                }
            }
        } header: {
            Text("Самочувствие сейчас")
        } footer: {
            Text("Эти данные используются только для текущего расчёта и не сохраняются в профиле ребёнка.")
        }
    }

    private var bodyTemperatureBinding: Binding<Double> {
        Binding(
            get: { viewModel.context.bodyTemperatureCelsius ?? 38 },
            set: { viewModel.context.bodyTemperatureCelsius = $0 }
        )
    }

    // MARK: - Activity

    private var activitySection: some View {
        Section("Активность") {
            Picker("Как будет двигаться", selection: activityBinding) {
                ForEach(BabyActivityLevel.allCases, id: \.self) { activity in
                    Label(activity.label, systemImage: activity.icon)
                        .tag(activity)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    // MARK: - Transport

    private var transportSection: some View {
        Section("Как гуляем") {
            Picker("Транспорт", selection: transportBinding) {
                ForEach(availableTransports, id: \.self) { transport in
                    Label(transport.walkLabel, systemImage: transport.walkSystemImage)
                        .tag(transport)
                }
            }
            .pickerStyle(.navigationLink)

            if viewModel.context.transportMode == .carrier {
                Toggle("Под курткой родителя", isOn: parentCarrierBinding)
            }
        }
    }

    private var availableTransports: [TransportMode] {
        switch viewModel.profile.ageGroup {
        case .infant, .baby:
            return [.pramBassinette, .pushchairSeat, .carrier, .carSeat]
        case .toddler:
            return [.walking, .pushchairSeat, .carrier, .carSeat]
        default:
            return [.walking, .carSeat]
        }
    }

    // MARK: - Insulation

    @ViewBuilder
    private var insulationSection: some View {
        if viewModel.context.transportMode == .pramBassinette
            || viewModel.context.transportMode == .pushchairSeat {
            Section {
                Toggle("Капюшон поднят", isOn: hoodBinding)
                Toggle(
                    "Дождевик установлен",
                    isOn: Binding(
                        get: { viewModel.context.rainCover == .present_on },
                        set: { viewModel.context.rainCover = $0 ? .present_on : .notPresent }
                    )
                )
                Picker("Утепление", selection: strollerInsulationBinding) {
                    ForEach(StrollerInsulationOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("Защита и утепление")
            } footer: {
                Text("Выберите один готовый вариант утепления. Дождевик требует вентиляции; плотной тканью коляску накрывать нельзя.")
            }
        }
    }

    // MARK: - Primary action

    private var applyButton: some View {
        Button {
            onSave(viewModel.finalizedContext())
            dismiss()
        } label: {
            Label("Показать рекомендацию", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
        }
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .accessibilityIdentifier("walkPreparation.apply")
    }

    // MARK: - Bindings

    private var activityBinding: Binding<BabyActivityLevel> {
        Binding(
            get: { viewModel.context.activityLevel },
            set: { viewModel.context.activityLevel = $0 }
        )
    }

    private var parentCarrierBinding: Binding<Bool> {
        Binding(
            get: { viewModel.context.parentWearingCarrier },
            set: { viewModel.context.parentWearingCarrier = $0 }
        )
    }

    private var transportBinding: Binding<TransportMode> {
        Binding(
            get: { viewModel.context.transportMode },
            set: { viewModel.selectTransport($0) }
        )
    }

    private var hoodBinding: Binding<Bool> {
        Binding(
            get: { viewModel.context.hoodUp },
            set: { viewModel.context.hoodUp = $0 }
        )
    }

    private var strollerInsulationBinding: Binding<StrollerInsulationOption> {
        Binding(
            get: {
                StrollerInsulationOption(
                    hasFootmuff: viewModel.context.strollerConvertTOG != nil,
                    hasBlanket: viewModel.context.blanketTOG != nil
                )
            },
            set: { option in
                viewModel.context.strollerConvertTOG = option.hasFootmuff ? 2 : nil
                viewModel.context.blanketTOG = option.hasBlanket ? 1 : nil
            }
        )
    }
}

// MARK: - Stroller insulation

private enum StrollerInsulationOption: String, CaseIterable, Identifiable {
    case none
    case blanket
    case footmuff
    case footmuffAndBlanket

    var id: String { rawValue }

    init(hasFootmuff: Bool, hasBlanket: Bool) {
        switch (hasFootmuff, hasBlanket) {
        case (false, false): self = .none
        case (false, true):  self = .blanket
        case (true, false):  self = .footmuff
        case (true, true):   self = .footmuffAndBlanket
        }
    }

    var label: String {
        switch self {
        case .none:               return L10n.text("Без дополнительного утепления")
        case .blanket:            return L10n.text("Плед")
        case .footmuff:           return L10n.text("Утеплённый конверт")
        case .footmuffAndBlanket: return L10n.text("Конверт и плед")
        }
    }

    var hasFootmuff: Bool {
        self == .footmuff || self == .footmuffAndBlanket
    }

    var hasBlanket: Bool {
        self == .blanket || self == .footmuffAndBlanket
    }
}

// MARK: - SelectionRow

private struct SelectionRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.indigo)
                }
            }
            .foregroundStyle(.primary)
        }
        .frame(minHeight: 44)
        .accessibilityValue(
            isSelected
                ? L10n.text("Выбрано")
                : L10n.text("Не выбрано")
        )
    }
}
