import Foundation

// SRP: хранилище профиля вынесено из доменной модели ChildProfile.
// Класс — singleton, используется только в основном таргете (не в виджете).

@Observable
final class ChildProfileStore: @unchecked Sendable {
    static let shared = ChildProfileStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    var profile: ChildProfile? {
        get {
            guard let data = defaults.data(forKey: AppGroup.profileKey) else { return nil }
            return try? JSONDecoder().decode(ChildProfile.self, from: data)
        }
        set {
            if let newValue {
                // Callers editing a profile retain its UUID in the value they
                // submit. A genuinely new profile must keep its own identity.
                if let data = try? JSONEncoder().encode(newValue) {
                    defaults.set(data, forKey: AppGroup.profileKey)
                }
            } else {
                defaults.removeObject(forKey: AppGroup.profileKey)
            }
        }
    }

    func replaceForRestore(with profile: ChildProfile?) {
        guard let profile else {
            defaults.removeObject(forKey: AppGroup.profileKey)
            return
        }
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: AppGroup.profileKey)
    }
}
