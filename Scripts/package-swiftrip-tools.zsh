#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$ROOT_DIR"
ARTIFACTS_ROOT="$TOOLS_DIR/Artifacts"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
PACKAGE_DIR="$TOOLS_DIR/Packages"
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

PACKAGE_VERSION="${SWIFTRIP_TOOLS_PACKAGE_VERSION:-$(json_value "$MANIFEST_FILE" version)}"
ARTIFACT_NAME="${SWIFTRIP_TOOLS_ARTIFACT_NAME:-$(json_value "$MANIFEST_FILE" artifactName)}"
EXPECTED_SHA256="${SWIFTRIP_TOOLS_EXPECTED_SHA256:-$(json_value "$MANIFEST_FILE" sha256)}"
PACKAGE_PATH="$PACKAGE_DIR/$ARTIFACT_NAME"
TAR_PATH="$PACKAGE_DIR/${ARTIFACT_NAME:r}"

echo "SwiftRip-Tools package"
echo "Root:     $ROOT_DIR"
echo "Manifest: $MANIFEST_FILE"
echo "Version:  $PACKAGE_VERSION"
echo "Package:  $PACKAGE_PATH"
echo "Arch:     $TOOLS_ARCH"

SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$VERIFY_SCRIPT"

mkdir -p "$PACKAGE_DIR"
rm -f "$PACKAGE_PATH"
rm -f "$TAR_PATH"

echo ""
echo "Creating package..."
COPYFILE_DISABLE=1 tar -cf "$TAR_PATH" \
    -C "$ARTIFACTS_ROOT" \
    "macos-$TOOLS_ARCH/HandBrakeCLI" \
    "macos-$TOOLS_ARCH/libdvdcss.2.dylib"
gzip -n "$TAR_PATH"

ACTUAL_SHA256="$(sha256_file "$PACKAGE_PATH")"

echo ""
echo "Package SHA-256:"
echo "$ACTUAL_SHA256  $PACKAGE_PATH"

if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo ""
    echo "WARNING: Package checksum does not match the manifest."
    echo "Manifest: $EXPECTED_SHA256"
    echo "Package:  $ACTUAL_SHA256"
    echo "Update $MANIFEST_FILE before publishing this package."
fi
