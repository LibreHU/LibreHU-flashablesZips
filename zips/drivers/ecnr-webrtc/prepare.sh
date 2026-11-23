#!/bin/sh
# Takes libEcnrForCustomer.so (armeabi-v7a, arm64-v8a) from the release ecnr-webrtc of this repository, built and
# tested by .github/workflows/ecnr-webrtc.yml from native/ecnr-webrtc, and checks it against its SHA256SUMS.
# $1 = work folder: files/ is filled, version is written. Exit 3 (zip left out) while the release does not exist.
set -e
W=$1
REPO=${GITHUB_REPOSITORY:-LibreHU/LibreHU-flashablesZips}
BASE="https://github.com/$REPO/releases/download/ecnr-webrtc"
mkdir -p "$W/files"
curl -fsSL --retry 3 -o "$W/files/SHA256SUMS" "$BASE/SHA256SUMS" || exit 3
for f in libEcnrForCustomer_armeabi-v7a.so libEcnrForCustomer_arm64-v8a.so version NOTICE; do
	curl -fsSL --retry 3 -o "$W/files/$f" "$BASE/$f"
done
(cd "$W/files" && sha256sum -c SHA256SUMS)
cp "$W/files/version" "$W/version"
