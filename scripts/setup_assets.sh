#!/bin/bash

set -e

echo "=================================================="
echo "Chess AI - Asset Setup Script"
echo "=================================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$SCRIPT_DIR/../game"
ASSETS_DIR="$GAME_DIR/assets"

echo "Creating asset directories..."
mkdir -p "$ASSETS_DIR/images/pieces"
mkdir -p "$ASSETS_DIR/images/boards"
mkdir -p "$ASSETS_DIR/images/icons"
mkdir -p "$ASSETS_DIR/sounds"

echo "Downloading Lichess chess pieces..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

git clone --depth 1 --filter=blob:none --sparse https://github.com/lichess-org/lila.git
cd lila
git sparse-checkout set public/piece

echo "Copying piece sets..."
cp -r public/piece/cburnett "$ASSETS_DIR/images/pieces/" 2>/dev/null || echo "  cburnett already exists or failed"
cp -r public/piece/merida "$ASSETS_DIR/images/pieces/" 2>/dev/null || echo "  merida already exists or failed"
cp -r public/piece/alpha "$ASSETS_DIR/images/pieces/" 2>/dev/null || echo "  alpha already exists or failed"
cp -r public/piece/pixel "$ASSETS_DIR/images/pieces/" 2>/dev/null || echo "  pixel already exists or failed"

echo "Downloading sound effects..."
cd "$ASSETS_DIR/sounds"

SOUNDS=(
  "Move:https://lichess1.org/assets/sound/standard/Move.mp3"
  "Capture:https://lichess1.org/assets/sound/standard/Capture.mp3"
  "Check:https://lichess1.org/assets/sound/standard/Check.mp3"
  "GenericNotify:https://lichess1.org/assets/sound/standard/GenericNotify.mp3"
)

for sound in "${SOUNDS[@]}"; do
  name="${sound%%:*}"
  url="${sound#*:}"
  lowercase_name=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  if [ ! -f "$lowercase_name.mp3" ]; then
    echo "  Downloading $name..."
    wget -q "$url" -O "$lowercase_name.mp3" || curl -s -o "$lowercase_name.mp3" "$url"
  else
    echo "  $name already exists"
  fi
done

mv genericnotify.mp3 checkmate.mp3 2>/dev/null || echo "  checkmate.mp3 already exists"

echo "Cleaning up..."
rm -rf "$TEMP_DIR"

echo ""
echo "=================================================="
echo "Asset setup complete!"
echo "=================================================="
echo ""
echo "Downloaded assets:"
echo "  - Chess pieces: cburnett, merida, alpha, pixel"
echo "  - Sound effects: move, capture, check, checkmate"
echo ""
echo "Location: $ASSETS_DIR"
echo ""
echo "Note: Fonts are loaded via google_fonts package (no download needed)"
echo ""
