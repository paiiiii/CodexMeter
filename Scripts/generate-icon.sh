#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly SOURCE="$PROJECT_DIR/Resources/AppIcon.png"
readonly OUTPUT="$PROJECT_DIR/Resources/AppIcon.icns"

if [[ ! -f "$SOURCE" ]]; then
    echo "error: missing $SOURCE" >&2
    exit 1
fi

width="$(/usr/bin/sips -g pixelWidth "$SOURCE" 2>/dev/null | awk '/pixelWidth:/{print $2}')"
height="$(/usr/bin/sips -g pixelHeight "$SOURCE" 2>/dev/null | awk '/pixelHeight:/{print $2}')"
format="$(/usr/bin/sips -g format "$SOURCE" 2>/dev/null | awk '/format:/{print $2}')"
readonly width height format

if [[ "$width" != "1024" || "$height" != "1024" || "$format" != "png" ]]; then
    echo "error: AppIcon.png must be a 1024x1024 PNG" >&2
    exit 1
fi

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/codexmeter-icon.XXXXXX")"
readonly temporary_root
readonly iconset="$temporary_root/AppIcon.iconset"

cleanup() {
    rm -rf -- "$temporary_root"
}
trap cleanup EXIT

mkdir -p "$iconset"

render() {
    local size="$1"
    local filename="$2"
    /usr/bin/sips -z "$size" "$size" "$SOURCE" --out "$iconset/$filename" >/dev/null
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

/usr/bin/iconutil -c icns "$iconset" -o "$OUTPUT"
echo "Created $OUTPUT"
