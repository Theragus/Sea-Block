# AGENTS.md

Orientation for AI agents and new contributors. It complements [README.md](README.md)
(what the project is, requirements, how it releases) and
[tools/loadtest/README.md](tools/loadtest/README.md) (how a change is tested).
Read both before changing anything; this file is the map between them.

## What this repository is

Sea Block is a Factorio overhaul mod: the map is open sea with one small island,
there are no ore patches, and every resource is pulled out of water through
Angel's and Bob's processing chains. This repository is a fork of
[modded-factorio/SeaBlock](https://github.com/modded-factorio/SeaBlock) that
carries its unreleased 2.0 `dev` branch forward to **Factorio 2.1**, because the
upstream port could no longer be installed at all (2.0 and 2.1 are separate
major versions to Factorio, and Bob's and Angel's had moved to 2.1).

- **Two mods ship from here.** `SeaBlock/` is the mod, published as `SeaBlock21`
  with the in-game title "Sea Block". `SeaBlockMetaPack/` is published as
  `SeaBlockMetaPack21`; it is a dependency list with no code, so installing it
  pulls in the whole recommended pack.
- **The portal names are not negotiable.** Mod portal names are unique per
  account and the originals belong to Trainwreck. Asset paths therefore use
  `__SeaBlock21__/...`, the remote interface is `SeaBlock21`, and both mods
  declare the originals (`SeaBlock`, `SeaBlockMetaPack`) incompatible.
- **Dependencies.** Hard: `base`, Bob's 3.0.x (`boblibrary`, `bobores`,
  `bobplates`, `bobelectronics`, `boblogistics`) and Angel's 2.1.x (`refining`,
  `petrochem`, `smelting`, `bioprocessing`). Many more are optional and gated
  with `if mods["..."]`. `quality`, `space-age`, `alien-biomes` and
  `angelsexploration` are declared incompatible. See `SeaBlock/info.json`.
- **Status.** It needs Factorio 2.1.20 or later, and loads and generates maps
  on 2.1.20 and 2.1.21 headless, with and without ScienceCostTweakerM. It has
  been play-tested to green science. Cliffs, migrations and balance are open
  upstream (README).
- **Languages.** Lua (Factorio embeds Lua 5.2) for the mod; Python 3 and bash
  for tooling, standard library only. No package manager, no lockfile.
- **Licence.** MIT, © KiwiHawk. `LICENSE` must ship inside each mod zip;
  `tools/package.py` refuses to pack without it.

## How a Factorio mod loads, and why the file names matter

Factorio runs every mod through fixed stages, in dependency order, and each
stage file of *every* mod runs before the next stage file of *any* mod:

1. **Settings stage**: `settings.lua`, `settings-updates.lua`,
   `settings-final-fixes.lua`. Declares mod settings.
2. **Data stage**: `data.lua`, then `data-updates.lua`, then
   `data-final-fixes.lua`. Mods build and mutate the global `data.raw` table of
   prototypes (items, recipes, technologies, entities, tiles, noise
   expressions). Only what is left in `data.raw` at the end exists in the game.
3. **Control stage**: `control.lua`, the live game. Prototypes are read-only via
   `prototypes.*`; the only state that survives a save is the `storage` table.

Sea Block declares Bob's and Angel's as dependencies, so each of its stage files
runs *after* theirs. That ordering is the whole design: Sea Block is glue that
reaches into `data.raw` by name and rewrites what Bob's and Angel's built. A
change that must see every other mod's final state goes in `data-final-fixes`;
one that other mods should be able to react to goes earlier.

Consequence for debugging: a renamed or removed prototype upstream does not
fail to compile. It fails at game start, one error per launch, or worse, loads
fine and silently strands a recipe. The load test exists for exactly that.

## Repository layout

```
SeaBlock/                     the mod (portal name SeaBlock21)
  info.json                   name, version, factorio_version, dependencies
  changelog.txt               Factorio-format changelog; newest entry == info.json version
  settings.lua                sb-default-landfill (only with LandfillPainting)
  settings-updates.lua        pins other mods' startup settings; requires settings-updates/*
  data.lua                    stage 1: lib, own prototypes, mapgen, data/*
  data-updates.lua            stage 2: requires data-updates/* (recipe and tech surgery)
  data-final-fixes.lua        stage 3: requires data-final-fixes/* (repairs that need everyone's final state)
  control.lua                 runtime: rock chest, tutorial unlock fallback, config-change reset
  remote.lua                  remote interface "SeaBlock21" (Milestones preset, victory stats, API)
  starting-items.lua          starting chest contents; shared by control.lua and data/misc.lua (YAFC)
  lib.lua                     seablock.lib.* helpers and seablock.reskins.* icon compositing
  mapgen.lua                  island/sea noise expressions, tiles, trees, worms (data stage)
  prototypes/                 Sea Block's own prototypes: items, recipes, categories, techs, rock chest
  data/                       tables.lua (startup-chain config), tech-tree, recipe, misc, SCT
  data-updates/               one file per topic: coal, algae, landfill, military, startup, ...
  data-final-fixes/           research-triggers, lab-coverage, mapgen, tech-tree, ...
  settings-updates/           one file per dependency mod whose settings are forced
  migrations/                 upstream 0.5.x/0.6.0 migrations (JSON renames and Lua)
  locale/<lang>/SeaBlock.cfg  translations; en is the source
  graphics/                   three technology icons and one item icon
SeaBlockMetaPack/             the pack (portal name SeaBlockMetaPack21): info.json, changelog, LICENSE, thumbnail
tools/
  package.py                  zips both mods as name_version.zip; checks LICENSE and changelog/version
  publish.py                  uploads to the mod portal; --pending asks it what is new, --check-tag checks a tag
  loadtest/                   the test rig (see its README): ci.sh, build_mods.py, discover.py,
                              run.lua + env.lua (Lua harness), audit_*.lua, check_references.py
.github/workflows/
  loadtest.yml                push, PR, weekly: tools/loadtest/ci.sh
  stylua.yml                  push: formats *.lua and commits "Format Code" as StyLuaFormatter (check run "prettier")
  release.yml                 push to main: asks the portal what is new; on approval, load test, publish, tag, release
  version.yml                 PR: changelog must match info.json; warns when a mod folder changes without a version bump
.github/ISSUE_TEMPLATE/       crash, soft-lock, suggestion forms
.github/CODEOWNERS            `* @Theragus`: every pull request needs the owner's review before merging
stylua.toml                   2-space indent (everything else StyLua default, 120 columns)
assets.sh                     one-off ImageMagick script that made graphics/technology/*.png; not a build step
factorio-mods-localization.json  Crowdin bot config inherited from upstream (points at a "dev" branch this repo lacks)
```

## Architecture of `SeaBlock/`

### Globals and helpers

Everything Sea Block defines hangs off one global table, `seablock`, created
with `seablock = seablock or {}` at the top of each entry file.

- `seablock.lib` (`lib.lua`): recipe and technology surgery. `substingredient`,
  `substresult`, `removeingredient`, `addresult`, `add_recipe_unlock`,
  `moveeffect` (follows an unlock that Bob's or Angel's moved to another
  technology), `takeeffect`, `add_effect`, `remove_effect`, `findtechunlock`,
  `hide` / `hide_item` / `hide_technology` / `unhide` / `unhide_recipe`,
  `copy_icon`, `add_flag`, `set_tile_restriction`, `set_probability_expression`,
  and `inherited_tech_unit` (derive a science cost from prerequisites).
- `seablock.reskins` (`lib.lua`): icon compositing copied from Artisanal
  Reskins with permission.
- `seablock.scripted_techs`, `seablock.startup_techs`,
  `seablock.startup_recipes`, `seablock.final_scripted_tech`,
  `seablock.final_startup_tech` (`data/tables.lua`): the configuration of the
  startup chain, below.
- `seablock.overwrite_setting`, `seablock.set_setting_default_value`
  (`settings-updates.lua`).
- `seablock.populate_starting_items` (`starting-items.lua`).

Sea Block also leans on its dependencies' libraries: `bobmods.lib.tech.*` and
`bobmods.lib.recipe.*` from boblibrary (`add_prerequisite`,
`replace_prerequisite`, `add_recipe_unlock`, `remove_recipe_unlock`,
`replace_ingredient`, `enabled`, `hide`, `set_category`, ...) and
`angelsmods.functions.*` from Angel's (`move_item`, `make_void`, ...).

**Most helpers log a warning instead of erroring when a name does not exist**,
and `tools/loadtest/ci.sh` fails the run on any log line mentioning `SeaBlock`
together with `Warning`, `does not exist` or `missing setting`. So a warning
from one of these helpers is a CI failure, not noise.

### The data stage, in `require` order

`data.lua`: `lib`, `prototypes/{item,recipe,recipe-category,technology,rockchest}`,
`mapgen`, `data-updates/Companion_Drones` (yes, from data.lua), then
`data/{tables,misc,ScienceCostTweakerM,recipe,tech-tree}`.

`data-updates.lua`: one file per topic. Notable ones: `coal.lua` (coal is
replaced by charcoal everywhere), `landfill.lua` (landfill from crushed stone),
`military.lua` (hides most of Bob's military tree; the only enemies are worms),
`unobtainable-items.lua` (hides mining drills, pumpjacks, gas refineries and
everything else that needs an ore patch), `slag-processing.lua`,
`thermal-extractor.lua`, `sulfur.lua`, `other-mods.lua` (compatibility for
mods outside the pack), and **`startup.lua`**, which runs near the end so it
sees the recipe graph after all the shuffling above.

`data-final-fixes.lua`: `logistics` (belt speeds), `icons`, `recipe`,
`tech-tree`, `unobtainable_items` (internal renames so FNEI search works),
`research-triggers`, `lab-coverage`, `mapgen`, `SpaceMod`, `ScienceCostTweakerM`
and, after every pass that edits prerequisites, `hidden-prerequisites`.

### The startup (tutorial) chain

The game begins with a rock chest of starting items and no lab. A short chain
of **research-trigger technologies** walks the player to red science:

| technology | completes when the player crafts | unlocks |
| --- | --- | --- |
| `sb-startup1` | crushed stiratite (`angels-ore3-crushed`) | iron plate, copper plate, copper cable |
| `angels-bio-wood-processing` | the same crushed stiratite (made a tutorial tech in `startup.lua`) | wood processing |
| `sb-startup3` | a basic circuit board (the 200 in the chest do not count) | inserters, pipes, gears, chests, belts, lab |
| `sb-startup4` | a lab | automation science pack |

With ScienceCostTweakerM installed, `sct-lab-t1` and
`sct-automation-science-pack` take the place of the last two: `startup.lua`
gives them the triggers, moves `sb-startup4`'s effects onto the SCT technology
and hides `sb-startup4`. `seablock.final_scripted_tech` names whichever ends
the chain.

`data/tables.lua` configures the chain and `data-updates/startup.lua` applies it:

- `scripted_techs` get no prerequisites added and ignore the tech cost
  multiplier.
- Every recipe that consumes a starting item (iron plate, gears, circuits,
  bricks, ...) is disabled and re-granted by `final_scripted_tech`, except the
  `startup_recipes` that stay enabled (electrolyser, crystallizer, offshore
  pump, foraging, ...). Their ingredients are pinned in `startup.lua`'s
  `knowningredients` table so the chest contents always suffice.
- `startup_techs` are made to depend on `final_scripted_tech`, capped at 20 red
  science and 15 seconds. **Any other technology with no prerequisites is given
  `final_startup_tech` (`angels-slag-processing-1`) as one.** That gate is why
  `data-final-fixes/research-triggers.lua` has to ungate trigger technologies
  that unlock nothing.

`control.lua` keeps a fallback: `storage.unlocks` maps an item to the
technologies it completes, and holding, picking up or crafting that item marks
them researched. Basic circuit boards only count when crafted.

### Map generation

`mapgen.lua` (data stage) clones `sand-1`/`sand-2` as `sand-4` (beach) and
`sand-5` (island interior), strips autoplace from every tile, and overrides the
`elevation` noise expression: a guaranteed starting tile, water below the
`waterline`, and a `distance_sigmoid` that lets scattered islands grow with
distance. Angel's trees only spawn on `sand-5` through `random_tree_islands`.
Worms are placed by `worm_autoplace`, which multiplies by `(1 - no_enemies_mode)`
so the "no enemies" map setting works (upstream #353); the puffer nest is an
Angel's resource and is deliberately exempt.

`data-final-fixes/mapgen.lua` removes autoplace from **every** resource (no ore
patches) and restricts Nauvis's `autoplace_settings` to the listed tiles and
entities. Cliffs are not reimplemented (upstream #352).

### Self-repair passes in `data-final-fixes`

Three modules are generic "find it and fix it" passes rather than per-name
patches, so they keep working as Bob's, Angel's and the base game move:

- `research-triggers.lua`: a 2.x research trigger that names a prototype Sea
  Block removed or made unobtainable gets a science cost inherited from its
  prerequisites (or is made free if it is a root). Trigger technologies that
  unlock nothing lose the startup gate, because Factorio would otherwise hold
  them at 99% with a full bar.
- `lab-coverage.lua`: Factorio 2.1 refuses to load if any technology's science
  pack set, hidden ones included, is not accepted in full by some lab. Hidden
  technologies are rewritten quietly; a visible one failing is logged loudly
  because that is a real progression bug.
- `hidden-prerequisites.lua`: a visible technology that requires a hidden or
  disabled one can never be researched, and the tree does not draw the hidden
  one, so the player sees every prerequisite green. Angel's disables Bob's
  `bob-<metal>-processing` technologies, and Bob's mods that load later add
  them back as prerequisites; the pass points each at
  `angels-<metal>-smelting-1`, or at an entry in its `successors` table.
  Prerequisites with no known successor are left for
  `audit_hidden_prerequisites.lua`, which fails on any it was not told is cut
  content.

When adding a fix, prefer this shape over patching one prototype by name if the
same breakage can recur elsewhere.

### Runtime (`control.lua`, `remote.lua`)

- `on_chunk_generated`: for the chunk holding a starting point on `nauvis` (or
  a `battle_surface*`), spawn `sb-rock-chest` ("Home") filled with
  `storage.starting_items`. In multiplayer each player gets the items on join
  instead. Inserting a nonexistent item during chunk generation is fatal and
  takes the save with it, which is why `starting-items.lua` drops unknown names
  and `audit_starting_items.lua` exists.
- `on_init` / `on_configuration_changed`: compute starting items from
  `prototypes.item`, set `storage.unlocks`, disable the freeplay crash site and
  default starting inventory, and on configuration change reset every force's
  technologies and recipes, re-enabling recipes of researched technologies
  ("heavy handed fix for mods that forget migration scripts").
- `remote.lua` registers interface `SeaBlock21`: `get_unlocks`, `set_unlock`,
  `get_starting_items`, `set_starting_item`, `set_starting_items`,
  `milestones_presets` (the Milestones mod preset; audited by
  `audit_milestones_preset.lua`) and `better-victory-screen-statistics`.
- Companion Drones: on player creation, swap the drones' coal for wood pellets
  and strip their weapons and shields.

### Settings

`settings.lua` adds `sb-default-landfill` only when LandfillPainting is
present. `settings-updates.lua` defines `seablock.overwrite_setting`, which
pins another mod's startup setting (`forced_value` for booleans, a single
`allowed_values` entry otherwise) and hides it, then requires one file per
dependency under `settings-updates/`. The Lua harness has to honour
`forced_value` over `default_value` for this reason.

### Optional-mod compatibility

Everything optional is gated with `if mods["name"] then` in the data stage and
`script.active_mods["name"]` at runtime, and the mod is listed as `? name` in
`info.json`. Compatibility lives in `data-updates/other-mods.lua` for mods
outside the pack and in a named file (`SpaceMod.lua`, `Companion_Drones.lua`,
`clowns.lua`, `science-cost-tweaker.lua`) for the larger ones. Prototypes that
may be absent are guarded with `if data.raw.<type>["name"] then`.

## Conventions

- **Naming.** Sea Block's own prototypes are prefixed `sb-`; Bob's are `bob-`,
  Angel's are `angels-`, ScienceCostTweakerM's are `sct-`. English strings go
  in `locale/en/SeaBlock.cfg`; when a key is deleted, delete it from the other
  locales too (that is what the translation PRs have done). Do not write
  translations by hand.
- **Factorio 2.0 data shapes.** Ingredients and results are
  `{ type = "item", name = "...", amount = n }`. The `{ "name", n }` shorthand
  and the `normal`/`expensive` split are gone and `audit_recipes.lua` rejects
  them. Technology `unit.ingredients` still use the `{ "pack", 1 }` pair form.
  Runtime code uses `storage` (not `global`) and `prototypes.*`
  (not `game.*_prototypes`).
- **Guard, don't assume.** Check `data.raw.<type>[name]` before touching an
  optional prototype, and use the helpers (which warn) rather than indexing nil.
- **Comments explain why.** Existing code states the upstream behaviour or
  engine rule that forced a change, often with an issue number. Keep doing that;
  the next person hits the same wall after the next dependency bump.
- **Formatting.** StyLua, 2-space indent, double quotes, 120 columns. The
  `stylua.yml` workflow reformats on every push and commits as
  `StyLuaFormatter`, so either run `stylua .` before pushing or pull after.
- **Lua 5.2 with Factorio's quirks.** `require` resolves relative to the
  requiring file first; `table.insert` ignores position bounds; `pairs()` order
  is pinned by the game but not by stock Lua. Details in the loadtest README.
- **Upstream first.** A fix that is a straight 2.x port issue rather than a
  fork decision should also go to modded-factorio/SeaBlock.

## Versioning, changelog and releases

- `SeaBlock/info.json` and `SeaBlockMetaPack/info.json` carry independent
  versions that interleave on one line (currently `SeaBlock21` is at 2.1.7 and
  the pack at 2.1.1). Bump only what changed, to the next free number.
- **Every version bump needs a changelog entry whose `Version:` equals
  `info.json`.** `tools/package.py` fails otherwise, and so does the release,
  and so does the `version.yml` check on every pull request.
- **A pull request that changes `SeaBlock/` or `SeaBlockMetaPack/` without
  bumping that mod's version releases nothing when merged.** `version.yml`
  warns about it on the changed file rather than failing, since a translation
  update or a cleanup may deliberately wait for the next release. Changes
  outside the two mod folders (workflows, `tools/`, docs) never ship and need
  no bump.
- `changelog.txt` is Factorio's strict format. Newest entry first. Copy an
  existing block: the 99-dash separator line, `Version: x.y.z`,
  `Date: YYYY-MM-DD`, a category indented two spaces (`Bugfixes:`, `Changes:`,
  `Features:`, `Info:`), entries as four spaces then `- `, and continuation or
  sub-bullets at six spaces. Entries are written for players: what changed,
  and the cause, in plain words.
- Commit and PR titles follow the history: an imperative summary, with the
  version in parentheses when the change bumps it, e.g.
  `Gate the Cobalt steel axe on cobalt steel (2.1.7)`.
- **A merge to `main` that bumps a version proposes a release.** Bump
  `info.json` and add the changelog entry in the same pull request as the
  change. On every push to `main`, `release.yml` runs
  `tools/publish.py --pending`, which asks the portal whether any mod carries a
  version it does not have yet. Usually not, and the run ends in seconds. When
  it does, the workflow checks the changelog and packaging, then waits for
  approval on the `release` GitHub environment (which also holds the
  `FACTORIO_API_KEY` secret). Once approved from the run page it runs the load
  test, uploads, and creates the `vX.Y.Z` tag and a GitHub release itself. A
  portal release cannot be deleted.
- **Do not create or push tags by hand.** The workflow tags what it published,
  so a tag always marks a release. A bump to a version already tagged on
  another commit is refused before approval is asked for. "Run workflow" on
  the Actions tab re-checks `main` by hand, for example after a failed upload.
  Registering a brand-new mod name is not automated.
- `python3 tools/package.py --out dist` builds the zips locally and runs the
  LICENSE and changelog checks. `python3 tools/publish.py --pending` prints the
  tag a release would use (it queries the portal, no key needed), and
  `python3 tools/publish.py --tag vX.Y.Z --check-tag` validates a tag against
  `info.json` offline. All need only Python 3.

## Testing and verification

There are no unit tests. Correctness means "the game loads, creates a map, Sea
Block logs no warnings, and the whole-graph audits pass". Read
`tools/loadtest/README.md` for the full picture; the short version:

```sh
tools/loadtest/ci.sh               # fetch factorio-data, Bob's, Angel's, SCT and the headless build, then load
tools/loadtest/ci.sh --skip-fetch  # reuse what is already under .loadtest/
```

It loads two configurations, the core pack and core plus ScienceCostTweakerM,
and runs every audit after each. Needs bash, python3, **lua5.2**, curl, git and
network access to factorio.com and github.com. Everything lands in
`.loadtest/` (gitignored). CI runs the same script on push, pull request and
weekly.

- **Dependency refs are branches** (`dev2.1`), on purpose, so upstream breaking
  Sea Block shows up early. A PR can go red without its own code changing; read
  the failure before assuming it is yours. Pins live in
  `tools/loadtest/dependencies.env`.
- **The Lua harness** (`run.lua` + `env.lua`) runs the real data stage under
  plain Lua 5.2 in about a second and is where the audits run. It is not a
  substitute for the game: it does no prototype validation and stubs graphics
  metadata. When the two disagree, the harness is wrong.
- **Audit contract.** An `audit_*.lua` file returns
  `function(data, mods, settings, resolve_asset)` and returns the number of
  findings, writing each to stderr; any nonzero total fails the run. A new audit
  must be added to the `lua5.2 run.lua ...` line in `ci.sh` and to the table in
  the loadtest README. Set `LOADTEST_DETERMINISTIC=1` when running the harness
  by hand so `pairs()` order is reproducible.
- Useful environment variables: `LOADTEST_STOP_AFTER=<stage>` to inspect
  `data.raw` part-way, `LOADTEST_ECHO_LOG=<substring>` to see matching `log()`
  lines, `LOADTEST_DUMP=<path>` with `dump.lua` to write every prototype name,
  which `check_references.py` then cross-references against the source to find
  renamed prototypes all at once.
- `tools/loadtest/retest.sh` repacks only Sea Block and re-runs map creation
  for a fast fix loop; its default paths are from a developer machine, so set
  `REPO` and `FACTORIO`.
- The headless build never loads sprites, so `audit_icons.lua` is the only
  check that an `icon_size` matches the PNG.

**In a sandbox without lua5.2 or network access** (true of the Claude Code
cloud container at the time of writing: only `python3` is present), the full
load test cannot run. What still can: `python3 tools/package.py --out <dir>`
and `python3 tools/publish.py --tag vX.Y.Z --check-tag`, plus careful reading.
Say so in the PR rather than claiming the load test passed.

## Common tasks

- **A dependency renamed or removed a prototype.** Grep the old name across
  `SeaBlock/`; with a dump, run `check_references.py` to find every stale
  literal at once. Guard with `if data.raw...` if the prototype is now
  optional. Add a changelog entry if players would notice.
- **Move a recipe unlock to another technology.** `seablock.lib.moveeffect`
  or `bobmods.lib.tech.remove_recipe_unlock` + `add_recipe_unlock`. Then run
  `audit_reachability.lua`: a disabled, visible recipe with no researchable
  unlock is the soft-lock class of bug that bit red science.
- **Change prerequisites or science costs.** `data/tech-tree.lua` for the
  general tree, `data-final-fixes/tech-tree.lua` when the change must land
  after Bob's and Angel's own updates. Remember `startup.lua` adds a prerequisite
  to any technology that has none.
- **Hide content.** `seablock.lib.hide(type, name)` for items and entities,
  `bobmods.lib.recipe.hide` for recipes, `seablock.lib.hide_technology` for
  techs. Hidden things are excluded from the reachability audit; disabled but
  visible things must have an unlock. `lab-coverage.lua` still has to be happy
  with a hidden technology's pack set.
- **Change the starting chest.** `starting-items.lua` only. It is read both at
  runtime and in the data stage (for YAFC via `data.data_crawler`), and
  `audit_starting_items.lua` checks every name exists.
- **Add compatibility for another mod.** A gated block in
  `data-updates/other-mods.lua` (or its own file if large), `? modname` in
  `SeaBlock/info.json`, and an entry in `SeaBlockMetaPack/info.json` only if it
  joins the recommended pack.
- **Touch the Milestones preset.** `remote.lua`; `audit_milestones_preset.lua`
  checks the names, because Milestones drops bad entries silently.
- **Release.** Bump `info.json` and add the changelog entry in the same pull
  request as the change, then merge. The release workflow notices the new
  version and waits for approval on the `release` environment; nobody pushes
  a tag. See README "Releasing".

## Gotchas and known quirks

- `control.lua` registers `on_load` and `on_player_created` more than once.
  Factorio keeps only the last registration per event, so the final handlers
  (which use `storage`) are the live ones and the earlier block that reads
  `global.starting_items` (pre-2.0 API) is dead code. Do not "fix" it by making
  it active; delete it or leave it.
- `settings.lua` lists `sb-default-landfill` values like `landfill-dirt`, while
  `locale/en` and `remote.lua` refer to `landfill-dirt-4`, `landfill-grass-1`
  and so on. `starting-items.lua` falls back to plain `landfill` when the chosen
  item does not exist. LandfillPainting is optional and not in the CI
  configurations, so this path is untested.
- `data-updates/Companion_Drones.lua` is required from `data.lua`, not from
  `data-updates.lua`, despite its folder.
- `data-updates/building-prerequisites.lua` carries a TODO to remove it once
  Angel's has the same prerequisites.
- `seablock.scripted_techs` still lists `sb-startup2`, which no longer exists;
  the code tolerates names that are absent.
- `angelsrefining` has a `pairs()`-order-dependent crash that stock Lua hits
  about one run in three. `LOADTEST_DETERMINISTIC=1` sidesteps it in the
  harness; the game itself pins its hash seed. It is reported upstream, not
  worked around here.
- `assets.sh` references a Factorio 1.x install and `hr-` sprites. It is
  history, not a build step.
- Factorio enables bundled mods that `mod-list.json` does not mention, so any
  test setup must explicitly disable `quality`, `space-age` and
  `elevated-rails`. `build_mods.py` does this by default.
- Default branch is `main`; changes arrive by pull request, recent ones squash
  merged with the PR number in the title. `CODEOWNERS` assigns everything to
  the repository owner, so a pull request stays "blocked" until they review
  it, whatever CI says.
