#!/bin/sh
# Modules de connectivite recompiles avec un noyau LibreHU linux-stable (branche stable-4.9.*, docs/STABLE.md du
# depot du noyau) : release latest-<branche>, fichier librehu_connectivity_ksu.zip (les memes .ko que le module
# KernelSU). $1 = dossier de travail (files/ et version y sont ecrits), $2 = branche.
# Ecrit files/modules/*.ko + SHA256SUMS, files/kernel_version (/proc/version du noyau) et files/kernels.sha256 :
# empreinte de la section noyau de boot_ac8257.img et de boot_ac8257_bootmenu.img, pour que le zip verifie que la
# partition boot contient bien ce noyau. GH_TOKEN pour l'API (CI) : empreintes des fichiers donnees par GitHub.
set -e
W=$1; BRANCH=$2
REPO=LibreHU/android_kernel_autochips_ac8257_4.9
TAG=latest-$BRANCH
mkdir -p "$W/files/modules" "$W/dl"
gh api "repos/$REPO/releases/tags/$TAG" > "$W/release.json"
python3 - "$W" <<'PY'
import json, sys
w = sys.argv[1]
r = json.load(open(f"{w}/release.json"))
urls = {a["name"]: (a["browser_download_url"], (a.get("digest") or "").removeprefix("sha256:")) for a in r["assets"]}
need = ["librehu_connectivity_ksu.zip", "boot_ac8257.img", "boot_ac8257_bootmenu.img", "release.txt"]
miss = [n for n in need if n not in urls]
if miss:
    sys.exit(f"absent de la release {r['tag_name']} : {', '.join(miss)}")
with open(f"{w}/assets", "w") as f:
    for n in need:
        f.write(f"{n} {urls[n][0]} {urls[n][1]}\n")
PY
while read -r NAME URL DIGEST; do
	curl -fsSL -o "$W/dl/$NAME" "$URL"
	SUM=$(sha256sum "$W/dl/$NAME" | cut -d' ' -f1)
	[ -z "$DIGEST" ] || [ "$DIGEST" = "$SUM" ] || { echo "$NAME : empreinte differente de celle de la release" >&2; exit 1; }
done < "$W/assets"

python3 - "$W" <<'PY'
import hashlib, struct, sys, zipfile
w = sys.argv[1]
names = ["wmt_drv", "wmt_chrdev_wifi", "bt_drv", "gps_drv", "fmradio_drv", "wlan_drv_gen4m"]
z = zipfile.ZipFile(f"{w}/dl/librehu_connectivity_ksu.zip")
sums = []
for n in names:
    data = z.read(f"modules/{n}.ko")
    if data[:4] != b"\x7fELF":
        sys.exit(f"{n}.ko : pas un module ELF")
    open(f"{w}/files/modules/{n}.ko", "wb").write(data)
    sums.append(f"{hashlib.sha256(data).hexdigest()}  {n}.ko")
open(f"{w}/files/modules/SHA256SUMS", "w").write("\n".join(sums) + "\n")
kv = z.read("kernel_version").decode().strip()
if not kv.startswith("Linux version "):
    sys.exit("kernel_version absent du module KernelSU")
open(f"{w}/files/kernel_version", "w").write(kv + "\n")
# Section noyau d'une image de boot Android v0/v1 : apres l'en-tete (une page), kernel_size octets
out = []
for img in ("boot_ac8257.img", "boot_ac8257_bootmenu.img"):
    b = open(f"{w}/dl/{img}", "rb").read()
    if b[:8] != b"ANDROID!":
        sys.exit(f"{img} : pas une image de boot Android")
    ksize, page = struct.unpack_from("<I", b, 8)[0], struct.unpack_from("<I", b, 36)[0]
    out.append(f"{hashlib.sha256(b[page:page + ksize]).hexdigest()}  {img}")
open(f"{w}/files/kernels.sha256", "w").write("\n".join(out) + "\n")
PY
sed -n 's/^version=//p' "$W/dl/release.txt" > "$W/version"
[ -s "$W/version" ] || { echo "version absente de release.txt" >&2; exit 1; }
echo "$BRANCH" > "$W/files/branch"
rm -rf "$W/dl" "$W/release.json" "$W/assets"
