#!/usr/bin/env bash
#
# Fetch the dependencies, then load Sea Block two ways: the core pack, and the
# core pack plus ScienceCostTweakerM, which exercises a large amount of
# Sea Block-specific code that the core pack never touches.
#
# Runs the same locally as in CI. Everything lands under $WORK (default
# .loadtest/), which is safe to delete.
#
# Usage: tools/loadtest/ci.sh [--skip-fetch]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
WORK="${WORK:-$REPO/.loadtest}"

# shellcheck disable=SC1091
set -a; . "$HERE/dependencies.env"; set +a

DEPS="$WORK/deps"
GAME="$WORK/factorio"
mkdir -p "$DEPS"

clone_at() {
  local repo="$1" ref="$2" dest="$3"
  if [ -d "$dest/.git" ]; then
    git -C "$dest" fetch --depth 1 origin "$ref" --quiet
  else
    rm -rf "$dest"
    git -C "$DEPS" init --quiet "$(basename "$dest")"
    git -C "$dest" remote add origin "https://github.com/$repo"
    git -C "$dest" fetch --depth 1 origin "$ref" --quiet
  fi
  git -C "$dest" checkout --quiet FETCH_HEAD
  echo "  $repo @ $ref -> $(git -C "$dest" rev-parse --short HEAD)"
}

if [ "${1:-}" != "--skip-fetch" ]; then
  echo "== fetching dependencies =="
  GIT_LFS_SKIP_SMUDGE=1 clone_at "$FACTORIO_DATA_REPO" "$FACTORIO_DATA_REF" "$DEPS/factorio-data"
  GIT_LFS_SKIP_SMUDGE=1 clone_at "$BOBSMODS_REPO" "$BOBSMODS_REF" "$DEPS/bobsmods"
  GIT_LFS_SKIP_SMUDGE=1 clone_at "$ANGELS_REPO" "$ANGELS_REF" "$DEPS/angelsmods"
  GIT_LFS_SKIP_SMUDGE=1 clone_at "$SCT_REPO" "$SCT_REF" "$DEPS/sct"

  if [ ! -x "$GAME/bin/x64/factorio" ]; then
    echo "  downloading Factorio $FACTORIO_VERSION headless"
    mkdir -p "$WORK"
    curl -sS -L -o "$WORK/headless.tar.xz" \
      "https://factorio.com/get-download/$FACTORIO_VERSION/headless/linux64"
    tar xJf "$WORK/headless.tar.xz" -C "$WORK"
    rm -f "$WORK/headless.tar.xz"
  fi
  echo "  factorio $("$GAME/bin/x64/factorio" --version | head -1)"
fi

ROOTS=(--root "$DEPS/factorio-data" --root "$DEPS/bobsmods" --root "$DEPS/angelsmods"
       --root "$DEPS/sct" --root "$REPO")

# The pack as the metapack defines it, minus the mods that are not on GitHub.
CORE_PACK=(boblibrary bobores bobplates bobelectronics boblogistics bobassembly
           bobenemies bobequipment bobinserters bobmining bobmodules bobpower
           bobrevamp bobtech bobwarfare bobgreenhouse bobvehicleequipment bobclasses
           angelsrefining angelsrefininggraphics angelspetrochem angelspetrochemgraphics
           angelssmelting angelssmeltinggraphics angelsbioprocessing
           angelsbioprocessinggraphics angelsaddons-storage SeaBlock21)

run_config() {
  local label="$1"; shift
  local enables=()
  for mod in "$@"; do enables+=(--enable "$mod"); done

  echo
  echo "== $label =="
  python3 "$HERE/build_mods.py" "${ROOTS[@]}" "${enables[@]}" --out "$GAME/mods" >/dev/null

  rm -f "$WORK/$label.zip"
  if ! "$GAME/bin/x64/factorio" --create "$WORK/$label.zip" \
        --mod-directory "$GAME/mods" >"$WORK/$label.log" 2>&1; then
    echo "FAILED: the data stage or prototype validation rejected this configuration"
    grep -a "Error" "$WORK/$label.log" | tail -20
    return 1
  fi
  grep -aq "^ *[0-9.]* Goodbye$" "$WORK/$label.log" || { echo "FAILED: no clean exit"; tail -20 "$WORK/$label.log"; return 1; }
  echo "  map created"

  # Warnings Sea Block itself is responsible for. Other mods' warnings are
  # theirs; failing on those would make this rig hostage to upstream noise.
  if grep -a "SeaBlock" "$WORK/$label.log" | grep -aqE "Warning|does not exist|missing setting"; then
    echo "FAILED: Sea Block logged warnings"
    grep -a "SeaBlock" "$WORK/$label.log" | grep -aE "Warning|does not exist|missing setting" | head -20
    return 1
  fi
  echo "  no Sea Block warnings"

  # The audits need the game's own load order, which the log records.
  python3 "$HERE/discover.py" --root "$GAME/mods-src" --order-from-log "$GAME/factorio-current.log" \
    --out "$WORK/$label-manifest.lua" >/dev/null 2>&1 || {
      # build_mods.py packs into zips; point the harness at the sources instead.
      python3 "$HERE/discover.py" "${ROOTS[@]}" --order-from-log "$GAME/factorio-current.log" \
        --out "$WORK/$label-manifest.lua" >/dev/null
    }
  LOADTEST_DETERMINISTIC=1 lua5.2 "$HERE/run.lua" "$WORK/$label-manifest.lua" \
    "$HERE/audit_integrity.lua" "$HERE/audit_recipes.lua" "$HERE/audit_icons.lua" \
    "$HERE/audit_starting_items.lua" "$HERE/audit_milestones_preset.lua"
}

failed=0
run_config core "${CORE_PACK[@]}" || failed=1
run_config sct "${CORE_PACK[@]}" ScienceCostTweakerM || failed=1

echo
if [ "$failed" -eq 0 ]; then
  echo "load test passed"
else
  echo "load test FAILED"
fi
exit "$failed"
