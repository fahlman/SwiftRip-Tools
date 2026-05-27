#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$ROOT_DIR"
SCRIPTS_DIR="$SCRIPT_DIR"
COMMON_SCRIPT="$SCRIPTS_DIR/lib/common.zsh"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts/macos-$TOOLS_ARCH"

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

assert_supported_tools_arch "$TOOLS_ARCH"

echo "SwiftRip-Tools build"
echo "Root:      $ROOT_DIR"
echo "Tools:     $TOOLS_DIR"
echo "Scripts:   $SCRIPTS_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Arch:      $TOOLS_ARCH"

mkdir -p "$ARTIFACTS_DIR"

echo ""
echo "Checking required build tools..."
require_command curl
require_command file
require_command otool
require_command strings
require_command tar
require_command xcrun
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
echo "SwiftRip-Tools build complete."

echo ""
echo "To create the distributable CI/local bootstrap package, run:"
echo "$SCRIPTS_DIR/package-swiftrip-tools.zsh --arch $TOOLS_ARCH"
