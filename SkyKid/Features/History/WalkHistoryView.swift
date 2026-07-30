import SwiftUI

// MARK: - WalkHistoryView (History tab)

struct WalkHistoryView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var recommendation: OutfitRecommendation? = nil
    var walkContext: WalkContext? = nil
    var onPersonalizationChange: () -> Void = {}

    @State private var store = WalkLogStore.shared
    @State private var personalizationStore = PersonalOffsetStore.shared
    @State private var showLog = false
    @State private var editingLog: WalkLog? = nil
    @State private var selectedLog: WalkLog? = nil
    private var tabBarHeight: CGFloat { SkyKidTabBarMetrics.totalHeight }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                if store.totalCount > 0 {
                    StatsHeaderCard(store: store)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
                }

                if !feedbackHistoryItems.isEmpty {
                    FeedbackHistorySection(items: feedbackHistoryItems)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                }

                if store.logs.isEmpty {
                    EmptyHistoryCard()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 0, trailing: 16))
                } else {
                    ForEach(store.logs) { log in
                        Button { selectedLog = log } label: {
                            WalkLogRow(log: log)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let idx = store.logs.firstIndex(where: { $0.id == log.id }) {
                                    store.delete(at: IndexSet(integer: idx))
                                    onPersonalizationChange()
                                }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                            Button { editingLog = log } label: {
                                Label("Изменить", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .skyKidBackground()
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: tabBarHeight + 80) }
            .navigationDestination(item: $selectedLog) { log in
                WalkLogDetailView(
                    log: log,
                    store: store,
                    profile: profile,
                    onChanged: onPersonalizationChange
                )
            }

            Button { showLog = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.08, green: 0.32, blue: 0.96),
                                     Color(red: 0.44, green: 0.14, blue: 0.86)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .shadow(color: .blue.opacity(0.35), radius: 10, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, tabBarHeight + 24)
        }
        .navigationTitle("Журнал прогулок")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showLog) {
            LogWalkSheet(
                weather: weather,
                profile: profile,
                recommendation: recommendation,
                walkContext: walkContext,
                onSaved: onPersonalizationChange
            )
        }
        .sheet(item: $editingLog) { log in
            LogWalkSheet(
                weather: weather,
                profile: profile,
                recommendation: recommendation,
                walkContext: walkContext,
                editingLog: log,
                onSaved: onPersonalizationChange
            )
        }
    }

    // MARK: - Feedback history

    private var feedbackHistoryItems: [FeedbackHistoryItem] {
        guard let profile else { return [] }
        let observations = personalizationStore.feedbackHistory(
            for: profile.thermalProfile
        )
        return FeedbackHistoryItemBuilder.make(from: observations)
    }
}

// MARK: - StatsHeaderCard

private struct StatsHeaderCard: View {
    let store: WalkLogStore

    var body: some View {
        HStack(spacing: 0) {
            statCell(
                value: "\(store.recentCount)",
                label: L10n.text("За 7 дней"),
                icon: "figure.walk",
                color: .blue
            )
            Divider().frame(height: 46)
            statCell(
                value: avgDuration,
                label: L10n.text("Средняя\nдлительность"),
                icon: "clock",
                color: .teal
            )
            Divider().frame(height: 46)
            statCell(
                value: "\(store.totalCount)",
                label: L10n.text("Всего\nзаписей"),
                icon: "list.bullet.clipboard",
                color: .purple
            )
        }
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var avgDuration: String {
        guard !store.logs.isEmpty else { return "—" }
        let avg = store.logs.map(\.durationMinutes).reduce(0, +) / store.logs.count
        return WalkDurationFormatter.string(minutes: avg)
    }

}

// MARK: - EmptyHistoryCard

private struct EmptyHistoryCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 48, weight: .thin))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            VStack(spacing: 6) {
                Text("Нет записей о прогулках")
                    .font(.headline)
                Text("Нажмите +, чтобы записать первую прогулку. Повторяющиеся оценки в похожих условиях помогут точнее подбирать одежду.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - WalkLogRow

private struct WalkLogRow: View {
    let log: WalkLog

    @State private var showingLiveActivityInfo = false

    private var comfortColor: Color { log.comfortLevel.color }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Comfort badge
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(comfortColor.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: log.comfortLevel.icon)
                    .font(.system(size: 19))
                    .foregroundStyle(comfortColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                        .font(.subheadline.weight(.semibold))
                    if log.isLiveTracked { liveBadge }
                    Spacer()
                    durationBadge
                }

                HStack(spacing: 10) {
                    Label("\(Int(log.weatherTemperature.rounded()))°C", systemImage: "thermometer.medium")
                    Label(log.comfortLevel.label, systemImage: log.comfortLevel.icon)
                        .foregroundStyle(comfortColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !log.outfitItemIDs.isEmpty {
                    let names = log.outfitItemIDs.compactMap { GarmentCatalog.byID[$0]?.name }
                    if !names.isEmpty {
                        Text(names.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
        .alert(L10n.text("Live Activity"), isPresented: $showingLiveActivityInfo) {
            Button(L10n.text("Понятно")) {}
        } message: {
            Text(L10n.text("Эта прогулка отслеживалась вживую: таймер и статус отображались на экране блокировки и в Dynamic Island, пока прогулка шла."))
        }
    }

    private var durationBadge: some View {
        Text(WalkDurationFormatter.string(minutes: log.durationMinutes))
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.07), in: Capsule())
    }

    private var liveBadge: some View {
        Button {
            showingLiveActivityInfo = true
        } label: {
            Label("Прогулка", systemImage: "figure.walk.motion")
                .labelStyle(.iconOnly)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.green)
                .padding(5)
                .background(Color.green.opacity(0.14), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text("Live Activity"))
        .accessibilityHint(L10n.text("Прогулка отслеживалась вживую через экран блокировки"))
    }
}

// MARK: - LogWalkSheet

struct LogWalkSheet: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var recommendation: OutfitRecommendation? = nil
    var walkContext: WalkContext? = nil
    var editingLog: WalkLog? = nil
    var onSaved: () -> Void = {}

    @State private var store = WalkLogStore.shared
    @State private var walkDate: Date = .now
    @State private var durationMinutes: Int = 30
    @State private var comfortLevel: BabyComfortLevel = .comfortable
    @State private var selectedOutfitIDs: Set<String> = []
    @State private var walkTemperature: Double = 12
    @Environment(\.dismiss) private var dismiss

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

// MARK: - WalkDateTimeCard

private struct WalkDateTimeCard: View {
    @Binding var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Дата и время прогулки", systemImage: "calendar.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Если записываете позже — выберите фактическое время.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            DatePicker(
                "",
                selection: $date,
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
}

// MARK: - WalkTemperatureCard

private struct WalkTemperatureCard: View {
    @Binding var temperature: Double

    private var tempColor: Color {
        switch temperature {
        case ...0:    return .blue
        case 0..<15:  return Color(red: 0.2, green: 0.55, blue: 1.0)
        case 15..<22: return .green
        case 22..<28: return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Температура на прогулке", systemImage: "thermometer.medium")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Введите температуру того момента — если записываете позже.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 20) {
                stepButton(icon: "minus", action: { temperature = max(-30, temperature - 1) })

                Spacer()

                Text("\(Int(temperature.rounded()))°C")
                    .font(.system(size: 44, weight: .thin, design: .rounded))
                    .foregroundStyle(tempColor)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25), value: temperature)
                    .frame(minWidth: 100)

                Spacer()

                stepButton(icon: "plus", action: { temperature = min(45, temperature + 1) })
            }

            Slider(value: $temperature, in: -30...45, step: 1)
                .tint(tempColor)
                .transaction { t in t.animation = nil }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    private func stepButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation { action() } }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WeatherContextCard (kept for possible reuse)

private struct WeatherContextCard: View {
    let weather: NormalizedWeather

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "thermometer.medium")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Погода во время прогулки")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(Int(weather.temperature.rounded()))° · ощущается \(Int(weather.apparentTemperature.rounded()))°C")
                    .font(.subheadline.weight(.medium))
            }
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - DurationPickerCard

private struct DurationPickerCard: View {
    @Binding var durationMinutes: Int
    private let options = [15, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Длительность прогулки", systemImage: "clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(options, id: \.self) { mins in
                        let selected = durationMinutes == mins
                        Button { durationMinutes = mins } label: {
                            Text(durationLabel(mins))
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    selected
                                        ? Color.blue
                                        : Color.primary.opacity(0.08),
                                    in: Capsule()
                                )
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

    private func durationLabel(_ mins: Int) -> String {
        WalkDurationFormatter.string(minutes: mins)
    }
}

// MARK: - ComfortLevelCard

private struct ComfortLevelCard: View {
    @Binding var selected: BabyComfortLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Как чувствовал себя малыш?", systemImage: "hand.raised.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Проверьте живот или заднюю поверхность шеи: кожа должна быть тёплой и сухой. Холодные кисти и стопы сами по себе не означают, что ребёнок замёрз.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 10) {
                ForEach(BabyComfortLevel.allCases) { level in
                    let isSelected = selected == level
                    let color = level.color
                    Button { withAnimation(.spring(response: 0.25)) { selected = level } } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(isSelected ? color.opacity(0.18) : Color.primary.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(isSelected ? color : Color.clear, lineWidth: 1.5)
                                    )
                                    .frame(height: 52)
                                Image(systemName: level.icon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(isSelected ? color : .secondary)
                            }
                            Text(level.label)
                                .font(.caption2.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? color : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - OutfitSummaryCard

private struct OutfitSummaryCard: View {
    @Binding var selectedIDs: Set<String>
    let suggestedIDs: [String]
    let profile: ChildProfile?
    var startInManual: Bool = false

    @State private var mode: PickMode = .auto
    @State private var wardrobeStore = UserWardrobeStore.shared

    private enum PickMode: String, CaseIterable {
        case auto   = "Рекомендация"
        case manual = "Гардероб"
    }

    private var autoItems: [GarmentItem] {
        suggestedIDs.compactMap { GarmentCatalog.byID[$0] }
    }

    private var manualItems: [GarmentItem] {
        let ageGroup = profile?.wardrobeAgeGroup
        return GarmentCatalog.catalogItems.filter { item in
            wardrobeStore.isOwned(item.id) &&
            (ageGroup == nil || item.catalogAgeGroup?.matches(ageGroup!) == true)
        }
    }

    private var displayItems: [GarmentItem] {
        mode == .auto ? autoItems : manualItems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Во что был одет", systemImage: "hanger")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Необязательно")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Picker("", selection: $mode) {
                ForEach(PickMode.allCases, id: \.self) { m in
                    Text(L10n.text(m.rawValue)).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, newMode in
                if newMode == .auto {
                    selectedIDs = Set(suggestedIDs)
                }
            }

            if displayItems.isEmpty {
                Text(
                    mode == .auto
                        ? L10n.text("Нет данных о погоде или профиле ребёнка")
                        : L10n.text("В гардеробе нет вещей для этого возраста")
                )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(displayItems) { item in
                        let on = selectedIDs.contains(item.id)
                        Button {
                            withAnimation(.spring(response: 0.2)) {
                                if on { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
                            }
                        } label: {
                            Text(item.name)
                                .font(.caption.weight(on ? .semibold : .regular))
                                .foregroundStyle(on ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    on ? Color.blue : Color.primary.opacity(0.09),
                                    in: Capsule()
                                )
                                .overlay(Capsule().strokeBorder(on ? Color.clear : Color.primary.opacity(0.18), lineWidth: 1))
                                .scaleEffect(on ? 1.04 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: on)
                        .sensoryFeedback(.selection, trigger: on)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
        .onAppear {
            if startInManual { mode = .manual }
        }
    }
}

// MARK: - WalkLogDetailView

private struct WalkLogDetailView: View {
    let store: WalkLogStore
    let profile: ChildProfile?
    let onChanged: () -> Void

    @State private var log: WalkLog
    @State private var showAddEvent = false
    @State private var reclassifyingEvent: WalkEvent?
    @Environment(\.dismiss) private var dismiss

    init(log: WalkLog, store: WalkLogStore, profile: ChildProfile?, onChanged: @escaping () -> Void) {
        self.store = store
        self.profile = profile
        self.onChanged = onChanged
        _log = State(initialValue: log)
    }

    private var comfortColor: Color { log.comfortLevel.color }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                comfortHero
                infoCard
                if !log.outfitItemIDs.isEmpty { outfitCard }
                if log.isLiveTracked { timelineCard }
                deleteButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .skyKidBackground()
        .navigationTitle("Прогулка")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddEvent) {
            AddWalkEventSheet(walkStart: log.date) { event in
                log.events.append(event)
                persist()
            }
        }
        .sheet(item: $reclassifyingEvent) { event in
            WalkEventReclassifySheet(event: event, profile: profile) { kind, garmentID, note in
                reclassify(event, kind: kind, garmentID: garmentID, note: note)
            }
        }
    }

    private func persist() {
        log.events.sort { $0.timestamp < $1.timestamp }
        store.update(log, profile: profile)
        onChanged()
    }

    private func reclassify(_ event: WalkEvent, kind: WalkEventKind, garmentID: String?, note: String?) {
        guard let idx = log.events.firstIndex(where: { $0.id == event.id }) else { return }
        let result = WalkEventReclassifier.apply(
            old: log.events[idx],
            newKind: kind,
            newGarmentID: garmentID,
            newNote: note,
            outfitItemIDs: log.outfitItemIDs
        )
        log.events[idx] = result.event
        log.outfitItemIDs = result.outfitItemIDs
        persist()
    }

    // MARK: Timeline

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Таймлайн прогулки", systemImage: "list.bullet.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { showAddEvent = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            if log.events.isEmpty {
                Text("Отметок не было")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(log.events.sorted { $0.timestamp > $1.timestamp }) { event in
                    timelineRow(event)
                        .contextMenu {
                            Button {
                                reclassifyingEvent = event
                            } label: {
                                Label("Назначить действие", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                log.events.removeAll { $0.id == event.id }
                                persist()
                            } label: {
                                Label("Удалить отметку", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
    }

    private func timelineRow(_ event: WalkEvent) -> some View {
        let color = event.kind.color
        let subtitle: String? = event.garmentID.flatMap { GarmentCatalog.byID[$0]?.name } ?? event.note
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: event.kind.icon).font(.system(size: 14)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(event.kind.title).font(.subheadline.weight(.medium))
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(event.timestamp, format: .dateTime.hour().minute())
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            if event.kind == .checkpoint {
                Button {
                    reclassifyingEvent = event
                } label: {
                    Text("Назначить")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: Sections

    private var comfortHero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(comfortColor.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: log.comfortLevel.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(comfortColor)
            }
            Text(log.comfortLevel.label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(comfortColor)
            Text("Самочувствие малыша")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(comfortColor.opacity(0.3), lineWidth: 1))
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(icon: "calendar", label: L10n.text("Дата"),
                    value: log.date.formatted(
                        .dateTime
                            .day()
                            .month(.wide)
                            .year()
                            .locale(L10n.locale)
                    ))
            Divider().padding(.leading, 52)
            infoRow(icon: "clock", label: L10n.text("Время"),
                    value: log.date.formatted(
                        .dateTime
                            .hour()
                            .minute()
                            .locale(L10n.locale)
                    ))
            Divider().padding(.leading, 52)
            infoRow(
                icon: "timer",
                label: L10n.text("Длительность"),
                value: durationString
            )
            Divider().padding(.leading, 52)
            infoRow(icon: "thermometer.medium", label: L10n.text("Температура"),
                    value: "\(Int(log.weatherTemperature.rounded()))°C")
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .padding(.leading, 16)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .padding(.trailing, 16)
        }
        .padding(.vertical, 13)
    }

    private var outfitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Одежда", systemImage: "hanger")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let items = log.outfitItemIDs.compactMap { GarmentCatalog.byID[$0] }
            FlowLayout(spacing: 8) {
                ForEach(items) { item in
                    Text(item.name)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.10), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.blue.opacity(0.25), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if let idx = store.logs.firstIndex(where: { $0.id == log.id }) {
                store.delete(at: IndexSet(integer: idx))
                onChanged()
            }
            dismiss()
        } label: {
            Label("Удалить прогулку", systemImage: "trash")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.red.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var durationString: String {
        WalkDurationFormatter.string(minutes: log.durationMinutes)
    }
}

// MARK: - AddWalkEventSheet

/// Добавление пропущенной отметки задним числом: тип события + время.
private struct AddWalkEventSheet: View {
    let walkStart: Date
    var onAdd: (WalkEvent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: WalkEventKind = .checkpoint
    @State private var timestamp: Date

    init(walkStart: Date, onAdd: @escaping (WalkEvent) -> Void) {
        self.walkStart = walkStart
        self.onAdd = onAdd
        _timestamp = State(initialValue: walkStart)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Тип отметки")) {
                    Picker("", selection: $kind) {
                        ForEach(WalkEventKind.allCases) { k in
                            Label(k.title, systemImage: k.icon).tag(k)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section(L10n.text("Время")) {
                    DatePicker("", selection: $timestamp, in: walkStart...Date.now,
                               displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                }
            }
            .navigationTitle("Новая отметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        onAdd(WalkEvent(timestamp: timestamp, kind: kind))
                        dismiss()
                    }.fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - WalkDurationFormatter

private enum WalkDurationFormatter {
    static func string(minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = minutes >= 60 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropLeading, .dropTrailing]

        return formatter.string(from: TimeInterval(minutes * 60))
            ?? L10n.format("%lld мин", minutes)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("История") {
    NavigationStack {
        WalkHistoryView(weather: .mock, profile: .mock)
    }
}
#endif
