#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$ROOT_DIR"
COMMON_SCRIPT="$SCRIPT_DIR/lib/common.zsh"
SOURCE_DIR="$TOOLS_DIR/Source"
BUILD_DIR="$TOOLS_DIR/Build/handbrake"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts/macos-$TOOLS_ARCH"

HANDBRAKE_VERSION="1.11.2"
HANDBRAKE_REPOSITORY_URL="https://github.com/fahlman/SwiftRip-HandBrake.git"
HANDBRAKE_SWIFTRIP_TAG="swiftrip-handbrake-${HANDBRAKE_VERSION}"
HANDBRAKE_SWIFTRIP_COMMIT="e1ac9de2cf1aa24c2b8a651b13735c21335a1229"
HANDBRAKE_SOURCE_DIR="$SOURCE_DIR/HandBrake-${HANDBRAKE_VERSION}-swiftrip"
LIBDVDREAD_PATCH="$HANDBRAKE_SOURCE_DIR/contrib/libdvdread/A03-macOS-hardened-runtime-dlopen.patch"

ARCH_BUILD_DIR="$BUILD_DIR/$TOOLS_ARCH"
ARCH_PREFIX_DIR="$BUILD_DIR/$TOOLS_ARCH-prefix"

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

echo "SwiftRip-Tools: build HandBrakeCLI"
echo "Root:      $ROOT_DIR"
echo "Source:    $SOURCE_DIR"
echo "Build:     $BUILD_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Version:   $HANDBRAKE_VERSION"
echo "Fork tag:  $HANDBRAKE_SWIFTRIP_TAG"
echo "Arch:      $TOOLS_ARCH"

assert_supported_tools_arch "$TOOLS_ARCH" "HandBrakeCLI"
require_command git

mkdir -p "$SOURCE_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$ARTIFACTS_DIR"

cd "$SOURCE_DIR"

if [[ -d "$HANDBRAKE_SOURCE_DIR/.git" ]]; then
    echo "Using existing source: $HANDBRAKE_SOURCE_DIR"
    ACTUAL_HANDBRAKE_COMMIT="$(git -C "$HANDBRAKE_SOURCE_DIR" rev-parse HEAD)"
    if [[ "$ACTUAL_HANDBRAKE_COMMIT" != "$HANDBRAKE_SWIFTRIP_COMMIT" ]]; then
        echo "Existing HandBrake source is not the pinned SwiftRip revision; refreshing..."
        rm -rf "$HANDBRAKE_SOURCE_DIR"
    fi
elif [[ -e "$HANDBRAKE_SOURCE_DIR" ]]; then
    echo "Removing non-Git HandBrake source directory: $HANDBRAKE_SOURCE_DIR"
    rm -rf "$HANDBRAKE_SOURCE_DIR"
fi

if [[ ! -d "$HANDBRAKE_SOURCE_DIR/.git" ]]; then
    echo "Cloning SwiftRip HandBrake fork..."
    git clone \
      --depth 1 \
      --branch "$HANDBRAKE_SWIFTRIP_TAG" \
      "$HANDBRAKE_REPOSITORY_URL" \
      "$HANDBRAKE_SOURCE_DIR"
fi

ACTUAL_HANDBRAKE_COMMIT="$(git -C "$HANDBRAKE_SOURCE_DIR" rev-parse HEAD)"
if [[ "$ACTUAL_HANDBRAKE_COMMIT" != "$HANDBRAKE_SWIFTRIP_COMMIT" ]]; then
    echo "ERROR: SwiftRip HandBrake fork revision mismatch."
    echo "Expected: $HANDBRAKE_SWIFTRIP_COMMIT"
    echo "Actual:   $ACTUAL_HANDBRAKE_COMMIT"
    exit 1
fi

echo "Verifying SwiftRip HandBrake fork patch..."
require_file "$LIBDVDREAD_PATCH" "SwiftRip HandBrake fork libdvdread patch"
if ! grep -Fq "@executable_path/../Frameworks/libdvdcss.2.dylib" "$LIBDVDREAD_PATCH"; then
    echo "ERROR: SwiftRip HandBrake fork patch does not use the app Frameworks libdvdcss path."
    exit 1
fi
if grep -Fq "/usr/local/lib/libdvdcss.2.dylib" "$LIBDVDREAD_PATCH"; then
    echo "ERROR: SwiftRip HandBrake fork patch still references /usr/local libdvdcss."
    exit 1
fi

echo ""
echo "Building HandBrakeCLI for $TOOLS_ARCH..."

rm -rf "$ARCH_BUILD_DIR" "$ARCH_PREFIX_DIR"

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
    PKG_CONFIG_LIBDIR="$ARCH_BUILD_DIR/contrib/lib/pkgconfig" \
    PATH="/opt/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    ./configure \
      --force \
      --disable-xcode \
      --optimize size-aggressive \
      --disable-x265 \
      --disable-fdk-aac \
      --disable-ffmpeg-aac \
      --disable-ffmpeg-prores \
      --disable-libdovi \
      --arch "$TOOLS_ARCH" \
      --build "$ARCH_BUILD_DIR" \
      --prefix "$ARCH_PREFIX_DIR" \
      --launch \
      --launch-jobs 0

echo ""
echo "Copying HandBrakeCLI artifact..."

cp "$ARCH_BUILD_DIR/HandBrakeCLI" "$ARTIFACTS_DIR/HandBrakeCLI"

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
