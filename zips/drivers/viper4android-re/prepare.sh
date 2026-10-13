#!/bin/sh
# Récupère le module officiel ViPERFX_RE (non-AIDL, Android 9) et en extrait les pilotes et la licence.
# $1 = dossier de travail : files/ y est rempli, version y est écrit.
set -e
W=$1
VER=v2.1.1
SHA=c8f769f9d9f470e47f8278d69615c899d54af3916d10291d853fbd299ee847a2
curl -fsSL -o "$W/module.zip" "https://github.com/likelikeslike/ViPERFX_RE/releases/download/$VER/ViPER4Android-RE-$VER.zip"
echo "$SHA  $W/module.zip" | sha256sum -c -
mkdir -p "$W/files" "$W/mod"
unzip -q -o "$W/module.zip" LICENSE 'common/files/*' -d "$W/mod"
cp "$W"/mod/common/files/libv4a_re_*.so "$W/mod/LICENSE" "$W/files/"
rm -rf "$W/mod" "$W/module.zip"
echo "$VER" > "$W/version"
