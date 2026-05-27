#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HANDBRAKE_SCRIPT="$SCRIPT_DIR/build-handbrakecli.zsh"
LIBDVDCSS_SCRIPT="$SCRIPT_DIR/build-libdvdcss.zsh"
ISSUE_BODY_PATH="${RUNNER_TEMP:-/tmp}/swiftriptools-upstream-update.md"

read_assignment() {
    local file_path="$1"
    local variable_name="$2"
    local value

    value="$(/usr/bin/awk -F'"' -v name="$variable_name" '$0 ~ "^" name "=" { print $2; exit }' "$file_path")"
    if [[ -z "$value" ]]; then
        echo "ERROR: Could not read $variable_name from $file_path" >&2
        exit 1
    fi

    print -r -- "$value"
}

version_latest() {
    /usr/bin/python3 - "$@" <<'PY'
import re
import sys

versions = []
for raw in sys.argv[1:]:
    match = re.search(r"([0-9]+(?:\.[0-9]+){1,3})", raw)
    if match:
        versions.append(match.group(1))

if not versions:
    raise SystemExit("No version strings were supplied")

def key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))

print(max(versions, key=key))
PY
}

version_greater_than() {
    /usr/bin/python3 - "$1" "$2" <<'PY'
import sys

left = tuple(int(part) for part in sys.argv[1].split("."))
right = tuple(int(part) for part in sys.argv[2].split("."))
width = max(len(left), len(right))
left = left + (0,) * (width - len(left))
right = right + (0,) * (width - len(right))
raise SystemExit(0 if left > right else 1)
PY
}

github_api_curl_args=(
    -fsSL
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28"
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    github_api_curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

echo "Checking pinned upstream tool versions..."

current_handbrake_version="$(read_assignment "$HANDBRAKE_SCRIPT" "HANDBRAKE_VERSION")"
current_libdvdcss_version="$(read_assignment "$LIBDVDCSS_SCRIPT" "LIBDVDCSS_VERSION")"

handbrake_json="$(curl "${github_api_curl_args[@]}" "https://api.github.com/repos/HandBrake/HandBrake/releases/latest")"
latest_handbrake_version="$(/usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))' <<< "$handbrake_json")"

libdvdcss_tags="$(
    git ls-remote --tags https://code.videolan.org/videolan/libdvdcss.git \
        | /usr/bin/awk -F/ '/refs\/tags\// && $0 !~ /\^\{\}$/ { print $NF }'
)"
latest_libdvdcss_version="$(version_latest ${(f)libdvdcss_tags})"

handbrake_update="false"
libdvdcss_update="false"
if version_greater_than "$latest_handbrake_version" "$current_handbrake_version"; then
    handbrake_update="true"
fi
if version_greater_than "$latest_libdvdcss_version" "$current_libdvdcss_version"; then
    libdvdcss_update="true"
fi

update_available="false"
if [[ "$handbrake_update" == "true" || "$libdvdcss_update" == "true" ]]; then
    update_available="true"
fi

cat > "$ISSUE_BODY_PATH" <<EOF
# Upstream tool updates

SwiftRip-Tools found upstream component versions that should be reviewed.

| Component | Current | Latest | Update available |
| --- | --- | --- | --- |
| HandBrake | $current_handbrake_version | $latest_handbrake_version | $handbrake_update |
| libdvdcss | $current_libdvdcss_version | $latest_libdvdcss_version | $libdvdcss_update |

## Review checklist

- Update the pinned version, commit, or SHA-256 in the matching build script.
- Sync the SwiftRip-HandBrake fork and create a new pinned fork tag if HandBrake changed.
- Rebuild and verify the Apple Silicon package.
- Rebuild and verify the Intel package.
- Publish replacement SwiftRip-Tools release assets.
- Update SwiftRip's tool manifests to the new release tag and checksums.
- Run the signed, sandboxed SwiftRip smoke test with a real DVD.
EOF

echo ""
echo "HandBrake: current $current_handbrake_version, latest $latest_handbrake_version"
echo "libdvdcss: current $current_libdvdcss_version, latest $latest_libdvdcss_version"

if [[ "$update_available" == "true" ]]; then
    echo "Upstream updates are available."
else
    echo "Pinned upstream tools are up to date."
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        print -r -- "update_available=$update_available"
        print -r -- "issue_title=Update SwiftRip-Tools upstream components"
        print -r -- "issue_body_path=$ISSUE_BODY_PATH"
    } >> "$GITHUB_OUTPUT"
fi
