# UJC201 - retire la sortie audio "deep_buffer" (zip TWRP), comme tools/ac8257/audio/no_deep_buffer.sh (depot du noyau) mais sans adb root
# Sur cette unite la sortie deep_buffer (PCM 3, MultiMedia2) reste muette : toute la musique passe alors par
# "primary" (celle des sonneries, qui marche). Voir docs/ujc201/audio_deep_buffer.md du depot du noyau.
# Fichier : le premier audio_policy_configuration.xml dans l'ordre de recherche d'Android 9.
# Sauvegarde : <fichier>.nodeep-orig a cote + /sdcard/UJC201_audio_backup/<date>/. Retour : zip no-deep-buffer-restore.

ui_print "UJC201 - deep_buffer audio output removed"
ui_print "------------------------------------------"
mount_rw
[ -d $SDCARD ] || abort "internal storage not mounted (/data decrypted?): no backup copy possible"
f=$(policy_file)
[ -n "$f" ] || abort "no audio_policy_configuration.xml"
ui_print "File used: $f"
SRC=$f; [ -f "$f.nodeep-orig" ] && SRC=$f.nodeep-orig
if ! grep -q deep_buffer "$SRC"; then
	ui_print "deep_buffer missing: nothing to do."
	cleanup; exit 0
fi
require_no_verity $(part_of $f)

TMP=${UJC_TMP:-/tmp}/ujc201_policy.xml
# Bloc <mixPort name="deep_buffer"> ... </mixPort> supprime, et deep_buffer retire des sources des routes.
sed -e '/<mixPort name="deep_buffer"/,/<\/mixPort>/d' -e 's/,deep_buffer//g' -e 's/deep_buffer,//g' "$SRC" > $TMP || abort "sed"
grep -q deep_buffer $TMP && abort "deep_buffer still present (a route that only uses it?): nothing was changed"
grep -q 'sources=""' $TMP && abort "route without a source: nothing was changed"
grep -q 'mixPort name="primary output"' $TMP || abort "primary output missing: nothing was changed"
grep -q '</audioPolicyConfiguration>' $TMP || abort "changed file truncated: nothing was changed"

BKDIR=$SDCARD/UJC201_audio_backup/$(date +%Y%m%d-%H%M%S)
if [ ! -f "$f.nodeep-orig" ]; then
	cp -p "$f" "$f.nodeep-orig" || abort "cannot back up $f.nodeep-orig"
	ui_print "Backup: $f.nodeep-orig"
fi
mkdir -p "$BKDIR$(dirname "$f")" && cp -p "$SRC" "$BKDIR$f" && ui_print "Copy: $BKDIR$f"
# reecriture sur place : garde l'inode, les droits et le contexte SELinux
cat $TMP > "$f" || abort "cannot write $f (restore $f.nodeep-orig)"
cmp -s $TMP "$f" || abort "check of $f failed"
rm -f $TMP
ui_print " "
ui_print "OK: deep_buffer removed, music goes through primary. Reboot."
ui_print "To go back: flash the no-deep-buffer-restore zip"
cleanup
exit 0
