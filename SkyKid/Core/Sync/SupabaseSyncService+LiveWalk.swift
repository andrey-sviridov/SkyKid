import Foundation
import Supabase

// MARK: - Идущая прогулка на сервере

/// Серверное отражение идущей прогулки: слот `live_walks`, по одному на
/// каждого родителя семьи (см. миграцию `2026-08-17-live-walks.sql`).
///
/// Как и весь остальной синк — best-effort: ошибки глотаются, недоступность
/// сервера не должна ломать саму прогулку на устройстве.
extension SupabaseSyncService {

    /// Кладёт текущее состояние прогулки в свой слот. Идемпотентно.
    func upsertLiveWalk(_ walk: ActiveWalk) async {
        guard let context = syncContext else { return }

        let lastEvent = walk.events.max { $0.timestamp < $1.timestamp }
        let row = LiveWalkUpsert(
            familyID: context.familyID,
            userID: context.userID,
            walkID: walk.id,
            startedAt: walk.startDate,
            plannedDurationMinutes: walk.plannedDurationMinutes,
            eventCount: walk.events.count,
            lastEventKind: lastEvent?.kind.rawValue,
            lastEventAt: lastEvent?.timestamp,
            payload: walk
        )

        try? await client
            .from("live_walks")
            .upsert(row, onConflict: "family_id,user_id")
            .execute()
    }

    /// Убирает свой слот — прогулка завершена или отменена.
    func deleteLiveWalk() async {
        guard let context = syncContext else { return }

        try? await client
            .from("live_walks")
            .delete()
            .eq("family_id", value: context.familyID)
            .eq("user_id", value: context.userID)
            .execute()
    }

    /// Полный список живых прогулок семьи — включая свою.
    ///
    /// Нужен на старте подписки и как fallback, когда Realtime не поднялся:
    /// состояние обязано быть верным даже без сокета. Отсев своей строки —
    /// не здесь, а в `LiveWalkObserver`: сервис не решает, что показывать.
    func pullLiveWalks() async -> [LiveWalkSnapshot] {
        guard let familyID = SupabaseAuthService.shared.familyID else { return [] }

        do {
            let rows: [LiveWalkRow] = try await client
                .from("live_walks")
                .select()
                .eq("family_id", value: familyID)
                .execute()
                .value
            return rows.map(\.snapshot)
        } catch {
            return []
        }
    }
}

// MARK: - Row mapping

/// Что уезжает на сервер. `updated_at` не шлём — его ставит триггер,
/// потому что часам устройства доверять нельзя.
private struct LiveWalkUpsert: Encodable {
    let familyID: UUID
    let userID: UUID
    let walkID: UUID
    let startedAt: Date
    let plannedDurationMinutes: Int?
    let eventCount: Int
    let lastEventKind: String?
    let lastEventAt: Date?
    let payload: ActiveWalk

    enum CodingKeys: String, CodingKey {
        case familyID = "family_id"
        case userID = "user_id"
        case walkID = "walk_id"
        case startedAt = "started_at"
        case plannedDurationMinutes = "planned_duration_minutes"
        case eventCount = "event_count"
        case lastEventKind = "last_event_kind"
        case lastEventAt = "last_event_at"
        case payload
    }
}

/// Что приезжает обратно.
///
/// `payload` разбирается тем же кодеком supabase-swift, что и всё
/// остальное (`JSONDecoder.supabase()`), и он же используется в Realtime
/// (`AnyJSON.decoder`) — поэтому даты в прогулке едут одинаково обоими
/// путями. Смешивать его с «голым» `JSONDecoder`, которым пишется App
/// Group, нельзя: `startDate` разъедется.
struct LiveWalkRow: Decodable {
    let userID: UUID
    let payload: ActiveWalk
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case payload
        case updatedAt = "updated_at"
    }

    var snapshot: LiveWalkSnapshot {
        LiveWalkSnapshot(walk: payload, ownerUserID: userID, updatedAt: updatedAt)
    }
}
