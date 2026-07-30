import Foundation

enum WalkDurationFormatter {
    static func string(minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = minutes >= 60 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.dropLeading, .dropTrailing]

        return formatter.string(from: TimeInterval(minutes * 60))
            ?? L10n.format("%lld мин", minutes)
    }
}
