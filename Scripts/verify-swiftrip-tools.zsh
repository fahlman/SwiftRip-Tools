#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMON_SCRIPT="$SCRIPT_DIR/lib/common.zsh"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
ARTIFACTS_DIR="$ROOT_DIR/Artifacts/macos-$TOOLS_ARCH"
HANDBRAKE_ARTIFACT="$ARTIFACTS_DIR/HandBrakeCLI"
LIBDVDCSS_ARTIFACT="$ARTIFACTS_DIR/libdvdcss.2.dylib"
LIBDVDCSS_FRAMEWORKS_PATH="@executable_path/../Frameworks/libdvdcss.2.dylib"
LEGACY_LIBDVDCSS_PATH="/usr/local/lib/libdvdcss.2.dylib"

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

assert_supported_tools_arch "$TOOLS_ARCH"

echo "SwiftRip-Tools: verify artifacts"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Arch:      $TOOLS_ARCH"

require_executable "$HANDBRAKE_ARTIFACT"
require_file "$LIBDVDCSS_ARTIFACT" "libdvdcss.2.dylib artifact"

UNEXPECTED_ARTIFACTS="$(
    find "$ARTIFACTS_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        ! -name HandBrakeCLI \
        ! -name libdvdcss.2.dylib
)"
if [[ -n "$UNEXPECTED_ARTIFACTS" ]]; then
    echo "ERROR: Unexpected SwiftRip-Tools artifact files:"
    echo "$UNEXPECTED_ARTIFACTS"
    exit 1
fi

echo ""
echo "HandBrakeCLI:"
file "$HANDBRAKE_ARTIFACT"
if ! file "$HANDBRAKE_ARTIFACT" | grep -q "$TOOLS_ARCH"; then
    echo "ERROR: HandBrakeCLI is not $TOOLS_ARCH."
    exit 1
fi

if otool -L "$HANDBRAKE_ARTIFACT" | grep -Eq "(/opt/local|/opt/homebrew|/usr/local)"; then
    echo "ERROR: HandBrakeCLI links against package-manager libraries."
    exit 1
fi

if ! grep -aFq "$LIBDVDCSS_FRAMEWORKS_PATH" "$HANDBRAKE_ARTIFACT"; then
    echo "ERROR: HandBrakeCLI does not contain the app Frameworks libdvdcss loader path:"
    echo "$LIBDVDCSS_FRAMEWORKS_PATH"
    exit 1
fi

if grep -aFq "$LEGACY_LIBDVDCSS_PATH" "$HANDBRAKE_ARTIFACT"; then
    echo "ERROR: HandBrakeCLI still contains the legacy libdvdcss loader path:"
    echo "$LEGACY_LIBDVDCSS_PATH"
    exit 1
fi

echo ""
echo "libdvdcss.2.dylib:"
file "$LIBDVDCSS_ARTIFACT"
if ! file "$LIBDVDCSS_ARTIFACT" | grep -q "$TOOLS_ARCH"; then
    echo "ERROR: libdvdcss.2.dylib is not $TOOLS_ARCH."
    exit 1
fi

if otool -L "$LIBDVDCSS_ARTIFACT" | grep -Eq "(/opt/local|/opt/homebrew|/usr/local)"; then
    echo "ERROR: libdvdcss.2.dylib links against package-manager libraries."
    exit 1
fi

otool -D "$LIBDVDCSS_ARTIFACT"

echo ""
echo "SwiftRip-Tools artifacts verified."
