#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
ARTIFACTS_ROOT="$TOOLS_DIR/Artifacts"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
PACKAGE_DIR="$TOOLS_DIR/Packages"
VERIFY_SCRIPT="$TOOLS_DIR/Scripts/verify-swiftrip-tools.zsh"

manifest_file_for_arch() {
    case "$TOOLS_ARCH" in
        arm64)
            echo "$TOOLS_DIR/Manifest/swiftrip-tools.json"
            ;;
        x86_64)
            echo "$TOOLS_DIR/Manifest/swiftrip-tools-x86_64.json"
            ;;
    esac
}

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

json_value() {
    local key="$1"
    /usr/bin/plutil -extract "$key" raw -o - "$MANIFEST_FILE"
}

case "$TOOLS_ARCH" in
    arm64|x86_64)
        ;;
    *)
        echo "ERROR: Unsupported SwiftRipTools architecture: $TOOLS_ARCH" >&2
        echo "Supported architectures: arm64, x86_64" >&2
        exit 64
        ;;
esac

MANIFEST_FILE="$(manifest_file_for_arch)"
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo "ERROR: Missing SwiftRipTools manifest for $TOOLS_ARCH:"
    echo "$MANIFEST_FILE"
    exit 1
fi

ARTIFACT_NAME="$(json_value artifactName)"
EXPECTED_SHA256="$(json_value sha256)"
PACKAGE_PATH="$PACKAGE_DIR/$ARTIFACT_NAME"
TAR_PATH="$PACKAGE_DIR/${ARTIFACT_NAME:r}"

echo "SwiftRipTools package"
echo "Root:     $ROOT_DIR"
echo "Manifest: $MANIFEST_FILE"
echo "Package:  $PACKAGE_PATH"
echo "Arch:     $TOOLS_ARCH"

SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$VERIFY_SCRIPT"

mkdir -p "$PACKAGE_DIR"
rm -f "$PACKAGE_PATH"
rm -f "$TAR_PATH"

echo ""
echo "Creating package..."
COPYFILE_DISABLE=1 tar -cf "$TAR_PATH" -C "$ARTIFACTS_ROOT" "macos-$TOOLS_ARCH"
gzip -n "$TAR_PATH"

ACTUAL_SHA256="$(shasum -a 256 "$PACKAGE_PATH" | awk '{print $1}')"

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
