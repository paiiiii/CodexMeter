#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

launch_after_install=1
case "${1:-}" in
    "")
        ;;
    --no-open)
        launch_after_install=0
        ;;
    -h|--help)
        echo "Usage: $(basename "$0") [--no-open]"
        echo "Environment: DIST_DIR sets the destination (default: ~/Applications)."
        exit 0
        ;;
    *)
        echo "error: unknown argument: $1" >&2
        echo "Usage: $(basename "$0") [--no-open]" >&2
        exit 2
        ;;
esac

DIST_DIR="${DIST_DIR:-${HOME:?HOME is required}/Applications}"
readonly DIST_DIR
readonly APP_BUNDLE="$DIST_DIR/CodexMeter.app"

DIST_DIR="$DIST_DIR" "$SCRIPT_DIR/build-app.sh"

if [[ "$launch_after_install" -eq 1 ]]; then
    open "$APP_BUNDLE"
fi
