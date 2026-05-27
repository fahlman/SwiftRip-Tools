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
        arm64|x86_64)
            ;;
        *)
            echo "ERROR: Unsupported $label architecture: $arch" >&2
            echo "Supported architectures: arm64, x86_64" >&2
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
        x86_64)
            echo "$tools_dir/Manifest/swiftrip-tools-x86_64.json"
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
