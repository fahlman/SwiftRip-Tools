#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMON_SCRIPT="$SCRIPT_DIR/lib/common.zsh"
HANDBRAKE_SCRIPT="$SCRIPT_DIR/build-handbrakecli.zsh"
LIBDVDCSS_SCRIPT="$SCRIPT_DIR/build-libdvdcss.zsh"
OUTPUT_DIR="$ROOT_DIR/PreparedToolUpdate"
HANDBRAKE_VERSION_INPUT=""
TOOLS_REPOSITORY="${SWIFTRIP_TOOLS_REPOSITORY:-fahlman/SwiftRip-Tools}"
HANDBRAKE_UPSTREAM_REPOSITORY_URL="${SWIFTRIP_HANDBRAKE_UPSTREAM_REPOSITORY_URL:-https://github.com/HandBrake/HandBrake.git}"
HANDBRAKE_SWIFTRIP_REPOSITORY_URL="${SWIFTRIP_HANDBRAKE_REPOSITORY_URL:-https://github.com/fahlman/SwiftRip-HandBrake.git}"
SHA_PLACEHOLDER="PREPARE_TOOL_UPDATE_SHA_PLACEHOLDER"

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

usage() {
    cat <<EOF
Usage: $0 --handbrake-version VERSION [--output-dir PATH]

Builds and packages a proposed SwiftRip-Tools HandBrake update for both arm64
and x86_64. The script verifies that the matching SwiftRip-HandBrake fork tag
exists, builds from that exact fork commit, generates package checksums,
release notes, candidate manifests, and a manifest diff.

This script does not publish GitHub release assets and does not edit SwiftRip.
EOF
}

read_assignment() {
    local file_path="$1"
    local variable_name="$2"
    local value

    value="$(/usr/bin/awk -F'"' -v name="$variable_name" '$0 ~ "^" name "=" { print $2; exit }' "$file_path")"
    if [[ -z "$value" ]]; then
        echo "ERROR: Could not read $variable_name from $file_path" >&2
        exit 1
    fi

    print -r -- "$value"
}

json_escape() {
    /usr/bin/python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

write_manifest() {
    local output_path="$1"
    local version="$2"
    local artifact_name="$3"
    local url="$4"
    local sha256="$5"

    cat > "$output_path" <<EOF
{
  "version": $(json_escape "$version"),
  "artifactName": $(json_escape "$artifact_name"),
  "url": $(json_escape "$url"),
  "sha256": $(json_escape "$sha256")
}
EOF
}

resolve_tag_commit() {
    local repository_url="$1"
    local tag_name="$2"
    local commit

    commit="$(
        git ls-remote --tags "$repository_url" "refs/tags/${tag_name}^{}" \
            | /usr/bin/awk '{ print $1; exit }'
    )"
    if [[ -z "$commit" ]]; then
        commit="$(
            git ls-remote --tags "$repository_url" "refs/tags/${tag_name}" \
                | /usr/bin/awk '{ print $1; exit }'
        )"
    fi

    print -r -- "$commit"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --handbrake-version)
            HANDBRAKE_VERSION_INPUT="${2:-}"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

require_value "handbrake version" "$HANDBRAKE_VERSION_INPUT"
require_value "output directory" "$OUTPUT_DIR"
require_command git
require_command curl
require_command file
require_command otool
require_command tar
require_command xcrun

case "$OUTPUT_DIR" in
    /*)
        ;;
    *)
        OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR"
        ;;
esac

HANDBRAKE_VERSION="${HANDBRAKE_VERSION_INPUT#v}"
if [[ ! "$HANDBRAKE_VERSION" =~ '^[0-9]+(\.[0-9]+){1,3}$' ]]; then
    echo "ERROR: HandBrake version must look like 1.11.2." >&2
    exit 64
fi

LIBDVDCSS_VERSION="$(read_assignment "$LIBDVDCSS_SCRIPT" "LIBDVDCSS_VERSION")"
LIBDVDCSS_SWIFTRIP_TAG="$(read_assignment "$LIBDVDCSS_SCRIPT" "LIBDVDCSS_SWIFTRIP_TAG")"
LIBDVDCSS_SWIFTRIP_COMMIT="$(read_assignment "$LIBDVDCSS_SCRIPT" "LIBDVDCSS_SWIFTRIP_COMMIT")"
HANDBRAKE_SWIFTRIP_TAG="swiftrip-handbrake-${HANDBRAKE_VERSION}"
PACKAGE_VERSION="handbrake-${HANDBRAKE_VERSION}-libdvdcss-${LIBDVDCSS_VERSION}"
RELEASE_TAG="$PACKAGE_VERSION"
RELEASE_BASE_URL="https://github.com/${TOOLS_REPOSITORY}/releases/download/${RELEASE_TAG}"

echo "SwiftRip-Tools prepare update"
echo "Root:             $ROOT_DIR"
echo "Output:           $OUTPUT_DIR"
echo "HandBrake:        $HANDBRAKE_VERSION"
echo "HandBrake fork:   $HANDBRAKE_SWIFTRIP_TAG"
echo "libdvdcss:        $LIBDVDCSS_VERSION"
echo "Release tag:      $RELEASE_TAG"

if ! git ls-remote --exit-code --tags "$HANDBRAKE_UPSTREAM_REPOSITORY_URL" "refs/tags/${HANDBRAKE_VERSION}" >/dev/null 2>&1; then
    echo "ERROR: Upstream HandBrake tag was not found: $HANDBRAKE_VERSION" >&2
    echo "Repository: $HANDBRAKE_UPSTREAM_REPOSITORY_URL" >&2
    exit 1
fi

HANDBRAKE_SWIFTRIP_COMMIT="$(resolve_tag_commit "$HANDBRAKE_SWIFTRIP_REPOSITORY_URL" "$HANDBRAKE_SWIFTRIP_TAG")"
if [[ -z "$HANDBRAKE_SWIFTRIP_COMMIT" ]]; then
    echo "ERROR: SwiftRip-HandBrake fork tag was not found: $HANDBRAKE_SWIFTRIP_TAG" >&2
    echo "Create and push that fork tag before preparing SwiftRip-Tools packages." >&2
    exit 1
fi

echo "HandBrake fork commit: $HANDBRAKE_SWIFTRIP_COMMIT"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Manifest" "$OUTPUT_DIR/Packages" "$OUTPUT_DIR/ReleaseNotes"

typeset -A package_sha_by_arch
typeset -A package_name_by_arch
typeset -A package_url_by_arch

for arch in arm64 x86_64; do
    assert_supported_tools_arch "$arch"

    artifact_name="swiftrip-tools-macos-${arch}-handbrake-${HANDBRAKE_VERSION}-libdvdcss-${LIBDVDCSS_VERSION}.tar.gz"
    package_url="${RELEASE_BASE_URL}/${artifact_name}"
    package_name_by_arch[$arch]="$artifact_name"
    package_url_by_arch[$arch]="$package_url"

    echo ""
    echo "Preparing $arch package..."

    SWIFTRIP_HANDBRAKE_VERSION="$HANDBRAKE_VERSION" \
    SWIFTRIP_HANDBRAKE_REPOSITORY_URL="$HANDBRAKE_SWIFTRIP_REPOSITORY_URL" \
    SWIFTRIP_HANDBRAKE_SWIFTRIP_TAG="$HANDBRAKE_SWIFTRIP_TAG" \
    SWIFTRIP_HANDBRAKE_SWIFTRIP_COMMIT="$HANDBRAKE_SWIFTRIP_COMMIT" \
    SWIFTRIP_TOOLS_ARCH="$arch" \
        "$SCRIPT_DIR/build-swiftrip-tools.zsh"

    SWIFTRIP_TOOLS_PACKAGE_VERSION="$PACKAGE_VERSION" \
    SWIFTRIP_TOOLS_ARTIFACT_NAME="$artifact_name" \
    SWIFTRIP_TOOLS_EXPECTED_SHA256="$SHA_PLACEHOLDER" \
        "$SCRIPT_DIR/package-swiftrip-tools.zsh" --arch "$arch"

    package_path="$ROOT_DIR/Packages/$artifact_name"
    require_file "$package_path" "$arch package"

    package_sha="$(sha256_file "$package_path")"
    package_sha_by_arch[$arch]="$package_sha"
    cp "$package_path" "$OUTPUT_DIR/Packages/$artifact_name"

    echo "$package_sha  $artifact_name" > "$OUTPUT_DIR/Packages/${artifact_name}.sha256"

    case "$arch" in
        arm64)
            manifest_name="swiftrip-tools.json"
            ;;
        x86_64)
            manifest_name="swiftrip-tools-x86_64.json"
            ;;
    esac

    write_manifest \
        "$OUTPUT_DIR/Manifest/$manifest_name" \
        "$PACKAGE_VERSION" \
        "$artifact_name" \
        "$package_url" \
        "$package_sha"
done

release_notes_path="$OUTPUT_DIR/ReleaseNotes/${PACKAGE_VERSION}.md"
cat > "$release_notes_path" <<EOF
# HandBrake ${HANDBRAKE_VERSION} + libdvdcss ${LIBDVDCSS_VERSION}

Prepared SwiftRip-Tools package set for SwiftRip.app.

## Components

- HandBrakeCLI: ${HANDBRAKE_VERSION}
- libdvdcss: ${LIBDVDCSS_VERSION}

## Assets

- \`${package_name_by_arch[arm64]}\`
  - SHA-256: \`${package_sha_by_arch[arm64]}\`
- \`${package_name_by_arch[x86_64]}\`
  - SHA-256: \`${package_sha_by_arch[x86_64]}\`

## Provenance

- Upstream HandBrake: ${HANDBRAKE_VERSION}
- SwiftRip-HandBrake fork tag: \`${HANDBRAKE_SWIFTRIP_TAG}\`
- SwiftRip-HandBrake pinned commit: \`${HANDBRAKE_SWIFTRIP_COMMIT}\`
- SwiftRip libdvdcss source tag: \`${LIBDVDCSS_SWIFTRIP_TAG}\`
- SwiftRip libdvdcss pinned commit: \`${LIBDVDCSS_SWIFTRIP_COMMIT}\`

The generated manifests pin the candidate release asset URLs and SHA-256 checksums. Review the fork patch and package output before publishing these assets.
EOF

diff -u "$ROOT_DIR/Manifest/swiftrip-tools.json" "$OUTPUT_DIR/Manifest/swiftrip-tools.json" > "$OUTPUT_DIR/manifest.diff" || true
diff -u "$ROOT_DIR/Manifest/swiftrip-tools-x86_64.json" "$OUTPUT_DIR/Manifest/swiftrip-tools-x86_64.json" >> "$OUTPUT_DIR/manifest.diff" || true

summary_path="$OUTPUT_DIR/summary.md"
cat > "$summary_path" <<EOF
# SwiftRip-Tools Prepared Update

## Requested Update

- HandBrake: ${HANDBRAKE_VERSION}
- HandBrake fork tag: \`${HANDBRAKE_SWIFTRIP_TAG}\`
- HandBrake fork commit: \`${HANDBRAKE_SWIFTRIP_COMMIT}\`
- libdvdcss: ${LIBDVDCSS_VERSION}
- Candidate release tag: \`${RELEASE_TAG}\`

## Packages

| Arch | Package | SHA-256 |
| --- | --- | --- |
| arm64 | \`${package_name_by_arch[arm64]}\` | \`${package_sha_by_arch[arm64]}\` |
| x86_64 | \`${package_name_by_arch[x86_64]}\` | \`${package_sha_by_arch[x86_64]}\` |

## Generated Files

- \`Manifest/swiftrip-tools.json\`
- \`Manifest/swiftrip-tools-x86_64.json\`
- \`ReleaseNotes/${PACKAGE_VERSION}.md\`
- \`manifest.diff\`
- Candidate package tarballs under \`Packages/\`

## Human Review Before Publishing

- Confirm the SwiftRip-HandBrake patch still loads \`@executable_path/../Frameworks/libdvdcss.2.dylib\`.
- Publish the candidate package tarballs to the \`${RELEASE_TAG}\` GitHub release only after review.
- Apply the generated manifests to SwiftRip-Tools and SwiftRip after publishing.
- Fetch both packages from SwiftRip and rerun \`BundleIntegrityTests\`.
EOF

echo ""
echo "Prepared update artifacts:"
find "$OUTPUT_DIR" -maxdepth 3 -type f | sort
echo ""
echo "Summary: $summary_path"
