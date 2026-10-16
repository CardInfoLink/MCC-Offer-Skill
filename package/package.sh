#!/bin/sh

set -eu

SOURCE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PACKAGE_DIR="${SOURCE_ROOT}/dist"
TESTING=false

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --testing) TESTING=true; shift ;;
    *) shift ;;
  esac
done

fail() { printf 'ERROR=%s\n' "$1" >&2; exit 1; }

# Extract YAML frontmatter from SKILL.md
extract_frontmatter() {
  local key="$1"
  local file="$2"
  local in_metadata=false
  
  awk -v key="$key" -v in_meta=0 '
    /^---$/ { if (NR == 1) { start=1; next } else { exit } }
    start == 1 && /^metadata:/ { in_meta=1; next }
    start == 1 && in_meta && /^  '"$key"':/ {
      match($0, /: (.*)/, arr)
      sub(/^ *'"$key"': */, "")
      print
      exit
    }
    start == 1 && /^[^ ]/ && in_meta { exit }
    start == 1 && !in_meta && /^'"$key"':/ {
      match($0, /: (.*)/, arr)
      sub(/^ *'"$key"': */, "")
      print
      exit
    }
  ' "$file"
}

# Verify SKILL.md structure
[ -f "${SOURCE_ROOT}/SKILL.md" ] || fail "MISSING_SKILL.md"
[ -f "${SOURCE_ROOT}/platforms/workbuddy/manifest.yaml" ] || fail "MISSING_workbuddy_manifest"
[ -f "${SOURCE_ROOT}/.claude-plugin/plugin.json" ] || fail "MISSING_plugin.json"

# Extract metadata from SKILL.md
NAME=$(extract_frontmatter "name" "${SOURCE_ROOT}/SKILL.md")
VERSION=$(extract_frontmatter "version" "${SOURCE_ROOT}/SKILL.md" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
SLUG=$(extract_frontmatter "slug" "${SOURCE_ROOT}/SKILL.md" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
DISPLAY_NAME=$(extract_frontmatter "displayName" "${SOURCE_ROOT}/SKILL.md" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
SUMMARY=$(extract_frontmatter "summary" "${SOURCE_ROOT}/SKILL.md" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
DESCRIPTION=$(extract_frontmatter "description" "${SOURCE_ROOT}/SKILL.md")
LICENSE=$(extract_frontmatter "license" "${SOURCE_ROOT}/SKILL.md" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
AUTHOR=$(extract_frontmatter "author" "${SOURCE_ROOT}/SKILL.md" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
HOMEPAGE=$(extract_frontmatter "homepage" "${SOURCE_ROOT}/SKILL.md" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
CATEGORY=$(extract_frontmatter "category" "${SOURCE_ROOT}/SKILL.md" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

[ -n "$NAME" ] || fail "MISSING_name_in_SKILL"
[ -n "$VERSION" ] || fail "MISSING_version_in_SKILL"
[ -n "$SLUG" ] || fail "MISSING_slug_in_metadata"

WORKBUDDY_DIR="${PACKAGE_DIR}/mcc-offer-skill-workbuddy-${VERSION}"

mkdir -p "${WORKBUDDY_DIR}"

# Copy source files
cp -r \
  "${SOURCE_ROOT}/SKILL.md" \
  "${SOURCE_ROOT}/scripts" \
  "${SOURCE_ROOT}/sub-skills" \
  "${SOURCE_ROOT}/config" \
  "${SOURCE_ROOT}/platforms/workbuddy/manifest.yaml" \
  "${WORKBUDDY_DIR}/"

# Apply testing mode: replace production URL with testing URL
if [ "$TESTING" = true ]; then
  CLIENT_CONF="${WORKBUDDY_DIR}/config/client.conf"
  if [ -f "$CLIENT_CONF" ]; then
    sed -i 's|API_BASE_URL=https://offercent\.azpromotion\.com|API_BASE_URL=https://offercent.ipay.so|g' "$CLIENT_CONF"
  fi
fi

# Create WorkBuddy-specific frontmatter in SKILL.md
SKILL_MD_PATH="${WORKBUDDY_DIR}/SKILL.md"
TEMP_SKILL_MD="${SKILL_MD_PATH}.tmp"

# Extract body after frontmatter
if head -n 1 "$SKILL_MD_PATH" | grep -q '^---'; then
  tail_n +2 "$SKILL_MD_PATH" | awk '/^---$/{found=1; next} found' > "$TEMP_SKILL_MD" || true
  BODY=$(cat "$TEMP_SKILL_MD")
else
  BODY=$(cat "$SKILL_MD_PATH")
fi

# Create WorkBuddy frontmatter (includes all fields)
cat > "$SKILL_MD_PATH" << EOF
---
name: ${NAME}
slug: ${SLUG}
displayName: ${DISPLAY_NAME}
version: ${VERSION}
summary: ${SUMMARY}
description: ${DESCRIPTION}
license: ${LICENSE}
compatibility: Requires POSIX Shell or Windows PowerShell, curl/curl.exe, and network access to the configured EverySkill API.
---
EOF

echo "$BODY" >> "$SKILL_MD_PATH"
rm -f "$TEMP_SKILL_MD"

# Create skills/ subdirectory structure
[ -d "${WORKBUDDY_DIR}/skills/mcc-offer-skill" ] || mkdir -p "${WORKBUDDY_DIR}/skills/mcc-offer-skill"
cp -r \
  "${WORKBUDDY_DIR}/SKILL.md" \
  "${WORKBUDDY_DIR}/scripts" \
  "${WORKBUDDY_DIR}/sub-skills" \
  "${WORKBUDDY_DIR}/config" \
  "${WORKBUDDY_DIR}/skills/mcc-offer-skill}/"

# Create/update plugin.json
cat > "${WORKBUDDY_DIR}/.claude-plugin/plugin.json" 2>/dev/null || mkdir -p "${WORKBUDDY_DIR}/.claude-plugin" && cat > "${WORKBUDDY_DIR}/.claude-plugin/plugin.json" << EOF
{
  "name": "${NAME}",
  "version": "${VERSION}",
  "description": "${DESCRIPTION}",
  "author": {
    "name": "${AUTHOR}"
  },
  "homepage": "${HOMEPAGE}",
  "repository": "https://github.com/CardInfoLink/MCC-Offer-Skill",
  "license": "${LICENSE}",
  "keywords": [
    "agent-skills",
    "mastercard",
    "credit-card",
    "offers"
  ]
}
EOF

# Create/update marketplace.json
MARKETPLACE_NAME="${SLUG}-marketplace"
cat > "${WORKBUDDY_DIR}/.claude-plugin/marketplace.json" << EOF
{
  "name": "${MARKETPLACE_NAME}",
  "description": "${DISPLAY_NAME} 插件目录。",
  "owner": {
    "name": "${AUTHOR}"
  },
  "plugins": [
    {
      "name": "${NAME}",
      "description": "${DESCRIPTION}",
      "author": {
        "name": "${AUTHOR}"
      },
      "category": "${CATEGORY}",
      "source": ".",
      "strict": false,
      "homepage": "${HOMEPAGE}"
    }
  ]
}
EOF

# Package into ZIP
cd "${PACKAGE_DIR}"
SUFFIX=$([ "$TESTING" = true ] && echo '-testing' || echo '')
ZIP_FILE="mcc-offer-skill-workbuddy-${VERSION}${SUFFIX}.zip"
if command -v zip >/dev/null 2>&1; then
  zip -r "${ZIP_FILE}" "mcc-offer-skill-workbuddy-${VERSION}" >/dev/null
else
  fail "zip_command_not_found"
fi

# Output results
printf '%s\n' "NAME=${NAME}"
printf '%s\n' "VERSION=${VERSION}"
printf '%s\n' "SLUG=${SLUG}"
printf '%s\n' "DISPLAY_NAME=${DISPLAY_NAME}"
printf '%s\n' "PACKAGE_PATH=${WORKBUDDY_DIR}"
printf '%s\n' "ZIP_PATH=${PACKAGE_DIR}/${ZIP_FILE}"
printf '%s\n' "TESTING=${TESTING}"
printf '%s\n' "PACKAGE=SUCCESS"
