#!/bin/sh

EXIT_NETWORK=13
EXIT_INTERFACE=14
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RESP_DIR="$SCRIPT_DIR/../config/data/res"
SEPARATOR='=.==.='
PLACEHOLDER=$(printf '\346\227\240')
CONFIG_DIR="$SCRIPT_DIR/../config"
BASE_URL_ARG=""
TIMEOUT=30
REQUEST_ID=""

usage() {
    printf '%s\n' 'Usage: sync-config.sh [--config-dir DIR] [--base-url URL] [--request-id ID] [--timeout SECONDS]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config-dir) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_INTERFACE"; }; CONFIG_DIR=$2; shift 2 ;;
        --base-url) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_NETWORK"; }; BASE_URL_ARG=$2; shift 2 ;;
        --request-id) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_INTERFACE"; }; REQUEST_ID=$2; shift 2 ;;
        --timeout) [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_NETWORK"; }; TIMEOUT=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit "$EXIT_INTERFACE" ;;
    esac
done

if [ ! -d "$CONFIG_DIR" ] && ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then
    printf '%s\n' 'SYNC_STATUS=UNCHANGED' 'SYNC_REASON=CONFIG_DIR_UNAVAILABLE' >&2
    exit "$EXIT_INTERFACE"
fi

CLIENT_FILE="$CONFIG_DIR/client.conf"
get_value() {
    key=$1
    file=$2
    [ -f "$file" ] || return 0
    awk -F= -v wanted="$key" '$1 == wanted { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

base_url=$BASE_URL_ARG
if [ -z "$base_url" ]; then base_url=${OFFER_SKILL_BASE_URL:-}; fi
if [ -z "$base_url" ]; then base_url=$(get_value API_BASE_URL "$CLIENT_FILE"); fi
config_url=$(get_value API_CONFIG_URL "$CLIENT_FILE")
config_path=$(get_value API_CONFIG_PATH "$CLIENT_FILE")
[ -n "$config_path" ] || config_path=/api/offer/config
if [ -z "$config_url" ] && [ -n "$base_url" ]; then config_url=${base_url%/}$config_path; fi

today=$(date +%F)
local_client_id=$(get_value LOCAL_CLIENT_ID "$CLIENT_FILE")
local_version=$(get_value LOCAL_CONFIG_VERSION "$CLIENT_FILE")
last_sync_date=$(get_value LOCAL_LAST_SYNC_DATE "$CLIENT_FILE")

sync_result() {
    status=$1
    reason=$2
    printf 'SYNC_STATUS=%s\n' "$status"
    [ -n "$reason" ] && printf 'SYNC_REASON=%s\n' "$reason" >&2
    if [ -n "$REQUEST_ID" ]; then
        printf 'SYNC_REQUEST_ID=%s\n' "$REQUEST_ID"
        printf 'SYNC_RESPONSE_FILE=%s\n' "$RESP_DIR/$REQUEST_ID.response"
    fi
}

if [ -n "$local_client_id" ] && [ "$last_sync_date" = "$today" ]; then
    sync_result UNCHANGED ""
    exit 0
fi

if [ -z "$config_url" ]; then
    sync_result UNCHANGED NO_ENDPOINT >&2
    exit "$EXIT_NETWORK"
fi

if [ -z "$REQUEST_ID" ]; then
    REQUEST_ID="sync-$(date +%Y%m%d%H%M%S)-$$"
fi
mkdir -p "$RESP_DIR" 2>/dev/null || true
RESPONSE_FILE="$RESP_DIR/$REQUEST_ID.response"
TMP_ROOT=${TMPDIR:-/tmp}
TMP_DIR="$TMP_ROOT/offer-skill-sync.$$"
if ! (umask 077 && mkdir "$TMP_DIR") 2>/dev/null; then
    sync_result UNCHANGED TEMP_DIR_UNAVAILABLE >&2
    exit "$EXIT_INTERFACE"
fi
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}
request=$(printf '{"clientId":"%s","configVersion":"%s"}' "$(json_escape "$local_client_id")" "$(json_escape "$local_version")")
api_exit=0
"$SCRIPT_DIR/api-call.sh" \
    --method POST \
    --url "$config_url" \
    --data "$request" \
    --request-id "$REQUEST_ID" \
    --output-file "$RESPONSE_FILE" \
    --timeout "$TIMEOUT" \
    --retry 3 > "$TMP_DIR/api-output" 2> "$TMP_DIR/api-error" || api_exit=$?

if [ ! -s "$RESPONSE_FILE" ]; then
    sync_result UNCHANGED NETWORK_UNAVAILABLE >&2
    exit "$EXIT_NETWORK"
fi

awk -v RS='=[.]==[.]=' -v dir="$TMP_DIR" '{ print > (dir "/part-" NR) } END { print NR > (dir "/count") }' "$RESPONSE_FILE"
count=$(cat "$TMP_DIR/count" 2>/dev/null || printf '0')
if [ "$count" -ne 7 ]; then
    sync_result UNCHANGED INVALID_RESPONSE >&2
    exit "$EXIT_INTERFACE"
fi

strip_cr() {
    tr -d '\r' < "$1" | sed '1{/^$/d};${/^$/d}'
}
code=$(tr -d '\r\n' < "$TMP_DIR/part-1")
message=$(strip_cr "$TMP_DIR/part-2")
regions_file="$TMP_DIR/regions"
banks_file="$TMP_DIR/banks"
tags_file="$TMP_DIR/tags"
strip_cr "$TMP_DIR/part-3" > "$regions_file"
strip_cr "$TMP_DIR/part-4" > "$banks_file"
strip_cr "$TMP_DIR/part-5" > "$tags_file"
response_client_id=$(tr -d '\r\n' < "$TMP_DIR/part-6")
response_version=$(tr -d '\r\n' < "$TMP_DIR/part-7")

if [ "$code" != S000000 ]; then
    [ -n "$message" ] || message=CONFIG_SYNC_FAILED
    sync_result UNCHANGED INTERFACE_ERROR >&2
    if [ "$api_exit" -eq "$EXIT_NETWORK" ]; then exit "$EXIT_NETWORK"; fi
    exit "$EXIT_INTERFACE"
fi

if [ -z "$response_client_id" ] || [ "$response_client_id" = "$PLACEHOLDER" ]; then
    sync_result UNCHANGED CLIENT_ID_MISSING >&2
    exit "$EXIT_INTERFACE"
fi

final_version=$local_version
if [ -n "$response_version" ] && [ "$response_version" != "$PLACEHOLDER" ]; then final_version=$response_version; fi

staged_regions=""
staged_banks=""
staged_tags=""
stage_payload() {
    source_file=$1
    marker=$2
    value=$(cat "$source_file")
    if [ "$value" = "$PLACEHOLDER" ] || [ -z "$value" ]; then return 0; fi
    pending="$CONFIG_DIR/.$marker.pending.$$"
    if ! cat "$source_file" > "$pending"; then return 1; fi
    case "$marker" in
        regions) staged_regions=$pending ;;
        banks) staged_banks=$pending ;;
        tags) staged_tags=$pending ;;
    esac
    return 0
}
if ! stage_payload "$regions_file" regions || ! stage_payload "$banks_file" banks || ! stage_payload "$tags_file" tags; then
    rm -f "$staged_regions" "$staged_banks" "$staged_tags"
    sync_result UNCHANGED CONFIG_WRITE_FAILED >&2
    exit "$EXIT_INTERFACE"
fi

[ -n "$staged_regions" ] && mv -f "$staged_regions" "$CONFIG_DIR/regions.txt"
[ -n "$staged_banks" ] && mv -f "$staged_banks" "$CONFIG_DIR/banks.txt"
[ -n "$staged_tags" ] && mv -f "$staged_tags" "$CONFIG_DIR/tags.txt"

update_client_file() {
    new_id=$1
    new_version=$2
    new_date=$3
    new_base=$4
    pending="$TMP_DIR/client.conf"
    if [ -f "$CLIENT_FILE" ]; then
        set_base=0
        [ -n "$new_base" ] && set_base=1
        awk -v id="$new_id" -v version="$new_version" -v syncdate="$new_date" -v base="$new_base" -v setbase="$set_base" '
            /^LOCAL_CLIENT_ID=/ { print "LOCAL_CLIENT_ID=" id; found_id=1; next }
            /^LOCAL_CONFIG_VERSION=/ { print "LOCAL_CONFIG_VERSION=" version; found_version=1; next }
            /^LOCAL_LAST_SYNC_DATE=/ { print "LOCAL_LAST_SYNC_DATE=" syncdate; found_date=1; next }
            /^API_BASE_URL=/ { if (setbase) print "API_BASE_URL=" base; else print; found_base=1; next }
            { print }
            END {
                if (!found_id) print "LOCAL_CLIENT_ID=" id
                if (!found_version) print "LOCAL_CONFIG_VERSION=" version
                if (!found_date) print "LOCAL_LAST_SYNC_DATE=" syncdate
                if (setbase && !found_base) print "API_BASE_URL=" base
            }
        ' "$CLIENT_FILE" > "$pending"
    else
        {
            printf '%s\n' "API_BASE_URL=$new_base" \
                'API_CONFIG_PATH=/api/offer/config' \
                'API_QUERY_PATH=/api/offer/query' \
                'API_DETAIL_PATH=/api/offer/detail' \
                'API_RECOMMEND_PATH=/api/offer/recommend' \
                'API_MORE_PATH=/api/offer/more' \
                "API_TIMEOUT_SECONDS=$TIMEOUT" \
                "LOCAL_CLIENT_ID=$new_id" \
                "LOCAL_CONFIG_VERSION=$new_version" \
                "LOCAL_LAST_SYNC_DATE=$new_date"
        } > "$pending"
    fi
    if ! mv -f "$pending" "$CLIENT_FILE"; then return 1; fi
    return 0
}

if ! update_client_file "$response_client_id" "$final_version" "$today" "$BASE_URL_ARG"; then
    sync_result UNCHANGED CLIENT_STATE_WRITE_FAILED >&2
    exit "$EXIT_INTERFACE"
fi

if [ "$local_version" = "$final_version" ] && [ -n "$local_client_id" ]; then
    sync_result UNCHANGED ""
else
    sync_result CHANGED ""
fi
exit 0
