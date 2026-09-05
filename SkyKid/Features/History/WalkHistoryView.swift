import SwiftUI

// MARK: - WalkHistoryView (History tab)

struct WalkHistoryView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var recommendation: OutfitRecommendation? = nil
    var walkContext: WalkContext? = nil
    var onPersonalizationChange: () -> Void = {}

    @Environment(WalkLogStore.self) private var store
    @State private var showLog = false
    @State private var editingLog: WalkLog? = nil
    @State private var selectedLog: WalkLog? = nil

    private var insights: WalkHistoryInsights? {
        WalkHistoryInsights.make(from: store.logs)
    }

    var body: some View {
        List {
            if let insights {
                WalkHistoryInsightsCard(insights: insights)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))
            }

            if store.logs.isEmpty {
                EmptyHistoryCard()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: insights == nil ? 12 : 6, leading: 16, bottom: 0, trailing: 16))
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
        .navigationDestination(item: $selectedLog) { log in
            WalkLogDetailView(
                log: log,
                store: store,
                profile: profile,
                onChanged: onPersonalizationChange
            )
        }
        .navigationTitle("Журнал прогулок")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showLog = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.text("Записать прогулку"))
            }
        }
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

}

// MARK: - Previews

#if DEBUG
#Preview("История") {
    NavigationStack {
        WalkHistoryView(weather: .mock, profile: .mock)
            .environment(WalkLogStore.shared)
    }
}
#endif
