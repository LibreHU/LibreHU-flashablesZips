# UJC201 - pilote ViPER4Android RE sans Magisk (zip TWRP)
# Installe libv4a_re.so dans /vendor/lib[64]/soundfx et declare l'effet dans les audio_effects.xml / .conf
# de vendor, ou de system s'il n'y en a pas dans vendor (librairie "v4a_re", effet "v4a_standard_re", UUID 90380da3-...) : ce que fait le module Magisk ViPERFX_RE.
# Sauvegarde : <fichier>.v4a-orig a cote + /sdcard/UJC201_viper_backup/<date>/.
# dm-verity : si /vendor (ou /system quand sa configuration est modifiee) est verifie (fs_mgr "avb"/"verify") et que
# vbmeta ne l'a pas desactive (adb disable-verity), s'arrete sans rien modifier.
# Retour : zip viper4android-re-restore.
# Avec KernelSU (Next), le module d'origine s'installe sans toucher aux partitions.

UUID=90380da3-8536-4744-a6a3-5731970e640f
ui_print "UJC201 - ViPER4Android RE (driver $V4A_VERSION) without Magisk"
ui_print "-----------------------------------------------------------"
mount_rw
[ -d $SDCARD ] || abort "internal storage not mounted (/data decrypted?): no backup copy possible"
# retire par viper4android-re-restore : la ROM LineageOS LibreHU peut de nouveau le mettre a jour
[ -f $SDCARD/LibreHU/no-viper ] && rm -f $SDCARD/LibreHU/no-viper && ui_print "$SDCARD/LibreHU/no-viper deleted"
TMPD=${UJC_TMP:-/tmp}/ujc201_v4a; rm -rf $TMPD; mkdir -p $TMPD
unzip -o -q "$ZIPFILE" 'files/*' -d $TMPD || abort "cannot extract the zip"

SYS=$(sysdir)
SDK=$(grep -m1 '^ro.build.version.sdk=' $SYS/build.prop 2>/dev/null | cut -d= -f2)
ui_print "Android SDK ${SDK:-?}"
case "$SDK" in 3[4-9]|[4-9][0-9]) abort "Android 14+: the AIDL variant of the driver is needed";; esac

CFGS=$(effect_configs)
[ -n "$CFGS" ] || abort "no audio_effects.xml / .conf in vendor or system"

# --- dm-verity : vendor (pilote), et system si sa configuration est modifiee
case "$CFGS" in $(sysdir)/*) require_no_verity vendor system;; *) require_no_verity vendor;; esac

STAMP=$(date +%Y%m%d-%H%M%S)
BKDIR=$SDCARD/UJC201_viper_backup/$STAMP
mkdir -p $BKDIR || abort "cannot create folder $BKDIR"

# --- pilote
LIBS=0
for arch in lib lib64; do
	d=$VENMNT/$arch/soundfx
	[ -d $d ] || continue
	so=$TMPD/files/libv4a_re_armeabi-v7a.so; [ $arch = lib64 ] && so=$TMPD/files/libv4a_re_arm64-v8a.so
	[ -f $so ] || abort "$so missing from the zip"
	cp $so $d/libv4a_re.so || abort "cannot copy into $d (vendor full?)"
	chmod 0644 $d/libv4a_re.so; chown 0:0 $d/libv4a_re.so 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon u:object_r:vendor_file:s0 $d/libv4a_re.so
	ui_print "$d/libv4a_re.so"
	LIBS=$((LIBS + 1))
done
[ $LIBS -gt 0 ] || abort "$VENMNT/lib/soundfx not found"

# --- configuration des effets
TMP=$TMPD/cfg
for f in $CFGS; do
	ui_print " "
	ui_print "$f"
	# version d'origine : la sauvegarde si deja installe (reinstallation propre)
	SRC=$f; [ -f "$f.v4a-orig" ] && SRC=$f.v4a-orig
	case $f in
	*.xml)
		grep -q '<libraries>' $SRC && grep -q '<effects>' $SRC || { ui_print "  no <libraries> / <effects>: skipped"; continue; }
		sed -e '/v4a_standard_re/d' -e '/"v4a_re"/d' \
		    -e "s|<libraries>|<libraries>\n        <library name=\"v4a_re\" path=\"libv4a_re.so\"/>|" \
		    -e "s|<effects>|<effects>\n        <effect name=\"v4a_standard_re\" library=\"v4a_re\" uuid=\"$UUID\"/>|" \
		    $SRC > $TMP || abort "sed"
		;;
	*.conf)
		grep -q '^libraries {' $SRC && grep -q '^effects {' $SRC || { ui_print "  no libraries / effects: skipped"; continue; }
		sed -e '/v4a_standard_re {/,/}/d' -e '/v4a_re {/,/}/d' \
		    -e "s|^libraries {|libraries {\n  v4a_re {\n    path /vendor/lib/soundfx/libv4a_re.so\n  }|" \
		    -e "s|^effects {|effects {\n  v4a_standard_re {\n    library v4a_re\n    uuid $UUID\n  }|" \
		    $SRC > $TMP || abort "sed"
		;;
	esac
	grep -q "$UUID" $TMP || abort "change of $f failed"
	if [ ! -f "$f.v4a-orig" ]; then
		cp -p "$f" "$f.v4a-orig" || abort "cannot back up $f.v4a-orig"
		ui_print "  backup: $f.v4a-orig"
	fi
	mkdir -p "$BKDIR$(dirname "$f")" && cp -p "$SRC" "$BKDIR$f"
	# reecriture sur place : garde l'inode, les droits et le contexte SELinux
	cat $TMP > "$f" || abort "cannot write $f (restore $f.v4a-orig)"
	cmp -s $TMP "$f" || abort "check of $f failed"
	ui_print "  effect v4a_standard_re declared"
done
rm -rf $TMPD

ui_print " "
ui_print "Done. Backup: $BKDIR"
ui_print "Reboot, then open ViPER4Android: the driver must be \"loaded\"."
ui_print "To go back: flash the viper4android-re-restore zip"
cleanup
exit 0
