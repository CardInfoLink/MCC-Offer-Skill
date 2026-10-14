#!/bin/sh
# Offer Skill 启动入口：环境检查 + 配置同步，一步完成。每个会话开始时运行一次，只看 READY。
#
# 标准输出（每行 KEY=VALUE）：
#   ENV_STATUS=OK | FAILED        环境检查结果；FAILED 时同时输出 REASON= 和 SUGGESTION=
#   SYNC_STATUS=CHANGED | UNCHANGED
#   SYNC_REASON=...               仅同步失败时出现（NETWORK_UNAVAILABLE / INVALID_RESPONSE / INTERFACE_ERROR ...）
#   DICT=OK | MISSING             地区、银行、标签三个字典是否都在且非空
#   DICT_MISSING=a.txt,b.txt      仅 DICT=MISSING 时出现
#   CONFIG_VERSION=...            当前本地配置版本（可能为空）
#   READY=YES | NO                能不能继续往后走（发业务请求）
#   NOT_READY_REASON=...          仅 READY=NO 时出现：ENV_FAILED / FIRST_SYNC_FAILED / DICT_MISSING
#
# READY=NO 的三种情况，退出码都不是 0，调用方必须停止，不能发业务请求：
#   ENV_FAILED        环境检查失败，退出码 10(shell 不支持) / 11(缺 curl) / 12(配置目录不可用或不可写)
#   FIRST_SYNC_FAILED 首次安装（还没有客户端 ID）同步没成功，退出码 13(网络) / 14(接口)；首次安装必须同步成功才算完成，
#                     失败不记“今天已同步”，下次调用会继续重试
#   DICT_MISSING      地区、银行、标签字典缺失或为空，退出码 14
# 已经安装过的客户端同步失败不阻断（沿用本地字典，READY=YES）。
#
# 配置同步的特殊之处：不留任何请求/响应文件。请求体现拼自 client.conf 的 LOCAL_CLIENT_ID 和 LOCAL_CONFIG_VERSION，
# 响应只在内存里解析，直接更新 config/ 下的文档。单次请求超时 10 秒，只试 1 次。
# 已有客户端 ID 的情况下，同一天只尝试一次：LOCAL_LAST_SYNC_DATE 等于今天就不联网；联网失败也会记下今天，当天不再重试。

EXIT_NETWORK=13
EXIT_INTERFACE=14
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLACEHOLDER=$(printf '\346\227\240')
CONFIG_DIR="$SCRIPT_DIR/../config"
BASE_URL_ARG=""
TIMEOUT=10

usage() {
    printf '%s\n' 'Usage: init.sh [--config-dir DIR] [--base-url URL]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config-dir) [ "$#" -ge 2 ] || { usage >&2; exit 12; }; CONFIG_DIR=$2; shift 2 ;;
        --base-url) [ "$#" -ge 2 ] || { usage >&2; exit 12; }; BASE_URL_ARG=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 12 ;;
    esac
done

CLIENT_FILE="$CONFIG_DIR/client.conf"
get_value() {
    key=$1
    file=$2
    [ -f "$file" ] || return 0
    awk -F= -v wanted="$key" '$1 == wanted { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

# ============================== ① 环境检查：失败就停 ==============================
env_fail() {
    printf '%s\n' 'ENV_STATUS=FAILED' "REASON=$2" "SUGGESTION=$3" 'READY=NO' 'NOT_READY_REASON=ENV_FAILED'
    exit "$1"
}

OS_NAME=$(uname -s 2>/dev/null || printf '%s' unknown)
case "$OS_NAME" in
    Linux*|Darwin*|*BSD|CYGWIN*|MINGW*|MSYS*) ;;
    *) env_fail 10 SHELL_UNSUPPORTED USE_SUPPORTED_SHELL ;;
esac
command -v curl >/dev/null 2>&1 || env_fail 11 CURL_MISSING INSTALL_CURL
if [ ! -d "$CONFIG_DIR" ] && ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then
    env_fail 12 CONFIG_DIR_UNAVAILABLE CREATE_CONFIG_DIR
fi
WRITE_TEST="$CONFIG_DIR/.write-test.$$"
if ! (umask 077 && : > "$WRITE_TEST") 2>/dev/null; then
    env_fail 12 CONFIG_DIR_NOT_WRITABLE GRANT_CONFIG_WRITE_PERMISSION
fi
rm -f "$WRITE_TEST"
printf '%s\n' 'ENV_STATUS=OK'

# ============================== ② 配置同步 ==============================
sync_status=UNCHANGED
sync_reason=""
sync_exit=0
sync_done() {
    sync_status=$1
    sync_reason=$2
    sync_exit=$3
}

# 联网失败（联网异常、响应异常、服务端报错）时，把今天记为“已尝试日”，当天不再重试。
# 首次安装（没有客户端 ID）不记：必须同步成功，失败后下次调用要继续重试。
# 只更新 LOCAL_LAST_SYNC_DATE 这一行，其他字段和字典文件一概不动；client.conf 不存在则不处理。
mark_attempt() {
    [ -n "$local_client_id" ] || return 0
    [ -f "$CLIENT_FILE" ] || return 0
    attempt_pending="$CONFIG_DIR/.client.conf.pending.$$"
    if awk -v syncdate="$today" '
        /^LOCAL_LAST_SYNC_DATE=/ { print "LOCAL_LAST_SYNC_DATE=" syncdate; found=1; next }
        { print }
        END { if (!found) print "LOCAL_LAST_SYNC_DATE=" syncdate }
    ' "$CLIENT_FILE" > "$attempt_pending"; then
        mv -f "$attempt_pending" "$CLIENT_FILE" || rm -f "$attempt_pending"
    else
        rm -f "$attempt_pending"
    fi
    return 0
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# 按分隔符取响应的第 N 段（去掉段首尾的空行和回车）
segment() {
    printf '%s\n' "$response" | awk -v RS='=[.]==[.]=' -v n="$1" 'NR == n { print; exit }' | tr -d '\r' | sed '1{/^$/d};${/^$/d}'
}

# 字典：先写同目录下的 .pending 文件，三份都写好再一起换名，保证不会出现只换了一半的状态
stage_payload() {
    seg_no=$1
    marker=$2
    value=$(segment "$seg_no")
    if [ "$value" = "$PLACEHOLDER" ] || [ -z "$value" ]; then return 0; fi
    pending="$CONFIG_DIR/.$marker.pending.$$"
    if ! printf '%s\n' "$value" > "$pending"; then return 1; fi
    case "$marker" in
        regions) staged_regions=$pending ;;
        banks) staged_banks=$pending ;;
        tags) staged_tags=$pending ;;
    esac
    return 0
}

update_client_file() {
    new_id=$1
    new_version=$2
    new_date=$3
    new_base=$4
    pending="$CONFIG_DIR/.client.conf.pending.$$"
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
    if ! mv -f "$pending" "$CLIENT_FILE"; then rm -f "$pending"; return 1; fi
    return 0
}

# 同步主流程：结果写进 sync_status / sync_reason / sync_exit，不直接退出
sync_config() {
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

    # 已有客户端 ID，且同一天已经尝试过（成功或失败都算）：不联网，直接返回。首次安装（没有客户端 ID）不适用，必须继续同步
    if [ -n "$local_client_id" ] && [ "$last_sync_date" = "$today" ]; then
        sync_done UNCHANGED "" 0
        return 0
    fi
    if [ -z "$config_url" ]; then
        sync_done UNCHANGED NO_ENDPOINT "$EXIT_NETWORK"
        return 0
    fi

    # 请求体现拼；只发一次，超时 TIMEOUT 秒；响应直接留在变量里，不落盘
    request=$(printf '{"clientId":"%s","configVersion":"%s"}' "$(json_escape "$local_client_id")" "$(json_escape "$local_version")")
    response=$(curl -sS -L -X POST -H 'Content-Type: application/json' --connect-timeout 5 --max-time "$TIMEOUT" --data-binary "$request" "$config_url" 2>/dev/null)
    curl_exit=$?
    if [ "$curl_exit" -ne 0 ] || [ -z "$response" ]; then
        mark_attempt
        sync_done UNCHANGED NETWORK_UNAVAILABLE "$EXIT_NETWORK"
        return 0
    fi

    # $(...) 会吃掉响应末尾的换行，补回一个，保证“最后一段为空”的响应仍能数出 7 段
    count=$(printf '%s\n' "$response" | awk -v RS='=[.]==[.]=' 'END { print NR }')
    if [ "$count" -ne 7 ]; then
        mark_attempt
        sync_done UNCHANGED INVALID_RESPONSE "$EXIT_INTERFACE"
        return 0
    fi
    code=$(segment 1)
    response_client_id=$(segment 6)
    response_version=$(segment 7)
    if [ "$code" != S000000 ]; then
        mark_attempt
        sync_done UNCHANGED INTERFACE_ERROR "$EXIT_INTERFACE"
        return 0
    fi
    if [ -z "$response_client_id" ] || [ "$response_client_id" = "$PLACEHOLDER" ]; then
        mark_attempt
        sync_done UNCHANGED CLIENT_ID_MISSING "$EXIT_INTERFACE"
        return 0
    fi

    final_version=$local_version
    if [ -n "$response_version" ] && [ "$response_version" != "$PLACEHOLDER" ]; then final_version=$response_version; fi

    staged_regions=""
    staged_banks=""
    staged_tags=""
    if ! stage_payload 3 regions || ! stage_payload 4 banks || ! stage_payload 5 tags; then
        rm -f "$staged_regions" "$staged_banks" "$staged_tags"
        sync_done UNCHANGED CONFIG_WRITE_FAILED "$EXIT_INTERFACE"
        return 0
    fi
    [ -n "$staged_regions" ] && mv -f "$staged_regions" "$CONFIG_DIR/regions.txt"
    [ -n "$staged_banks" ] && mv -f "$staged_banks" "$CONFIG_DIR/banks.txt"
    [ -n "$staged_tags" ] && mv -f "$staged_tags" "$CONFIG_DIR/tags.txt"

    if ! update_client_file "$response_client_id" "$final_version" "$today" "$BASE_URL_ARG"; then
        sync_done UNCHANGED CLIENT_STATE_WRITE_FAILED "$EXIT_INTERFACE"
        return 0
    fi
    if [ "$local_version" = "$final_version" ] && [ -n "$local_client_id" ]; then
        sync_done UNCHANGED "" 0
    else
        sync_done CHANGED "" 0
    fi
    return 0
}

sync_config
printf 'SYNC_STATUS=%s\n' "$sync_status"
[ -n "$sync_reason" ] && printf 'SYNC_REASON=%s\n' "$sync_reason"

# ============================== ③ 字典是否可用 ==============================
missing=""
for name in regions banks tags; do
    if [ ! -s "$CONFIG_DIR/$name.txt" ]; then
        if [ -z "$missing" ]; then missing="$name.txt"; else missing="$missing,$name.txt"; fi
    fi
done
if [ -z "$missing" ]; then
    printf '%s\n' 'DICT=OK'
else
    printf '%s\n' 'DICT=MISSING'
    printf 'DICT_MISSING=%s\n' "$missing"
fi

# ============================== ④ 当前配置版本 ==============================
printf 'CONFIG_VERSION=%s\n' "$(get_value LOCAL_CONFIG_VERSION "$CLIENT_FILE")"

# ============================== ⑤ 能不能继续：首次安装没同步成功，或字典缺失，都不能往后走 ==============================
now_client_id=$(get_value LOCAL_CLIENT_ID "$CLIENT_FILE")
not_ready=""
ready_exit=0
if [ -z "$now_client_id" ]; then
    not_ready=FIRST_SYNC_FAILED
    case "$sync_exit" in 13|14) ready_exit=$sync_exit ;; *) ready_exit=14 ;; esac
elif [ -n "$missing" ]; then
    not_ready=DICT_MISSING
    ready_exit=14
fi
if [ -n "$not_ready" ]; then
    printf '%s\n' 'READY=NO'
    printf 'NOT_READY_REASON=%s\n' "$not_ready"
    exit "$ready_exit"
fi
printf '%s\n' 'READY=YES'
exit 0
