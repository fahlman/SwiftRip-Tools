#!/bin/zsh
set -euo pipefail

TARGET_PATH="${1:-}"

if [[ -z "$TARGET_PATH" || "$TARGET_PATH" == "-h" || "$TARGET_PATH" == "--help" ]]; then
    echo "Usage: $0 PATH_TO_A03_MACOS_HARDENED_RUNTIME_DLOPEN_PATCH"
    exit $([[ -z "$TARGET_PATH" ]] && echo 64 || echo 0)
fi

if [[ ! -f "$TARGET_PATH" ]]; then
    echo "ERROR: HandBrake libdvdread patch was not found:"
    echo "$TARGET_PATH"
    exit 1
fi

/usr/bin/python3 - "$TARGET_PATH" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

old = '+  #define CSS_USR_LOCAL_LIB "/usr/local/lib/libdvdcss.2.dylib"'
new = '+  #define CSS_USR_LOCAL_LIB "@executable_path/../Frameworks/libdvdcss.2.dylib"'

old_count = text.count(old)
new_count = text.count(new)

if old_count == 0 and new_count == 1:
    print(f"HandBrake libdvdcss patch already applied: {path}")
    raise SystemExit(0)

if old_count != 1 or new_count != 0:
    print("ERROR: HandBrake's libdvdread patch no longer has the expected single", file=sys.stderr)
    print("/usr/local/lib -> app-bundle Frameworks substitution.", file=sys.stderr)
    print(f"Path: {path}", file=sys.stderr)
    print(f"Legacy occurrence count: {old_count}", file=sys.stderr)
    print(f"App-bundle occurrence count: {new_count}", file=sys.stderr)
    raise SystemExit(1)

path.write_text(text.replace(old, new), encoding="utf-8")
print(f"Applied HandBrake libdvdcss patch: {path}")
PY
