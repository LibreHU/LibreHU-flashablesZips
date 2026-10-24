#!/bin/sh
# TWRP bêta : la dernière build twrp-build-* de la CI, pré-releases comprises (même téléchargement que twrp-ujc201).
TWRP_CHANNEL=beta exec sh "$(dirname "$0")/../twrp-ujc201/prepare.sh" "$1"
