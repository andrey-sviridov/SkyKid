import Foundation

// MARK: - AgeSafetyPolicy

/// Selects conservative outdoor exposure limits from corrected age.
/// It does not diagnose illness or inspect current weather.
enum AgeSafetyPolicy {

    // MARK: - Supported product scope

    /// The externally reviewed v1 scope is birth through the first birthday.
    /// The boundary is calendar-based: a child is supported on the day they
    /// turn 12 months and becomes out of scope on the following day.
    static let maximumSupportedAgeMonths = ChildThermalProfile.maximumSupportedAgeMonths
    typealias SupportedAgeScope = SupportedChildAgeScope

    static func scope(
        for profile: ChildThermalProfile,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SupportedAgeScope {
        scope(for: profile.birthday, now: now, calendar: calendar)
    }

    static func scope(
        for birthday: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SupportedAgeScope {
        ChildThermalProfile.supportedAgeScope(
            for: birthday,
            now: now,
            calendar: calendar
        )
    }

    static func isSupported(
        _ profile: ChildThermalProfile,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        scope(for: profile, now: now, calendar: calendar).isSupported
    }

    /// Date range for new profiles. It includes the whole current calendar
    /// day so a date-only picker cannot accidentally reject today's birthday.
    static func supportedBirthdayRange(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: now)
        let oldest = calendar.date(
            byAdding: .month,
            value: -maximumSupportedAgeMonths,
            to: today
        ) ?? today
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: today)?
            .addingTimeInterval(-1)
            ?? now
        return oldest...endOfToday
    }

    /// Keeps a legacy out-of-scope date visible while editing so loading an
    /// old profile never mutates its data. Saving still rejects that date.
    static func birthdayPickerRange(
        existingBirthday: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ClosedRange<Date> {
        let supportedRange = supportedBirthdayRange(now: now, calendar: calendar)
        guard let existingBirthday,
              !scope(for: existingBirthday, now: now, calendar: calendar).isSupported
        else {
            return supportedRange
        }

        let legacyDate = calendar.startOfDay(for: existingBirthday)
        return min(legacyDate, supportedRange.lowerBound)...supportedRange.upperBound
    }

    // MARK: - Exposure limits

    static func limits(for profile: ChildThermalProfile) -> OutdoorSafetyLimits {
        let correctedAgeWeeks = profile.correctedAgeWeeks

        for entry in OutfitConfig.Safety.noWalkThresholds
            where correctedAgeWeeks <= entry.maxCorrWeeks {
            return OutdoorSafetyLimits(
                coldBelow: entry.coldBelow,
                hotAbove: entry.hotAbove,
                usesAdditionalMedicalCaution: false
            )
        }

        let fallback = OutfitConfig.Safety.noWalkThresholds.last
        return OutdoorSafetyLimits(
            coldBelow: fallback?.coldBelow ?? -15,
            hotAbove: fallback?.hotAbove ?? 33,
            usesAdditionalMedicalCaution: false
        )
    }
}
