#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS_DIR="$ROOT_DIR/SwiftRipTools"
SOURCE_DIR="$TOOLS_DIR/Source"
BUILD_DIR="$TOOLS_DIR/Build/libdvdcss"
TOOLS_ARCH="${SWIFTRIP_TOOLS_ARCH:-arm64}"
ARTIFACTS_DIR="$TOOLS_DIR/Artifacts/macos-$TOOLS_ARCH"

LIBDVDCSS_VERSION="1.5.0"
LIBDVDCSS_ARCHIVE="libdvdcss-${LIBDVDCSS_VERSION}.tar.xz"
LIBDVDCSS_SOURCE_DIR="$SOURCE_DIR/libdvdcss-${LIBDVDCSS_VERSION}"
LIBDVDCSS_URL="https://get.videolan.org/libdvdcss/${LIBDVDCSS_VERSION}/${LIBDVDCSS_ARCHIVE}"
LIBDVDCSS_SHA256="529463e4d1befef82e5c6e470db7661a2db0343e092a2fb0d6c037cab8a5c399"

ARCH_PREFIX="$BUILD_DIR/$TOOLS_ARCH-prefix"

MESON_CMD="${MESON_CMD:-}"
NINJA_CMD="${NINJA_CMD:-}"

echo "SwiftRipTools: build libdvdcss"
echo "Root:      $ROOT_DIR"
echo "Source:    $SOURCE_DIR"
echo "Build:     $BUILD_DIR"
echo "Artifacts: $ARTIFACTS_DIR"
echo "Version:   $LIBDVDCSS_VERSION"
echo "Arch:      $TOOLS_ARCH"

case "$TOOLS_ARCH" in
    arm64|x86_64)
        ;;
    *)
        echo "ERROR: Unsupported libdvdcss architecture: $TOOLS_ARCH" >&2
        echo "Supported architectures: arm64, x86_64" >&2
        exit 64
        ;;
esac

mkdir -p "$SOURCE_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$ARTIFACTS_DIR"

cd "$SOURCE_DIR"

if [[ ! -f "$LIBDVDCSS_ARCHIVE" ]]; then
    echo "Downloading $LIBDVDCSS_ARCHIVE from VideoLAN..."
    curl -fL "$LIBDVDCSS_URL" -o "$LIBDVDCSS_ARCHIVE"
else
    echo "Using existing archive: $SOURCE_DIR/$LIBDVDCSS_ARCHIVE"
fi

echo "Verifying $LIBDVDCSS_ARCHIVE checksum..."
ACTUAL_LIBDVDCSS_SHA256="$(shasum -a 256 "$LIBDVDCSS_ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_LIBDVDCSS_SHA256" != "$LIBDVDCSS_SHA256" ]]; then
    echo "ERROR: $LIBDVDCSS_ARCHIVE checksum mismatch."
    echo "Expected: $LIBDVDCSS_SHA256"
    echo "Actual:   $ACTUAL_LIBDVDCSS_SHA256"
    exit 1
fi

if [[ ! -d "$LIBDVDCSS_SOURCE_DIR" ]]; then
    echo "Extracting $LIBDVDCSS_ARCHIVE..."
    tar -xJf "$LIBDVDCSS_ARCHIVE"
else
    echo "Using existing source: $LIBDVDCSS_SOURCE_DIR"
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
    echo "Expected VideoLAN libdvdcss source to contain meson.build, but it was not found." >&2
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
echo "Checking for accidental MacPorts runtime dependencies..."
if otool -L "$ARTIFACT_DYLIB" | grep -q "/opt/local"; then
    echo "ERROR: libdvdcss.2.dylib links against /opt/local libraries."
    exit 1
fi

echo "No /opt/local runtime dependencies found."
echo ""
echo "libdvdcss build complete."
