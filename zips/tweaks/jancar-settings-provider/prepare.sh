#!/bin/sh
# Fournisseur de reglages LibreHU (org.librehu.jacsettings) : LibreHU-JacSettings-main.apk de la release latest-main
# de LibreHU-service, publiee par sa CI avec l'APK du service. $1 = dossier de travail (files/ et version y sont
# ecrits). GH_TOKEN pour l'API (CI) : empreinte de l'APK donnee par GitHub.
set -e
W=$1
REPO=LibreHU/LibreHU-service
TAG=latest-main
ASSET=LibreHU-JacSettings-main.apk
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
curl -fsSL -o "$W/files/LibreHUJacSettings.apk" "$URL"
curl -fsSL -o "$W/release.txt" "$NOTES"
SUM=$(sha256sum "$W/files/LibreHUJacSettings.apk" | cut -d' ' -f1)
[ -z "$DIGEST" ] || [ "$DIGEST" = "$SUM" ] || { echo "empreinte differente de celle de la release" >&2; exit 1; }
# Un APK (archive zip) avec son manifeste
python3 - "$W/files/LibreHUJacSettings.apk" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
if "AndroidManifest.xml" not in z.namelist():
    sys.exit("pas un APK (AndroidManifest.xml absent)")
PY
echo "$SUM  LibreHUJacSettings.apk" > "$W/files/LibreHUJacSettings.apk.sha256"
# Meme version que l'APK du service de cette build (meme depot, meme commit)
sed -n 's/^versionName=//p' "$W/release.txt" > "$W/version"
[ -s "$W/version" ] || { echo "version absente de release.txt" >&2; exit 1; }
rm -f "$W/release.json" "$W/asset" "$W/release.txt"
