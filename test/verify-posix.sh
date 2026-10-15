#!/bin/sh

set -u

# EverySkill-Skill POSIX integration verification.
# All process logs and raw API responses are kept under test/logs/.
# Usage:
#   sh test/verify-posix.sh
#   sh test/verify-posix.sh http://127.0.0.1:12345

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
LOG_DIR="$SCRIPT_DIR/logs"
TMP_DIR="$LOG_DIR/.tmp-$$"
LOG_FILE="$LOG_DIR/verify-$(date +%Y%m%d%H%M%S)-$$.log"
BASE_URL=${1:-}

INIT="$PROJECT_ROOT/scripts/init.sh"
CALL="$PROJECT_ROOT/scripts/call.sh"
CLEAN="$PROJECT_ROOT/scripts/clean.sh"

PASS_COUNT=0
FAIL_COUNT=0

mkdir -p "$LOG_DIR" "$TMP_DIR" || exit 1

cleanup_tmp() {
    rm -rf "$TMP_DIR"
}
trap cleanup_tmp EXIT HUP INT TERM

log() {
    printf '%s\n' "$1" | tee -a "$LOG_FILE"
}

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    log "[PASS] $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    log "[FAIL] $1"
}

section() {
    log ""
    log "== $1 =="
}

run_logged() {
    label=$1
    shift
    output_file="$TMP_DIR/$label.output"
    log "[RUN] $*"
    "$@" > "$output_file" 2>&1
    code=$?
    cat "$output_file" | tee -a "$LOG_FILE"
    return "$code"
}

extract_string() {
    key=$1
    file=$2
    tr ',' '\n' < "$file" | sed -n "s/.*\"$key\":\"\([^\"]*\)\".*/\1/p" | head -n 1
}

extract_bool() {
    key=$1
    file=$2
    sed -n "s/.*\"$key\":\([^,}]*\).*/\1/p" "$file" | head -n 1
}

cleanup_event() {
    event_id=$1
    run_logged "clean-$event_id" sh "$CLEAN" --request-id "$event_id" || true
}

section 'Environment and script syntax'

for command in sh curl; do
    if command -v "$command" >/dev/null 2>&1; then
        pass "$command is available"
    else
        fail "$command is unavailable"
    fi
done

for script in "$INIT" "$CALL" "$CLEAN"; do
    name=$(basename "$script")
    if sh -n "$script" >/dev/null 2>&1; then
        pass "$name syntax is valid"
    else
        fail "$name syntax check failed"
    fi
done

if [ "$FAIL_COUNT" -ne 0 ]; then
    log 'Basic environment checks failed; stop.'
    exit 1
fi

section 'Init: environment check'
# 一个全新的配置目录（没有 client.conf、没有字典）：环境检查应通过；没有服务地址，首次安装同步不可能成功，所以整体 READY=NO
ENV_CONFIG_DIR="$TMP_DIR/env-config"
if run_logged init-env sh "$INIT" --config-dir "$ENV_CONFIG_DIR"; then
    fail 'init on a fresh config dir unexpectedly returned 0'
else
    code=$?
    if [ "$code" -eq 13 ]; then
        pass 'init on a fresh config dir returns 13 (first sync cannot succeed)'
    else
        fail "init on a fresh config dir returned $code instead of 13"
    fi
fi

if grep -q 'ENV_STATUS=OK' "$TMP_DIR/init-env.output"; then
    pass 'environment status is OK'
else
    fail 'environment status is not OK'
fi

# 配置目录路径是一个已存在的文件：环境检查必须失败，退出码 12，READY=NO
ENV_BAD_DIR="$TMP_DIR/env-bad-dir"
printf 'x' > "$ENV_BAD_DIR"
if run_logged init-env-bad sh "$INIT" --config-dir "$ENV_BAD_DIR"; then
    fail 'init with an unusable config dir unexpectedly returned 0'
else
    code=$?
    if [ "$code" -eq 12 ] && grep -q 'ENV_STATUS=FAILED' "$TMP_DIR/init-env-bad.output" && grep -q 'NOT_READY_REASON=ENV_FAILED' "$TMP_DIR/init-env-bad.output"; then
        pass 'unusable config dir returns 12 with ENV_FAILED'
    else
        fail "unusable config dir returned $code or missing ENV_FAILED output"
    fi
fi

section 'Request ID is mandatory'
MISSING_ID_OUTPUT=$(sh "$CALL" --method GET --url 'http://127.0.0.1:1/offer/query' --retry 1 2>&1)
MISSING_ID_CODE=$?
printf '%s\n' "$MISSING_ID_OUTPUT" | tee -a "$LOG_FILE"
if [ "$MISSING_ID_CODE" -eq 14 ]; then
    pass 'missing request ID returns 14'
else
    fail "missing request ID returned $MISSING_ID_CODE"
fi

section 'API transport failure and single response file'
FAIL_EVENT='verify-api-failure'
FAIL_RESPONSE="$LOG_DIR/$FAIL_EVENT.response"
if run_logged "$FAIL_EVENT" sh "$CALL" \
    --method GET \
    --url 'http://127.0.0.1:1/offer/query' \
    --request-id "$FAIL_EVENT" \
    --output-file "$FAIL_RESPONSE" \
    --retry 1; then
    fail 'unreachable API unexpectedly succeeded'
else
    code=$?
    if [ "$code" -eq 13 ]; then
        pass 'network failure returns 13'
    else
        fail "network failure returned $code instead of 13"
    fi
fi

if [ -f "$FAIL_RESPONSE" ]; then
    pass 'failure response was saved under test/logs'
else
    fail 'failure response file is missing'
fi
cleanup_event "$FAIL_EVENT"

section 'Init: configuration sync fallback'
# 首次安装（没有客户端 ID）+ 服务地址连不上：必须 READY=NO、退出码 13，并且不能记“今天已同步”
FALLBACK_CONFIG="$TMP_DIR/fallback-config"
mkdir -p "$FALLBACK_CONFIG"
printf '%s\n' 'API_BASE_URL=http://127.0.0.1:1' 'API_CONFIG_PATH=/api/offer/config' 'LOCAL_CLIENT_ID=' 'LOCAL_CONFIG_VERSION=' 'LOCAL_LAST_SYNC_DATE=' > "$FALLBACK_CONFIG/client.conf"
FALLBACK_EVENT='verify-init-fallback'
if run_logged "$FALLBACK_EVENT" sh "$INIT" --config-dir "$FALLBACK_CONFIG"; then
    fail 'first install against an unreachable server unexpectedly succeeded'
else
    code=$?
    if [ "$code" -eq 13 ]; then
        pass 'first install against an unreachable server returns 13'
    else
        fail "first install against an unreachable server returned $code instead of 13"
    fi
fi
if grep -q 'READY=NO' "$TMP_DIR/$FALLBACK_EVENT.output" && grep -q 'NOT_READY_REASON=FIRST_SYNC_FAILED' "$TMP_DIR/$FALLBACK_EVENT.output" && grep -q 'SYNC_REASON=NETWORK_UNAVAILABLE' "$TMP_DIR/$FALLBACK_EVENT.output"; then
    pass 'first install failure reports READY=NO / FIRST_SYNC_FAILED'
else
    fail 'first install failure output is incorrect'
fi
if grep -q '^LOCAL_LAST_SYNC_DATE=$' "$FALLBACK_CONFIG/client.conf"; then
    pass 'failed first install does not record today as synced'
else
    fail 'failed first install wrongly recorded a sync date'
fi
if [ -z "$(ls "$FALLBACK_CONFIG" | grep -v -e '^client.conf$')" ]; then
    pass 'sync leaves no extra files in the config dir'
else
    fail 'sync left extra files in the config dir'
fi

section 'Optional real EverySkill API flow'

if [ -z "$BASE_URL" ]; then
    log 'BASE_URL was not supplied; skip real API flow.'
    log 'Run with: sh test/verify-posix.sh http://127.0.0.1:12345'
else
    CONFIG_EVENT='verify-init-real'
    REAL_CONFIG_DIR="$TMP_DIR/real-config"
    if run_logged "$CONFIG_EVENT" sh "$INIT" \
        --config-dir "$REAL_CONFIG_DIR" \
        --base-url "$BASE_URL"; then
        if grep -q 'SYNC_STATUS=CHANGED\|SYNC_STATUS=UNCHANGED' "$TMP_DIR/$CONFIG_EVENT.output" && grep -q 'READY=YES' "$TMP_DIR/$CONFIG_EVENT.output"; then
            pass 'init against the real server returned READY=YES'
        else
            fail 'init against the real server did not report READY=YES'
        fi
    else
        fail 'init against the real server failed'
    fi

    QUERY_EVENT='verify-query'
    QUERY_REQUEST="$LOG_DIR/$QUERY_EVENT.request"
    QUERY_RESPONSE="$LOG_DIR/$QUERY_EVENT.response"
    printf '%s\n' '{"intentTags":[{"tagName":"\u6e29\u6cc9\u5ea6\u5047","matchScore":90},{"tagName":"\u9152\u5e97","matchScore":65},{"tagName":"\u4eb2\u5b50","matchScore":45}],"filters":null}' > "$QUERY_REQUEST"
    if run_logged "$QUERY_EVENT" sh "$CALL" \
        --method POST \
        --url "${BASE_URL%/}/api/offer/query" \
        --data-file "$QUERY_REQUEST" \
        --request-id "$QUERY_EVENT" \
        --output-file "$QUERY_RESPONSE" \
        --retry 1; then
        if grep -q '"code":"S000000"' "$QUERY_RESPONSE"; then
            pass 'query returned success'
        else
            fail 'query returned no success code'
        fi
    else
        fail 'query call failed'
    fi

    OFFER_ID=$(extract_string offerId "$QUERY_RESPONSE")
    CACHE_ID=$(extract_string queryCacheId "$QUERY_RESPONSE")
    HAS_MORE=$(extract_bool hasMore "$QUERY_RESPONSE")

    if [ -n "$OFFER_ID" ]; then
        DETAIL_EVENT='verify-detail'
        DETAIL_RESPONSE="$LOG_DIR/$DETAIL_EVENT.response"
        if run_logged "$DETAIL_EVENT" sh "$CALL" \
            --method GET \
            --url "${BASE_URL%/}/api/offer/detail/$OFFER_ID" \
            --request-id "$DETAIL_EVENT" \
            --output-file "$DETAIL_RESPONSE" \
            --retry 1; then
            if grep -q '"code":"S000000"' "$DETAIL_RESPONSE"; then pass 'detail returned success'; else fail 'detail returned no success code'; fi
        else
            fail 'detail call failed'
        fi
    else
        fail 'query returned no offerId; detail skipped'
    fi

    RECOMMEND_RESPONSE=""
    if [ -n "$OFFER_ID" ]; then
        RECOMMEND_EVENT='verify-recommend'
        RECOMMEND_REQUEST="$LOG_DIR/$RECOMMEND_EVENT.request"
        RECOMMEND_RESPONSE="$LOG_DIR/$RECOMMEND_EVENT.response"
        printf '{"baseOfferId":"%s"}\n' "$OFFER_ID" > "$RECOMMEND_REQUEST"
        if run_logged "$RECOMMEND_EVENT" sh "$CALL" \
            --method POST \
            --url "${BASE_URL%/}/api/offer/recommend" \
            --data-file "$RECOMMEND_REQUEST" \
            --request-id "$RECOMMEND_EVENT" \
            --output-file "$RECOMMEND_RESPONSE" \
            --retry 1; then
            if grep -q '"code":"S000000"' "$RECOMMEND_RESPONSE"; then pass 'recommend returned success'; else fail 'recommend returned no success code'; fi
        else
            fail 'recommend call failed'
        fi
    fi

    MORE_CACHE_ID="$CACHE_ID"
    MORE_HAS_MORE="$HAS_MORE"
    MORE_BASE_ID=""
    MORE_TAGS='[{"tagName":"\\u6e29\\u6cc9\\u5ea6\\u5047","matchScore":90},{"tagName":"\\u9152\\u5e97","matchScore":65},{"tagName":"\\u4eb2\\u5b50","matchScore":45}]'
    if [ "$MORE_HAS_MORE" != 'true' ] && [ -n "$RECOMMEND_RESPONSE" ] && grep -q '"code":"S000000"' "$RECOMMEND_RESPONSE"; then
        MORE_CACHE_ID=$(extract_string queryCacheId "$RECOMMEND_RESPONSE")
        MORE_HAS_MORE=$(extract_bool hasMore "$RECOMMEND_RESPONSE")
        MORE_BASE_ID="$OFFER_ID"
        MORE_TAGS='[]'
    fi

    if [ "$MORE_HAS_MORE" = 'true' ] && [ -n "$MORE_CACHE_ID" ]; then
        MORE_EVENT='verify-more'
        MORE_REQUEST="$LOG_DIR/$MORE_EVENT.request"
        MORE_RESPONSE="$LOG_DIR/$MORE_EVENT.response"
        printf '{"queryCacheId":"%s","page":2,"intentTags":%s,"filters":null,"baseOfferId":"%s"}\n' "$MORE_CACHE_ID" "$MORE_TAGS" "$MORE_BASE_ID" > "$MORE_REQUEST"
        if run_logged "$MORE_EVENT" sh "$CALL" \
            --method POST \
            --url "${BASE_URL%/}/api/offer/more" \
            --data-file "$MORE_REQUEST" \
            --request-id "$MORE_EVENT" \
            --output-file "$MORE_RESPONSE" \
            --retry 1; then
            if grep -q '"code":"S000000"' "$MORE_RESPONSE"; then pass 'more returned success'; else fail 'more returned no success code'; fi
        else
            fail 'more call failed'
        fi
    else
        log 'No more page was reported; skip more call.'
    fi

    cleanup_event "$QUERY_EVENT"
    cleanup_event 'verify-detail'
    cleanup_event 'verify-recommend'
    cleanup_event 'verify-more'
fi

section 'Summary'
log "PASS=$PASS_COUNT"
log "FAIL=$FAIL_COUNT"
log "LOG_FILE=$LOG_FILE"

if [ "$FAIL_COUNT" -eq 0 ]; then
    log 'POSIX verification completed successfully.'
    exit 0
fi

log 'POSIX verification has failures. Review the log file.'
exit 1
