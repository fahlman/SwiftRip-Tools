#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
ARTIFACTS_DIR="$ROOT_DIR/SwiftRipTools/Artifacts/macos-$TOOLS_ARCH"
HANDBRAKE_ARTIFACT="$ARTIFACTS_DIR/HandBrakeCLI"
LIBDVDCSS_ARTIFACT="$ARTIFACTS_DIR/libdvdcss.2.dylib"
LIBDVDCSS_FRAMEWORKS_PATH="@executable_path/../Frameworks/libdvdcss.2.dylib"
LEGACY_LIBDVDCSS_PATH="/usr/local/lib/libdvdcss.2.dylib"

case "$TOOLS_ARCH" in
    arm64|x86_64)
        ;;
    *)
        echo "ERROR: Unsupported SwiftRipTools architecture: $TOOLS_ARCH" >&2
        echo "Supported architectures: arm64, x86_64" >&2
        exit 64
        ;;
esac

echo "SwiftRipTools: verify artifacts"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Arch:      $TOOLS_ARCH"

if [[ ! -x "$HANDBRAKE_ARTIFACT" ]]; then
    echo "ERROR: Missing executable HandBrakeCLI artifact:"
    echo "$HANDBRAKE_ARTIFACT"
    exit 1
fi

if [[ ! -f "$LIBDVDCSS_ARTIFACT" ]]; then
    echo "ERROR: Missing libdvdcss.2.dylib artifact:"
    echo "$LIBDVDCSS_ARTIFACT"
    exit 1
fi

echo ""
echo "HandBrakeCLI:"
file "$HANDBRAKE_ARTIFACT"
if ! file "$HANDBRAKE_ARTIFACT" | grep -q "$TOOLS_ARCH"; then
    echo "ERROR: HandBrakeCLI is not $TOOLS_ARCH."
    exit 1
fi

if otool -L "$HANDBRAKE_ARTIFACT" | grep -q "/opt/local"; then
    echo "ERROR: HandBrakeCLI links against /opt/local libraries."
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

if otool -L "$LIBDVDCSS_ARTIFACT" | grep -q "/opt/local"; then
    echo "ERROR: libdvdcss.2.dylib links against /opt/local libraries."
    exit 1
fi

otool -D "$LIBDVDCSS_ARTIFACT"

echo ""
echo "SwiftRipTools artifacts verified."
