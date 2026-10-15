#!/bin/sh

set -eu

SOURCE_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PROFILE=testing
VERSION=0.1.0
OUTPUT_ROOT="$SOURCE_ROOT/dist"
PLATFORM=agent-skill

usage() {
    printf '%s\n' 'Usage: package.sh [--profile testing|product] [--version VERSION] [--output DIR] [--platform agent-skill|claude-plugin|cursor|openclaw|workbuddy|npm|all]'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; PROFILE=$2; shift 2 ;;
        --version) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; VERSION=$2; shift 2 ;;
        --output) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; OUTPUT_ROOT=$2; shift 2 ;;
        --platform) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; PLATFORM=$2; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

case "$PROFILE" in testing|product) ;; *) printf '%s\n' 'PROFILE_INVALID' >&2; exit 2 ;; esac
case "$VERSION" in ""|*[!A-Za-z0-9._-]*) printf '%s\n' 'VERSION_INVALID' >&2; exit 2 ;; esac
case "$PLATFORM" in agent-skill|claude-plugin|cursor|openclaw|workbuddy|npm|all) ;; *) printf '%s\n' 'PLATFORM_INVALID' >&2; exit 2 ;; esac

PROFILE_FILE="$SOURCE_ROOT/config/client.$PROFILE"
for required in SKILL.md README.md LICENSE CHANGELOG.md scripts sub-skills config/tags.txt config/regions.txt config/banks.txt; do
    if [ ! -e "$SOURCE_ROOT/$required" ]; then
        printf 'MISSING_SOURCE=%s\n' "$required" >&2
        exit 3
    fi
done
if [ ! -e "$PROFILE_FILE" ]; then
    printf 'MISSING_SOURCE=%s\n' "$PROFILE_FILE" >&2
    exit 3
fi

copy_core_tree() {
    destination=$1
    mkdir -p "$destination/config"
    cp "$SOURCE_ROOT/SKILL.md" "$destination/SKILL.md"
    cp "$SOURCE_ROOT/README.md" "$destination/README.md"
    cp "$SOURCE_ROOT/LICENSE" "$destination/LICENSE"
    cp "$SOURCE_ROOT/CHANGELOG.md" "$destination/CHANGELOG.md"
    cp "$SOURCE_ROOT/config/tags.txt" "$destination/config/tags.txt"
    cp "$SOURCE_ROOT/config/regions.txt" "$destination/config/regions.txt"
    cp "$SOURCE_ROOT/config/banks.txt" "$destination/config/banks.txt"
    cp "$PROFILE_FILE" "$destination/config/client.conf"
    sed -i 's/^LOCAL_CLIENT_ID=.*/LOCAL_CLIENT_ID=/; s/^LOCAL_CONFIG_VERSION=.*/LOCAL_CONFIG_VERSION=/; s/^LOCAL_LAST_SYNC_DATE=.*/LOCAL_LAST_SYNC_DATE=/' "$destination/config/client.conf"
    for dir in scripts sub-skills references assets docs; do
        if [ -d "$SOURCE_ROOT/$dir" ]; then
            mkdir -p "$destination/$dir"
            cp -R "$SOURCE_ROOT/$dir/." "$destination/$dir/"
        fi
    done
}

remove_excluded_content() {
    package_dir=$1
    rm -rf "$package_dir/config/data" "$package_dir/test" "$package_dir/.git" "$package_dir/.kiro" "$package_dir/.idea" "$package_dir/dist"
}

new_zip() {
    package_dir=$1
    package_name=$2
    rm -f "$OUTPUT_ROOT/$package_name.zip"
    if command -v zip >/dev/null 2>&1; then
        (cd "$OUTPUT_ROOT" && zip -qr "$package_name.zip" "$package_name")
        printf 'ARCHIVE=%s\n' "$OUTPUT_ROOT/$package_name.zip"
    elif command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
        archive_win=$(cygpath -w "$OUTPUT_ROOT/$package_name.zip")
        package_win=$(cygpath -w "$package_dir")
        powershell.exe -NoProfile -Command "Compress-Archive -Path '$package_win' -DestinationPath '$archive_win' -Force"
        printf 'ARCHIVE=%s\n' "$OUTPUT_ROOT/$package_name.zip"
    else
        printf '%s\n' 'ZIP_NOT_AVAILABLE'
    fi
}

build_package() {
    kind=$1
    if [ "$kind" = agent-skill ]; then
        package_name="mcc-offer-skill-$PROFILE-$VERSION"
    else
        package_name="mcc-offer-skill-$kind-$PROFILE-$VERSION"
    fi
    package_dir="$OUTPUT_ROOT/$package_name"
    rm -rf "$package_dir"
    mkdir -p "$OUTPUT_ROOT"

    case "$kind" in
        agent-skill)
            copy_core_tree "$package_dir"
            ;;
        claude-plugin)
            mkdir -p "$package_dir/skills/mcc-offer-skill"
            copy_core_tree "$package_dir/skills/mcc-offer-skill"
            cp -R "$SOURCE_ROOT/platforms/claude-code/.claude-plugin" "$package_dir/"
            sed -i "s/\"version\": \"0.1.0\"/\"version\": \"$VERSION\"/g" "$package_dir/.claude-plugin/plugin.json" "$package_dir/.claude-plugin/marketplace.json"
            ;;
        cursor)
            copy_core_tree "$package_dir/.cursor/skills/mcc-offer-skill"
            ;;
        openclaw)
            copy_core_tree "$package_dir/skills/mcc-offer-skill"
            ;;
        workbuddy)
            copy_core_tree "$package_dir"
            cp "$SOURCE_ROOT/platforms/workbuddy/manifest.yaml" "$package_dir/manifest.yaml"
            sed -i "s/^version:.*/version: $VERSION/" "$package_dir/manifest.yaml"
            ;;
        npm)
            copy_core_tree "$package_dir"
            cp "$SOURCE_ROOT/platforms/npm/package.json" "$package_dir/package.json"
            sed -i "s|\"version\": \"[^\"]*\"|\"version\": \"$VERSION\"|" "$package_dir/package.json"
            ;;
    esac

    remove_excluded_content "$package_dir"
    new_zip "$package_dir" "$package_name"
    if [ "$kind" = npm ] && command -v npm >/dev/null 2>&1; then
        (cd "$package_dir" && npm pack --ignore-scripts --pack-destination "$OUTPUT_ROOT")
    fi
    printf 'PACKAGE_DIR=%s\nPROFILE=%s\nVERSION=%s\nPLATFORM=%s\n' "$package_dir" "$PROFILE" "$VERSION" "$kind"
}

if [ "$PLATFORM" = all ]; then
    for kind in agent-skill claude-plugin cursor openclaw workbuddy npm; do build_package "$kind"; done
else
    build_package "$PLATFORM"
fi
