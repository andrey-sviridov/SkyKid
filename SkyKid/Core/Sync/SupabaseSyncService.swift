import Foundation
import Supabase

/// Синхронизация `ChildProfile` + `WalkLog` с Supabase.
///
/// Все методы — best-effort: ошибки сети/шифрования проглатываются внутри
/// (как уже делает `NotificationService` через `try?`) — недоступность
/// сервера не должна ломать локальную работу приложения.
@MainActor
final class SupabaseSyncService {
    static let shared = SupabaseSyncService()

    private init() {}

    private var client: SupabaseClient { SupabaseClientProvider.client }

    /// Выгрузка разрешена только когда локальные данные уже привязаны к
    /// текущему аккаунту. Данные, созданные в автономном режиме, не должны
    /// улетать на сервер молча — сначала пользователь соглашается на перенос
    /// в `AccountCard`, и только потом появляется привязка.
    /// Чтение (`pull*`) этим не ограничено — оно безопасно и нужно как раз
    /// для первичной гидратации нового устройства.
    ///
    /// `familyID` обязателен: строки принадлежат семье, а `userID` остаётся
    /// лишь отметкой, кто из родителей сохранил запись последним.
    private var syncContext: (familyID: UUID, userID: UUID)? {
        let auth = SupabaseAuthService.shared
        guard auth.isLocalDataLinkedToCurrentAccount,
              let userID = auth.userID,
              let familyID = auth.familyID
        else { return nil }
        return (familyID, userID)
    }

    // MARK: - Семья

    /// Возвращает семью текущего пользователя, создавая её при первом входе.
    /// Одна строка на обоих родителей — см. `ensure_family()` в миграции.
    @discardableResult
    func ensureFamily() async throws -> UUID {
        let familyID: UUID = try await client.rpc("ensure_family").execute().value
        SupabaseAuthService.shared.setFamilyID(familyID)
        return familyID
    }

    /// Одноразовый код для второго родителя. Ключ шифрования имени ребёнка
    /// вшивается в код на устройстве и на сервер не попадает.
    func createFamilyInvite() async throws -> String {
        guard let context = syncContext else { throw FamilyError.notReady }
        let inserted: FamilyInviteRow = try await client
            .from("family_invites")
            .insert(FamilyInviteInsert(familyID: context.familyID, createdBy: context.userID))
            .select()
            .single()
            .execute()
            .value
        return FamilyInviteCode.make(
            inviteID: inserted.id,
            keyBase64: try ChildNameCipher.exportKeyBase64()
        )
    }

    /// Присоединение по коду: сервер переводит пользователя в семью
    /// приглашающего, а ключ из кода делает читаемым имя ребёнка.
    @discardableResult
    func redeemFamilyInvite(code: String) async throws -> UUID {
        let payload = try FamilyInviteCode.parse(code)
        let familyID: UUID = try await client
            .rpc("redeem_family_invite", params: RedeemInviteParams(inviteID: payload.inviteID))
            .execute()
            .value
        try ChildNameCipher.importKey(base64: payload.keyBase64)
        SupabaseAuthService.shared.setFamilyID(familyID)
        return familyID
    }

    /// Присоединение по коду вместе с подтягиванием данных семьи.
    ///
    /// Возвращает профиль ребёнка, если он в семье уже заведён. `nil` — это
    /// не ошибка: приглашающий мог позвать второго родителя раньше, чем
    /// создал профиль, и тогда его создаст любой из них — запись всё равно
    /// окажется общей.
    @discardableResult
    func joinFamilyAndPullData(code: String) async throws -> ChildProfile? {
        try await redeemFamilyInvite(code: code)

        // Данные семьи теперь наши: снимаем гейт выгрузки, иначе всё, что
        // второй родитель добавит дальше, останется только на устройстве.
        SupabaseAuthService.shared.linkLocalDataToCurrentAccount()

        let profile = await pullProfile()
        if let profile {
            ChildProfileStore.shared.profile = profile
        }

        let remoteLogs = await pullAllWalkLogs()
        let knownIDs = Set(WalkLogStore.shared.logs.map(\.id))
        for log in remoteLogs.reversed() where !knownIDs.contains(log.id) {
            WalkLogStore.shared.add(log, profile: profile)
        }
        return profile
    }

    /// Сколько родителей сейчас в семье — по этому числу карточка решает,
    /// показывать приглашение или отметку «второй родитель подключён».
    func familyMemberCount() async -> Int {
        guard let familyID = SupabaseAuthService.shared.familyID else { return 0 }
        do {
            let rows: [FamilyMemberRow] = try await client
                .from("family_members")
                .select()
                .eq("family_id", value: familyID)
                .execute()
                .value
            return rows.count
        } catch {
            return 0
        }
    }

    enum FamilyError: Error {
        case notReady
    }

    // MARK: - ChildProfile

    func pushProfile(_ profile: ChildProfile) async {
        guard let context = syncContext else { return }
        try? await upsertProfile(profile, context: context)
    }

    private func upsertProfile(
        _ profile: ChildProfile,
        context: (familyID: UUID, userID: UUID)
    ) async throws {
        let encryptedName = try ChildNameCipher.encrypt(profile.name)
        let row = ChildProfileRow(
            familyID: context.familyID,
            userID: context.userID,
            encryptedName: encryptedName,
            gender: profile.gender.rawValue,
            birthday: BirthdayFormat.string(from: profile.birthday),
            gestationalAgeWeeks: profile.gestationalAgeWeeks,
            stableTraits: profile.stableTraits.map(\.rawValue),
            temperaturePreferenceOffset: profile.temperaturePreferenceOffset,
            schemaVersion: ChildProfile.currentSchemaVersion
        )
        try await client.from("child_profiles").upsert(row).execute()
    }

    func pullProfile() async -> ChildProfile? {
        guard let familyID = SupabaseAuthService.shared.familyID else { return nil }
        do {
            let row: ChildProfileRow = try await client
                .from("child_profiles")
                .select()
                .eq("family_id", value: familyID)
                .single()
                .execute()
                .value
            let name = try ChildNameCipher.decrypt(row.encryptedName)

            var profile = ChildProfile(
                name: name,
                gender: ChildGender(rawValue: row.gender) ?? .boy,
                birthday: try BirthdayFormat.date(from: row.birthday)
            )
            profile.temperaturePreferenceOffset = row.temperaturePreferenceOffset
            profile.stableTraits = Set(row.stableTraits.compactMap(StableThermalTrait.init(rawValue:)))
            profile.gestationalAgeWeeks = row.gestationalAgeWeeks
            return profile
        } catch {
            return nil
        }
    }

    // MARK: - WalkLog

    func pushWalkLog(_ log: WalkLog) async {
        guard let context = syncContext else { return }
        try? await upsertWalkLog(log, context: context)
    }

    private func upsertWalkLog(
        _ log: WalkLog,
        context: (familyID: UUID, userID: UUID)
    ) async throws {
        let row = WalkLogRemoteRow(log: log, familyID: context.familyID, userID: context.userID)
        try await client.from("walk_logs").upsert(row).execute()
    }

    func deleteWalkLogRemote(id: UUID) async {
        guard syncContext != nil else { return }
        do {
            try await client.from("walk_logs").delete().eq("id", value: id).execute()
        } catch {
            // best-effort
        }
    }

    func pullAllWalkLogs() async -> [WalkLog] {
        guard let familyID = SupabaseAuthService.shared.familyID else { return [] }
        do {
            let rows: [WalkLogRemoteRow] = try await client
                .from("walk_logs")
                .select()
                .eq("family_id", value: familyID)
                .order("date", ascending: false)
                .execute()
                .value
            return rows.map(\.walkLog)
        } catch {
            return []
        }
    }

    // MARK: - Перенос автономных данных в аккаунт

    /// Привязывает локальное хранилище к текущему `auth.uid()` и выгружает
    /// всё, что было создано до входа.
    ///
    /// В отличие от остальных методов возвращает результат, а не глотает
    /// ошибку: перенос запускает сам пользователь и должен увидеть, если он
    /// не удался. При неудаче привязка откатывается — предложение вернётся,
    /// а повторный запуск безопасен, потому что записи заливаются `upsert`
    /// по первичному ключу.
    @discardableResult
    func migrateLocalDataToCurrentAccount(
        profile: ChildProfile?,
        walkLogs: [WalkLog]
    ) async -> Bool {
        let auth = SupabaseAuthService.shared
        guard let userID = auth.userID else { return false }

        auth.linkLocalDataToCurrentAccount()
        do {
            let familyID = try await ensureFamily()
            let context = (familyID: familyID, userID: userID)
            if let profile {
                try await upsertProfile(profile, context: context)
            }
            for log in walkLogs {
                try await upsertWalkLog(log, context: context)
            }
            return true
        } catch {
            auth.unlinkLocalData()
            return false
        }
    }
}

// MARK: - Дата рождения: календарные сутки, а не момент времени

/// `child_profiles.birthday` — колонка типа `date`, и обе стороны обмена
/// ломались об это, пока дата ездила как `Date`:
///
/// - чтение: PostgREST отдаёт «2001-05-14» без времени, а декодер
///   supabase-swift понимает только полный ISO-таймстемп. `pullProfile()`
///   падал на декодировании, глотал ошибку и возвращал `nil` — приложение
///   решало, что профиля на сервере нет, и снова просило его создать;
/// - запись: `Date` сериализуется в GMT, поэтому выбранная в UTC+5 полночь
///   14 мая уезжала на сервер как «2001-05-13T19:00:00» и после приведения
///   к `date` сохранялась как 13 мая.
///
/// День рождения — это календарный день, который пользователь видел в
/// пикере, а не момент времени, поэтому он и передаётся как «yyyy-MM-dd» в
/// текущей временной зоне устройства.
enum BirthdayFormat {
    enum FormatError: Error {
        case invalidDate(String)
    }

    private static let style = Date.ISO8601FormatStyle(timeZone: .autoupdatingCurrent)
        .year()
        .month()
        .day()

    static func string(from date: Date) -> String {
        date.formatted(style)
    }

    static func date(from string: String) throws -> Date {
        do {
            return try Date(string, strategy: style)
        } catch {
            throw FormatError.invalidDate(string)
        }
    }
}

// MARK: - Row mapping

private struct RedeemInviteParams: Encodable {
    let inviteID: UUID

    enum CodingKeys: String, CodingKey {
        case inviteID = "invite_id"
    }
}

private struct FamilyInviteInsert: Encodable {
    let familyID: UUID
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case familyID = "family_id"
        case createdBy = "created_by"
    }
}

private struct FamilyInviteRow: Decodable {
    let id: UUID
}

private struct FamilyMemberRow: Decodable {
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}

private struct ChildProfileRow: Codable {
    let familyID: UUID
    let userID: UUID
    let encryptedName: String
    let gender: String
    let birthday: String
    let gestationalAgeWeeks: Int
    let stableTraits: [String]
    let temperaturePreferenceOffset: Double
    let schemaVersion: Int

    enum CodingKeys: String, CodingKey {
        case familyID = "family_id"
        case userID = "user_id"
        case encryptedName = "encrypted_name"
        case gender
        case birthday
        case gestationalAgeWeeks = "gestational_age_weeks"
        case stableTraits = "stable_traits"
        case temperaturePreferenceOffset = "temperature_preference_offset"
        case schemaVersion = "schema_version"
    }
}

private struct WalkLogRemoteRow: Codable {
    let id: UUID
    let familyID: UUID
    let userID: UUID
    let date: Date
    let durationMinutes: Int
    let outfitItemIDs: [String]
    let comfortLevel: String
    let weatherTemperature: Double
    let apparentTemperature: Double
    let microclimateTemperature: Double?
    let transportMode: String?
    let activityLevel: String?
    let walkType: String?
    let targetTOG: Double?
    let effectiveOutfitTOG: Double?
    let events: [WalkEvent]
    let isLiveTracked: Bool
    let weatherCode: Int?
    let plannedDurationMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case familyID = "family_id"
        case userID = "user_id"
        case date
        case durationMinutes = "duration_minutes"
        case outfitItemIDs = "outfit_item_ids"
        case comfortLevel = "comfort_level"
        case weatherTemperature = "weather_temperature"
        case apparentTemperature = "apparent_temperature"
        case microclimateTemperature = "microclimate_temperature"
        case transportMode = "transport_mode"
        case activityLevel = "activity_level"
        case walkType = "walk_type"
        case targetTOG = "target_tog"
        case effectiveOutfitTOG = "effective_outfit_tog"
        case events
        case isLiveTracked = "is_live_tracked"
        case weatherCode = "weather_code"
        case plannedDurationMinutes = "planned_duration_minutes"
    }

    init(log: WalkLog, familyID: UUID, userID: UUID) {
        id = log.id
        self.familyID = familyID
        self.userID = userID
        date = log.date
        durationMinutes = log.durationMinutes
        outfitItemIDs = log.outfitItemIDs
        comfortLevel = log.comfortLevel.rawValue
        weatherTemperature = log.weatherTemperature
        apparentTemperature = log.apparentTemperature
        microclimateTemperature = log.microclimateTemperature
        transportMode = log.transportMode?.rawValue
        activityLevel = log.activityLevel?.rawValue
        walkType = log.walkType?.rawValue
        targetTOG = log.targetTOG
        effectiveOutfitTOG = log.effectiveOutfitTOG
        events = log.events
        isLiveTracked = log.isLiveTracked
        weatherCode = log.weatherCode
        plannedDurationMinutes = log.plannedDurationMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        familyID = try c.decode(UUID.self, forKey: .familyID)
        userID = try c.decode(UUID.self, forKey: .userID)
        date = try c.decode(Date.self, forKey: .date)
        durationMinutes = try c.decode(Int.self, forKey: .durationMinutes)
        outfitItemIDs = try c.decodeIfPresent([String].self, forKey: .outfitItemIDs) ?? []
        comfortLevel = try c.decode(String.self, forKey: .comfortLevel)
        weatherTemperature = try c.decode(Double.self, forKey: .weatherTemperature)
        apparentTemperature = try c.decode(Double.self, forKey: .apparentTemperature)
        microclimateTemperature = try c.decodeIfPresent(Double.self, forKey: .microclimateTemperature)
        transportMode = try c.decodeIfPresent(String.self, forKey: .transportMode)
        activityLevel = try c.decodeIfPresent(String.self, forKey: .activityLevel)
        walkType = try c.decodeIfPresent(String.self, forKey: .walkType)
        targetTOG = try c.decodeIfPresent(Double.self, forKey: .targetTOG)
        effectiveOutfitTOG = try c.decodeIfPresent(Double.self, forKey: .effectiveOutfitTOG)
        events = try c.decodeIfPresent([WalkEvent].self, forKey: .events) ?? []
        isLiveTracked = try c.decodeIfPresent(Bool.self, forKey: .isLiveTracked) ?? false
        weatherCode = try c.decodeIfPresent(Int.self, forKey: .weatherCode)
        plannedDurationMinutes = try c.decodeIfPresent(Int.self, forKey: .plannedDurationMinutes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(familyID, forKey: .familyID)
        try c.encode(userID, forKey: .userID)
        try c.encode(date, forKey: .date)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(outfitItemIDs, forKey: .outfitItemIDs)
        try c.encode(comfortLevel, forKey: .comfortLevel)
        try c.encode(weatherTemperature, forKey: .weatherTemperature)
        try c.encode(apparentTemperature, forKey: .apparentTemperature)
        try c.encodeIfPresent(microclimateTemperature, forKey: .microclimateTemperature)
        try c.encodeIfPresent(transportMode, forKey: .transportMode)
        try c.encodeIfPresent(activityLevel, forKey: .activityLevel)
        try c.encodeIfPresent(walkType, forKey: .walkType)
        try c.encodeIfPresent(targetTOG, forKey: .targetTOG)
        try c.encodeIfPresent(effectiveOutfitTOG, forKey: .effectiveOutfitTOG)
        try c.encode(events, forKey: .events)
        try c.encode(isLiveTracked, forKey: .isLiveTracked)
        try c.encodeIfPresent(weatherCode, forKey: .weatherCode)
        try c.encodeIfPresent(plannedDurationMinutes, forKey: .plannedDurationMinutes)
    }

    var walkLog: WalkLog {
        WalkLog(
            id: id,
            date: date,
            durationMinutes: durationMinutes,
            outfitItemIDs: outfitItemIDs,
            comfortLevel: BabyComfortLevel(rawValue: comfortLevel) ?? .comfortable,
            weatherTemperature: weatherTemperature,
            apparentTemperature: apparentTemperature,
            microclimateTemperature: microclimateTemperature,
            transportMode: transportMode.flatMap(TransportMode.init(rawValue:)),
            activityLevel: activityLevel.flatMap(BabyActivityLevel.init(rawValue:)),
            walkType: walkType.flatMap(WalkType.init(rawValue:)),
            targetTOG: targetTOG,
            effectiveOutfitTOG: effectiveOutfitTOG,
            events: events,
            isLiveTracked: isLiveTracked,
            weatherCode: weatherCode,
            plannedDurationMinutes: plannedDurationMinutes
        )
    }
}
