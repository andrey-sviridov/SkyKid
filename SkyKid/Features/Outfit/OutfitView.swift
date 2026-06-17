import SwiftUI

// MARK: - OutfitView

struct OutfitView: View {
    let weather: WeatherData
    var profile: ChildProfile?

    @State private var feedbackSent: UserFeedback? = nil

    // MARK: Engine integration (new TOG pipeline)

    private var recommendation: OutfitRecommendation? {
        guard let profile else { return nil }
        let gear = GearSetup.from(profile: profile)
        return OutfitRecommendationService.shared.recommend(weather: weather,
                                                            profile: profile,
                                                            gearSetup: gear)
    }

    // Adapter: maps OutfitRecommendation back to [LayeredOutfit.Layer] for existing UI
    private var displayLayers: [LayeredOutfit.Layer] {
        guard let rec = recommendation else { return [] }
        return rec.allDisplayLayers.map {
            LayeredOutfit.Layer(name: $0.name, systemImage: $0.systemImage, reason: $0.reason)
        }
    }

    private var effectiveTemp: Double {
        recommendation?.explanation.first(where: { $0.unit == "°C" })?.value
            ?? weather.apparentTemperature
    }

    // Synthesized LayeredOutfit for hero card and perception note
    private var syntheticOutfit: LayeredOutfit? {
        guard let profile else { return nil }
        return LayeredOutfit(
            effectiveTemp: effectiveTemp,
            baseLayer: displayLayers.first,
            midLayer: displayLayers.dropFirst().first,
            outerLayer: nil,
            accessories: []
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            if let profile, profile.strollerType.isSafetyAlarm,
               profile.ageGroup == .infant || profile.ageGroup == .baby {
                // Source: Алгоритм одевания младенца, стр. 5-6
                // Накрытая коляска → парниковый эффект + ребризинг CO₂ → риск СВСМ.
                // Алерт только для детей до 12 мес — СВСМ-риск специфичен для этого возраста.
                strollerSafetyAlertView(profile: profile)
            } else if let profile, let rec = recommendation,
                      let noWalkWarning = temperatureNoWalkWarning(in: rec) {
                noWalkScreen(rec: rec, profile: profile, warning: noWalkWarning)
            } else if let profile, let rec = recommendation, let outfit = syntheticOutfit {
                ScrollView {
                    VStack(spacing: 14) {
                        heroCard(outfit: outfit, profile: profile)
                        perceptionNote(profile: profile, outfit: outfit)
                        if !rec.warnings.filter({ $0.severity == .danger || $0.severity == .caution }).isEmpty {
                            safetyWarningsBanner(rec.warnings)
                        }
                        if let window = rec.walkWindow {
                            walkWindowCard(window)
                        }
                        conditionsBadges
                        layersSection(layers: displayLayers)
                        feedbackSection(profile: profile, tMicro: rec.explanation.first(where: { $0.unit == "°C" && $0.label.contains("§3") })?.value ?? weather.apparentTemperature)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            } else {
                ContentUnavailableView(
                    "Создайте профиль ребёнка",
                    systemImage: "person.badge.plus",
                    description: Text("Профиль поможет рассчитать одежду точнее")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .skyKidBackground()
        .navigationBarTitleDisplayMode(.inline)
        .task(id: weather) {
            // P2-3: уведомления синхронизируются раз на обновление погоды,
            // не в computed property (он вызывается каждый рендер)
            guard let profile, let rec = recommendation else { return }
            await NotificationService.shared.sync(
                recommendation: rec,
                gearSetup: GearSetup.from(profile: profile)
            )
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    Image(systemName: "hanger")
                        .font(.subheadline.weight(.semibold))
                    Text(profile.map { "Гардероб · \($0.name)" } ?? "Что надеть")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Stroller safety alert

    private func strollerSafetyAlertView(profile: ChildProfile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse)
                        .padding(.top, 32)
                    Text("ОПАСНО")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.red)
                    Text("Накрытая коляска опасна для жизни")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    strollerAlertRow(icon: "thermometer.sun.fill",
                                     text: "Температура внутри накрытой коляски достигает критического уровня за 30 минут")
                    strollerAlertRow(icon: "lungs.fill",
                                     text: "Плотная накидка блокирует воздух — накапливается CO₂, угнетается дыхание")
                    strollerAlertRow(icon: "heart.slash.fill",
                                     text: "Прямой риск синдрома внезапной смерти младенца (СВСМ)")
                }
                .padding(18)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.red.opacity(0.4), lineWidth: 1))

                Text("Снимите накидку прямо сейчас. Для защиты от солнца используйте только сетчатый тент с вентиляцией.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
    }

    private func strollerAlertRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.red)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Temperature no-walk screen

    private func temperatureNoWalkWarning(in rec: OutfitRecommendation) -> SafetyWarning? {
        rec.warnings.first {
            $0.code == .noWalkRecommended && $0.severity == .danger &&
            ($0.systemImage == "sun.max.trianglebadge.exclamationmark" ||
             $0.systemImage == "snowflake.circle.fill")
        }
    }

    private func noWalkScreen(rec: OutfitRecommendation, profile: ChildProfile, warning: SafetyWarning) -> some View {
        let isHot = warning.systemImage == "sun.max.trianglebadge.exclamationmark"
        let accent: Color = isHot ? .red : .blue
        let tip = isHot
            ? "Если вышли вынужденно — лёгкое боди, тень, вода каждые 10 минут."
            : "Если нужно выйти — максимальное утепление, не дольше 15 минут, закройте кожу."

        return ScrollView {
            VStack(spacing: 20) {
                // Icon + temperature
                VStack(spacing: 10) {
                    Image(systemName: warning.systemImage)
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(accent)
                        .symbolEffect(.pulse)
                        .padding(.top, 36)

                    Text("\(Int(weather.apparentTemperature.rounded()))°")
                        .font(.system(size: 64, weight: .thin, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("Прогулка не рекомендуется")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(warning.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // Next safe walk window
                if let window = rec.walkWindow {
                    walkWindowCard(window)
                }

                // Force-majeure tip
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(accent.opacity(0.25), lineWidth: 1))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Hero card

    private func heroCard(outfit: LayeredOutfit, profile: ChildProfile) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: weather.conditionIcon)
                    .font(.system(size: 56))
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.bounce, value: weather.weatherCode)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 5)

                Spacer()

                VStack(spacing: 1) {
                    Text("\(Int(outfit.effectiveTemp.rounded()))°")
                        .font(.system(size: 54, weight: .thin, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: outfit.effectiveTemp)
                    Text("для \(profile.ageLabel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(outfitTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("На улице \(Int(weather.temperature.rounded()))° · ощущается \(Int(weather.apparentTemperature.rounded()))°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let delta = Int((outfit.effectiveTemp - weather.apparentTemperature).rounded())
                    if delta != 0 {
                        Text("С учётом профиля: \(delta > 0 ? "+" : "")\(delta)°")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: outfitIcon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Perception note

    private func perceptionNote(profile: ChildProfile, outfit: LayeredOutfit) -> some View {
        // Используем effectiveTemp из рекомендации — одна формула с расчётом одежды
        let p = ChildWeatherPerception(profile: profile, weather: weather, effectiveTemp: outfit.effectiveTemp)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: p.moodSystemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: p.moodColor.0, green: p.moodColor.1, blue: p.moodColor.2))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 6) {
                Text(p.summary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(p.ageContextNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.10), lineWidth: 1))
    }

    // MARK: - Walk window card (P1-3)

    private func walkWindowCard(_ window: DateInterval) -> some View {
        let fmt = Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute()
        let isTomorrow = !Calendar.current.isDateInToday(window.start)
        let prefix = isTomorrow ? "завтра " : ""
        return HStack(spacing: 12) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 24)
            Text("Лучшее время для прогулки: \(prefix)\(window.start.formatted(fmt))–\(window.end.formatted(fmt))")
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.green.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Condition badges

    @ViewBuilder
    private var conditionsBadges: some View {
        let hasWind = weather.windSpeed > 7
        let hasSnow = (71...77).contains(weather.weatherCode)
        let hasRain = !hasSnow && ((51...82).contains(weather.weatherCode) || weather.precipitation > 0.1)

        if hasWind || hasRain || hasSnow {
            HStack(spacing: 8) {
                if hasWind {
                    conditionChip(icon: "wind", label: "\(Int(weather.windSpeed.rounded())) м/с", color: .cyan)
                }
                if hasSnow {
                    conditionChip(icon: "snowflake", label: "Снег", color: .blue)
                } else if hasRain {
                    conditionChip(icon: "cloud.rain.fill", label: "Дождь", color: .indigo)
                }
                Spacer()
            }
        }
    }

    private func conditionChip(icon: String, label: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Safety warnings banner

    @ViewBuilder
    private func safetyWarningsBanner(_ warnings: [SafetyWarning]) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(warnings.filter { $0.severity == .danger || $0.severity == .caution }.prefix(3).enumerated()), id: \.offset) { _, warning in
                HStack(spacing: 12) {
                    Image(systemName: warning.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(warning.severity == .danger ? .red : .orange)
                        .frame(width: 24)
                    Text(warning.message)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder((warning.severity == .danger ? Color.red : Color.orange).opacity(0.4), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Layers section

    @ViewBuilder
    private func layersSection(layers: [LayeredOutfit.Layer]) -> some View {
        if layers.isEmpty {
            Text("Лёгкое и удобное — больше ничего не нужно")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 16)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Label("Что надеть", systemImage: "hanger")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(layers.count) \(itemsWord(layers.count))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(layers.enumerated()), id: \.element.id) { idx, layer in
                        layerRow(layer: layer, index: idx, isLast: idx == layers.count - 1)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal:   .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: layers.map(\.name))
            }
        }
    }


    private func layerRow(layer: LayeredOutfit.Layer, index: Int, isLast: Bool) -> some View {
        let isFirst = index == 0
        let radius: (CGFloat, CGFloat) = (isFirst ? 18 : 6, isLast ? 18 : 6)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(rowAccent(index).opacity(0.22))
                    .frame(width: 44, height: 44)
                Image(systemName: layer.systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(rowAccent(index))
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(layer.name)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(layer.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "checkmark")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.regularMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius:     radius.0,
                bottomLeadingRadius:  radius.1,
                bottomTrailingRadius: radius.1,
                topTrailingRadius:    radius.0
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius:     radius.0,
                bottomLeadingRadius:  radius.1,
                bottomTrailingRadius: radius.1,
                topTrailingRadius:    radius.0
            )
            .strokeBorder(.primary.opacity(0.10), lineWidth: 1)
        )
        .padding(.vertical, 0.5)
    }

    // MARK: - Feedback section

    private func feedbackSection(profile: ChildProfile, tMicro: Double) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label("Оцените одежду", systemImage: "hand.thumbsup")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)

            ZStack {
                if let sent = feedbackSent {
                    confirmationBanner(feedback: sent)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                } else {
                    feedbackButtons(profile: profile, tMicro: tMicro)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: feedbackSent == nil)
        }
    }

    private func feedbackButtons(profile: ChildProfile, tMicro: Double) -> some View {
        HStack(spacing: 8) {
            feedbackButton(label: "Холодно", icon: "thermometer.snowflake", color: .blue) {
                BiasStore.shared.record(.tooCold, for: profile, feelsLike: weather.apparentTemperature)
                PersonalOffsetStore.shared.record(.tooCold, for: profile, tMicro: tMicro)
                triggerFeedback(.tooCold)
            }
            feedbackButton(label: "Комфортно", icon: "checkmark.circle", color: .green) {
                PersonalOffsetStore.shared.record(.comfortable, for: profile, tMicro: tMicro)
                triggerFeedback(.comfortable)
            }
            feedbackButton(label: "Жарко", icon: "thermometer.sun", color: .red) {
                BiasStore.shared.record(.tooWarm, for: profile, feelsLike: weather.apparentTemperature)
                PersonalOffsetStore.shared.record(.tooWarm, for: profile, tMicro: tMicro)
                triggerFeedback(.tooWarm)
            }
        }
    }

    private func feedbackButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(color.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func confirmationBanner(feedback: UserFeedback) -> some View {
        Label("Учту на следующей прогулке", systemImage: "brain.headset")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(feedbackAccent(feedback))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(feedbackAccent(feedback).opacity(0.30), lineWidth: 1)
            )
    }

    private func triggerFeedback(_ feedback: UserFeedback) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            feedbackSent = feedback
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                feedbackSent = nil
            }
        }
    }

    private func feedbackAccent(_ feedback: UserFeedback) -> Color {
        switch feedback {
        case .tooCold:     return .blue
        case .comfortable: return .green
        case .tooWarm:     return .red
        }
    }

    // MARK: - Helpers

    private var outfitIcon: String {
        switch effectiveTemp {
        case ..<(-10): return "thermometer.snowflake.circle.fill"
        case -10..<0:  return "snowflake"
        case 0..<10:   return "cloud.snow.fill"
        case 10..<18:  return "cloud.sun.fill"
        default:       return "sun.max.fill"
        }
    }

    private var outfitTitle: String {
        switch effectiveTemp {
        case ..<0:    return "Одеваемся тепло!"
        case 0..<10:  return "Не забудьте куртку"
        case 10..<18: return "Лёгкий слой"
        default:      return "Легко и комфортно"
        }
    }

    private func rowAccent(_ index: Int) -> Color {
        let palette: [Color] = [.blue, .teal, .green, .orange, .purple, .pink, .indigo, .cyan]
        return palette[index % palette.count]
    }

    private func itemsWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod100 >= 11 && mod100 <= 19 { return "вещей" }
        switch mod10 {
        case 1: return "вещь"
        case 2, 3, 4: return "вещи"
        default: return "вещей"
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("🧥 Весна · 2 года") {
    NavigationStack {
        OutfitView(weather: .mock, profile: .mock)
    }
}

#Preview("❄️ Зима · 4 мес") {
    NavigationStack {
        OutfitView(weather: .mockWinter, profile: .mockInfant)
    }
}

#Preview("Нет профиля") {
    NavigationStack {
        OutfitView(weather: .mock)
    }
}
#endif
