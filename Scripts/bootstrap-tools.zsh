#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/SwiftRipTools/Scripts"
ARTIFACTS_DIR="$ROOT_DIR/SwiftRipTools/Artifacts/macos-arm64"
FORCE_BUILD=0

for argument in "$@"; do
    case "$argument" in
        --force)
            FORCE_BUILD=1
            ;;
        *)
            echo "Usage: $0 [--force]"
            exit 64
            ;;
    esac
done

echo "SwiftRipTools bootstrap"
echo "Root:      $ROOT_DIR"
echo "Artifacts: $ARTIFACTS_DIR"

if [[ "$FORCE_BUILD" -eq 0 ]] && "$SCRIPTS_DIR/verify-swiftrip-tools.zsh"; then
    echo ""
    echo "Existing SwiftRipTools artifacts are ready."
    exit 0
fi

echo ""
echo "Building SwiftRipTools artifacts..."
"$SCRIPTS_DIR/build-swiftrip-tools.zsh"

echo ""
"$SCRIPTS_DIR/verify-swiftrip-tools.zsh"
