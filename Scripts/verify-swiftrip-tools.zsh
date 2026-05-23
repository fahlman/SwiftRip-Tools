#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ARTIFACTS_DIR="$ROOT_DIR/SwiftRipTools/Artifacts/macos-arm64"
HANDBRAKE_ARTIFACT="$ARTIFACTS_DIR/HandBrakeCLI"
LIBDVDCSS_ARTIFACT="$ARTIFACTS_DIR/libdvdcss.2.dylib"
LIBDVDCSS_FRAMEWORKS_PATH="@executable_path/../Frameworks/libdvdcss.2.dylib"
LEGACY_LIBDVDCSS_PATH="/usr/local/lib/libdvdcss.2.dylib"

echo "SwiftRipTools: verify artifacts"
echo "Artifacts: $ARTIFACTS_DIR"

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
if ! file "$HANDBRAKE_ARTIFACT" | grep -q "arm64"; then
    echo "ERROR: HandBrakeCLI is not arm64."
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
if ! file "$LIBDVDCSS_ARTIFACT" | grep -q "arm64"; then
    echo "ERROR: libdvdcss.2.dylib is not arm64."
    exit 1
fi

if otool -L "$LIBDVDCSS_ARTIFACT" | grep -q "/opt/local"; then
    echo "ERROR: libdvdcss.2.dylib links against /opt/local libraries."
    exit 1
fi

otool -D "$LIBDVDCSS_ARTIFACT"

echo ""
echo "SwiftRipTools artifacts verified."
