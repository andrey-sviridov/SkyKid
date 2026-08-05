import Foundation

/// Код приглашения второго родителя: `skykid1:<uuid приглашения>.<ключ>`.
///
/// Идентификатор приглашения сервер знает, а ключ шифрования имени ребёнка —
/// нет: он существует только внутри кода, который родители пересылают друг
/// другу сами. Поэтому код нельзя продиктовать голосом — он длинный и его
/// отправляют через шеринг.
///
/// Разбор кода вынесен отдельно от сети: это чистая логика, и она
/// покрывается тестами без обращения к Supabase.
enum FamilyInviteCode {
    static let prefix = "skykid1:"

    struct Payload: Equatable {
        let inviteID: UUID
        let keyBase64: String
    }

    enum CodeError: Error, Equatable {
        case malformed
    }

    static func make(inviteID: UUID, keyBase64: String) -> String {
        "\(prefix)\(inviteID.uuidString).\(keyBase64)"
    }

    static func parse(_ rawCode: String) throws -> Payload {
        // Код приезжает из буфера обмена и мессенджеров, поэтому пробелы,
        // переводы строк и регистр префикса прощаем.
        let trimmed = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix(prefix) else { throw CodeError.malformed }

        let body = String(trimmed.dropFirst(prefix.count))
        // Ни UUID, ни base64 точку не содержат, поэтому разделитель
        // однозначен даже без ограничения на число частей.
        guard let separator = body.firstIndex(of: ".") else { throw CodeError.malformed }

        let idPart = String(body[body.startIndex..<separator])
        let keyPart = String(body[body.index(after: separator)...])

        guard let inviteID = UUID(uuidString: idPart), !keyPart.isEmpty else {
            throw CodeError.malformed
        }
        return Payload(inviteID: inviteID, keyBase64: keyPart)
    }
}
