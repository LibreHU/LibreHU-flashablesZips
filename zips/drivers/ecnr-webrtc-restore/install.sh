# UJC201 - removes the WebRTC ECNR of LibreHU (zip TWRP)
# Puts back the original libEcnrForCustomer.so of each folder from $SDCARD/LibreHU/backup/ecnr-orig (made by the zip
# ecnr-webrtc or by the LibreHU LineageOS ROM zip), or deletes the LibreHU one where there was none. Creates
# $SDCARD/LibreHU/no-ecnr-webrtc: the LibreHU LineageOS ROM zips no longer install it (the zip ecnr-webrtc deletes it).
# The ROM's vendor cleanup keeps its own backup of the uVoice files (LibreHU/backup/vendor-cleanup-<date>, restore.sh).

ui_print "UJC201 - WebRTC ECNR removed, original library put back"
ui_print "-------------------------------------------------------"
mount_rw
require_no_verity vendor
MARK="LibreHU WebRTC ECNR"
BKDIR=$SDCARD/LibreHU/backup/ecnr-orig
N=0
if [ -d $BKDIR ]; then
	while read -r S F; do
		[ -n "$F" ] || continue
		[ "$(sha256sum $BKDIR/$F | cut -d' ' -f1)" = "$S" ] || abort "backup $BKDIR/$F damaged: nothing changed"
	done < $BKDIR/SHA256SUMS
fi
for arch in lib lib64; do
	f=$VENMNT/$arch/libEcnrForCustomer.so
	if [ -f $BKDIR/$arch/libEcnrForCustomer.so ]; then
		cat $BKDIR/$arch/libEcnrForCustomer.so > $f || abort "cannot write $f"
		chmod 0644 $f; chown 0:0 $f 2>/dev/null
		CTX=$(cat $BKDIR/$arch/context 2>/dev/null); [ -n "$CTX" ] || CTX=u:object_r:vendor_file:s0
		[ -z "$UJC_TEST" ] && chcon $CTX $f
		ui_print "$f: original put back"
		N=$((N + 1))
	elif [ -f $f ] && grep -q "$MARK" $f; then
		rm -f $f && ui_print "$f: LibreHU library deleted" && N=$((N + 1))
	fi
done
if [ -d $SDCARD ]; then
	mkdir -p $SDCARD/LibreHU && touch $SDCARD/LibreHU/no-ecnr-webrtc || abort "cannot create $SDCARD/LibreHU/no-ecnr-webrtc"
	chown 1023:1023 $SDCARD/LibreHU $SDCARD/LibreHU/no-ecnr-webrtc 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon u:object_r:media_rw_data_file:s0 $SDCARD/LibreHU $SDCARD/LibreHU/no-ecnr-webrtc 2>/dev/null
	ui_print "$SDCARD/LibreHU/no-ecnr-webrtc: the LibreHU LineageOS ROM zips will no longer install it"
fi
ui_print " "
[ $N -gt 0 ] && ui_print "Done, reboot." || ui_print "Nothing to remove."
cleanup
exit 0
