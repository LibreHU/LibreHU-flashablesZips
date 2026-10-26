#!/usr/bin/env python3
"""Builds every zip of zips/<category>/<id>/ into dist/, with dist/index.json for LibreHU Apps.

Each item: zip.json (metadata), install.sh (body of update-binary, after common/twrp-common.sh and the files listed
in "include"), optional files/ (copied into the zip) and prepare.sh <workdir> (fills <workdir>/files and
<workdir>/version before packaging).
"variants" (list of objects) builds one zip per entry from the same item: "{key}" in the string fields of zip.json is
replaced by the value of the entry, and prepare.sh gets the entry in the environment as ZIP_<KEY>.
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")
BUILD = os.path.join(ROOT, "build")
REPO = os.environ.get("GITHUB_REPOSITORY", "LibreHU/LibreHU-flashablesZips")
TAG = os.environ.get("ZIPS_TAG", "zips")
BASE = f"https://github.com/{REPO}/releases/download/{TAG}/"
FIELDS = ("id", "name", "category", "description", "warning", "devices", "restore", "hidden", "partition", "upstream", "license")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def update_binary(meta, version, body):
    common = open(os.path.join(ROOT, "common", "twrp-common.sh")).read()
    for inc in meta.get("include", []):
        common += "\n" + open(os.path.join(ROOT, inc)).read()
    devices = " ".join(meta.get("devices", []))
    check = ""
    if devices:
        check = (
            'DEV=$(getprop ro.product.device)\n'
            f'case " {devices} " in *" $DEV "*) ;; *) abort "appareil \\"$DEV\\" non pris en charge ({devices})";; esac\n'
        )
    head = f'#!/sbin/sh\nOUTFD=$2; ZIPFILE=$3; ZIP_ID={meta["id"]}; VERSION={version}; V4A_VERSION={version}\n'
    return head + common + "\n" + check + body


def add_tree(z, src, arc):
    for dirpath, _, files in sorted(os.walk(src)):
        for name in sorted(files):
            full = os.path.join(dirpath, name)
            rel = os.path.join(arc, os.path.relpath(full, src))
            info = zipfile.ZipInfo(rel, date_time=(2020, 1, 1, 0, 0, 0))
            info.external_attr = 0o644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, open(full, "rb").read())


def expand(meta):
    """zip.json without "variants": itself; with: one copy per entry, "{key}" replaced in its strings."""
    variants = meta.pop("variants", None)
    if not variants:
        return [(meta, {})]

    def sub(v, var):
        if isinstance(v, str):
            for k, x in var.items():
                v = v.replace("{" + k + "}", x)
            return v
        if isinstance(v, list):
            return [sub(i, var) for i in v]
        if isinstance(v, dict):
            return {k: sub(i, var) for k, i in v.items()}
        return v
    return [(sub(meta, var), var) for var in variants]


def build(item_dir, meta, var):
    zid = meta["id"]
    work = os.path.join(BUILD, zid)
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(os.path.join(work, "files"))
    if os.path.isdir(os.path.join(item_dir, "files")):
        shutil.copytree(os.path.join(item_dir, "files"), os.path.join(work, "files"), dirs_exist_ok=True)
    prepare = os.path.join(item_dir, "prepare.sh")
    if os.path.exists(prepare):
        env = dict(os.environ, **{"ZIP_" + k.upper(): v for k, v in var.items()})
        subprocess.run(["sh", prepare, work], check=True, env=env)
    version = meta.get("version") or open(os.path.join(work, "version")).read().strip()
    body = open(os.path.join(item_dir, "install.sh")).read()
    out = os.path.join(DIST, f"{zid}.zip")
    with zipfile.ZipFile(out, "w") as z:
        for name, data in (
            ("META-INF/com/google/android/update-binary", update_binary(meta, version, body)),
            ("META-INF/com/google/android/updater-script", "# voir update-binary\n"),
        ):
            info = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
            info.external_attr = 0o755 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, data)
        if os.listdir(os.path.join(work, "files")):
            add_tree(z, os.path.join(work, "files"), "files")
    entry = {k: meta[k] for k in FIELDS if k in meta}
    entry.update(version=version, url=BASE + f"{zid}.zip", size=os.path.getsize(out), sha256=sha256(out))
    if meta.get("image"):
        img = os.path.join(DIST, f"{zid}.img")
        shutil.copy(os.path.join(work, meta["image"]), img)
        entry.update(image_url=BASE + f"{zid}.img", image_size=os.path.getsize(img), image_sha256=sha256(img))
    return entry


def main():
    shutil.rmtree(DIST, ignore_errors=True)
    os.makedirs(DIST)
    entries, failed = [], []
    zips = os.path.join(ROOT, "zips")
    for cat in sorted(os.listdir(zips)):
        for zid in sorted(os.listdir(os.path.join(zips, cat))):
            d = os.path.join(zips, cat, zid)
            if not os.path.exists(os.path.join(d, "zip.json")):
                continue
            for meta, var in expand(json.load(open(os.path.join(d, "zip.json")))):
                try:
                    e = build(d, meta, var)
                    entries.append(e)
                    print(f"{e['category']}/{e['id']} {e['version']} {e['size']} B")
                except Exception as ex:  # one zip failing does not stop the others
                    failed.append(meta["id"])
                    print(f"!! {meta['id']}: {ex}", file=sys.stderr)
    cats = json.load(open(os.path.join(ROOT, "categories.json")))["categories"]
    index = {"generated": int(time.time()), "repo": REPO, "categories": cats, "zips": entries}
    json.dump(index, open(os.path.join(DIST, "index.json"), "w"), ensure_ascii=False, indent=2)
    if failed:
        # What built is still published; the workflow fails afterwards (dist/failed.txt).
        print("failed: " + ", ".join(failed), file=sys.stderr)
        open(os.path.join(BUILD, "failed.txt"), "w").write("\n".join(failed) + "\n")
        if not entries:
            sys.exit(1)


if __name__ == "__main__":
    main()
