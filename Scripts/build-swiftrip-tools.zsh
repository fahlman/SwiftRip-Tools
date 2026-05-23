#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
SCRIPTS_DIR="$TOOLS_DIR/Scripts"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts/macos-arm64"

echo "SwiftRipTools build"
echo "Root:      $ROOT_DIR"
echo "Tools:     $TOOLS_DIR"
echo "Scripts:   $SCRIPTS_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Arch:      arm64"

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
"$SCRIPTS_DIR/build-libdvdcss.zsh"

echo ""
echo "Building HandBrakeCLI..."
"$SCRIPTS_DIR/build-handbrakecli.zsh"

echo ""
echo "Final artifact check:"
ls -lh "$ARTIFACTS_DIR"
"$SCRIPTS_DIR/verify-swiftrip-tools.zsh"

echo ""
echo "SwiftRipTools build complete."
