#!/bin/sh
# Noyau (boot_ac8257_bootmenu.img) et modules de connectivite de la branche ZIP_BRANCH (variantes de zip.json)
set -e
T="$(dirname "$0")/../../../tools"
sh "$T/kernel_prepare.sh" "$1" "$ZIP_BRANCH" boot_ac8257_bootmenu.img
sh "$T/conn_prepare.sh" "$1" "$ZIP_BRANCH"
