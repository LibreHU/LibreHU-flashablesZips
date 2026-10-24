# Écrit TWRP (files/twrp.img) dans la partition recovery de l'UJC201.
ui_print "UJC201 - TWRP $VERSION (beta : build de test de la CI)"
ui_print "-----------------------------------------------------------"
DEV=$(getprop ro.product.device)
[ "$DEV" = ac8257_demo ] || abort "appareil \"$DEV\" : ce zip est pour l'UJC201 (ac8257_demo)"
PART=""
for p in /dev/block/by-name/recovery /dev/block/platform/*/by-name/recovery /dev/block/platform/*/*/by-name/recovery; do
	[ -e "$p" ] && { PART=$p; break; }
done
[ -n "$PART" ] || abort "partition recovery introuvable"
TMPD=${UJC_TMP:-/tmp}/librehu_twrp; rm -rf $TMPD; mkdir -p $TMPD
unzip -o -q "$ZIPFILE" 'files/twrp.img' 'files/twrp.img.sha256' -d $TMPD || abort "extraction du zip impossible"
(cd $TMPD/files && sha256sum -c twrp.img.sha256 >/dev/null) || abort "image abimee (empreinte)"
ISZ=$(stat -c %s $TMPD/files/twrp.img)
PSZ=$(blockdev --getsize64 "$PART" 2>/dev/null)
[ -n "$PSZ" ] && [ "$ISZ" -le "$PSZ" ] || abort "image ($ISZ octets) plus grande que la partition ($PSZ)"
if [ -d $SDCARD ]; then
	mkdir -p $SDCARD/LibreHU/backup
	B=$SDCARD/LibreHU/backup/recovery-$(date +%Y%m%d-%H%M%S).img
	dd if="$PART" of="$B" bs=1048576 2>/dev/null && ui_print "Sauvegarde : $B"
else
	ui_print "Memoire interne non montee : pas de sauvegarde du recovery actuel"
fi
dd if=$TMPD/files/twrp.img of="$PART" bs=1048576 2>/dev/null || abort "ecriture de $PART impossible"
sync
W=$(head -c $ISZ "$PART" | sha256sum | cut -d' ' -f1)
E=$(cut -d' ' -f1 $TMPD/files/twrp.img.sha256)
[ "$W" = "$E" ] || abort "verification apres ecriture echouee : reflasher la sauvegarde"
rm -rf $TMPD
ui_print " "
ui_print "TWRP $VERSION ecrit dans $PART."
cleanup
exit 0
