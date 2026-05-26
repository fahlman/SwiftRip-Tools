#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
SCRIPTS_DIR="$TOOLS_DIR/Scripts"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts/macos-$TOOLS_ARCH"

case "$TOOLS_ARCH" in
    arm64|x86_64)
        ;;
    *)
        echo "ERROR: Unsupported SwiftRipTools architecture: $TOOLS_ARCH" >&2
        echo "Supported architectures: arm64, x86_64" >&2
        exit 64
        ;;
esac

echo "SwiftRipTools build"
echo "Root:      $ROOT_DIR"
echo "Tools:     $TOOLS_DIR"
echo "Scripts:   $SCRIPTS_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Arch:      $TOOLS_ARCH"

mkdir -p "$ARTIFACTS_DIR"

required_commands=(
    curl
    file
    otool
    strings
    tar
    xcrun
)

echo ""
echo "Checking required build tools..."
for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $command_name"
        exit 1
    fi
done
echo "Required build tools found."

echo ""
echo "Building libdvdcss..."
SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/build-libdvdcss.zsh"

echo ""
echo "Building HandBrakeCLI..."
SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/build-handbrakecli.zsh"

echo ""
echo "Final artifact check:"
ls -lh "$ARTIFACTS_DIR"
SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/verify-swiftrip-tools.zsh"

echo ""
echo "SwiftRipTools build complete."

echo ""
echo "To create the distributable CI/local bootstrap package, run:"
echo "$SCRIPTS_DIR/package-swiftrip-tools.zsh --arch $TOOLS_ARCH"
