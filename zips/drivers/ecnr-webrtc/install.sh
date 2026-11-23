# UJC201 - WebRTC echo cancellation / noise reduction for calls (zip TWRP)
# Installs libEcnrForCustomer.so of LibreHU (native/ecnr-webrtc of this repository) in /vendor/lib[64], next to
# libecnrhelper.so: the audio HAL loads it through that helper (dlopen) during calls when
# vendor.audiohal.third_ecnr_lib.enable is 1 (LibreHU-service > Audio > Microphone > ECNR).
# Only where the vendor has libecnrhelper.so (same lib / lib64 folder): a vendor without it (older builds, e.g. 1457)
# has no such hook in its audio HAL, and nothing is installed.
# Backup, once (never overwritten): $SDCARD/LibreHU/backup/ecnr-orig (the original file of each folder, or "absent"),
# which ecnr-webrtc-restore puts back. dm-verity on /vendor: stops without changing anything.

ui_print "UJC201 - WebRTC echo cancellation / noise reduction ($VERSION)"
ui_print "---------------------------------------------------------------"
mount_rw
[ -d $SDCARD ] || abort "internal storage not mounted (/data decrypted?): no backup copy possible"
require_no_verity vendor
TMPD=${UJC_TMP:-/tmp}/ujc201_ecnr; rm -rf $TMPD; mkdir -p $TMPD
unzip -o -q "$ZIPFILE" 'files/*' -d $TMPD || abort "cannot extract the zip"
while read -r S F; do
	[ -n "$F" ] || continue
	[ "$(sha256sum $TMPD/files/$F | cut -d' ' -f1)" = "$S" ] || abort "wrong checksum for $F"
done < $TMPD/files/SHA256SUMS

MARK="LibreHU WebRTC ECNR"
BKDIR=$SDCARD/LibreHU/backup/ecnr-orig
DIRS=""
for arch in lib lib64; do
	[ -f $VENMNT/$arch/libecnrhelper.so ] && DIRS="$DIRS $arch"
done
[ -n "$DIRS" ] || abort "no libecnrhelper.so in $VENMNT/lib or lib64: the audio HAL of this vendor has no ECNR hook, nothing installed"

# --- sauvegarde des originaux, une seule fois (jamais une copie de la bibliotheque LibreHU)
if [ ! -d $BKDIR ]; then
	mkdir -p $BKDIR || abort "cannot create $BKDIR"
	for arch in $DIRS; do
		f=$VENMNT/$arch/libEcnrForCustomer.so
		if [ -f $f ] && ! grep -q "$MARK" $f; then
			mkdir -p $BKDIR/$arch && cp -p $f $BKDIR/$arch/ || { rm -rf $BKDIR; abort "cannot back up $f"; }
			ls -Z $f 2>/dev/null | awk '{print $1}' > $BKDIR/$arch/context
			ui_print "original backed up: $BKDIR/$arch/libEcnrForCustomer.so"
		else
			echo "$arch" >> $BKDIR/absent
		fi
	done
	(cd $BKDIR && find . -name '*.so' -exec sha256sum {} \; > SHA256SUMS)
fi

# --- bibliotheque LibreHU
N=0
for arch in $DIRS; do
	so=$TMPD/files/libEcnrForCustomer_armeabi-v7a.so; [ $arch = lib64 ] && so=$TMPD/files/libEcnrForCustomer_arm64-v8a.so
	f=$VENMNT/$arch/libEcnrForCustomer.so
	if cmp -s $so $f; then
		ui_print "$f: already $VERSION"
		N=$((N + 1))
		continue
	fi
	cp $so $f.librehu.new || { rm -f $f.librehu.new; abort "cannot copy into $VENMNT/$arch (vendor full?)"; }
	chmod 0644 $f.librehu.new; chown 0:0 $f.librehu.new 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon u:object_r:vendor_file:s0 $f.librehu.new
	mv -f $f.librehu.new $f || abort "cannot replace $f"
	ui_print "$f: $VERSION"
	N=$((N + 1))
done
[ -f $SDCARD/LibreHU/no-ecnr-webrtc ] && rm -f $SDCARD/LibreHU/no-ecnr-webrtc && ui_print "$SDCARD/LibreHU/no-ecnr-webrtc deleted"
rm -rf $TMPD
ui_print " "
ui_print "Done ($N folder(s)). Reboot, then in LibreHU-service > Audio > Microphone:"
ui_print "ECNR on; echo canceller, noise reduction and gain just below."
cleanup
exit 0
