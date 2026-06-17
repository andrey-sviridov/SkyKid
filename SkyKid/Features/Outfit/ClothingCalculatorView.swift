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
    var weather: WeatherData?          // feelsLike used as initial temperature
    @State private var model: WardrobeModel

    init(profile: ChildProfile? = nil, weather: WeatherData? = nil) {
        self.profile = profile
        self.weather = weather
        _model = State(initialValue: WardrobeModel(
            temperature: weather?.apparentTemperature ?? 12.0,
            ageGroup:    profile?.wardrobeAgeGroup ?? .earlyInfant
        ))
    }

    var body: some View {
        ScrollView {
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

                    // ⚡ PERF: selectedItems — value type, не изменяется при сдвиге слайдера
                    ClothingConstructorSection(
                        selectedItems: model.selectedItems,
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
        }
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
            guard let t = newTemp else { return }
            model.weatherTemperature = t
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
// ⚡ PERF: `selectedItems` — value type (Set<GarmentItem>).
// SwiftUI сравнивает через Equatable; при сдвиге слайдера body не вычисляется.

struct ClothingConstructorSection: View {
    let selectedItems: Set<GarmentItem>
    let onToggle: (GarmentItem) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(GarmentLayer.allCases) { layer in
                let items = GarmentCatalog.byLayer[layer] ?? []
                let selCount = items.filter { selectedItems.contains($0) }.count

                VStack(alignment: .leading, spacing: 10) {
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

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(items) { item in
                            GarmentCard(
                                item: item,
                                isSelected: selectedItems.contains(item),
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
    }
}

// MARK: – GarmentCard ─────────────────────────────────────────────────────
// ⚡ PERF: только `isSelected: Bool` и `item: GarmentItem` (value types).

struct GarmentCard: View {
    let item: GarmentItem
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.13) : Color.primary.opacity(0.08))
                        .frame(width: 54, height: 54)

                    Image(systemName: item.symbol)
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                        .frame(width: 54, height: 54)

                    if isSelected {
                        Circle()
                            .fill(.blue)
                            .frame(width: 19, height: 19)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 4, y: -4)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }

                Text(item.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .blue : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(String(format: "%.2g TOG", item.tog))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                isSelected ? Color.blue.opacity(0.07) : Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.0 : 0.97)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.68), value: isSelected)
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
