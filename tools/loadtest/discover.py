#!/usr/bin/env python3
"""Scan mod directories, resolve load order, emit a Lua manifest.

Factorio orders mods topologically by their declared dependencies and falls
back to alphabetical order for mods that do not constrain each other. This
reproduces that so the harness runs data stages in the same order the game
would.
"""

import argparse
import json
import os
import re
import sys

DEP_RE = re.compile(r"^\s*(?P<prefix>!|\?|\(\?\)|~)?\s*(?P<name>[^<>=\s]+)\s*(?P<op>[<>=]+)?\s*(?P<ver>\S+)?\s*$")


def parse_dep(raw):
    m = DEP_RE.match(raw)
    if not m:
        return None
    prefix = (m.group("prefix") or "").strip()
    return {
        "name": m.group("name").strip(),
        "optional": prefix in ("?", "(?)"),
        "incompatible": prefix == "!",
        # "~" means "load order does not matter"
        "ordering": prefix != "~" and prefix != "!",
    }


def find_mods(roots):
    """A mod directory is any directory containing an info.json."""
    mods = {}
    for root in roots:
        if os.path.isfile(os.path.join(root, "info.json")):
            candidates = [root]
        else:
            candidates = [os.path.join(root, e) for e in sorted(os.listdir(root))]
        for path in candidates:
            info_path = os.path.join(path, "info.json")
            if not os.path.isfile(info_path):
                continue
            with open(info_path, encoding="utf-8") as fh:
                # Sea Block's info.json has blank lines between dependency
                # groups, which is valid JSON, but be forgiving anyway.
                info = json.loads(fh.read())
            mods[info["name"]] = {
                "name": info["name"],
                "version": info.get("version", "0.0.0"),
                "path": os.path.abspath(path),
                "factorio_version": info.get("factorio_version", "0.12"),
                "deps": [d for d in (parse_dep(x) for x in info.get("dependencies", ["base"])) if d],
            }
    return mods


def resolve(mods, enabled):
    """Topologically sort `enabled`, reporting unmet hard deps and conflicts."""
    problems = []
    selected = {n: mods[n] for n in enabled if n in mods}
    for name in enabled:
        if name not in mods:
            problems.append(f"mod not found on disk: {name}")

    for mod in selected.values():
        for dep in mod["deps"]:
            if dep["incompatible"]:
                if dep["name"] in selected:
                    problems.append(f"{mod['name']} is incompatible with {dep['name']}, but both are enabled")
            elif not dep["optional"] and dep["name"] not in selected:
                problems.append(f"{mod['name']} requires {dep['name']}, which is not enabled")

    order, visiting, done = [], set(), set()

    def visit(name):
        if name in done:
            return
        if name in visiting:
            problems.append(f"dependency cycle involving {name}")
            return
        visiting.add(name)
        mod = selected.get(name)
        if mod:
            for dep in sorted(mod["deps"], key=lambda d: d["name"]):
                if dep["ordering"] and not dep["incompatible"] and dep["name"] in selected:
                    visit(dep["name"])
        visiting.discard(name)
        done.add(name)
        if mod:
            order.append(name)

    # core and base always come first, then everything else alphabetically.
    for name in ("core", "base"):
        if name in selected:
            visit(name)
    for name in sorted(selected):
        visit(name)

    return order, problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", action="append", required=True, help="directory to scan for mods")
    ap.add_argument("--enable", action="append", default=[], help="mod name to enable")
    ap.add_argument("--enable-all", action="store_true", help="enable every mod found")
    ap.add_argument(
        "--order-from-log",
        help="a factorio-current.log to take the load order from, instead of "
        "sorting locally; the game's order is authoritative and small "
        "differences change which mod sees which data first",
    )
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    mods = find_mods(args.root)
    enabled = sorted(mods) if args.enable_all else args.enable

    if args.order_from_log:
        import re as _re

        seen, order = set(), []
        pat = _re.compile(r"Loading mod (\S+) \S+ \(data\.lua\)")
        with open(args.order_from_log, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = pat.search(line)
                if m and m.group(1) not in seen:
                    seen.add(m.group(1))
                    order.append(m.group(1))
        order = [n for n in order if n in mods]
        if "core" in mods and "core" not in order:
            order.insert(0, "core")
        problems = [f"mod not found on disk: {n}" for n in enabled if n not in mods]
    else:
        order, problems = resolve(mods, enabled)

    if problems:
        for p in problems:
            print(f"load-order error: {p}", file=sys.stderr)
        return 1

    # Every mod must agree on the major version, or Factorio refuses to load it.
    versions = {}
    for name in order:
        if name in ("core", "base"):
            continue
        versions.setdefault(mods[name]["factorio_version"], []).append(name)
    if len(versions) > 1:
        print("factorio_version mismatch across enabled mods:", file=sys.stderr)
        for ver, names in sorted(versions.items()):
            print(f"  {ver}: {', '.join(names)}", file=sys.stderr)
        return 1

    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write("-- generated by discover.py; do not edit\nreturn {\n")
        for name in order:
            mod = mods[name]
            fh.write(
                '  { name = %s, version = %s, path = %s },\n'
                % (json.dumps(name), json.dumps(mod["version"]), json.dumps(mod["path"]))
            )
        fh.write("}\n")

    print(f"{len(order)} mods, target factorio_version {list(versions)[0] if versions else 'n/a'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
