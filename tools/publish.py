#!/usr/bin/env python3
"""Publish the packaged mods to the Factorio mod portal.

The portal does not watch GitHub, so a release has to be pushed to it. This
does that over the upload API rather than the web form, so a tag can drive it.

    FACTORIO_API_KEY=... tools/publish.py --tag v2.1.2

The key comes from https://factorio.com/profile and needs the
"ModPortal: Upload Mods" usage. A published release cannot be deleted, so
this refuses anything it is not sure about rather than uploading and hoping:
it checks the tag against info.json, skips versions already on the portal,
and will not register a mod name that does not exist yet.

Pass --dry-run to do everything except the upload itself.
"""

import argparse
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import package  # noqa: E402  (same directory, shares the packing rules)

# The mod whose version the tag names. The pack is versioned alongside it but
# does not always change, so it is published only when its version is new.
ANCHOR = "SeaBlock"

PORTAL = "https://mods.factorio.com"
INIT_UPLOAD = f"{PORTAL}/api/v2/mods/releases/init_upload"


class Failure(Exception):
    pass


def post(url, fields, files=None, token=None):
    """POST multipart/form-data and return the decoded JSON body."""
    boundary = uuid.uuid4().hex
    body = bytearray()
    for name, value in fields.items():
        body += f"--{boundary}\r\n".encode()
        body += f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        body += f"{value}\r\n".encode()
    for name, path in (files or {}).items():
        ctype = mimetypes.guess_type(path)[0] or "application/octet-stream"
        body += f"--{boundary}\r\n".encode()
        body += (
            f'Content-Disposition: form-data; name="{name}"; '
            f'filename="{os.path.basename(path)}"\r\n'
        ).encode()
        body += f"Content-Type: {ctype}\r\n\r\n".encode()
        with open(path, "rb") as fh:
            body += fh.read()
        body += b"\r\n"
    body += f"--{boundary}--\r\n".encode()

    headers = {"Content-Type": f"multipart/form-data; boundary={boundary}"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(url, data=bytes(body), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as err:
        detail = err.read().decode(errors="replace")
        try:
            parsed = json.loads(detail)
            detail = f"{parsed.get('error', 'Unknown')}: {parsed.get('message', detail)}"
        except ValueError:
            pass
        raise Failure(f"HTTP {err.code} from {urllib.parse.urlparse(url).path} — {detail}")


def published_versions(name):
    """Versions already on the portal, or None if the mod is not registered."""
    try:
        with urllib.request.urlopen(f"{PORTAL}/api/mods/{name}", timeout=60) as response:
            data = json.loads(response.read().decode())
    except urllib.error.HTTPError as err:
        if err.code == 404:
            return None
        raise Failure(f"could not be read from the portal: HTTP {err.code}")
    return {release["version"] for release in data.get("releases", [])}


def upload(name, zip_path, token, dry_run):
    started = post(INIT_UPLOAD, {"mod": name}, token=token)
    url = started.get("upload_url")
    if not url:
        raise Failure(f"init_upload returned no upload_url ({started})")
    if dry_run:
        print(f"  {name}: would upload {os.path.basename(zip_path)}")
        return
    result = post(url, {}, files={"file": zip_path}, token=token)
    if not result.get("success"):
        raise Failure(f"upload rejected — {result}")
    print(f"  {name}: published {os.path.basename(zip_path)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tag", help="release tag, e.g. v2.1.2; checked against info.json")
    ap.add_argument("--out", default=os.path.join(package.REPO, "dist"))
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    token = os.environ.get("FACTORIO_API_KEY")
    if not token:
        print("FACTORIO_API_KEY is not set", file=sys.stderr)
        return 1

    os.makedirs(args.out, exist_ok=True)
    infos = {}
    for mod in package.MODS:
        src = os.path.join(package.REPO, mod)
        with open(os.path.join(src, "info.json"), encoding="utf-8") as fh:
            infos[mod] = json.load(fh)

    if args.tag:
        wanted = args.tag[1:] if args.tag.startswith("v") else args.tag
        actual = infos[ANCHOR]["version"]
        if wanted != actual:
            print(
                f"tag {args.tag} does not match {ANCHOR}/info.json version {actual} — "
                "retag or bump, but do not publish a version nobody named",
                file=sys.stderr,
            )
            return 1

    # Package first: its LICENSE and changelog checks are the last chance to
    # catch a bad build, and a portal release cannot be taken back.
    if package.build(args.out, infos) != 0:
        return 1

    failed = False
    for mod, info in infos.items():
        name, version = info["name"], info["version"]
        try:
            live = published_versions(name)
            if live is None:
                raise Failure(
                    "not on the mod portal. The first release of a new mod has to be "
                    "published by hand; this only uploads further releases."
                )
            if version in live:
                print(f"  {name}: {version} is already published, skipping")
                continue
            upload(name, os.path.join(args.out, f"{name}_{version}.zip"), token, args.dry_run)
        except Failure as err:
            failed = True
            print(f"  {name}: {err}", file=sys.stderr)

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
