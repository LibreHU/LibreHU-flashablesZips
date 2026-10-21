#!/bin/sh
# boot_ac8257_bootmenu.img de la release latest-connectivity-builtin du depot du noyau (tools/kernel_prepare.sh)
exec sh "$(dirname "$0")/../../../tools/kernel_prepare.sh" "$1" connectivity-builtin boot_ac8257_bootmenu.img
