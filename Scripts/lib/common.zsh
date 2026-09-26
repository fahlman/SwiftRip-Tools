# Every SwiftRip tool artifact targets the newest macOS, which runs only on
# Apple silicon, so arm64 is the only architecture (see the shared rules).
SWIFTRIP_TOOLS_MIN_MACOS="27.0"

# A package's name includes its minimum macOS, so rebuilding the same HandBrake
# and libdvdcss for a newer macOS publishes a new release instead of replacing
# a package that SwiftRip pins by checksum.
swiftrip_tools_package_version() {
    local handbrake_version="$1"
    local libdvdcss_version="$2"

    print -r -- "handbrake-${handbrake_version}-libdvdcss-${libdvdcss_version}-macos-${SWIFTRIP_TOOLS_MIN_MACOS}"
}

require_command() {
    local command_name="$1"

    if [[ "$command_name" == /* ]]; then
        if [[ -x "$command_name" ]]; then
            return 0
        fi

        echo "ERROR: Required command not found: $command_name" >&2
        exit 1
    fi

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $command_name" >&2
        exit 1
    fi
}

videolan_git() {
    GIT_TERMINAL_PROMPT=0 git \
        -c http.connectTimeout=20 \
        -c http.lowSpeedLimit=1 \
        -c http.lowSpeedTime=20 \
        "$@"
}

videolan_git_retry() {
    local attempt
    local delay
    local output

    for attempt in 1 2 3; do
        if output="$(videolan_git "$@")"; then
            print -r -- "$output"
            return 0
        fi

        if (( attempt < 3 )); then
            delay=$((attempt * 5))
            echo "VideoLAN Git request failed; retrying in ${delay}s (attempt $((attempt + 1))/3)." >&2
            sleep "$delay"
        fi
    done

    echo "ERROR: VideoLAN Git request failed after 3 attempts." >&2
    return 1
}

require_file() {
    local file_path="$1"
    local label="${2:-file}"

    if [[ ! -f "$file_path" ]]; then
        echo "ERROR: Missing $label:" >&2
        echo "$file_path" >&2
        exit 1
    fi
}

require_executable() {
    local executable_path="$1"

    if [[ ! -x "$executable_path" ]]; then
        echo "ERROR: Missing executable:" >&2
        echo "$executable_path" >&2
        exit 1
    fi
}

require_value() {
    local name="$1"
    local value="$2"

    if [[ -z "$value" ]]; then
        echo "ERROR: Missing required value: $name" >&2
        exit 1
    fi
}

assert_supported_tools_arch() {
    local arch="$1"
    local label="${2:-SwiftRip-Tools}"

    case "$arch" in
        arm64)
            ;;
        *)
            echo "ERROR: Unsupported $label architecture: $arch" >&2
            echo "Supported architecture: arm64. Intel builds were retired: macOS $SWIFTRIP_TOOLS_MIN_MACOS runs only on Apple silicon." >&2
            exit 64
            ;;
    esac
}

manifest_file_for_arch() {
    local tools_dir="$1"
    local arch="$2"

    assert_supported_tools_arch "$arch"

    case "$arch" in
        arm64)
            echo "$tools_dir/Manifest/swiftrip-tools.json"
            ;;
    esac
}

json_value() {
    local plist_path="$1"
    local key="$2"

    /usr/bin/plutil -extract "$key" raw -o - "$plist_path"
}

sha256_file() {
    local file_path="$1"

    /usr/bin/shasum -a 256 "$file_path" | /usr/bin/awk '{print $1}'
}
