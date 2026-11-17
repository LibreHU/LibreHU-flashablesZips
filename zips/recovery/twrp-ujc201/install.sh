# Écrit TWRP (files/twrp.img) dans la partition recovery de l'UJC201.
ui_print "UJC201 - TWRP $VERSION"
ui_print "-----------------------------------------------------------"
DEV=$(getprop ro.product.device)
[ "$DEV" = ac8257_demo ] || abort "device \"$DEV\": this zip is for the UJC201 (ac8257_demo)"
PART=""
for p in /dev/block/by-name/recovery /dev/block/platform/*/by-name/recovery /dev/block/platform/*/*/by-name/recovery; do
	[ -e "$p" ] && { PART=$p; break; }
done
[ -n "$PART" ] || abort "recovery partition not found"
TMPD=${UJC_TMP:-/tmp}/librehu_twrp; rm -rf $TMPD; mkdir -p $TMPD
unzip -o -q "$ZIPFILE" 'files/twrp.img' 'files/twrp.img.sha256' -d $TMPD || abort "cannot extract the zip"
(cd $TMPD/files && sha256sum -c twrp.img.sha256 >/dev/null) || abort "damaged image (checksum)"
ISZ=$(stat -c %s $TMPD/files/twrp.img)
PSZ=$(blockdev --getsize64 "$PART" 2>/dev/null)
[ -n "$PSZ" ] && [ "$ISZ" -le "$PSZ" ] || abort "image ($ISZ bytes) larger than the partition ($PSZ)"
if [ -d $SDCARD ]; then
	mkdir -p $SDCARD/LibreHU/backup
	B=$SDCARD/LibreHU/backup/recovery-$(date +%Y%m%d-%H%M%S).img
	dd if="$PART" of="$B" bs=1048576 2>/dev/null && ui_print "Backup: $B"
else
	ui_print "Internal storage not mounted: no backup of the current recovery"
fi
dd if=$TMPD/files/twrp.img of="$PART" bs=1048576 2>/dev/null || abort "cannot write $PART"
sync
W=$(head -c $ISZ "$PART" | sha256sum | cut -d' ' -f1)
E=$(cut -d' ' -f1 $TMPD/files/twrp.img.sha256)
[ "$W" = "$E" ] || abort "check after writing failed: flash the backup again"
rm -rf $TMPD
ui_print " "
ui_print "TWRP $VERSION written to $PART."
cleanup
exit 0
