#!/bin/sh
# Télécharge l'image TWRP de la dernière release twrp-build-* (non brouillon) du dépôt de l'appareil.
# $1 = dossier de travail : files/twrp.img (+ .sha256) et version y sont écrits. GH_TOKEN pour l'API (CI).
set -e
W=$1
REPO=LibreHU/android_device_alps_ac8257_demo
mkdir -p "$W/files"
gh api "repos/$REPO/releases?per_page=30" > "$W/releases.json"
python3 - "$W" <<'PY'
import json, sys, re
w = sys.argv[1]
rels = [r for r in json.load(open(f"{w}/releases.json")) if r["tag_name"].startswith("twrp-build-") and not r["draft"]]
rels.sort(key=lambda r: int(re.sub(r"\D", "", r["tag_name"]) or 0), reverse=True)
for r in rels:
    imgs = [a for a in r["assets"] if re.match(r"(?i)^twrp.*\.img$", a["name"])]
    if imgs:
        a = imgs[0]
        open(f"{w}/asset", "w").write(f"{r['tag_name']}\n{a['browser_download_url']}\n{(a.get('digest') or '').removeprefix('sha256:')}\n")
        break
else:
    sys.exit("aucune image TWRP dans les releases")
PY
TAG=$(sed -n 1p "$W/asset"); URL=$(sed -n 2p "$W/asset"); DIGEST=$(sed -n 3p "$W/asset")
curl -fsSL -o "$W/files/twrp.img" "$URL"
SUM=$(sha256sum "$W/files/twrp.img" | cut -d' ' -f1)
[ -z "$DIGEST" ] || [ "$DIGEST" = "$SUM" ] || { echo "empreinte différente de celle de la release" >&2; exit 1; }
echo "$SUM  twrp.img" > "$W/files/twrp.img.sha256"
echo "$TAG" | sed 's/^twrp-build-/v/' > "$W/version"
rm -f "$W/releases.json" "$W/asset"
