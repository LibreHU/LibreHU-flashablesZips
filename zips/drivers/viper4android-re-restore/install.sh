# UJC201 - retire le pilote ViPER4Android RE installe par ujc201_viper_install (zip TWRP)
# Remet chaque audio_effects d'origine (<fichier>.v4a-orig) et supprime libv4a_re.so.
# dm-verity reste desactive : les blocs de vendor ne redeviennent pas identiques a l'image d'origine.
# Cree /sdcard/LibreHU/no-viper : le zip de la ROM LineageOS LibreHU, qui installe ou met a jour le pilote a chaque
# mise a jour, n'y touche plus (le zip viper4android-re supprime ce fichier).

ui_print "UJC201 - ViPER4Android RE: driver removal"
ui_print "---------------------------------------------"
mount_rw
N=0
for f in $(effect_configs); do
	[ -f "$f.v4a-orig" ] || continue
	cat "$f.v4a-orig" > "$f" || abort "cannot write $f"
	cmp -s "$f.v4a-orig" "$f" || abort "check of $f failed"
	rm -f "$f.v4a-orig"
	ui_print "$f: original put back"
	N=$((N + 1))
done
for arch in lib lib64; do
	f=$VENMNT/$arch/soundfx/libv4a_re.so
	[ -f $f ] && rm -f $f && ui_print "$f: deleted" && N=$((N + 1))
done
if [ -d $SDCARD ]; then
	mkdir -p $SDCARD/LibreHU && touch $SDCARD/LibreHU/no-viper || abort "cannot create $SDCARD/LibreHU/no-viper"
	chown 1023:1023 $SDCARD/LibreHU $SDCARD/LibreHU/no-viper 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon u:object_r:media_rw_data_file:s0 $SDCARD/LibreHU $SDCARD/LibreHU/no-viper 2>/dev/null
	ui_print "$SDCARD/LibreHU/no-viper: the LibreHU LineageOS ROM zips will no longer put the driver back"
else
	ui_print "Internal storage not mounted: the LibreHU LineageOS ROM will put the driver back at its next update"
fi
ui_print " "
[ $N -gt 0 ] && ui_print "Done, reboot." || ui_print "Nothing to remove."
cleanup
exit 0
