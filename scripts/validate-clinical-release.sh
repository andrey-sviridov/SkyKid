#!/bin/sh

set -eu

# MARK: - Paths

ROOT_DIR="${SRCROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
STATUS_FILE="${ROOT_DIR}/docs/clinical-review-status.plist"
INPUT_LIST="${ROOT_DIR}/docs/clinical-policy-inputs.xcfilelist"
OUTPUT_FILE="${SCRIPT_OUTPUT_FILE_0:-}"

# MARK: - Output

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

write_marker() {
    [ -n "$OUTPUT_FILE" ] || return 0
    /usr/bin/printf '%s\n' "$1" > "$OUTPUT_FILE"
}

# MARK: - Input

json_value() {
    /usr/bin/plutil -extract "$1" raw -o - "$STATUS_FILE" 2>/dev/null || true
}

policy_file_path() {
    entry="$1"
    case "$entry" in
        "\$(SRCROOT)/"*)
            relative_path=$(/usr/bin/printf '%s\n' "$entry" | /usr/bin/cut -d/ -f2-)
            /usr/bin/printf '%s/%s\n' "$ROOT_DIR" "$relative_path"
            ;;
        *)
            fail "Недопустимая строка в clinical-policy-inputs.xcfilelist: ${entry}"
            ;;
    esac
}

# MARK: - Policy fingerprint

policy_digest() {
    [ -f "$INPUT_LIST" ] || fail "Не найден список clinical-policy-inputs.xcfilelist."

    while IFS= read -r entry || [ -n "$entry" ]; do
        case "$entry" in
            ""|\#*) continue ;;
        esac

        path=$(policy_file_path "$entry")
        [ -f "$path" ] || fail "Не найден safety-файл: ${path}"
    done < "$INPUT_LIST"

    while IFS= read -r entry || [ -n "$entry" ]; do
        case "$entry" in
            ""|\#*) continue ;;
        esac

        path=$(policy_file_path "$entry")
        relative_path=$(/usr/bin/printf '%s\n' "$entry" | /usr/bin/cut -d/ -f2-)
        checksum=$(/usr/bin/shasum -a 256 "$path" | /usr/bin/awk '{print $1}')
        /usr/bin/printf '%s  %s\n' "$checksum" "$relative_path"
    done < "$INPUT_LIST" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'
}

# MARK: - Commands

if [ "${1:-}" = "--print-digest" ]; then
    policy_digest
    exit 0
fi

# Debug builds remain available for development and clinical review.
if [ "${CONFIGURATION:-Release}" != "Release" ]; then
    write_marker "Skipped for ${CONFIGURATION:-development} configuration."
    exit 0
fi

[ -f "$STATUS_FILE" ] || fail "Не найден clinical-review-status.plist."
/usr/bin/plutil -lint "$STATUS_FILE" >/dev/null

status=$(json_value status)
if [ "$status" != "approved" ]; then
    fail "Release заблокирован: письменное согласование лицензированного педиатра ещё не получено. См. docs/clinical-review.md."
fi

reviewer_name=$(json_value reviewer.name)
reviewer_license=$(json_value reviewer.license)
reviewer_jurisdiction=$(json_value reviewer.jurisdiction)
target_jurisdiction=$(json_value scope.targetJurisdiction)
reviewed_at=$(json_value approval.reviewedAt)
reviewed_commit=$(json_value approval.reviewedCommit)
reviewed_digest=$(json_value approval.policyDigest)

[ -n "$reviewer_name" ] || fail "В согласовании не указано имя рецензента."
[ -n "$reviewer_license" ] || fail "В согласовании не указан номер лицензии."
[ -n "$reviewer_jurisdiction" ] || fail "В согласовании не указана юрисдикция лицензии."
[ -n "$target_jurisdiction" ] || fail "Не выбран регион релиза."
[ -n "$reviewed_at" ] || fail "Не указана дата клинической проверки."
[ -n "$reviewed_commit" ] || fail "Не указан проверенный commit."
[ -n "$reviewed_digest" ] || fail "Не указан digest проверенных safety-политик."

current_digest=$(policy_digest)
if [ "$reviewed_digest" != "$current_digest" ]; then
    fail "Safety-политики изменились после согласования. Требуется повторная клиническая проверка."
fi

/usr/bin/printf 'Clinical release gate: approved (%s, %s).\n' \
    "$reviewer_name" \
    "$target_jurisdiction"
write_marker "Approved: ${reviewer_name}, ${target_jurisdiction}, ${current_digest}"
