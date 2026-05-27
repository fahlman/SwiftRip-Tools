#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$ROOT_DIR"
COMMON_SCRIPT="$SCRIPT_DIR/lib/common.zsh"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
PACKAGE_DIR="$TOOLS_DIR/Packages"
REPOSITORY="${SWIFTRIP_TOOLS_REPOSITORY:-fahlman/SwiftRip-Tools}"

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            TOOLS_ARCH="${2:-}"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--arch arm64|x86_64]"
            exit 64
            ;;
    esac
done

assert_supported_tools_arch "$TOOLS_ARCH"

MANIFEST_FILE="$(manifest_file_for_arch "$TOOLS_DIR" "$TOOLS_ARCH")"

if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "ERROR: Missing SwiftRip-Tools manifest:"
    echo "$MANIFEST_FILE"
    exit 1
fi

ARTIFACT_NAME="$(json_value "$MANIFEST_FILE" artifactName)"
EXPECTED_SHA256="$(json_value "$MANIFEST_FILE" sha256)"
PACKAGE_PATH="$PACKAGE_DIR/$ARTIFACT_NAME"
RELEASE_URL="$(json_value "$MANIFEST_FILE" url)"
RELEASE_TAG="$(basename "$(dirname "$RELEASE_URL")")"

if [[ ! -f "$PACKAGE_PATH" ]]; then
    echo "ERROR: Missing package:"
    echo "$PACKAGE_PATH"
    echo ""
    echo "Create it first with:"
    echo "$TOOLS_DIR/Scripts/package-swiftrip-tools.zsh --arch $TOOLS_ARCH"
    exit 1
fi

ACTUAL_SHA256="$(sha256_file "$PACKAGE_PATH")"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "ERROR: Package checksum does not match manifest."
    echo "Expected: $EXPECTED_SHA256"
    echo "Actual:   $ACTUAL_SHA256"
    exit 1
fi

echo "SwiftRip-Tools publish"
echo "Repository: $REPOSITORY"
echo "Tag:        $RELEASE_TAG"
echo "Package:    $PACKAGE_PATH"
echo "SHA-256:    $ACTUAL_SHA256"
echo "Arch:       $TOOLS_ARCH"

if command -v gh >/dev/null 2>&1; then
    echo ""
    echo "Publishing with GitHub CLI..."
    if gh release view "$RELEASE_TAG" --repo "$REPOSITORY" >/dev/null 2>&1; then
        gh release upload "$RELEASE_TAG" "$PACKAGE_PATH" --repo "$REPOSITORY" --clobber
    else
        gh release create "$RELEASE_TAG" "$PACKAGE_PATH" \
            --repo "$REPOSITORY" \
            --title "$RELEASE_TAG" \
            --notes "SwiftRip bundled tool package. SHA-256: $ACTUAL_SHA256"
    fi
    exit 0
fi

echo ""
echo "GitHub CLI was not found, so publish this package in the browser:"
echo "1. Open: https://github.com/$REPOSITORY/releases/new?tag=$RELEASE_TAG"
echo "2. Set Release title to: $RELEASE_TAG"
echo "3. Attach this file:"
echo "$PACKAGE_PATH"
echo "4. Publish the release."
echo ""
echo "Opening the release page and revealing the package in Finder..."
open "https://github.com/$REPOSITORY/releases/new?tag=$RELEASE_TAG"
open -R "$PACKAGE_PATH"
