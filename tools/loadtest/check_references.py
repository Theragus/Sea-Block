#!/usr/bin/env python3
"""Cross-reference prototype names mentioned in source against a loaded dump.

Most Sea Block breakage after a dependency bump is a renamed or removed
prototype: the code still says "bob-carbon" but Bob's now calls it "carbon".
Those only surface one crash at a time at load, so this finds them all at once.

Two classes of reference are checked:

  typed    data.raw.item["x"] / data.raw["recipe"]["x"]  -> type and name
  untyped  any other string literal                      -> name under any type

Untyped literals are heuristically filtered; the point is a short review list,
not a proof.
"""

import argparse
import os
import re
import sys

TYPED_RE = re.compile(
    r"""data\.raw
        (?: \.(?P<t1>[a-zA-Z_][\w-]*) | \[\s*["'](?P<t2>[^"']+)["']\s*\] )
        \s*\[\s*["'](?P<name>[^"']+)["']\s*\]""",
    re.VERBOSE,
)

STRING_RE = re.compile(r"""["']([^"'\n]{2,})["']""")

# Literals that are clearly not prototype names.
SKIP_PATTERNS = [
    re.compile(r"^__"),                     # mod paths
    re.compile(r"\s"),                      # sentences, locale text
    re.compile(r"^[a-z-]+\.[a-z-]+"),       # locale keys like "item-name.foo"
    re.compile(r"\.(png|ogg|lua|json)$"),   # asset paths
    re.compile(r"^/"),
    re.compile(r"^%"),
    re.compile(r"^[A-Z_]+$"),               # constants
]

# Strings that are legitimately not prototype names but look like one.
VOCABULARY = {
    # prototype types and stage/lifecycle words
    "item", "fluid", "recipe", "technology", "tool", "entity", "tile", "module",
    "capsule", "ammo", "gun", "armor", "repair-tool", "rail-planner", "item-with-entity-data",
    "recipe-category", "item-subgroup", "item-group", "fuel-category", "resource-category",
    "noise-expression", "noise-function", "autoplace-control", "map-gen-presets",
    "utility-constants", "simple-entity", "optimized-decorative", "unit-spawner",
    "turret", "tree", "character", "reactor", "furnace", "assembling-machine",
    "mining-drill", "offshore-pump", "boiler", "generator", "lab", "beacon",
    "electric-energy-interface", "storage-tank", "pipe", "pump", "inserter",
    "transport-belt", "underground-belt", "splitter", "loader", "container",
    "logistic-container", "roboport", "wall", "gate", "radar", "planet",
    "cliff", "fish", "resource", "unit", "corpse", "explosion", "projectile",
    "sticker", "smoke-with-trigger", "trivial-smoke", "particle",
    # common field values
    "left", "right", "top", "bottom", "center", "north", "south", "east", "west",
    "normal", "expensive", "input", "output", "input-output", "none", "always",
    "true", "false", "nil", "and", "or", "not",
    "enemy", "player", "neutral",
    "basic-solid", "basic-fluid", "advanced-crafting", "crafting", "smelting",
    "chemistry", "oil-processing", "rocket-building", "centrifuging",
    "not-deconstructable", "hidden", "hide-from-bonus-gui", "hide-from-fuel-tooltip",
    "placeable-neutral", "player-creation", "placeable-player", "building-direction-8-way",
    "unlock-recipe", "give-item", "gun-speed", "ammo-damage", "turret-attack",
    "num-quality-unlocks", "nothing", "count", "time",
}


def load_dump(path):
    by_type = {}
    all_names = set()
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            proto_type, _, name = line.rstrip("\n").partition("\t")
            by_type.setdefault(proto_type, set()).add(name)
            all_names.add(name)
    return by_type, all_names


def strip_comments(text):
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def looks_like_name(s):
    if s in VOCABULARY:
        return False
    for pat in SKIP_PATTERNS:
        if pat.search(s):
            return False
    # prototype names are lowercase, digits, dashes, underscores
    return bool(re.fullmatch(r"[a-z0-9][a-z0-9_-]*", s)) and "-" in s or s in ("coal", "stone", "wood")


def scan(source_dirs, by_type, all_names):
    typed_findings = []
    untyped_findings = []
    for source_dir in source_dirs:
        for root, _, files in os.walk(source_dir):
            for fname in sorted(files):
                if not fname.endswith(".lua"):
                    continue
                path = os.path.join(root, fname)
                with open(path, encoding="utf-8") as fh:
                    raw = fh.read()
                text = strip_comments(raw)
                line_of = lambda pos: raw.count("\n", 0, pos) + 1  # noqa: E731

                typed_spans = []
                for m in TYPED_RE.finditer(text):
                    proto_type = m.group("t1") or m.group("t2")
                    name = m.group("name")
                    typed_spans.append(m.span())
                    known = by_type.get(proto_type, set())
                    if name not in known:
                        where = "no such %s" % proto_type if known else "no prototypes of type %s" % proto_type
                        alt = sorted(t for t, names in by_type.items() if name in names)
                        typed_findings.append(
                            (path, text[: m.start()].count("\n") + 1, proto_type, name, where, alt)
                        )

                for m in STRING_RE.finditer(text):
                    if any(s <= m.start() < e for s, e in typed_spans):
                        continue
                    s = m.group(1)
                    if not looks_like_name(s):
                        continue
                    if s in all_names:
                        continue
                    untyped_findings.append((path, text[: m.start()].count("\n") + 1, s))
    return typed_findings, untyped_findings


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", required=True)
    ap.add_argument("--source", action="append", required=True)
    ap.add_argument("--untyped", action="store_true", help="also list unrecognised bare literals")
    args = ap.parse_args()

    by_type, all_names = load_dump(args.dump)
    typed, untyped = scan(args.source, by_type, all_names)

    rel = lambda p: os.path.relpath(p)  # noqa: E731

    if typed:
        print("== typed references to prototypes that do not exist ==")
        for path, line, proto_type, name, why, alt in typed:
            extra = (" (exists as: %s)" % ", ".join(alt)) if alt else ""
            print("%s:%d  data.raw.%s[%r]  -- %s%s" % (rel(path), line, proto_type, name, why, extra))
        print()

    if untyped:
        seen = {}
        for path, line, name in untyped:
            seen.setdefault(name, []).append("%s:%d" % (rel(path), line))
        if args.untyped:
            print("== bare literals matching no prototype of any type ==")
            for name in sorted(seen):
                print("%-44s %s" % (name, ", ".join(seen[name][:4])))
            print()
        print("%d typed finding(s), %d distinct unrecognised literal(s)" % (len(typed), len(seen)))
    else:
        print("%d typed finding(s)" % len(typed))

    return 1 if typed else 0


if __name__ == "__main__":
    sys.exit(main())
