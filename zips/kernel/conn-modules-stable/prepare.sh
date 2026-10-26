#!/bin/sh
# Modules de connectivite de la branche stable-4.9.150 (tools/conn_prepare.sh) ; a changer a chaque lot valide
exec sh "$(dirname "$0")/../../../tools/conn_prepare.sh" "$1" stable-4.9.150
