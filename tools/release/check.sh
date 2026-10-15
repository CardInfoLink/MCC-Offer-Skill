#!/bin/sh

set -eu

SOURCE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
fail() { printf 'CHECK_FAILED=%s\n' "$1" >&2; exit 1; }

for required in \
    SKILL.md README.md LICENSE CHANGELOG.md \
    scripts/init.sh scripts/call.sh scripts/clean.sh \
    scripts/init.ps1 scripts/call.ps1 scripts/clean.ps1 \
    sub-skills config/client.conf config/tags.txt config/regions.txt config/banks.txt \
    .claude-plugin/plugin.json .claude-plugin/marketplace.json \
    platforms/workbuddy/manifest.yaml platforms/npm/package.json; do
    [ -e "$SOURCE_ROOT/$required" ] || fail "MISSING_SOURCE=$required"
done

name=$(sed -n 's/^name:[[:space:]]*//p' "$SOURCE_ROOT/SKILL.md" | head -n 1)
[ "$name" = 'mcc-offer-skill' ] || fail 'SKILL_NAME_INVALID'

if grep -Eq '^LOCAL_CLIENT_ID=.+|^LOCAL_CONFIG_VERSION=.+|^LOCAL_LAST_SYNC_DATE=.+' "$SOURCE_ROOT/config/client.conf"; then
    fail 'CLIENT_CONFIG_LOCAL_STATE_NOT_EMPTY'
fi

if [ -d "$SOURCE_ROOT/config/data/req" ] && find "$SOURCE_ROOT/config/data/req" -type f ! -name .gitkeep | grep -q .; then
    fail 'REQUEST_RUNTIME_DATA_PRESENT'
fi
if [ -d "$SOURCE_ROOT/config/data/res" ] && find "$SOURCE_ROOT/config/data/res" -type f ! -name .gitkeep | grep -q .; then
    fail 'RESPONSE_RUNTIME_DATA_PRESENT'
fi

command -v node >/dev/null 2>&1 || fail 'NODE_MISSING_FOR_JSON_CHECK'
ROOT="$SOURCE_ROOT" node <<'NODE'
const fs = require('fs');
const path = require('path');
const root = process.env.ROOT;
const readJson = (relative) => JSON.parse(fs.readFileSync(path.join(root, relative), 'utf8'));
const plugin = readJson('.claude-plugin/plugin.json');
const marketplace = readJson('.claude-plugin/marketplace.json');
const npm = readJson('platforms/npm/package.json');
if (plugin.name !== 'mcc-offer-skill') throw new Error('PLUGIN_NAME_INVALID');
if (!Array.isArray(marketplace.plugins) || marketplace.plugins.length < 1) throw new Error('MARKETPLACE_PLUGINS_MISSING');
const entry = marketplace.plugins.find((item) => item.name === 'mcc-offer-skill');
if (!entry || !entry.source || entry.source.source !== 'git-subdir') throw new Error('MARKETPLACE_SOURCE_INVALID');
if (entry.source.path !== '.') throw new Error('MARKETPLACE_PATH_INVALID');
if (!Array.isArray(entry.skills) || !entry.skills.includes('./')) throw new Error('MARKETPLACE_SKILL_PATH_INVALID');
if (npm.name !== 'mcc-offer-skill' || npm.private === true) throw new Error('NPM_METADATA_INVALID');
NODE

if ! grep -Eq '^name:[[:space:]]*mcc-offer-skill$' "$SOURCE_ROOT/platforms/workbuddy/manifest.yaml"; then fail 'WORKBUDDY_NAME_INVALID'; fi
if ! grep -Eq '^entry:[[:space:]]*SKILL\.md$' "$SOURCE_ROOT/platforms/workbuddy/manifest.yaml"; then fail 'WORKBUDDY_ENTRY_INVALID'; fi

for script in "$SOURCE_ROOT/scripts"/*.sh "$SOURCE_ROOT/tools/release/check.sh"; do
    [ -f "$script" ] || continue
    sh -n "$script" || fail "SHELL_SYNTAX_$(basename "$script")"
done

printf '%s\n' 'CHECK=PASS'
