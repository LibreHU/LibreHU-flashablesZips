#!/bin/sh
# boot_ac8257_bootmenu.img de la release latest-LibreHU-main du depot du noyau (tools/kernel_prepare.sh)
exec sh "$(dirname "$0")/../../../tools/kernel_prepare.sh" "$1" LibreHU-main boot_ac8257_bootmenu.img
