# Sea Block — Factorio 2.1 fork

A fork of [modded-factorio/SeaBlock](https://github.com/modded-factorio/SeaBlock),
carrying its unreleased 2.0 `dev` branch forward to **Factorio 2.1**.

Published as **`SeaBlock21`** (and **`SeaBlockMetaPack21`** for the pack). The
original names belong to Trainwreck on the mod portal, and mod names are unique
per account, so a fork cannot reuse them. The in-game titles are unchanged.

Sea Block was created by Trainwreck and is maintained upstream by KiwiHawk.
The mod portal release is still [0.5.16 for Factorio 1.1](https://mods.factorio.com/mod/SeaBlock).
This fork exists because the upstream port had stalled in a state that could
not be installed at all, and is not affiliated with or endorsed by the upstream
maintainers.

## Why a 2.1 fork and not a 2.0 one

Upstream's `dev` branch declares `factorio_version: 2.0` and pins Bob's 2.1.x
and Angel's 2.0.x. Both of those have since shipped for Factorio 2.1, and the
modding documentation is explicit that this matters:

> Mods can only be compatible with one major version, not multiple. A
> `factorio_version` of `"2.0"` indicates support for all releases under that
> major version, **and no other major releases**.

Factorio treats 2.1 as a separate major version from 2.0. So Sea Block and its
own required dependencies had become mutually unloadable — there was no
combination of published versions that would start. Retargeting 2.1 is what
made everything else testable.

## Status

**It loads and generates maps. It has been play-tested up until green science.**

Verified against Factorio 2.1.19 and 2.1.20 headless with Bob's 3.0.x and Angel's 2.1.x,
with and without ScienceCostTweakerM, and with enemies both on and disabled.
That covers load-time and static-graph correctness — prototype validity,
technology tree integrity, recipe and science pack reachability. It says
nothing about whether the game is balanced or finishable.

Known to be outstanding, all tracked upstream:

- Cliffs are still not reimplemented in map generation ([#352])
- Migrations are unwritten ([#354]) — entity filters, crystallization, technologies
- The balance items in the [Sea Block 2.0 milestone][milestone]

[#352]: https://github.com/modded-factorio/SeaBlock/issues/352
[#354]: https://github.com/modded-factorio/SeaBlock/issues/354
[milestone]: https://github.com/modded-factorio/SeaBlock/milestone/18

## Requirements

- **Factorio 2.1.x.** At time of writing 2.1 is the experimental branch; 2.0.x
  is still marked stable. On Steam: Properties → Betas → `experimental`.
- Bob's mods 3.0.x and Angel's mods 2.1.x from the mod portal.
- `quality`, `space-age` and `elevated-rails` **disabled**. Sea Block declares
  them incompatible, and Factorio enables bundled mods that a `mod-list.json`
  does not mention.

Install `SeaBlockMetaPack21` to pull in the full recommended pack. Three mods that
were previously required have no 2.1 release: Explosive Excavation and Space
Extension Mod are dropped, and LandfillPainting is now optional.

## Testing

`tools/loadtest/` holds a rig for checking that a change still loads, since the
project had no way to do that. It drives the freely distributed headless build
for authoritative verification, and a fast Lua harness for whole-graph audits
that would otherwise cost a game launch each. See
[its README](tools/loadtest/README.md).

## Releasing

The mod portal does not watch GitHub, so a release has to be pushed to it.
`.github/workflows/release.yml` does that, and **a merge that bumps a version is
what proposes a release**:

1. Bump `version` in the changed mod's `info.json` and add a matching entry at
   the top of its `changelog.txt`, in the same pull request as the change.
2. Merge it. On every push to `main` the workflow asks the portal whether any
   mod carries a version it does not have yet. For an ordinary merge the answer
   is no and the run ends in seconds.
3. When there is a new version, the release job waits for approval on the
   `release` environment. Approve it from the run page (or reject it to hold
   the release) and it runs the load test, uploads over the portal's
   [upload API][api], then creates the `v…` tag on that commit and a GitHub
   release with the zips.

There is no tag to push by hand: the workflow tags what it published, so a tag
always marks a release and a merged bump cannot be forgotten. **Run workflow**
on the Actions tab re-checks `main` by hand, for example after a failed upload.

The other half, a change merged *without* a bump, is flagged on the pull
request by `.github/workflows/version.yml`. It warns when `SeaBlock/` or
`SeaBlockMetaPack/` changes but that mod's version does not, since that merge
releases nothing, and fails when the newest changelog entry and `info.json`
disagree. Changes outside the two mod folders never ship and are not checked.

**One release covers whatever is new.** The two mods are versioned on a single
line but bump independently — the pack is a dependency list and rarely changes —
so the tag takes the version of whichever mod you bumped, and `publish.py` skips
the ones the portal already has:

| changed | bump | published as |
| --- | --- | --- |
| Sea Block only | Sea Block to `2.1.3` | `v2.1.3`; the pack is skipped |
| the pack only | the pack to `2.1.4` | `v2.1.4`; Sea Block is skipped |
| both | both to `2.1.5` | `v2.1.5`, both |

The rule is *bump whatever changed to the next free number*. Versions interleave
on one line, so tags never collide; a bump to a number that is already tagged
on another commit is refused before approval is asked for.

Approval rather than publishing on every merge, because **a mod portal release
cannot be deleted**. Everything that can be checked before that point is:

- `info.json` against the newest `changelog.txt` entry, so a version nobody
  wrote a changelog for cannot ship — checked before approval is asked for
- `LICENSE` present inside each mod, as MIT requires
- the load test, on both configurations

Publishing needs a `release` environment (Settings → Environments) with you as
required reviewer and a `FACTORIO_API_KEY` secret, created at
[factorio.com/profile](https://factorio.com/profile) with the
**ModPortal: Upload Mods** usage. Keeping the key on the environment means only
an approved job can read it. Registering a *new* mod name is a different
permission and is not automated — `tools/publish.py` stops rather than create
one. To build the zips without publishing, run `tools/package.py`.

[api]: https://wiki.factorio.com/Mod_upload_API

## Licence and credit

MIT, © KiwiHawk, which permits redistribution and modification provided the
notice travels with it — `LICENSE` ships inside both mods. Sea Block is
Trainwreck's design, maintained upstream by KiwiHawk; this fork carries their
work forward and claims none of it.

## Contributing back

Changes here are meant to be useful upstream. Anything that is a straight port
fix rather than a fork-specific decision should go to
[modded-factorio/SeaBlock](https://github.com/modded-factorio/SeaBlock).
