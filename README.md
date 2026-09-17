# Sea Block — Factorio 2.1 fork

A fork of [modded-factorio/SeaBlock](https://github.com/modded-factorio/SeaBlock),
carrying its unreleased 2.0 `dev` branch forward to **Factorio 2.1**.

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

**It loads and generates maps. It has not been play-tested.**

Verified against Factorio 2.1.19 headless with Bob's 3.0.x and Angel's 2.1.x,
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

Install `SeaBlockMetaPack` to pull in the full recommended pack. Three mods that
were previously required have no 2.1 release: Explosive Excavation and Space
Extension Mod are dropped, and LandfillPainting is now optional.

## Testing

`tools/loadtest/` holds a rig for checking that a change still loads, since the
project had no way to do that. It drives the freely distributed headless build
for authoritative verification, and a fast Lua harness for whole-graph audits
that would otherwise cost a game launch each. See
[its README](tools/loadtest/README.md).

## Contributing back

Changes here are meant to be useful upstream. Anything that is a straight port
fix rather than a fork-specific decision should go to
[modded-factorio/SeaBlock](https://github.com/modded-factorio/SeaBlock).
