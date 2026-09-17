#!/usr/bin/env python3
"""Pack the mods for the Factorio mod portal.

Factorio wants each mod as `name_version.zip` containing a single top-level
`name_version/` directory. Both mods were hand-packed before this existed,
which is how LICENSE was once left out of every zip, and how a version bump
was once missed until the portal rejected the upload. Both are checked here.

    tools/package.py --out dist
"""

import argparse
import json
import os
import re
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODS = ["SeaBlock", "SeaBlockMetaPack"]

EXCLUDE_DIRS = {".git", ".github", "__pycache__", ".vscode"}
EXCLUDE_FILES = {".gitignore", ".gitattributes", ".DS_Store"}

# The mod portal rejects a re-upload of an existing version, so the most
# common packaging mistake is shipping the version that is already up there.
# The changelog's newest entry is the one place that records the intent.
CHANGELOG_VERSION = re.compile(r"^Version:\s*(\S+)\s*$", re.M)


def check(src, info):
    problems = []
    if not os.path.isfile(os.path.join(src, "LICENSE")):
        problems.append("LICENSE is missing — MIT requires it travel with redistributions")

    changelog = os.path.join(src, "changelog.txt")
    if os.path.isfile(changelog):
        with open(changelog, encoding="utf-8") as fh:
            found = CHANGELOG_VERSION.search(fh.read())
        if not found:
            problems.append("changelog.txt has no Version: entry")
        elif found.group(1) != info["version"]:
            problems.append(
                f"changelog.txt's newest entry is {found.group(1)}, "
                f"but info.json says {info['version']} — bump one of them"
            )
    return problems


def pack(src, stem, out_dir):
    out = os.path.join(out_dir, stem + ".zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for dirpath, dirnames, filenames in os.walk(src):
            dirnames[:] = [d for d in sorted(dirnames) if d not in EXCLUDE_DIRS]
            for fname in sorted(filenames):
                if fname in EXCLUDE_FILES:
                    continue
                full = os.path.join(dirpath, fname)
                zf.write(full, os.path.join(stem, os.path.relpath(full, src)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(REPO, "dist"))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    failed = False
    for mod in MODS:
        src = os.path.join(REPO, mod)
        with open(os.path.join(src, "info.json"), encoding="utf-8") as fh:
            info = json.load(fh)

        problems = check(src, info)
        if problems:
            failed = True
            print(f"{mod}:")
            for problem in problems:
                print(f"  {problem}")
            continue

        out = pack(src, f"{info['name']}_{info['version']}", args.out)
        print(f"{info['name']} {info['version']}  ->  {out}  ({os.path.getsize(out):,} bytes)")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
