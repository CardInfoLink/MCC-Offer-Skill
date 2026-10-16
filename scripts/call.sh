#!/bin/sh
# Generic API caller. Request and response bodies are saved under config/data.

EXIT_NETWORK=13
EXIT_HTTP=14
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DATA_ROOT="$SCRIPT_DIR/../config/data"
REQUEST_DIR="$DATA_ROOT/req"
RESPONSE_DIR="$DATA_ROOT/res"
METHOD=GET
URL=""
DATA=""
DATA_FILE=""
TIMEOUT=30
RETRIES=3
REQUEST_ID=""
OUTPUT_FILE=""

# Client ID: read LOCAL_CLIENT_ID from config/client.conf and send it as the X-Skill-Client-Id header (used by the server for tracking).
# Only a 24-char hex value is sent; if it is missing or malformed the header is left out and the server treats the call as anonymous.
# 清一次 BOM（以防 client.conf 未经过 init.sh 清理）
CONF_PATH="$SCRIPT_DIR/../config/client.conf"
first_bytes=$(od -An -tx1 -N3 "$CONF_PATH" 2>/dev/null | tr -d ' \n')
if [ "$first_bytes" = "efbbbf" ]; then
    sed -i '1s/^\xEF\xBB\xBF//' "$CONF_PATH" 2>/dev/null
fi
CLIENT_ID=$(awk -F= '$1 == "LOCAL_CLIENT_ID" { sub(/^[^=]*=/, ""); print; exit }' "$CONF_PATH" 2>/dev/null | tr -d '\r ')
case "$CLIENT_ID" in
    *[!0-9a-fA-F]*) CLIENT_ID="" ;;
esac
[ "${#CLIENT_ID}" -eq 24 ] || CLIENT_ID=""

usage() {
    printf '%s\n' 'Usage: call.sh --method METHOD --url URL [--data JSON|--data-file FILE] [--request-id ID] [--output-file FILE] [--timeout SECONDS] [--retry COUNT]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --method) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_HTTP"; }; METHOD=$2; shift 2 ;;
        --url) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_HTTP"; }; URL=$2; shift 2 ;;
        --data) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_HTTP"; }; DATA=$2; shift 2 ;;
        --data-file) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_HTTP"; }; DATA_FILE=$2; shift 2 ;;
        --request-id) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_HTTP"; }; REQUEST_ID=$2; shift 2 ;;
        --output-file) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_HTTP"; }; OUTPUT_FILE=$2; shift 2 ;;
        --timeout) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_HTTP"; }; TIMEOUT=$2; shift 2 ;;
        --retry) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_HTTP"; }; RETRIES=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit "$EXIT_HTTP" ;;
    esac
done

[ -n "$URL" ] || { printf '%s\n' 'URL_REQUIRED' >&2; exit "$EXIT_HTTP"; }
[ -z "$DATA" ] || [ -z "$DATA_FILE" ] || { printf '%s\n' 'REQUEST_BODY_CONFLICT' >&2; exit "$EXIT_HTTP"; }
case "$METHOD" in GET|POST|PUT|PATCH|DELETE) ;; *) printf '%s\n' 'METHOD_UNSUPPORTED' >&2; exit "$EXIT_HTTP" ;; esac
[ -n "$REQUEST_ID" ] || { printf '%s\n' 'REQUEST_ID_REQUIRED' >&2; exit "$EXIT_HTTP"; }

REQUEST_FILE="$REQUEST_DIR/$REQUEST_ID.request"
[ -n "$OUTPUT_FILE" ] || OUTPUT_FILE="$RESPONSE_DIR/$REQUEST_ID.response"
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$REQUEST_DIR" "$OUTPUT_DIR" 2>/dev/null || { printf '%s\n' 'DATA_DIR_CREATE_FAILED' >&2; exit "$EXIT_NETWORK"; }

write_atomic() {
    source_file=$1
    target_file=$2
    target_dir=$(dirname "$target_file")
    mkdir -p "$target_dir" 2>/dev/null || return 1
    pending_file="$target_file.pending.$$"
    cat "$source_file" > "$pending_file" || return 1
    mv -f "$pending_file" "$target_file" || return 1
    return 0
}
write_text_atomic() {
    content=$1
    target_file=$2
    target_dir=$(dirname "$target_file")
    mkdir -p "$target_dir" 2>/dev/null || return 1
    pending_file="$target_file.pending.$$"
    printf '%s' "$content" > "$pending_file" || return 1
    mv -f "$pending_file" "$target_file" || return 1
    return 0
}

if [ -n "$DATA_FILE" ]; then
    write_atomic "$DATA_FILE" "$REQUEST_FILE" || { printf '%s\n' 'REQUEST_FILE_WRITE_FAILED' >&2; exit "$EXIT_NETWORK"; }
elif [ -n "$DATA" ]; then
    write_text_atomic "$DATA" "$REQUEST_FILE" || { printf '%s\n' 'REQUEST_FILE_WRITE_FAILED' >&2; exit "$EXIT_NETWORK"; }
else
    write_text_atomic '' "$REQUEST_FILE" || { printf '%s\n' 'REQUEST_FILE_WRITE_FAILED' >&2; exit "$EXIT_NETWORK"; }
fi

TMP_ROOT=${TMPDIR:-/tmp}
TMP_DIR="$TMP_ROOT/offer-skill-call.$$"
if ! (umask 077 && mkdir "$TMP_DIR") 2>/dev/null; then
    printf '%s\n' 'TEMP_DIR_CREATE_FAILED' >&2
    exit "$EXIT_NETWORK"
fi
RESPONSE_TEMP="$TMP_DIR/response"
ERROR_TEMP="$TMP_DIR/error"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

attempt=1
http_status=000
curl_exit=1
while [ "$attempt" -le "$RETRIES" ]; do
    : > "$RESPONSE_TEMP"
    : > "$ERROR_TEMP"
    if [ -n "$DATA" ] || [ -n "$DATA_FILE" ]; then
        http_status=$(curl -sS -L -X "$METHOD" -H 'Content-Type: application/json' -H "X-Skill-Client-Id:$CLIENT_ID" --connect-timeout 5 --max-time "$TIMEOUT" --data-binary "@$REQUEST_FILE" -o "$RESPONSE_TEMP" -w '%{http_code}' "$URL" 2>"$ERROR_TEMP")
    else
        http_status=$(curl -sS -L -X "$METHOD" -H 'Content-Type: application/json' -H "X-Skill-Client-Id:$CLIENT_ID" --connect-timeout 5 --max-time "$TIMEOUT" -o "$RESPONSE_TEMP" -w '%{http_code}' "$URL" 2>"$ERROR_TEMP")
    fi
    curl_exit=$?
    if [ "$curl_exit" -eq 0 ]; then
        case "$http_status" in
            2[0-9][0-9]) break ;;
            5[0-9][0-9]) ;;
            *) break ;;
        esac
    fi
    [ "$attempt" -lt "$RETRIES" ] || break
    attempt=$((attempt + 1))
    sleep 1
done

result_code=0
if [ "$curl_exit" -ne 0 ] || [ "$http_status" = 000 ] || [ -z "$http_status" ]; then
    result_code=$EXIT_NETWORK
elif ! printf '%s' "$http_status" | grep -Eq '^2[0-9][0-9]$'; then
    result_code=$EXIT_HTTP
fi

write_atomic "$RESPONSE_TEMP" "$OUTPUT_FILE" || { printf '%s\n' 'RESPONSE_FILE_WRITE_FAILED' >&2; exit "$EXIT_NETWORK"; }
printf 'REQUEST_ID=%s\n' "$REQUEST_ID"
printf 'REQUEST_FILE=%s\n' "$REQUEST_FILE"
printf 'RESPONSE_FILE=%s\n' "$OUTPUT_FILE"
printf 'HTTP_STATUS=%s\n' "$http_status"
printf 'EXIT_CODE=%s\n' "$result_code"

if [ "$result_code" -eq "$EXIT_NETWORK" ]; then
    printf '%s\n' 'NETWORK_REQUEST_FAILED' >&2
    exit "$EXIT_NETWORK"
fi
if [ "$result_code" -eq "$EXIT_HTTP" ]; then
    printf 'HTTP_NON_SUCCESS_%s\n' "$http_status" >&2
    exit "$EXIT_HTTP"
fi
exit 0
