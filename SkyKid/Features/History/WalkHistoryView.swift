import SwiftUI

// MARK: - WalkHistoryView (History tab)

struct WalkHistoryView: View {
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    var recommendation: OutfitRecommendation? = nil
    var walkContext: WalkContext? = nil
    var onPersonalizationChange: () -> Void = {}

    @Environment(WalkLogStore.self) private var store
    @Environment(PersonalOffsetStore.self) private var personalizationStore
    @State private var showLog = false
    @State private var editingLog: WalkLog? = nil
    @State private var selectedLog: WalkLog? = nil
    @State private var pendingDeletionIDs: Set<UUID> = []

    private var personalizationSummary: PersonalizationSummary? {
        guard let profile, let recommendation, let walkContext else { return nil }
        return personalizationStore.summary(
            for: profile,
            context: .recommendation(recommendation, walkContext: walkContext)
        )
    }

    private var insights: WalkHistoryInsights {
        WalkHistoryInsights.learning(from: personalizationSummary)
    }

    private var feedbackItems: [FeedbackHistoryItem] {
        guard let profile else { return [] }
        return FeedbackHistoryItemBuilder.make(
            from: personalizationStore.feedbackHistory(for: profile)
        )
    }

    private var visibleLogs: [WalkLog] {
        store.logs.filter { !pendingDeletionIDs.contains($0.id) }
    }

    var body: some View {
        List {
            ThermalLearningCard(insights: insights)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 6, trailing: 16))

            if !feedbackItems.isEmpty {
                FeedbackHistorySection(items: feedbackItems)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }

            if visibleLogs.isEmpty {
                EmptyHistoryCard()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
            } else {
                ForEach(visibleLogs) { log in
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
                            delete(log)
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

    private func delete(_ log: WalkLog) {
        withAnimation { _ = pendingDeletionIDs.insert(log.id) }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            store.delete(id: log.id)
            pendingDeletionIDs.remove(log.id)
            onPersonalizationChange()
        }
    }

}

// MARK: - Previews

#if DEBUG
#Preview("История") {
    NavigationStack {
        WalkHistoryView(weather: .mock, profile: .mock)
            .environment(WalkLogStore.shared)
            .environment(PersonalOffsetStore.shared)
    }
}
#endif
