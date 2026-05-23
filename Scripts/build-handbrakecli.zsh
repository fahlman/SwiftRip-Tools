#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
SOURCE_DIR="$TOOLS_DIR/Source"
BUILD_DIR="$TOOLS_DIR/Build/handbrake"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts/macos-arm64"
PATCHES_DIR="$TOOLS_DIR/Patches/HandBrake"

HANDBRAKE_VERSION="1.11.1"
HANDBRAKE_ARCHIVE="HandBrake-${HANDBRAKE_VERSION}-source.tar.bz2"
HANDBRAKE_URL="https://github.com/HandBrake/HandBrake/releases/download/${HANDBRAKE_VERSION}/${HANDBRAKE_ARCHIVE}"
HANDBRAKE_SOURCE_DIR="$SOURCE_DIR/HandBrake-${HANDBRAKE_VERSION}"
LIBDVDREAD_PATCH="$PATCHES_DIR/libdvdread/A03-macOS-hardened-runtime-dlopen.patch"

ARM64_BUILD_DIR="$BUILD_DIR/arm64"
ARM64_PREFIX_DIR="$BUILD_DIR/arm64-prefix"

echo "SwiftRipTools: build HandBrakeCLI"
echo "Root:      $ROOT_DIR"
echo "Source:    $SOURCE_DIR"
echo "Build:     $BUILD_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Version:   $HANDBRAKE_VERSION"
echo "Arch:      arm64"

mkdir -p "$SOURCE_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$ARTIFACTS_DIR"

cd "$SOURCE_DIR"

if [[ ! -f "$HANDBRAKE_ARCHIVE" ]]; then
    echo "Downloading $HANDBRAKE_ARCHIVE from HandBrake GitHub releases..."
    curl -L -o "$HANDBRAKE_ARCHIVE" "$HANDBRAKE_URL"
else
    echo "Using existing archive: $SOURCE_DIR/$HANDBRAKE_ARCHIVE"
fi

if [[ ! -d "$HANDBRAKE_SOURCE_DIR" ]]; then
    echo "Extracting $HANDBRAKE_ARCHIVE..."
    tar -xjf "$HANDBRAKE_ARCHIVE"
else
    echo "Using existing source: $HANDBRAKE_SOURCE_DIR"
fi

echo "Applying SwiftRip HandBrake patches..."
if [[ ! -f "$LIBDVDREAD_PATCH" ]]; then
    echo "ERROR: Missing SwiftRip HandBrake patch:"
    echo "$LIBDVDREAD_PATCH"
    exit 1
fi

cp "$LIBDVDREAD_PATCH" "$HANDBRAKE_SOURCE_DIR/contrib/libdvdread/A03-macOS-hardened-runtime-dlopen.patch"
if ! cmp -s "$LIBDVDREAD_PATCH" "$HANDBRAKE_SOURCE_DIR/contrib/libdvdread/A03-macOS-hardened-runtime-dlopen.patch"; then
    echo "ERROR: Failed to apply SwiftRip libdvdread patch."
    exit 1
fi

echo ""
echo "Building HandBrakeCLI for arm64..."

rm -rf "$ARM64_BUILD_DIR" "$ARM64_PREFIX_DIR"

cd "$HANDBRAKE_SOURCE_DIR"

env -u CPATH \
    -u LIBRARY_PATH \
    -u LD_LIBRARY_PATH \
    -u DYLD_LIBRARY_PATH \
    -u PKG_CONFIG_PATH \
    -u CFLAGS \
    -u CPPFLAGS \
    -u CXXFLAGS \
    -u LDFLAGS \
    PKG_CONFIG_LIBDIR="$ARM64_BUILD_DIR/contrib/lib/pkgconfig" \
    PATH="/opt/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    ./configure \
      --force \
      --disable-xcode \
      --arch arm64 \
      --build "$ARM64_BUILD_DIR" \
      --prefix "$ARM64_PREFIX_DIR" \
      --launch \
      --launch-jobs 0

echo ""
echo "Copying HandBrakeCLI artifact..."

cp "$ARM64_BUILD_DIR/HandBrakeCLI" "$ARTIFACTS_DIR/HandBrakeCLI"

echo ""
echo "Built artifact: $ARTIFACTS_DIR/HandBrakeCLI"
file "$ARTIFACTS_DIR/HandBrakeCLI"

echo ""
echo "Runtime library check:"
otool -L "$ARTIFACTS_DIR/HandBrakeCLI"

echo ""
echo "Checking for accidental MacPorts runtime dependencies..."
if otool -L "$ARTIFACTS_DIR/HandBrakeCLI" | grep -q "/opt/local"; then
    echo "ERROR: HandBrakeCLI links against /opt/local libraries."
    exit 1
fi

if ! grep -aFq "@executable_path/../Frameworks/libdvdcss.2.dylib" "$ARTIFACTS_DIR/HandBrakeCLI"; then
    echo "ERROR: HandBrakeCLI does not contain the app Frameworks libdvdcss loader path."
    exit 1
fi

if grep -aFq "/usr/local/lib/libdvdcss.2.dylib" "$ARTIFACTS_DIR/HandBrakeCLI"; then
    echo "ERROR: HandBrakeCLI still contains the legacy /usr/local libdvdcss loader path."
    exit 1
fi

echo "No /opt/local runtime dependencies found."
echo ""
echo "HandBrakeCLI build complete."
