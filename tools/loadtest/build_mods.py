#!/usr/bin/env python3
"""Assemble a Factorio mods directory from unpacked mod sources.

Factorio wants each mod as `name_version.zip` containing a single top-level
`name_version/` folder, plus a mod-list.json saying which are enabled. This
packs source checkouts (GitHub clones, this repo) into that shape so the real
game binary can load them.
"""

import argparse
import json
import os
import shutil
import sys
import zipfile

EXCLUDE_DIRS = {".git", ".github", "__pycache__", ".vscode"}
EXCLUDE_FILES = {".gitignore", ".gitattributes", ".DS_Store"}


def find_mods(roots):
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
                info = json.load(fh)
            mods[info["name"]] = (os.path.abspath(path), info)
    return mods


def pack(src, name, version, out_dir):
    stem = f"{name}_{version}"
    out = os.path.join(out_dir, stem + ".zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=1) as zf:
        for dirpath, dirnames, filenames in os.walk(src):
            dirnames[:] = [d for d in sorted(dirnames) if d not in EXCLUDE_DIRS]
            for fname in sorted(filenames):
                if fname in EXCLUDE_FILES:
                    continue
                full = os.path.join(dirpath, fname)
                rel = os.path.relpath(full, src)
                zf.write(full, os.path.join(stem, rel))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", action="append", required=True)
    ap.add_argument("--enable", action="append", default=[])
    ap.add_argument(
        "--disable",
        action="append",
        default=["quality", "space-age", "elevated-rails"],
        help="mods bundled with the install that must be listed as disabled, "
        "since Factorio enables anything a mod-list.json does not mention",
    )
    ap.add_argument("--out", required=True, help="the mods/ directory to create")
    args = ap.parse_args()

    mods = find_mods(args.root)
    missing = [n for n in args.enable if n not in mods and n != "base"]
    if missing:
        print("not found on disk: " + ", ".join(missing), file=sys.stderr)
        return 1

    if os.path.isdir(args.out):
        shutil.rmtree(args.out)
    os.makedirs(args.out)

    entries = [{"name": "base", "enabled": True}]
    for name in args.disable:
        entries.append({"name": name, "enabled": False})
    for name in args.enable:
        if name in ("base", "core"):
            continue
        src, info = mods[name]
        pack(src, name, info["version"], args.out)
        entries.append({"name": name, "enabled": True})

    with open(os.path.join(args.out, "mod-list.json"), "w", encoding="utf-8") as fh:
        json.dump({"mods": entries}, fh, indent=2)

    print(f"packed {len(entries) - 1} mods into {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
