#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/SwiftRipTools/Scripts"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
ARTIFACTS_DIR="$ROOT_DIR/SwiftRipTools/Artifacts/macos-$TOOLS_ARCH"
FORCE_BUILD=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE_BUILD=1
            shift
            ;;
        --arch)
            TOOLS_ARCH="${2:-}"
            ARTIFACTS_DIR="$ROOT_DIR/SwiftRipTools/Artifacts/macos-$TOOLS_ARCH"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--force] [--arch arm64|x86_64]"
            exit 64
            ;;
    esac
done

case "$TOOLS_ARCH" in
    arm64|x86_64)
        ;;
    *)
        echo "ERROR: Unsupported SwiftRipTools architecture: $TOOLS_ARCH" >&2
        echo "Supported architectures: arm64, x86_64" >&2
        exit 64
        ;;
esac

echo "SwiftRipTools bootstrap"
echo "Root:      $ROOT_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Arch:      $TOOLS_ARCH"

if [[ "$FORCE_BUILD" -eq 0 ]] && SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/verify-swiftrip-tools.zsh"; then
    echo ""
    echo "Existing SwiftRipTools artifacts are ready."
    exit 0
fi

if [[ "$FORCE_BUILD" -eq 0 ]]; then
    echo ""
    echo "Fetching SwiftRipTools artifacts..."
    if SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/fetch-swiftrip-tools.zsh"; then
        echo ""
        echo "Fetched SwiftRipTools artifacts are ready."
        exit 0
    fi
fi

echo ""
echo "Fetch unavailable; building SwiftRipTools artifacts locally."

echo ""
echo "Building SwiftRipTools artifacts..."
SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/build-swiftrip-tools.zsh"

echo ""
SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/verify-swiftrip-tools.zsh"
