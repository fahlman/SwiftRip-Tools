#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
SOURCE_DIR="$TOOLS_DIR/Source"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts/macos-universal"

echo "SwiftRipTools build"
echo "Root:      $ROOT_DIR"
echo "Tools:     $TOOLS_DIR"
echo "Source:    $SOURCE_DIR"
echo "Artifacts: $ARTIFACTS_DIR"

mkdir -p "$SOURCE_DIR"
mkdir -p "$ARTIFACTS_DIR"

echo ""
echo "Building libdvdcss..."
"$TOOLS_DIR/Scripts/build-libdvdcss.zsh"

echo ""
echo "SwiftRipTools build complete."
echo "Artifacts: $ARTIFACTS_DIR"
