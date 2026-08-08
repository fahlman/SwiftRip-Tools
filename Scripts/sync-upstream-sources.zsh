#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMON_SCRIPT="$SCRIPT_DIR/lib/common.zsh"
PATCH_SCRIPT="$SCRIPT_DIR/apply-handbrake-libdvdcss-patch.zsh"
WORK_DIR=""
HANDBRAKE_VERSION=""
LIBDVDCSS_VERSION=""
DRY_RUN=false
OUTPUT_FILE="${GITHUB_OUTPUT:-}"

HANDBRAKE_UPSTREAM_REPOSITORY_URL="${SWIFTRIP_HANDBRAKE_UPSTREAM_REPOSITORY_URL:-https://github.com/HandBrake/HandBrake.git}"
HANDBRAKE_SWIFTRIP_REPOSITORY_URL="${SWIFTRIP_HANDBRAKE_REPOSITORY_URL:-https://github.com/fahlman/SwiftRip-HandBrake.git}"
LIBDVDCSS_UPSTREAM_REPOSITORY_URL="${SWIFTRIP_LIBDVDCSS_UPSTREAM_REPOSITORY_URL:-https://code.videolan.org/videolan/libdvdcss.git}"
LIBDVDCSS_SWIFTRIP_REPOSITORY_URL="${SWIFTRIP_LIBDVDCSS_REPOSITORY_URL:-https://github.com/fahlman/SwiftRip-libdvdcss.git}"
AUTOMATION_TOKEN="${SWIFTRIP_AUTOMATION_TOKEN:-${GITHUB_TOKEN:-}}"

# shellcheck source=/dev/null
source "$COMMON_SCRIPT"

usage() {
    cat <<'USAGE'
Usage: Scripts/sync-upstream-sources.zsh --handbrake-version VERSION --libdvdcss-version VERSION [options]

Create immutable SwiftRip source tags for the requested upstream versions.

HandBrake is cloned from the exact upstream release tag, the single SwiftRip
libdvdcss app-bundle patch is applied, and the resulting commit is pushed to
SwiftRip-HandBrake as swiftrip-handbrake-VERSION.

libdvdcss is cloned from the exact VideoLAN release tag and pushed unchanged
to SwiftRip-libdvdcss as swiftrip-libdvdcss-VERSION.

Options:
  --handbrake-version VERSION  Upstream HandBrake release, for example 1.11.2.
  --libdvdcss-version VERSION  Upstream libdvdcss release, for example 1.6.0.
  --output-file PATH            Write key=value results to PATH.
  --dry-run                     Build and verify source commits without pushing.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --handbrake-version)
            HANDBRAKE_VERSION="${2:-}"
            shift 2
            ;;
        --libdvdcss-version)
            LIBDVDCSS_VERSION="${2:-}"
            shift 2
            ;;
        --output-file)
            OUTPUT_FILE="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
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

require_value "HandBrake version" "$HANDBRAKE_VERSION"
require_value "libdvdcss version" "$LIBDVDCSS_VERSION"
require_command git
require_command curl
if [[ "$DRY_RUN" == false ]]; then
    require_command base64
fi

if [[ "$DRY_RUN" == false ]]; then
    require_value "SWIFTRIP_AUTOMATION_TOKEN" "$AUTOMATION_TOKEN"
fi

if [[ ! "$HANDBRAKE_VERSION" =~ '^[0-9]+(\.[0-9]+){1,3}$' ]]; then
    echo "ERROR: Invalid HandBrake version: $HANDBRAKE_VERSION" >&2
    exit 64
fi
if [[ ! "$LIBDVDCSS_VERSION" =~ '^[0-9]+(\.[0-9]+){1,3}$' ]]; then
    echo "ERROR: Invalid libdvdcss version: $LIBDVDCSS_VERSION" >&2
    exit 64
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/swiftrip-source-sync.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

authenticated_git() {
    if [[ "$DRY_RUN" == true || -z "$AUTOMATION_TOKEN" ]]; then
        git "$@"
        return
    fi

    local encoded_credentials
    encoded_credentials="$(printf 'x-access-token:%s' "$AUTOMATION_TOKEN" | base64 | tr -d '\n')"
    git -c "http.extraheader=Authorization: Basic $encoded_credentials" "$@"
}

remote_tag_commit() {
    local repository_url="$1"
    local tag_name="$2"
    local commit

    if [[ "$repository_url" == https://github.com/* ]]; then
        commit="$(authenticated_git ls-remote --tags "$repository_url" "refs/tags/${tag_name}^{}" | /usr/bin/awk '{ print $1; exit }')"
    else
        commit="$(GIT_TERMINAL_PROMPT=0 git \
            -c http.connectTimeout=20 \
            -c http.lowSpeedLimit=1 \
            -c http.lowSpeedTime=20 \
            ls-remote --tags "$repository_url" "refs/tags/${tag_name}^{}" \
            | /usr/bin/awk '{ print $1; exit }')"
    fi
    if [[ -z "$commit" ]]; then
        if [[ "$repository_url" == https://github.com/* ]]; then
            commit="$(authenticated_git ls-remote --tags "$repository_url" "refs/tags/${tag_name}" | /usr/bin/awk '{ print $1; exit }')"
        else
            commit="$(GIT_TERMINAL_PROMPT=0 git \
                -c http.connectTimeout=20 \
                -c http.lowSpeedLimit=1 \
                -c http.lowSpeedTime=20 \
                ls-remote --tags "$repository_url" "refs/tags/${tag_name}" \
                | /usr/bin/awk '{ print $1; exit }')"
        fi
    fi

    print -r -- "$commit"
}

resolve_upstream_tag() {
    local repository_url="$1"
    local version="$2"
    local candidate
    local commit

    for candidate in "$version" "v$version" "v_${version//./_}"; do
        commit="$(remote_tag_commit "$repository_url" "$candidate")"
        if [[ -n "$commit" ]]; then
            print -r -- "$candidate"
            return 0
        fi
    done

    echo "ERROR: Could not find upstream release tag for $version in $repository_url" >&2
    return 1
}

clone_tag() {
    local repository_url="$1"
    local tag_name="$2"
    local destination="$3"

    if [[ "$repository_url" == https://code.videolan.org/* ]]; then
        git clone --quiet --depth 1 --branch "$tag_name" "$repository_url" "$destination"
        return
    fi

    git clone --quiet --filter=blob:none --no-checkout "$repository_url" "$destination"
    git -C "$destination" fetch --quiet --depth 1 origin "refs/tags/${tag_name}:refs/tags/${tag_name}"
    git -C "$destination" checkout --quiet --detach "$tag_name"
}

push_tag() {
    local source_dir="$1"
    local repository_url="$2"
    local tag_name="$3"

    if [[ "$DRY_RUN" == true ]]; then
        echo "DRY RUN: would push $tag_name to $repository_url" >&2
        return 0
    fi

    authenticated_git -C "$source_dir" \
        push --quiet "$repository_url" "HEAD:refs/tags/$tag_name"
}

ensure_handbrake_tag() {
    local upstream_tag
    local fork_tag="swiftrip-handbrake-$HANDBRAKE_VERSION"
    local existing_commit
    local source_dir="$WORK_DIR/HandBrake"
    local patch_path

    existing_commit="$(remote_tag_commit "$HANDBRAKE_SWIFTRIP_REPOSITORY_URL" "$fork_tag")"
    if [[ -n "$existing_commit" ]]; then
        echo "HandBrake source tag already exists: $fork_tag ($existing_commit)" >&2
        print -r -- "$existing_commit"
        return 0
    fi

    upstream_tag="$(resolve_upstream_tag "$HANDBRAKE_UPSTREAM_REPOSITORY_URL" "$HANDBRAKE_VERSION")"
    echo "Creating $fork_tag from HandBrake upstream tag $upstream_tag..." >&2
    clone_tag "$HANDBRAKE_UPSTREAM_REPOSITORY_URL" "$upstream_tag" "$source_dir"

    patch_path="$source_dir/contrib/libdvdread/A03-macOS-hardened-runtime-dlopen.patch"
    "$PATCH_SCRIPT" "$patch_path" >&2

    git -C "$source_dir" config user.name "SwiftRip upstream automation"
    git -C "$source_dir" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git -C "$source_dir" add contrib/libdvdread/A03-macOS-hardened-runtime-dlopen.patch
    if ! git -C "$source_dir" diff --cached --quiet; then
        git -C "$source_dir" commit --quiet -m "Load libdvdcss from app bundle frameworks"
    fi

    push_tag "$source_dir" "$HANDBRAKE_SWIFTRIP_REPOSITORY_URL" "$fork_tag"
    existing_commit="$(git -C "$source_dir" rev-parse HEAD)"
    print -r -- "$existing_commit"
}

ensure_libdvdcss_tag() {
    local upstream_tag
    local fork_tag="swiftrip-libdvdcss-$LIBDVDCSS_VERSION"
    local existing_commit
    local source_dir="$WORK_DIR/libdvdcss"

    existing_commit="$(remote_tag_commit "$LIBDVDCSS_SWIFTRIP_REPOSITORY_URL" "$fork_tag")"
    if [[ -n "$existing_commit" ]]; then
        echo "libdvdcss source tag already exists: $fork_tag ($existing_commit)" >&2
        print -r -- "$existing_commit"
        return 0
    fi

    upstream_tag="$(resolve_upstream_tag "$LIBDVDCSS_UPSTREAM_REPOSITORY_URL" "$LIBDVDCSS_VERSION")"
    echo "Creating $fork_tag from VideoLAN upstream tag $upstream_tag..." >&2
    clone_tag "$LIBDVDCSS_UPSTREAM_REPOSITORY_URL" "$upstream_tag" "$source_dir"

    git -C "$source_dir" config user.name "SwiftRip upstream automation"
    git -C "$source_dir" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    push_tag "$source_dir" "$LIBDVDCSS_SWIFTRIP_REPOSITORY_URL" "$fork_tag"
    existing_commit="$(git -C "$source_dir" rev-parse HEAD)"
    print -r -- "$existing_commit"
}

echo "SwiftRip upstream source synchronization"
echo "HandBrake:  $HANDBRAKE_VERSION"
echo "libdvdcss:  $LIBDVDCSS_VERSION"
echo "Dry run:    $DRY_RUN"

HANDBRAKE_COMMIT="$(ensure_handbrake_tag)"
LIBDVDCSS_COMMIT="$(ensure_libdvdcss_tag)"

echo "HandBrake fork commit:  $HANDBRAKE_COMMIT"
echo "libdvdcss fork commit:  $LIBDVDCSS_COMMIT"

if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    {
        print -r -- "handbrake_version=$HANDBRAKE_VERSION"
        print -r -- "handbrake_tag=swiftrip-handbrake-$HANDBRAKE_VERSION"
        print -r -- "handbrake_commit=$HANDBRAKE_COMMIT"
        print -r -- "libdvdcss_version=$LIBDVDCSS_VERSION"
        print -r -- "libdvdcss_tag=swiftrip-libdvdcss-$LIBDVDCSS_VERSION"
        print -r -- "libdvdcss_commit=$LIBDVDCSS_COMMIT"
    } > "$OUTPUT_FILE"
fi
