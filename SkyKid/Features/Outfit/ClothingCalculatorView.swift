// ClothingCalculatorView.swift
// SRP: только SwiftUI-компоненты вкладки «Конструктор».
// Бизнес-логика — WardrobeModel.swift | Модели — GarmentCatalog.swift
// ─────────────────────────────────────────────────────────────────────────
// PERF: ClothingConstructorSection получает `selectedItems: Set<GarmentItem>`
// как VALUE-параметр. LazyVGrid не перерисовывается при сдвиге слайдера —
// только при тапе на предмет одежды.
// ─────────────────────────────────────────────────────────────────────────

import SwiftUI

// MARK: – Root View ───────────────────────────────────────────────────────

struct ClothingCalculatorView: View {
    var profile: ChildProfile?
    var weather: WeatherData?
    @State private var model: WardrobeModel

    init(profile: ChildProfile? = nil, weather: WeatherData? = nil) {
        self.profile = profile
        self.weather = weather
        _model = State(initialValue: WardrobeModel(
            temperature: weather?.apparentTemperature ?? 12.0,
            ageGroup:    profile?.wardrobeAgeGroup ?? .earlyInfant
        ))
    }

    private var togRecommendation: OutfitRecommendation? {
        guard let profile, let weather else { return nil }
        return OutfitRecommendationService.shared.recommend(
            weather: weather,
            profile: profile,
            gearSetup: GearSetup.from(profile: profile)
        )
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {

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

                    PediatricNoteCard()

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
            if let rec = togRecommendation {
                model.syncWithTOG(rec)
            }
        }
        .onChange(of: weather?.apparentTemperature) { _, newTemp in
            if let rec = togRecommendation {
                model.syncWithTOG(rec)
            } else if let t = newTemp {
                model.weatherTemperature = t
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                let canReset = !(model.selectedItems.isEmpty &&
                                 model.temperature == model.weatherTemperature)
                Button {
                    withAnimation(.spring(response: 0.3)) { model.resetAll() }
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

// MARK: – WeatherControlsCard ─────────────────────────────────────────────

struct WeatherControlsCard: View {
    @Bindable var model: WardrobeModel

    var body: some View {
        VStack(spacing: 16) {

            HStack(spacing: 14) {
                Image(systemName: model.weatherIcon)
                    .font(.system(size: 46))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 58)
                    .animation(.spring(response: 0.4), value: model.weatherIcon)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(model.temperature.rounded()))°C")
                        .font(.system(size: 50, weight: .thin, design: .rounded))
                        .foregroundStyle(model.tempColor)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25), value: model.temperature)
                    Text("Температура на улице")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(spacing: 5) {
                Slider(value: $model.temperature, in: -25...35, step: 1)
                    .tint(model.tempColor)
                    .transaction { t in t.animation = nil }
                HStack {
                    Text("−25°")
                    Spacer()
                    Text("0°")
                    Spacer()
                    Text("+35°")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.child")
                        .foregroundStyle(.secondary)
                    Text("Возраст / активность")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Picker("Возраст", selection: $model.ageGroup) {
                    ForEach(WardrobeAgeGroup.allCases) { g in Text(g.rawValue).tag(g) }
                }
                .pickerStyle(.segmented)

                Text(model.ageGroup.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: model.ageGroup)
            }
        }
        .skyKidCard()
    }
}

// MARK: – RiskMeterCard ───────────────────────────────────────────────────
// Получает только value types — view identity стабильна независимо от модели

struct RiskMeterCard: View {
    let riskLevel: ThermalRisk
    let meterProgress: Double
    let currentHeat: Double
    let requiredHeat: Double
    let deviation: Double
    let riskLabel: String
    let riskDetail: String

    var body: some View {
        VStack(spacing: 14) {

            HStack(spacing: 12) {
                Image(systemName: riskLevel.symbol)
                    .font(.title)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(riskLevel.color)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(riskLabel)
                        .font(.headline)
                        .foregroundStyle(riskLevel.color)
                    Text(riskDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .animation(.easeInOut(duration: 0.2), value: riskLevel)

            RiskMeterBar(progress: meterProgress)

            Divider()

            HStack(spacing: 0) {
                heatStat(value: currentHeat,  label: "Текущее\nтепло",  color: riskLevel.color)
                Divider().frame(height: 46)
                heatStat(value: requiredHeat, label: "Нужно\nтепла",    color: .primary)
                Divider().frame(height: 46)
                heatStat(value: deviation,    label: "Разница",          color: riskLevel.color, sign: true)
            }
        }
        .skyKidCard()
    }

    @ViewBuilder
    private func heatStat(value: Double, label: String, color: Color, sign: Bool = false) -> some View {
        VStack(spacing: 3) {
            let prefix = sign && value > 0 ? "+" : ""
            Text("\(prefix)\(value, specifier: "%.1f")")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(color)
                .contentTransition(.numericText(countsDown: value < 0))
                .animation(.spring(response: 0.28), value: value)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – RiskMeterBar ────────────────────────────────────────────────────

struct RiskMeterBar: View {
    let progress: Double   // 0 = extreme cold · 0.5 = optimal · 1 = extreme heat

    private static let gradient = LinearGradient(
        colors: [.blue, Color(red: 0.3, green: 0.7, blue: 1), .green, .yellow, .orange, .red],
        startPoint: .leading, endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let p = max(0, min(1, progress))
                let D: CGFloat = 28
                let thumbX = (geo.size.width - D) * CGFloat(p)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Self.gradient)
                        .frame(height: 14)
                        .padding(.horizontal, D / 2)

                    Circle()
                        .fill(.white)
                        .frame(width: D, height: D)
                        .overlay(Circle().strokeBorder(thumbColor(p), lineWidth: 3))
                        .shadow(color: .black.opacity(0.14), radius: 3, x: 0, y: 2)
                        .offset(x: thumbX)
                        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: progress)
                }
            }
            .frame(height: 28)

            HStack {
                Label("Холодно", systemImage: "snowflake")
                Spacer()
                Text("Ок")
                Spacer()
                Label("Жарко", systemImage: "flame.fill")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func thumbColor(_ p: Double) -> Color {
        switch p {
        case ..<0.25:     return .blue
        case 0.25..<0.45: return Color(red: 0.3, green: 0.7, blue: 1)
        case 0.45..<0.55: return .green
        case 0.55..<0.75: return .orange
        default:          return .red
        }
    }
}

// MARK: – AlertCard ───────────────────────────────────────────────────────

struct AlertCard: View {
    let icon: String
    let color: Color
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(color)
                Text(message).font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.24), lineWidth: 1))
    }
}

// MARK: – AutoSelectButton ────────────────────────────────────────────────

struct AutoSelectButton: View {
    let tempLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Автоподбор одежды")
                        .font(.headline)
                    Text("Оптимально для \(tempLabel)")
                        .font(.caption)
                        .opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .opacity(0.6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.32, blue: 0.96),
                             Color(red: 0.44, green: 0.14, blue: 0.86)],
                    startPoint: .leading, endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

// MARK: – PediatricNoteCard ───────────────────────────────────────────────

struct PediatricNoteCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.title3)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.teal)
            VStack(alignment: .leading, spacing: 3) {
                Text("Совет педиатра")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
                Text("Холодные ручки и носик — это нормально. Проверяйте температуру по задней части шеи малыша.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: – ClothingConstructorSection ─────────────────────────────────────

// MARK: – PinnedItemsCard ─────────────────────────────────────────────────

struct PinnedItemsCard: View {
    @Bindable var model: WardrobeModel
    @State private var showEdit = false

    private var pinnedItems: [GarmentItem] {
        GarmentCatalog.all
            .filter { model.pinnedItemIDs.contains($0.id) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("Надевается всегда")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Изменить") { showEdit = true }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.purple)
            }

            if pinnedItems.isEmpty {
                Text("Нет закреплённых вещей")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(pinnedItems) { item in
                        HStack(spacing: 5) {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.purple)
                            Text(item.name)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.10), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.purple.opacity(0.22), lineWidth: 1))
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.purple.opacity(0.22), lineWidth: 1))
        .sheet(isPresented: $showEdit) {
            EditPinnedItemsSheet(model: model)
        }
    }
}

// MARK: – FlowLayout ──────────────────────────────────────────────────────

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0; var maxH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            rowH = max(rowH, sz.height); x += sz.width + spacing; maxH = max(maxH, y + rowH)
        }
        return CGSize(width: width, height: maxH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            rowH = max(rowH, sz.height); x += sz.width + spacing
        }
    }
}

// MARK: – EditPinnedItemsSheet ────────────────────────────────────────────

struct EditPinnedItemsSheet: View {
    @Bindable var model: WardrobeModel
    @Environment(\.dismiss) private var dismiss

    private var itemsByLayer: [(GarmentLayer, [GarmentItem])] {
        let relevant = GarmentCatalog.all.filter {
            $0.catalogAgeGroup == nil || $0.catalogAgeGroup?.matches(model.ageGroup) == true
        }.sorted { $0.name < $1.name }
        return GarmentLayer.allCases.compactMap { layer in
            let items = relevant.filter { $0.layer == layer }
            return items.isEmpty ? nil : (layer, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Выбранные вещи всегда включаются в расчёт и не снимаются при сбросе.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                ForEach(itemsByLayer, id: \.0) { layer, items in
                    Section(layer.rawValue) {
                        ForEach(items) { item in
                            let pinned = model.isPinned(item)
                            Button {
                                withAnimation {
                                    if pinned { model.unpin(item) } else { model.pin(item) }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.symbol)
                                        .frame(width: 26)
                                        .foregroundStyle(pinned ? .purple : .secondary)
                                    Text(item.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if pinned {
                                        Image(systemName: "pin.fill")
                                            .foregroundStyle(.purple)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Вещи по умолчанию")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}

// MARK: – ClothingConstructorSection ─────────────────────────────────────

struct ClothingConstructorSection: View {
    let ageGroup: WardrobeAgeGroup
    let selectedItems: Set<GarmentItem>
    var pinnedIDs: Set<String> = []
    let onToggle: (GarmentItem) -> Void

    var body: some View {
        let itemsByLayer = GarmentCatalog.displayItems(for: ageGroup)
        let allSelected = selectedItems.sorted { $0.name < $1.name }

        VStack(spacing: 12) {
            if !allSelected.isEmpty {
                autoSelectedSection(items: allSelected)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            ForEach(GarmentLayer.allCases) { layer in
                let items = itemsByLayer[layer] ?? []
                if !items.isEmpty {
                    layerSection(layer: layer, items: items)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: allSelected.map(\.id))
    }

    private func autoSelectedSection(items: [GarmentItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars").font(.caption)
                Text("Подобрано автоматически").font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(items.count) вещей")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1), in: Capsule())
            }
            .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    GarmentListRow(
                        item: item,
                        isSelected: true,
                        isPinned: pinnedIDs.contains(item.id),
                        isLast: idx == items.count - 1,
                        onTap: { onToggle(item) }
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.blue.opacity(0.22), lineWidth: 1))
    }

    private func layerSection(layer: GarmentLayer, items: [GarmentItem]) -> some View {
        let selCount = items.filter { selectedItems.contains($0) }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: layer.icon).font(.caption)
                Text(layer.rawValue).font(.subheadline.weight(.semibold))
                Spacer()
                if selCount > 0 {
                    Text("\(selCount) выбрано")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                }
            }
            .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    GarmentListRow(
                        item: item,
                        isSelected: selectedItems.contains(item),
                        isPinned: pinnedIDs.contains(item.id),
                        isLast: idx == items.count - 1,
                        onTap: { onToggle(item) }
                    )
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }
}

// MARK: – GarmentListRow ──────────────────────────────────────────────────

struct GarmentListRow: View {
    let item: GarmentItem
    let isSelected: Bool
    var isPinned: Bool = false
    let isLast: Bool
    let onTap: () -> Void

    @State private var isPreviewPresented = false

    private var effectiveColor: Color { isPinned ? .purple : .blue }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GarmentIconView(
                    item: item,
                    isSelected: isSelected,
                    accentColor: effectiveColor,
                    size: 40
                )
                .onLongPressGesture(minimumDuration: 0.45) {
                    isPreviewPresented = true
                }

                Button {
                    isPreviewPresented = true
                } label: {
                    Text(item.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? effectiveColor : .primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .center, spacing: 3) {
                    Button {
                        if !isPinned { onTap() }
                    } label: {
                        statusIcon
                    }
                    .buttonStyle(.plain)
                    .disabled(isPinned)

                    Text(String(format: "%.2g", item.tog))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .frame(width: 48)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(isSelected ? effectiveColor.opacity(0.04) : Color.clear)
            .sheet(isPresented: $isPreviewPresented) {
                GarmentIconPreviewSheet(item: item)
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isSelected)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: isPinned)

            if !isLast {
                Divider().padding(.leading, 66)
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isPinned {
            Image(systemName: "pin.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.purple)
                .frame(width: 28, height: 28)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        } else if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
        } else {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .frame(width: 28, height: 28)
        }
    }
}

// MARK: – TemperatureNoWalkCard ───────────────────────────────────────────

struct TemperatureNoWalkCard: View {
    let isHot: Bool
    let temperature: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: isHot ? "thermometer.sun.fill" : "snowflake.circle.fill")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(isHot ? .red : .blue)
                    .symbolEffect(.pulse)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isHot ? "Слишком жарко для прогулки" : "Слишком холодно для прогулки")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(isHot
                         ? "При \(Int(temperature.rounded()))° прогулка опасна для ребёнка."
                         : "При \(Int(temperature.rounded()))° высок риск переохлаждения.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text(isHot
                 ? "Если вышли вынужденно — лёгкое боди, тень, вода каждые 10 минут."
                 : "Если нужно выйти — максимальное утепление, не дольше 15 минут.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background((isHot ? Color.red : Color.blue).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder((isHot ? Color.red : Color.blue).opacity(0.25), lineWidth: 1))
    }
}

// MARK: – Previews ────────────────────────────────────────────────────────

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
