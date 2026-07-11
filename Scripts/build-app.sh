#!/usr/bin/env bash

set -euo pipefail

umask 022

readonly PRODUCT_NAME="CodexMeter"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
readonly XCODE_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

DIST_DIR="${DIST_DIR:-${HOME:?HOME is required}/Applications}"
readonly DIST_DIR
readonly APP_BUNDLE="$DIST_DIR/$PRODUCT_NAME.app"

if [[ -d "$XCODE_DEVELOPER_DIR" ]]; then
    export DEVELOPER_DIR="$XCODE_DEVELOPER_DIR"
fi

if ! command -v swift >/dev/null 2>&1; then
    echo "error: Swift 6.2 or newer is required." >&2
    exit 1
fi

if [[ ! -f "$INFO_PLIST" ]]; then
    echo "error: missing $INFO_PLIST" >&2
    exit 1
fi

if command -v plutil >/dev/null 2>&1; then
    plutil -lint "$INFO_PLIST" >/dev/null
fi

echo "Building $PRODUCT_NAME (Release)..."
(
    cd "$PROJECT_DIR"
    swift build -c release --product "$PRODUCT_NAME"
)

BIN_DIR="$(
    cd "$PROJECT_DIR"
    swift build -c release --show-bin-path
)"
readonly BIN_DIR
readonly EXECUTABLE="$BIN_DIR/$PRODUCT_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "error: Release executable was not produced at $EXECUTABLE" >&2
    exit 1
fi

STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codexmeter-package.XXXXXX")"
readonly STAGING_ROOT
readonly STAGED_APP="$STAGING_ROOT/$PRODUCT_NAME.app"

cleanup() {
    rm -rf -- "$STAGING_ROOT"
}
trap cleanup EXIT

mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
install -m 0755 "$EXECUTABLE" "$STAGED_APP/Contents/MacOS/$PRODUCT_NAME"
install -m 0644 "$INFO_PLIST" "$STAGED_APP/Contents/Info.plist"

# Copy only compiled SwiftPM resource bundles. Source files, environment files,
# credentials, and the user's Codex login state are never copied into the app.
for resource_bundle in "$BIN_DIR"/*.bundle; do
    [[ -d "$resource_bundle" ]] || continue
    cp -R "$resource_bundle" "$STAGED_APP/Contents/Resources/"
done

if command -v codesign >/dev/null 2>&1; then
    echo "Applying ad-hoc code signature..."
    codesign --force --sign - --timestamp=none "$STAGED_APP"
    codesign --verify --deep --strict "$STAGED_APP"
else
    echo "warning: codesign is unavailable; leaving the local bundle unsigned." >&2
fi

mkdir -p "$DIST_DIR"
if [[ -e "$APP_BUNDLE" ]]; then
    rm -rf -- "$APP_BUNDLE"
fi
mv "$STAGED_APP" "$APP_BUNDLE"

echo "Created $APP_BUNDLE"
echo "Run with: open \"$APP_BUNDLE\""
