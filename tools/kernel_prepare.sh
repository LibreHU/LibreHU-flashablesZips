#!/bin/sh
# Image de boot d'un noyau LibreHU : release latest-<branche> du depot du noyau (publiee par sa CI a chaque build).
# $1 = dossier de travail (files/boot.img + .sha256 et version y sont ecrits), $2 = branche, $3 = image de la release
# (boot_ac8257.img, boot_ac8257_bootmenu.img). GH_TOKEN pour l'API (CI) : empreinte de l'image donnee par GitHub.
set -e
W=$1; BRANCH=$2; ASSET=$3
REPO=LibreHU/android_kernel_autochips_ac8257_4.9
TAG=latest-$BRANCH
mkdir -p "$W/files"
gh api "repos/$REPO/releases/tags/$TAG" > "$W/release.json"
python3 - "$W" "$ASSET" <<'PY'
import json, sys
w, asset = sys.argv[1], sys.argv[2]
r = json.load(open(f"{w}/release.json"))
urls = {a["name"]: (a["browser_download_url"], (a.get("digest") or "").removeprefix("sha256:")) for a in r["assets"]}
if asset not in urls or "release.txt" not in urls:
    sys.exit(f"{asset} ou release.txt absent de la release {r['tag_name']}")
open(f"{w}/asset", "w").write(f"{urls[asset][0]}\n{urls[asset][1]}\n{urls['release.txt'][0]}\n")
PY
URL=$(sed -n 1p "$W/asset"); DIGEST=$(sed -n 2p "$W/asset"); NOTES=$(sed -n 3p "$W/asset")
curl -fsSL -o "$W/files/boot.img" "$URL"
curl -fsSL -o "$W/release.txt" "$NOTES"
SUM=$(sha256sum "$W/files/boot.img" | cut -d' ' -f1)
[ -z "$DIGEST" ] || [ "$DIGEST" = "$SUM" ] || { echo "empreinte differente de celle de la release" >&2; exit 1; }
# Image de boot Android ("ANDROID!") de 10 Mio au plus (partition boot de l'UJC201), pied AVB a la fin
[ "$(head -c 8 "$W/files/boot.img")" = "ANDROID!" ] || { echo "pas une image de boot Android" >&2; exit 1; }
[ "$(stat -c %s "$W/files/boot.img")" -le 10485760 ] || { echo "image plus grande que la partition boot" >&2; exit 1; }
[ "$(tail -c 64 "$W/files/boot.img" | head -c 4)" = AVBf ] || { echo "pied AVB absent (le LK refuserait l'image)" >&2; exit 1; }
echo "$SUM  boot.img" > "$W/files/boot.img.sha256"
sed -n 's/^version=//p' "$W/release.txt" > "$W/version"
[ -s "$W/version" ] || { echo "version absente de release.txt" >&2; exit 1; }
rm -f "$W/release.json" "$W/asset" "$W/release.txt"
