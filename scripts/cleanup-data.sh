#!/bin/sh

EXIT_INVALID=14
REQUEST_ID=""

usage() {
    printf '%s\n' 'Usage: cleanup-data.sh --request-id EVENT_ID'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --request-id)
            [ "$#" -ge 2 ] || { usage >&2; exit "$EXIT_INVALID"; }
            REQUEST_ID=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit "$EXIT_INVALID"
            ;;
    esac
done

case "$REQUEST_ID" in
    ""|*[!A-Za-z0-9._-]*)
        printf '%s\n' 'REQUEST_ID_INVALID' >&2
        exit "$EXIT_INVALID"
        ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DATA_ROOT="$SCRIPT_DIR/../config/data"
REQUEST_FILE="$DATA_ROOT/req/$REQUEST_ID.request"
RESPONSE_FILE="$DATA_ROOT/res/$REQUEST_ID.response"
removed=0

for file in "$REQUEST_FILE" "$RESPONSE_FILE"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        removed=$((removed + 1))
    fi
done

printf 'CLEANUP_REQUEST_ID=%s\n' "$REQUEST_ID"
if [ "$removed" -gt 0 ]; then
    printf '%s\n' 'CLEANUP_STATUS=REMOVED'
else
    printf '%s\n' 'CLEANUP_STATUS=NOT_FOUND'
fi
printf 'CLEANUP_FILES=%s\n' "$removed"
exit 0
