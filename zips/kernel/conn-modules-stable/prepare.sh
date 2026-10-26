#!/bin/sh
# Modules de connectivite de la branche ZIP_BRANCH (variantes de zip.json, tools/conn_prepare.sh)
exec sh "$(dirname "$0")/../../../tools/conn_prepare.sh" "$1" "$ZIP_BRANCH"
