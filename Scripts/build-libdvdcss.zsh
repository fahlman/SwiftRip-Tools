#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$ROOT_DIR"
COMMON_SCRIPT="$SCRIPT_DIR/lib/common.zsh"
SOURCE_DIR="$TOOLS_DIR/Source"
BUILD_DIR="$TOOLS_DIR/Build/libdvdcss"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts/macos-$TOOLS_ARCH"

LIBDVDCSS_VERSION="1.5.0"
LIBDVDCSS_REPOSITORY_URL="https://github.com/fahlman/SwiftRip-libdvdcss.git"
LIBDVDCSS_SWIFTRIP_TAG="swiftrip-libdvdcss-${LIBDVDCSS_VERSION}"
LIBDVDCSS_SWIFTRIP_COMMIT="c838ca97553aeb8505b7baf02b9a90f8505de212"
LIBDVDCSS_SOURCE_DIR="$SOURCE_DIR/libdvdcss-${LIBDVDCSS_VERSION}-swiftrip"

ARCH_PREFIX="$BUILD_DIR/$TOOLS_ARCH-prefix"

MESON_CMD="${MESON_CMD:-}"
NINJA_CMD="${NINJA_CMD:-}"

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

echo "SwiftRip-Tools: build libdvdcss"
echo "Root:      $ROOT_DIR"
echo "Source:    $SOURCE_DIR"
echo "Build:     $BUILD_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Version:   $LIBDVDCSS_VERSION"
echo "Source tag: $LIBDVDCSS_SWIFTRIP_TAG"
echo "Arch:      $TOOLS_ARCH"

assert_supported_tools_arch "$TOOLS_ARCH" "libdvdcss"
require_command git

mkdir -p "$SOURCE_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$ARTIFACTS_DIR"

cd "$SOURCE_DIR"

if [[ -d "$LIBDVDCSS_SOURCE_DIR/.git" ]]; then
    echo "Using existing source: $LIBDVDCSS_SOURCE_DIR"
    ACTUAL_LIBDVDCSS_COMMIT="$(git -C "$LIBDVDCSS_SOURCE_DIR" rev-parse HEAD)"
    if [[ "$ACTUAL_LIBDVDCSS_COMMIT" != "$LIBDVDCSS_SWIFTRIP_COMMIT" ]]; then
        echo "Existing libdvdcss source is not the pinned SwiftRip revision; refreshing..."
        rm -rf "$LIBDVDCSS_SOURCE_DIR"
    fi
elif [[ -e "$LIBDVDCSS_SOURCE_DIR" ]]; then
    echo "Removing non-Git libdvdcss source directory: $LIBDVDCSS_SOURCE_DIR"
    rm -rf "$LIBDVDCSS_SOURCE_DIR"
fi

if [[ ! -d "$LIBDVDCSS_SOURCE_DIR/.git" ]]; then
    echo "Cloning SwiftRip libdvdcss source..."
    git clone \
      --depth 1 \
      --branch "$LIBDVDCSS_SWIFTRIP_TAG" \
      "$LIBDVDCSS_REPOSITORY_URL" \
      "$LIBDVDCSS_SOURCE_DIR"
fi

ACTUAL_LIBDVDCSS_COMMIT="$(git -C "$LIBDVDCSS_SOURCE_DIR" rev-parse HEAD)"
if [[ "$ACTUAL_LIBDVDCSS_COMMIT" != "$LIBDVDCSS_SWIFTRIP_COMMIT" ]]; then
    echo "ERROR: SwiftRip libdvdcss source revision mismatch."
    echo "Expected: $LIBDVDCSS_SWIFTRIP_COMMIT"
    echo "Actual:   $ACTUAL_LIBDVDCSS_COMMIT"
    exit 1
fi

if [[ -z "$MESON_CMD" ]]; then
    if command -v meson >/dev/null 2>&1; then
        MESON_CMD="meson"
    else
        echo "Meson was not found. Install it first, for example: python3 -m pip install --user meson" >&2
        exit 1
    fi
fi

if [[ -z "$NINJA_CMD" ]]; then
    if command -v ninja >/dev/null 2>&1; then
        NINJA_CMD="ninja"
    else
        echo "Ninja was not found. Install it first, for example: brew install ninja or python3 -m pip install --user ninja" >&2
        exit 1
    fi
fi

if [[ ! -f "$LIBDVDCSS_SOURCE_DIR/meson.build" ]]; then
    echo "Expected SwiftRip libdvdcss source to contain meson.build, but it was not found." >&2
    echo "Source directory: $LIBDVDCSS_SOURCE_DIR" >&2
    exit 1
fi

build_arch() {
    local arch="$1"
    local prefix="$2"
    local arch_build_dir="$BUILD_DIR/$arch"
    local machine_file="$BUILD_DIR/$arch-meson.ini"

    echo ""
    echo "Building libdvdcss for $arch..."

    rm -rf "$arch_build_dir" "$prefix" "$machine_file"
    mkdir -p "$arch_build_dir" "$prefix"

    cat > "$machine_file" <<EOF
[binaries]
c = 'clang'

[built-in options]
c_args = ['-arch', '$arch', '-mmacosx-version-min=13.0']
c_link_args = ['-arch', '$arch', '-mmacosx-version-min=13.0']
default_library = 'shared'

[project options]

[host_machine]
system = 'darwin'
cpu_family = '$arch'
cpu = '$arch'
endian = 'little'
EOF

    "$MESON_CMD" setup "$arch_build_dir" "$LIBDVDCSS_SOURCE_DIR" \
        --prefix "$prefix" \
        --libdir lib \
        --buildtype release \
        --default-library shared \
        --native-file "$machine_file"

    "$NINJA_CMD" -C "$arch_build_dir"
    "$NINJA_CMD" -C "$arch_build_dir" install
}

build_arch "$TOOLS_ARCH" "$ARCH_PREFIX"

ARCH_DYLIB="$ARCH_PREFIX/lib/libdvdcss.2.dylib"
ARTIFACT_DYLIB="$ARTIFACTS_DIR/libdvdcss.2.dylib"

if [[ ! -f "$ARCH_DYLIB" ]]; then
    echo "Missing $TOOLS_ARCH dylib: $ARCH_DYLIB" >&2
    exit 1
fi

echo ""
echo "Copying $TOOLS_ARCH dylib artifact..."
cp "$ARCH_DYLIB" "$ARTIFACT_DYLIB"

install_name_tool -id "@rpath/libdvdcss.2.dylib" "$ARTIFACT_DYLIB"

echo ""
echo "Built artifact: $ARTIFACT_DYLIB"
file "$ARTIFACT_DYLIB"
otool -D "$ARTIFACT_DYLIB"

echo ""
echo "Checking for accidental package-manager runtime dependencies..."
if otool -L "$ARTIFACT_DYLIB" | grep -Eq "(/opt/local|/opt/homebrew|/usr/local)"; then
    echo "ERROR: libdvdcss.2.dylib links against package-manager libraries."
    exit 1
fi

echo "No package-manager runtime dependencies found."
echo ""
echo "libdvdcss build complete."
