import SwiftUI

// MARK: - LiveWalkDetailView

/// Прогулка второго родителя — только для просмотра.
///
/// Собран из тех же блоков, что и `ActiveWalkView`, но с `isEditable: false`:
/// менять чужую запись нельзя, а расходиться два экрана прогулки не должны.
struct LiveWalkDetailView: View {
    let snapshot: LiveWalkSnapshot
    var weather: NormalizedWeather?
    var profile: ChildProfile?
    /// Смотреть чужую прогулку — не повод не пойти гулять самому.
    var onStartOwnWalk: () -> Void = {}

    @Environment(LiveWalkObserver.self) private var observer

    private var walk: ActiveWalk { snapshot.walk }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                WalkTimerHeaderCard(
                    walk: walk,
                    weather: weather,
                    ownerName: observer.partnerName
                )

                WalkOutfitChipsCard(
                    selectedIDs: .constant(walk.outfitItemIDs),
                    profile: profile,
                    targetTOG: walk.targetTOG,
                    isEditable: false
                )

                WalkTimelineCard(
                    events: walk.events,
                    startDate: walk.startDate,
                    isEditable: false
                )

                LiveWalkStatusFooter(
                    ownerName: observer.partnerName,
                    updatedAt: snapshot.updatedAt,
                    isConnected: observer.isConnected
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .skyKidBackground()
        .navigationTitle("Прогулка второго родителя")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            startOwnWalkButton
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        // Пока экран открыт, уведомлять о новых отметках незачем — они
        // приезжают прямо в таймлайн под носом у пользователя.
        .onAppear { observer.isViewingLiveWalk = true }
        .onDisappear { observer.isViewingLiveWalk = false }
    }

    private var startOwnWalkButton: some View {
        Button(action: onStartOwnWalk) {
            Label("Начать свою прогулку", systemImage: "figure.walk")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.24, green: 0.35, blue: 0.92),
                                 Color(red: 0.55, green: 0.27, blue: 0.90)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }
        .buttonStyle(.plain)
    }
}
