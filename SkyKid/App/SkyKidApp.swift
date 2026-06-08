import SwiftUI
import AppIntents

@main
struct SkyKidApp: App {

    init() {
        if #available(iOS 17, *) {
            SkyKidShortcuts.updateAppShortcutParameters()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
