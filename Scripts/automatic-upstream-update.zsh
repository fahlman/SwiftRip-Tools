#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMON_SCRIPT="$SCRIPT_DIR/lib/common.zsh"
SYNC_SCRIPT="$SCRIPT_DIR/sync-upstream-sources.zsh"
PREPARE_SCRIPT="$SCRIPT_DIR/prepare-tool-update.zsh"
TOOLS_REPOSITORY="${SWIFTRIP_TOOLS_REPOSITORY:-fahlman/SwiftRip-Tools}"
SWIFTRIP_REPOSITORY="${SWIFTRIP_APP_REPOSITORY:-fahlman/SwiftRip}"
TARGET_BRANCH="${SWIFTRIP_TOOLS_BRANCH:-main}"
HANDBRAKE_VERSION=""
LIBDVDCSS_VERSION=""
AUTOMATION_TOKEN="${SWIFTRIP_AUTOMATION_TOKEN:-${GITHUB_TOKEN:-}}"
WORK_DIR=""
OUTPUT_DIR=""

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

usage() {
    cat <<'USAGE'
Usage: Scripts/automatic-upstream-update.zsh --handbrake-version VERSION --libdvdcss-version VERSION

Synchronize exact upstream source tags, build and package both architectures,
publish a SwiftRip-Tools GitHub release, update this repository's pins, and
dispatch the exact tool revision to SwiftRip.

Required environment:
  SWIFTRIP_AUTOMATION_TOKEN  Token with write access to SwiftRip-Tools,
                             SwiftRip-HandBrake, SwiftRip-libdvdcss, and the
                             SwiftRip repository dispatch API.

Options:
  --handbrake-version VERSION  HandBrake version to publish.
  --libdvdcss-version VERSION  libdvdcss version to publish.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --handbrake-version)
            HANDBRAKE_VERSION="${2:-}"
            shift 2
            ;;
        --libdvdcss-version)
            LIBDVDCSS_VERSION="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

require_value "HandBrake version" "$HANDBRAKE_VERSION"
require_value "libdvdcss version" "$LIBDVDCSS_VERSION"
require_value "SWIFTRIP_AUTOMATION_TOKEN" "$AUTOMATION_TOKEN"
require_command git
require_command gh
require_command curl
require_command python3

if [[ ! "$HANDBRAKE_VERSION" =~ '^[0-9]+(\.[0-9]+){1,3}$' ]]; then
    echo "ERROR: Invalid HandBrake version: $HANDBRAKE_VERSION" >&2
    exit 64
fi
if [[ ! "$LIBDVDCSS_VERSION" =~ '^[0-9]+(\.[0-9]+){1,3}$' ]]; then
    echo "ERROR: Invalid libdvdcss version: $LIBDVDCSS_VERSION" >&2
    exit 64
fi

export GH_TOKEN="$AUTOMATION_TOKEN"

read_assignment() {
    local file_path="$1"
    local variable_name="$2"
    /usr/bin/awk -F'"' -v name="$variable_name" '$0 ~ "^" name "=" { print $2; exit }' "$file_path"
}

update_assignment() {
    local file_path="$1"
    local variable_name="$2"
    local value="$3"

    /usr/bin/python3 - "$file_path" "$variable_name" "$value" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
name = sys.argv[2]
value = sys.argv[3]
text = path.read_text(encoding="utf-8")
pattern = re.compile(rf'^{re.escape(name)}="[^"]*"$', re.MULTILINE)
replacement = f'{name}="{value}"'
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit(f"Could not update {name} in {path}; matches={count}")
path.write_text(text, encoding="utf-8")
PY
}

replace_text() {
    local file_path="$1"
    shift

    /usr/bin/python3 - "$file_path" "$@" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
arguments = sys.argv[2:]
if len(arguments) % 2:
    raise SystemExit("replace_text requires old/new pairs")

text = path.read_text(encoding="utf-8")
for index in range(0, len(arguments), 2):
    text = text.replace(arguments[index], arguments[index + 1])
path.write_text(text, encoding="utf-8")
PY
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swiftrip-automatic-update.XXXXXX")"
OUTPUT_DIR="$ROOT_DIR/PreparedToolUpdate"
trap 'rm -rf "$WORK_DIR"' EXIT

HANDBRAKE_SCRIPT="$SCRIPT_DIR/build-handbrakecli.zsh"
LIBDVDCSS_SCRIPT="$SCRIPT_DIR/build-libdvdcss.zsh"
OLD_HANDBRAKE_VERSION="$(read_assignment "$HANDBRAKE_SCRIPT" "HANDBRAKE_VERSION")"
OLD_HANDBRAKE_COMMIT="$(read_assignment "$HANDBRAKE_SCRIPT" "HANDBRAKE_SWIFTRIP_COMMIT")"
OLD_LIBDVDCSS_VERSION="$(read_assignment "$LIBDVDCSS_SCRIPT" "LIBDVDCSS_VERSION")"
OLD_LIBDVDCSS_COMMIT="$(read_assignment "$LIBDVDCSS_SCRIPT" "LIBDVDCSS_SWIFTRIP_COMMIT")"
OLD_PACKAGE_VERSION="handbrake-${OLD_HANDBRAKE_VERSION}-libdvdcss-${OLD_LIBDVDCSS_VERSION}"
PACKAGE_VERSION="handbrake-${HANDBRAKE_VERSION}-libdvdcss-${LIBDVDCSS_VERSION}"
RELEASE_TAG="$PACKAGE_VERSION"
RELEASE_NOTES_PATH="$OUTPUT_DIR/ReleaseNotes/${PACKAGE_VERSION}.md"

echo "SwiftRip automatic upstream update"
echo "HandBrake:  $HANDBRAKE_VERSION"
echo "libdvdcss:  $LIBDVDCSS_VERSION"
echo "Repository: $TOOLS_REPOSITORY"
echo "App repo:   $SWIFTRIP_REPOSITORY"

SOURCE_METADATA="$WORK_DIR/source.env"
SWIFTRIP_AUTOMATION_TOKEN="$AUTOMATION_TOKEN" \
    "$SYNC_SCRIPT" \
    --handbrake-version "$HANDBRAKE_VERSION" \
    --libdvdcss-version "$LIBDVDCSS_VERSION" \
    --output-file "$SOURCE_METADATA"

# The synchronization script writes only validated hexadecimal commits and
# version/tag values. Keep the generated metadata private to this job.
source "$SOURCE_METADATA"

SWIFTRIP_AUTOMATION_TOKEN="$AUTOMATION_TOKEN" \
    SWIFTRIP_HANDBRAKE_VERSION="$HANDBRAKE_VERSION" \
    SWIFTRIP_HANDBRAKE_REPOSITORY_URL="https://github.com/fahlman/SwiftRip-HandBrake.git" \
    SWIFTRIP_HANDBRAKE_SWIFTRIP_TAG="$handbrake_tag" \
    SWIFTRIP_HANDBRAKE_SWIFTRIP_COMMIT="$handbrake_commit" \
    SWIFTRIP_LIBDVDCSS_VERSION="$LIBDVDCSS_VERSION" \
    SWIFTRIP_LIBDVDCSS_REPOSITORY_URL="https://github.com/fahlman/SwiftRip-libdvdcss.git" \
    SWIFTRIP_LIBDVDCSS_SWIFTRIP_TAG="$libdvdcss_tag" \
    SWIFTRIP_LIBDVDCSS_SWIFTRIP_COMMIT="$libdvdcss_commit" \
    "$PREPARE_SCRIPT" \
    --handbrake-version "$HANDBRAKE_VERSION" \
    --libdvdcss-version "$LIBDVDCSS_VERSION" \
    --output-dir "$OUTPUT_DIR"

echo "Updating SwiftRip-Tools manifests and provenance..."
/bin/cp "$OUTPUT_DIR/Manifest/swiftrip-tools.json" "$ROOT_DIR/Manifest/swiftrip-tools.json"

update_assignment "$HANDBRAKE_SCRIPT" "HANDBRAKE_VERSION" "$HANDBRAKE_VERSION"
update_assignment "$HANDBRAKE_SCRIPT" "HANDBRAKE_SWIFTRIP_TAG" "$handbrake_tag"
update_assignment "$HANDBRAKE_SCRIPT" "HANDBRAKE_SWIFTRIP_COMMIT" "$handbrake_commit"
update_assignment "$LIBDVDCSS_SCRIPT" "LIBDVDCSS_VERSION" "$LIBDVDCSS_VERSION"
update_assignment "$LIBDVDCSS_SCRIPT" "LIBDVDCSS_SWIFTRIP_TAG" "$libdvdcss_tag"
update_assignment "$LIBDVDCSS_SCRIPT" "LIBDVDCSS_SWIFTRIP_COMMIT" "$libdvdcss_commit"

for documentation_path in README.md SOURCE_OFFER.md THIRD_PARTY_NOTICES.md; do
    replace_text "$ROOT_DIR/$documentation_path" \
        "$OLD_PACKAGE_VERSION" "$PACKAGE_VERSION" \
        "swiftrip-handbrake-$OLD_HANDBRAKE_VERSION" "$handbrake_tag" \
        "swiftrip-libdvdcss-$OLD_LIBDVDCSS_VERSION" "$libdvdcss_tag" \
        "$OLD_HANDBRAKE_COMMIT" "$handbrake_commit" \
        "$OLD_LIBDVDCSS_COMMIT" "$libdvdcss_commit" \
        "$OLD_HANDBRAKE_VERSION" "$HANDBRAKE_VERSION" \
        "$OLD_LIBDVDCSS_VERSION" "$LIBDVDCSS_VERSION" \
        "HandBrakeCLI $OLD_HANDBRAKE_VERSION" "HandBrakeCLI $HANDBRAKE_VERSION" \
        "libdvdcss $OLD_LIBDVDCSS_VERSION" "libdvdcss $LIBDVDCSS_VERSION"
done

if [[ ! -f "$RELEASE_NOTES_PATH" ]]; then
    echo "ERROR: Prepared release notes were not generated: $RELEASE_NOTES_PATH" >&2
    exit 1
fi

echo "Checking generated metadata before publishing..."
git -C "$ROOT_DIR" diff --check
"$SCRIPT_DIR/validate-repo.zsh"

typeset -a package_paths
package_paths=("$OUTPUT_DIR/Packages/"*.tar.gz)

echo "Publishing SwiftRip-Tools release $RELEASE_TAG..."
if gh release view "$RELEASE_TAG" --repo "$TOOLS_REPOSITORY" >/dev/null 2>&1; then
    if [[ "${SWIFTRIP_RELEASE_ALLOW_CLOBBER:-0}" != "1" ]]; then
        echo "ERROR: SwiftRip-Tools release already exists: $RELEASE_TAG" >&2
        echo "Set SWIFTRIP_RELEASE_ALLOW_CLOBBER=1 only for an intentional rerun." >&2
        exit 1
    fi
    gh release upload "$RELEASE_TAG" "${package_paths[@]}" --repo "$TOOLS_REPOSITORY" --clobber
else
    gh release create "$RELEASE_TAG" "${package_paths[@]}" \
        --repo "$TOOLS_REPOSITORY" \
        --target "$TARGET_BRANCH" \
        --title "$RELEASE_TAG" \
        --notes-file "$RELEASE_NOTES_PATH"
fi

echo "Committing updated SwiftRip-Tools pins..."
git -C "$ROOT_DIR" add \
    Manifest/swiftrip-tools.json \
    Scripts/build-handbrakecli.zsh \
    Scripts/build-libdvdcss.zsh \
    README.md \
    SOURCE_OFFER.md \
    THIRD_PARTY_NOTICES.md

if git -C "$ROOT_DIR" diff --cached --quiet; then
    echo "SwiftRip-Tools pins are already committed."
else
    git -C "$ROOT_DIR" config user.name "SwiftRip upstream automation"
    git -C "$ROOT_DIR" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git -C "$ROOT_DIR" commit -m "Update HandBrake $HANDBRAKE_VERSION and libdvdcss $LIBDVDCSS_VERSION"
fi

git -C "$ROOT_DIR" push origin "HEAD:$TARGET_BRANCH"
TOOLS_REVISION="$(git -C "$ROOT_DIR" rev-parse HEAD)"

echo "Dispatching tool update to SwiftRip at $TOOLS_REVISION..."
/usr/bin/python3 - "$SWIFTRIP_REPOSITORY" "$TOOLS_REVISION" "$PACKAGE_VERSION" "$RELEASE_TAG" "$HANDBRAKE_VERSION" "$handbrake_tag" "$handbrake_commit" "$LIBDVDCSS_VERSION" "$libdvdcss_tag" "$libdvdcss_commit" <<'PY' | gh api --method POST "repos/$SWIFTRIP_REPOSITORY/dispatches" --input -
import json
import sys

(
    repository,
    tools_revision,
    package_version,
    release_tag,
    handbrake_version,
    handbrake_tag,
    handbrake_commit,
    libdvdcss_version,
    libdvdcss_tag,
    libdvdcss_commit,
) = sys.argv[1:]

json.dump(
    {
        "event_type": "swiftrip-tools-updated",
        "client_payload": {
            "tools_repository": "fahlman/SwiftRip-Tools",
            "tools_revision": tools_revision,
            "package_version": package_version,
            "tools_release_tag": release_tag,
            "handbrake_version": handbrake_version,
            "handbrake_source_tag": handbrake_tag,
            "handbrake_source_commit": handbrake_commit,
            "libdvdcss_version": libdvdcss_version,
            "libdvdcss_source_tag": libdvdcss_tag,
            "libdvdcss_source_commit": libdvdcss_commit,
        },
    },
    sys.stdout,
)
PY

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        print -r -- "package_version=$PACKAGE_VERSION"
        print -r -- "release_tag=$RELEASE_TAG"
        print -r -- "tools_revision=$TOOLS_REVISION"
    } >> "$GITHUB_OUTPUT"
fi

echo "Automatic SwiftRip upstream update complete."
