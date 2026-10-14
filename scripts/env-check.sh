#!/bin/sh

EXIT_SHELL=10
EXIT_CURL=11
EXIT_CONFIG=12
EXIT_NETWORK=13

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR="$SCRIPT_DIR/../config"
CHECK_URL=""

usage() {
    printf '%s\n' 'Usage: env-check.sh [--config-dir DIR] [--url URL]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config-dir)
            [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_CONFIG"; }
            CONFIG_DIR=$2
            shift 2
            ;;
        --url)
            [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_NETWORK"; }
            CHECK_URL=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit "$EXIT_SHELL"
            ;;
    esac
done

OS_NAME=$(uname -s 2>/dev/null || printf '%s' unknown)
case "$OS_NAME" in
    Linux*|Darwin*|*BSD|CYGWIN*|MINGW*|MSYS*) ;;
    *)
        printf '%s\n' 'STATUS=FAILED' 'REASON=SHELL_UNSUPPORTED' 'SUGGESTION=USE_SUPPORTED_SHELL' >&2
        exit "$EXIT_SHELL"
        ;;
esac

if ! command -v curl >/dev/null 2>&1; then
    printf '%s\n' 'STATUS=FAILED' 'REASON=CURL_MISSING' 'SUGGESTION=INSTALL_CURL' >&2
    exit "$EXIT_CURL"
fi

if [ ! -d "$CONFIG_DIR" ] && ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then
    printf '%s\n' 'STATUS=FAILED' 'REASON=CONFIG_DIR_UNAVAILABLE' 'SUGGESTION=CREATE_CONFIG_DIR' >&2
    exit "$EXIT_CONFIG"
fi

WRITE_TEST="$CONFIG_DIR/.write-test.$$"
if ! (umask 077 && : > "$WRITE_TEST") 2>/dev/null; then
    printf '%s\n' 'STATUS=FAILED' 'REASON=CONFIG_DIR_NOT_WRITABLE' 'SUGGESTION=GRANT_CONFIG_WRITE_PERMISSION' >&2
    exit "$EXIT_CONFIG"
fi
rm -f "$WRITE_TEST"

NETWORK_STATUS=NOT_CHECKED
if [ -n "$CHECK_URL" ]; then
    HTTP_STATUS=$(curl -sS --connect-timeout 5 --max-time 10 -o /dev/null -w '%{http_code}' "$CHECK_URL" 2>/dev/null) || HTTP_STATUS=000
    case "$HTTP_STATUS" in
        000)
            printf '%s\n' 'STATUS=FAILED' 'REASON=NETWORK_UNAVAILABLE' 'SUGGESTION=CHECK_NETWORK_AND_RETRY' >&2
            exit "$EXIT_NETWORK"
            ;;
        *) NETWORK_STATUS=AVAILABLE ;;
    esac
fi

printf '%s\n' \
    'STATUS=OK' \
    'SHELL=POSIX' \
    "OS=$OS_NAME" \
    'CURL=curl' \
    "CONFIG_DIR=$CONFIG_DIR" \
    "NETWORK=$NETWORK_STATUS"
exit 0
