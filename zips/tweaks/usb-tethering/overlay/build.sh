#!/bin/sh
# Builds ../files/LibreHUEthernetUsb.apk from this folder (aapt2, apksigner of the Android SDK).
#   sh build.sh [android.jar]
# The signature does not matter for a static overlay of /vendor: a throwaway key is made for each build.
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}
BT=$(ls -d "$SDK"/build-tools/* | sort -V | tail -n 1)
JAR=${1:-$(ls "$SDK"/platforms/android-*/android.jar | sort -V | tail -n 1)}
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
"$BT/aapt2" compile --dir res -o "$W/res.zip"
"$BT/aapt2" link -o "$W/unsigned.apk" -I "$JAR" --manifest AndroidManifest.xml "$W/res.zip"
"$BT/zipalign" -f 4 "$W/unsigned.apk" "$W/aligned.apk"
keytool -genkeypair -keystore "$W/k.jks" -storepass librehu -keypass librehu -alias overlay -keyalg RSA -keysize 2048 \
	-validity 10000 -dname "CN=LibreHU overlay" >/dev/null 2>&1
"$BT/apksigner" sign --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --v4-signing-enabled false --ks "$W/k.jks" --ks-pass pass:librehu --key-pass pass:librehu --out ../files/LibreHUEthernetUsb.apk \
	"$W/aligned.apk"
"$BT/aapt2" dump resources ../files/LibreHUEthernetUsb.apk | grep -A1 config_ethernet_iface_regex
(cd ../files && sha256sum LibreHUEthernetUsb.apk > SHA256SUMS)
