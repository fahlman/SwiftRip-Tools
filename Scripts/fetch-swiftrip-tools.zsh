#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$ROOT_DIR"
DOWNLOAD_DIR="$TOOLS_DIR/Packages"
ARTIFACTS_ROOT="$TOOLS_DIR/Artifacts"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-swiftrip-tools.zsh"
COMMON_SCRIPT="$SCRIPT_DIR/lib/common.zsh"

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
    echo "ERROR: Missing SwiftRip-Tools manifest for $TOOLS_ARCH:"
    echo "$MANIFEST_FILE"
    exit 1
fi

VERSION="$(json_value "$MANIFEST_FILE" version)"
ARTIFACT_NAME="$(json_value "$MANIFEST_FILE" artifactName)"
ARTIFACT_URL="$(json_value "$MANIFEST_FILE" url)"
EXPECTED_SHA256="$(json_value "$MANIFEST_FILE" sha256)"
PACKAGE_PATH="$DOWNLOAD_DIR/$ARTIFACT_NAME"

echo "SwiftRip-Tools fetch"
echo "Root:     $ROOT_DIR"
echo "Manifest: $MANIFEST_FILE"
echo "Version:  $VERSION"
echo "Package:  $PACKAGE_PATH"
echo "Arch:     $TOOLS_ARCH"

mkdir -p "$DOWNLOAD_DIR"

if [[ ! -f "$PACKAGE_PATH" ]]; then
    echo ""
    echo "Downloading SwiftRip-Tools package..."
    curl -fL "$ARTIFACT_URL" -o "$PACKAGE_PATH"
else
    echo ""
    echo "Using existing package: $PACKAGE_PATH"
fi

echo ""
echo "Verifying package checksum..."
ACTUAL_SHA256="$(sha256_file "$PACKAGE_PATH")"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "ERROR: SwiftRip-Tools package checksum mismatch."
    echo "Expected: $EXPECTED_SHA256"
    echo "Actual:   $ACTUAL_SHA256"
    exit 1
fi

echo ""
echo "Extracting SwiftRip-Tools artifacts..."
rm -rf "$ARTIFACTS_ROOT/macos-$TOOLS_ARCH"
mkdir -p "$ARTIFACTS_ROOT"
tar -xzf "$PACKAGE_PATH" -C "$ARTIFACTS_ROOT"

echo ""
SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$VERIFY_SCRIPT"

echo ""
echo "SwiftRip-Tools fetch complete."
