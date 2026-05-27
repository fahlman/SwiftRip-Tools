#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Checking whitespace..."
git -C "$ROOT_DIR" diff --check

echo "Checking generated artifacts are not tracked..."
TRACKED_GENERATED="$(
    git -C "$ROOT_DIR" ls-files \
        Artifacts \
        Build \
        Packages \
        Source \
        .DS_Store
)"
if [[ -n "$TRACKED_GENERATED" ]]; then
    echo "ERROR: Generated/vendor/build artifacts are tracked:"
    echo "$TRACKED_GENERATED"
    exit 1
fi

echo "Checking shell script syntax..."
while IFS= read -r script_path; do
    /bin/zsh -n "$ROOT_DIR/$script_path"
done < <(
    git -C "$ROOT_DIR" ls-files \
        'Scripts/*.zsh' \
        'Scripts/**/*.zsh'
)

echo "Checking JSON manifests..."
while IFS= read -r json_path; do
    /usr/bin/plutil -convert json -o /dev/null "$ROOT_DIR/$json_path"
done < <(
    git -C "$ROOT_DIR" ls-files 'Manifest/*.json'
)

echo "Checking manifest release host..."
while IFS= read -r manifest_path; do
    manifest_url="$(/usr/bin/plutil -extract url raw -o - "$ROOT_DIR/$manifest_path")"
    case "$manifest_url" in
        https://github.com/fahlman/SwiftRip-Tools/releases/download/*)
            ;;
        *)
            echo "ERROR: Manifest URL must point at fahlman/SwiftRip-Tools release assets:"
            echo "$manifest_path: $manifest_url"
            exit 1
            ;;
    esac
done < <(
    git -C "$ROOT_DIR" ls-files 'Manifest/*.json'
)

echo "SwiftRip-Tools repository validation passed."
