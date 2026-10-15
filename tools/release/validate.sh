#!/bin/sh

set -eu
PACKAGE_DIR=${1:-}
if [ -z "$PACKAGE_DIR" ]; then printf '%s\n' 'Usage: validate.sh PACKAGE_DIR' >&2; exit 2; fi

fail() { printf 'VALIDATION_FAILED=%s\n' "$1" >&2; exit 1; }

[ -f "$PACKAGE_DIR/SKILL.md" ] || fail 'SKILL_MISSING'
[ -f "$PACKAGE_DIR/LICENSE" ] || fail 'LICENSE_MISSING'
[ -f "$PACKAGE_DIR/config/client.conf" ] || fail 'CLIENT_CONFIG_MISSING'
[ -d "$PACKAGE_DIR/scripts" ] || fail 'SCRIPTS_MISSING'
[ -d "$PACKAGE_DIR/sub-skills" ] || fail 'SUB_SKILLS_MISSING'

name=$(sed -n 's/^name:[[:space:]]*//p' "$PACKAGE_DIR/SKILL.md" | head -n 1)
[ "$name" = 'mcc-offer-skill' ] || fail 'SKILL_NAME_INVALID'

if grep -Eq '^LOCAL_CLIENT_ID=.+|^LOCAL_CONFIG_VERSION=.+|^LOCAL_LAST_SYNC_DATE=.+' "$PACKAGE_DIR/config/client.conf"; then
    fail 'LOCAL_STATE_NOT_EMPTY'
fi

for forbidden in test .git .kiro .idea config/data; do
    [ ! -e "$PACKAGE_DIR/$forbidden" ] || fail "FORBIDDEN_PATH_$forbidden"
done

for script in "$PACKAGE_DIR/scripts"/*.sh; do
    [ -f "$script" ] || continue
    sh -n "$script" || fail "SHELL_SYNTAX_$(basename "$script")"
done

printf '%s\n' 'VALIDATION=PASS'
exit 0
