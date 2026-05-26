#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
DOWNLOAD_DIR="$TOOLS_DIR/Packages"
ARTIFACTS_ROOT="$TOOLS_DIR/Artifacts"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
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

VERSION="$(json_value version)"
ARTIFACT_NAME="$(json_value artifactName)"
ARTIFACT_URL="$(json_value url)"
EXPECTED_SHA256="$(json_value sha256)"
PACKAGE_PATH="$DOWNLOAD_DIR/$ARTIFACT_NAME"

echo "SwiftRipTools fetch"
echo "Root:     $ROOT_DIR"
echo "Manifest: $MANIFEST_FILE"
echo "Version:  $VERSION"
echo "Package:  $PACKAGE_PATH"
echo "Arch:     $TOOLS_ARCH"

mkdir -p "$DOWNLOAD_DIR"

if [[ ! -f "$PACKAGE_PATH" ]]; then
    echo ""
    echo "Downloading SwiftRipTools package..."
    curl -fL "$ARTIFACT_URL" -o "$PACKAGE_PATH"
else
    echo ""
    echo "Using existing package: $PACKAGE_PATH"
fi

echo ""
echo "Verifying package checksum..."
ACTUAL_SHA256="$(shasum -a 256 "$PACKAGE_PATH" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    echo "ERROR: SwiftRipTools package checksum mismatch."
    echo "Expected: $EXPECTED_SHA256"
    echo "Actual:   $ACTUAL_SHA256"
    exit 1
fi

echo ""
echo "Extracting SwiftRipTools artifacts..."
rm -rf "$ARTIFACTS_ROOT/macos-$TOOLS_ARCH"
mkdir -p "$ARTIFACTS_ROOT"
tar -xzf "$PACKAGE_PATH" -C "$ARTIFACTS_ROOT"

echo ""
SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$VERIFY_SCRIPT"

echo ""
echo "SwiftRipTools fetch complete."
