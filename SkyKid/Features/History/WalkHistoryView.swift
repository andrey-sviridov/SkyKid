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
    private var tabBarHeight: CGFloat { SkyKidTabBarMetrics.totalHeight }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List {
                if store.totalCount > 0 {
                    StatsHeaderCard(store: store)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
                }

                if !feedbackHistoryItems.isEmpty {
                    FeedbackHistorySection(items: feedbackHistoryItems)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                }

                if store.logs.isEmpty {
                    EmptyHistoryCard()
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 0, trailing: 16))
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
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: tabBarHeight + 80) }
            .navigationDestination(item: $selectedLog) { log in
                WalkLogDetailView(
                    log: log,
                    store: store,
                    profile: profile,
                    onChanged: onPersonalizationChange
                )
            }

            Button { showLog = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.08, green: 0.32, blue: 0.96),
                                     Color(red: 0.44, green: 0.14, blue: 0.86)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .shadow(color: .blue.opacity(0.35), radius: 10, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, tabBarHeight + 24)
        }
        .navigationTitle("Журнал прогулок")
        .navigationBarTitleDisplayMode(.large)
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

    // MARK: - Feedback history

    private var feedbackHistoryItems: [FeedbackHistoryItem] {
        guard let profile else { return [] }
        let observations = personalizationStore.feedbackHistory(
            for: profile.thermalProfile
        )
        return FeedbackHistoryItemBuilder.make(from: observations)
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
