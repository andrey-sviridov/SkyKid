import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    let onStartupReady: @MainActor () -> Void

    @State private var composition = AppComposition()

    var body: some View {
        RootFlow(composition: composition, onStartupReady: onStartupReady)
    }
}
