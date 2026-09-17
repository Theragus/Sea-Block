# Load test

Sea Block is glue: almost everything it does is reaching into Bob's and
Angel's prototypes by name. When those mods rename or remove something, Sea
Block does not fail to compile — it fails at startup, one error at a time,
and each round trip costs a full game launch. This directory exists to make
that loop fast and to catch a whole class of breakage in one pass.

There are two layers, and `ci.sh` drives both:

```sh
tools/loadtest/ci.sh              # fetch everything, then load two configurations
tools/loadtest/ci.sh --skip-fetch # reuse what is already in .loadtest/
```

It loads the core pack and the core pack plus ScienceCostTweakerM, which
exercises a lot of Sea Block code the core pack never reaches. A configuration
passes when the game creates a map, Sea Block logs no warnings of its own, and
the audits come back clean. Other mods' warnings are theirs; failing on those
would make this rig hostage to upstream noise.

`.github/workflows/loadtest.yml` runs exactly this on push and weekly.
Dependency versions live in `dependencies.env`; they are branch refs rather than
commits on purpose, so upstream breaking Sea Block shows up quickly — which
means a pull request can go red without its own code changing, and the failure
is worth reading before assuming it is yours.

## 1. The real game (authoritative)

The Factorio headless build is distributed free and runs the complete data
stage plus prototype validation, which is exactly what has to pass. Creating
a map exercises everything short of actually playing.

```sh
# one-off setup
curl -L -o headless.tar.xz https://factorio.com/get-download/2.1.19/headless/linux64
tar xJf headless.tar.xz            # gives ./factorio

# assemble a mods directory from source checkouts
python3 build_mods.py \
  --root /path/to/factorio-data \
  --root /path/to/bobsmods \
  --root /path/to/Arch666Angel/mods \
  --root /path/to/this/repo \
  --enable boblibrary --enable bobores ... --enable SeaBlock \
  --out factorio/mods

./factorio/bin/x64/factorio --create /tmp/test-map.zip --mod-directory factorio/mods
```

`build_mods.py` packs each source directory as `name_version.zip` and writes a
`mod-list.json`. It disables `quality`, `space-age` and `elevated-rails` by
default, because Factorio enables any bundled mod a `mod-list.json` does not
mention and Sea Block declares those incompatible.

`retest.sh` repacks just Sea Block and re-runs the map creation, which is the
loop to use while fixing errors.

A successful run ends with `Done.` and leaves a map file behind. Any prototype
problem prints as `Error Util.cpp:81: ...` and names the prototype.

## 2. The Lua harness (fast, for audits)

`run.lua` runs the same data stage under plain `lua5.2` using the real
`core/lualib` from [wube/factorio-data], emulating only the globals the engine
injects (`data`, `mods`, `settings`, `defines`, `serpent`, Factorio's
`require` semantics). It loads in about a second, so it is the right place to
hang whole-graph audits that would otherwise need a game launch each.

```sh
python3 discover.py --root /path/to/mods --order-from-log factorio-current.log \
  --out /tmp/manifest.lua
lua5.2 run.lua /tmp/manifest.lua audit_integrity.lua
```

Pass `--order-from-log` a `factorio-current.log` from a real run. Load order
decides which mod sees which data first, and the game's order is the one that
matters; the local topological sort in `discover.py` is only a fallback and
does differ in places.

The harness is not a substitute for the game. It does not validate prototypes,
and it stubs the graphics metadata that `factorio-data` strips. Treat a
disagreement between the two as the harness being wrong.

### Engine behaviour the harness has to match

Three things the game does that plain Lua 5.2 does not, each found by a
disagreement between the two:

- **`require` resolves relative to the requiring file first**, then the mod
  root, then `core/lualib`. ScienceCostTweakerM's `prototypes/0_entity.lua`
  does `require("entities.intermediates")` for a file beside it.
- **`forced_value` beats `default_value`** when resolving a startup setting. Sea
  Block pins Bob's and Angel's options with `forced_value`, so reading only
  `default_value` silently runs a different configuration than the game does.
- **`table.insert` does not enforce its position bound.** Lua 5.1 allowed any
  position and 5.2 added the check; Factorio kept the old behaviour and mods
  rely on it — Bob's inserts its science pack at index 5 of a lab input list
  another mod may have cut to one entry.
- **`defines.prototypes` groups every prototype type under its base type.** The
  base game's recycler mod walks `defines.prototypes.item` to generate a
  recycling recipe per item; an empty table there means no recycling recipes at
  all, and then Bob's indexes a nil for one it expects.

`LOADTEST_DETERMINISTIC=1` sorts `pairs()` keys. Lua randomises its string hash
seed per process, so any mod whose behaviour depends on iteration order becomes
a coin flip — see below. Factorio pins its seed; this gives the harness a stable
order too. Not the game's order, but a reproducible one, which is what CI needs.

### A known flaky failure, and why it matters

Without `LOADTEST_DETERMINISTIC=1`, roughly one run in three dies inside `angelsrefining`'s
`override-functions.lua` with `table index is nil`, reached from
`angelspetrochem`'s data-updates. It is not a harness bug. `p_result_merge` in
`angelsrefining/prototypes/recipe-builder.lua` substitutes a void placeholder
when a recipe patch merges down to no results:

```lua
rs[1] = { "angels-void", 1 }
```

That is the `{"name", count}` shorthand Factorio 2.0 removed, so the entry has
no `name` field, and the next pass over that recipe uses `item.name` as a table
key. Whether it is reached at all depends on `pairs()` ordering, and stock Lua
randomises its string hash seed per process — hence one run in three.

Factorio pins its hash seed for determinism, so the stock game takes the same
path every time and currently does not hit it with this mod set. It is still a
live upstream bug: a different mod set, or an engine change, flips which side
of it you land on. Reported upstream rather than worked around here, because
Sea Block loads after the mod that trips it and cannot get in front of it.

### Audits

| script | what it checks |
| --- | --- |
| `audit_integrity.lua` | every technology prerequisite, recipe unlock and science pack, and every recipe ingredient, result and category, resolves to something that exists |
| `audit_recipes.lua` | recipes use the 2.0 ingredient/result shape, not the removed `{"name", count}` shorthand or `normal`/`expensive` split |
| `dump.lua` | writes every prototype name to `$LOADTEST_DUMP` as `type<TAB>name` |
| `audit_icons.lua` | every declared `icon_size` fits inside the actual PNG — the one class of breakage a headless server cannot see, because it never loads sprites |
| `audit_starting_items.lua` | the starting rock chest can be filled — it runs in the control stage from chunk generation, where a missing item is non-recoverable, and neither a headless map creation nor a data stage load reaches it |
| `audit_milestones_preset.lua` | the Milestones preset Sea Block serves from `remote.lua` names real prototypes — Milestones drops invalid entries rather than erroring, so the only symptom is a milestone quietly missing |
| `check_references.py` | cross-references names written in Sea Block's source against a dump, so renamed prototypes show up all at once |

`LOADTEST_STOP_AFTER=data` stops after a given stage, which is how you find
which mod introduced bad data when a later mod is the one that crashes on it.

[wube/factorio-data]: https://github.com/wube/factorio-data
