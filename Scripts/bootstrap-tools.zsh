#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR"
COMMON_SCRIPT="$SCRIPT_DIR/lib/common.zsh"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts/macos-$TOOLS_ARCH"
FORCE_BUILD=0

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE_BUILD=1
            shift
            ;;
        --arch)
            TOOLS_ARCH="${2:-}"
            ARTIFACTS_DIR="$ROOT_DIR/Artifacts/macos-$TOOLS_ARCH"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--force] [--arch arm64|x86_64]"
            exit 64
            ;;
    esac
done

assert_supported_tools_arch "$TOOLS_ARCH"

echo "SwiftRip-Tools bootstrap"
echo "Root:      $ROOT_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Arch:      $TOOLS_ARCH"

if [[ "$FORCE_BUILD" -eq 0 ]] && SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/verify-swiftrip-tools.zsh"; then
    echo ""
    echo "Existing SwiftRip-Tools artifacts are ready."
    exit 0
fi

if [[ "$FORCE_BUILD" -eq 0 ]]; then
    echo ""
    echo "Fetching SwiftRip-Tools artifacts..."
    if SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/fetch-swiftrip-tools.zsh"; then
        echo ""
        echo "Fetched SwiftRip-Tools artifacts are ready."
        exit 0
    fi
fi

echo ""
echo "Fetch unavailable; building SwiftRip-Tools artifacts locally."

echo ""
echo "Building SwiftRip-Tools artifacts..."
SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/build-swiftrip-tools.zsh"

echo ""
SWIFTRIP_TOOLS_ARCH="$TOOLS_ARCH" "$SCRIPTS_DIR/verify-swiftrip-tools.zsh"
