#!/bin/sh
# Repack Sea Block (and the metapack) and run the real Factorio data stage.
set -e
REPO="${REPO:-/home/user/Sea-Block}"
FACTORIO="${FACTORIO:-/home/user/factorio-test}"
VERSION=$(python3 -c "import json;print(json.load(open('$REPO/SeaBlock/info.json'))['version'])")
rm -f "$FACTORIO"/mods/SeaBlock_*.zip
cd "$REPO" && zip -qr "$FACTORIO/mods/SeaBlock_$VERSION.zip" SeaBlock -x '*.git*'
# Factorio wants the archive's top-level folder to be name_version.
cd "$FACTORIO/mods" && mkdir -p .stage && rm -rf .stage/* \
  && cp -r "$REPO/SeaBlock" ".stage/SeaBlock_$VERSION" \
  && rm -f "SeaBlock_$VERSION.zip" \
  && (cd .stage && zip -qr "../SeaBlock_$VERSION.zip" "SeaBlock_$VERSION") \
  && rm -rf .stage
cd "$FACTORIO"
rm -f /tmp/claude-0/lt/test-map.zip
./factorio/bin/x64/factorio --create /tmp/claude-0/lt/test-map.zip --mod-directory "$FACTORIO/mods" 2>&1 | tail -"${TAIL:-25}"
