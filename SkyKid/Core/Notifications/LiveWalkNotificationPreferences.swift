import Foundation

// MARK: - LiveWalkNotificationPreferences

struct LiveWalkNotificationPreferences {
    static let key = "live_walk_notify_v1"

    static var isEnabled: Bool {
        get { AppGroup.defaults.bool(forKey: key) }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }
}
