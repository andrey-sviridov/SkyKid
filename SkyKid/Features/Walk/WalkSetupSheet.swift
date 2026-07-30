import SwiftUI

// MARK: - WalkTOGVerdict

/// Вердикт «жарко/холодно» по суммарному TOG набора относительно целевого TOG.
struct WalkTOGVerdict {
    let effective: Double
    let target: Double?

    enum Level {
        case cold, cool, comfortable, warm, hot

        var label: String {
            switch self {
            case .cold:        return L10n.text("Замёрзнет")
            case .cool:        return L10n.text("Прохладно")
            case .comfortable: return L10n.text("Комфортно")
            case .warm:        return L10n.text("Тепловато")
            case .hot:         return L10n.text("Перегрев")
            }
        }

        var icon: String {
            switch self {
            case .cold:        return "snowflake"
            case .cool:        return "wind"
            case .comfortable: return "checkmark.circle.fill"
            case .warm:        return "sun.max.fill"
            case .hot:         return "flame.fill"
            }
        }

        var color: Color {
            switch self {
            case .cold:        return .blue
            case .cool:        return .teal
            case .comfortable: return .green
            case .warm:        return .orange
            case .hot:         return .red
            }
        }
    }

    /// Отклонение набора от цели (TOG). nil, если цель неизвестна.
    var delta: Double? {
        guard let target else { return nil }
        return effective - target
    }

    var level: Level {
        guard let delta else { return .comfortable }
        switch delta {
        case ..<(-1.0):      return .cold
        case -1.0..<(-0.4):  return .cool
        case -0.4...0.4:     return .comfortable
        case 0.4...1.0:      return .warm
        default:             return .hot
        }
    }
}

// MARK: - GarmentChip

/// Чип вещи: мелкая иконка + название + TOG, с опциональной кнопкой удаления.
struct GarmentChip: View {
    let item: GarmentItem
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 7) {
            GarmentIconView(
                item: item,
                isSelected: true,
                accentColor: .blue,
                size: 26,
                shape: .roundedRectangle(6)
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(L10n.format("%.2f TOG", item.tog))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, onRemove == nil ? 12 : 6)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.primary.opacity(0.14), lineWidth: 1))
    }
}

// MARK: - WalkOutfitChipsCard

/// Карточка «Во что одет»: чипы одежды + «＋», суммарный TOG и вердикт.
struct WalkOutfitChipsCard: View {
    @Binding var selectedIDs: [String]
    let profile: ChildProfile?
    let targetTOG: Double?
    var onAdd: (String) -> Void = { _ in }
    var onRemove: (String) -> Void = { _ in }

    @State private var showPicker = false

    private var items: [GarmentItem] {
        selectedIDs.compactMap { GarmentCatalog.byID[$0] }
    }

    private var effectiveTOG: Double {
        items.map(\.tog).reduce(0, +)
    }

    private var verdict: WalkTOGVerdict {
        WalkTOGVerdict(effective: effectiveTOG, target: targetTOG)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Во что одет", systemImage: "hanger")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L10n.format("%.1f TOG", effectiveTOG))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            FlowLayout(spacing: 8) {
                ForEach(items) { item in
                    GarmentChip(item: item) {
                        withAnimation(.spring(response: 0.2)) {
                            selectedIDs.removeAll { $0 == item.id }
                        }
                        onRemove(item.id)
                    }
                }
                addChip
            }

            verdictBar
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        .sheet(isPresented: $showPicker) {
            GarmentPickerSheet(profile: profile, selectedIDs: $selectedIDs, onAdd: onAdd)
        }
    }

    private var addChip: some View {
        Button { showPicker = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                Text("Добавить")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.blue.opacity(0.10), in: Capsule())
            .overlay(
                Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(Color.blue.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var verdictBar: some View {
        let level = verdict.level
        HStack(spacing: 10) {
            Image(systemName: level.icon)
                .font(.system(size: 18))
                .foregroundStyle(level.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(level.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(level.color)
                if let target = targetTOG {
                    Text(L10n.format("Цель ~%.1f TOG", target))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Нет данных о рекомендации")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(level.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - GarmentPickerSheet

/// Всплывающий выбор вещи с поиском и фильтром по гардеробу.
struct GarmentPickerSheet: View {
    let profile: ChildProfile?
    @Binding var selectedIDs: [String]
    var onAdd: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var ownedOnly = true
    @State private var wardrobeStore = UserWardrobeStore.shared

    private var filtered: [GarmentItem] {
        let ageGroup = profile?.wardrobeAgeGroup
        return GarmentCatalog.catalogItems.filter { item in
            let matchesAge = ageGroup == nil || item.catalogAgeGroup?.matches(ageGroup!) != false
            let matchesOwned = !ownedOnly || wardrobeStore.isOwned(item.id)
            let matchesSearch = search.isEmpty
                || item.name.localizedCaseInsensitiveContains(search)
            return matchesAge && matchesOwned && matchesSearch
        }
        .sorted { lhs, rhs in
            let l = selectedIDs.contains(lhs.id)
            let r = selectedIDs.contains(rhs.id)
            if l != r { return l && !r }
            return lhs.tog < rhs.tog
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Toggle(isOn: $ownedOnly) {
                    Label("Только мой гардероб", systemImage: "checkmark.seal")
                        .font(.subheadline)
                }
                .listRowBackground(Color.clear)

                ForEach(filtered) { item in
                    let on = selectedIDs.contains(item.id)
                    Button {
                        withAnimation(.spring(response: 0.2)) { toggle(item.id) }
                    } label: {
                        HStack(spacing: 12) {
                            GarmentIconView(
                                item: item,
                                isSelected: on,
                                accentColor: .blue,
                                size: 34,
                                shape: .roundedRectangle(8)
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.subheadline)
                                Text(L10n.format("%.2f TOG", item.tog))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(on ? Color.blue : Color.secondary.opacity(0.4))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .skyKidBackground()
            .searchable(text: $search, prompt: L10n.text("Поиск одежды"))
            .navigationTitle("Выбор одежды")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if let idx = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: idx)
        } else {
            selectedIDs.append(id)
            onAdd(id)
        }
    }
}

// MARK: - WalkSetupSheet

/// Экран создания прогулки: дата/время, снапшот погоды, целевая длительность,
/// набор одежды с TOG-вердиктом и кнопка «Начать прогулку».
struct WalkSetupSheet: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var recommendation: OutfitRecommendation?
    var walkContext: WalkContext?
    var onStarted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var store = ActiveWalkStore.shared
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

// MARK: - PlannedDurationCard

private struct PlannedDurationCard: View {
    @Binding var minutes: Int?
    private let options: [Int?] = [nil, 30, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Планируемая длительность", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                        let selected = minutes == opt
                        Button { minutes = opt } label: {
                            Text(label(opt))
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selected ? Color.blue : Color.primary.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.25), value: selected)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func label(_ opt: Int?) -> String {
        guard let opt else { return L10n.text("Без цели") }
        return opt >= 60
            ? L10n.format("%lld ч %lld мин", opt / 60, opt % 60).replacingOccurrences(of: " 0 мин", with: "")
            : L10n.format("%lld мин", opt)
    }
}

// MARK: - WalkWeatherSnapshotCard

/// Снапшот текущей погоды: иконка + описание + температура на weather-градиенте.
struct WalkWeatherSnapshotCard: View {
    let weather: NormalizedWeather?

    var body: some View {
        let tone = SkyKidTheme.WeatherTone(weatherCode: weather?.weatherCode)
        HStack(spacing: 14) {
            Image(systemName: weather?.conditionIcon ?? "questionmark")
                .font(.system(size: 34))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(tone.onColor)
                .frame(width: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(weather?.conditionDescription ?? L10n.text("Нет данных о погоде"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tone.onColor)
                if let weather {
                    Text(L10n.format("%lld° · ощущается %lld°C",
                                     Int(weather.temperature.rounded()),
                                     Int(weather.apparentTemperature.rounded())))
                        .font(.caption)
                        .foregroundStyle(tone.onColor.opacity(0.85))
                }
            }
            Spacer()
        }
        .padding(16)
        .background(SkyKidTheme.weatherGradient(for: weather?.weatherCode), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.25), lineWidth: 1))
    }
}
