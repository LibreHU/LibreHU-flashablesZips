# UJC201 - retire le pilote ViPER4Android RE installe par ujc201_viper_install (zip TWRP)
# Remet chaque audio_effects d'origine (<fichier>.v4a-orig) et supprime libv4a_re.so.
# dm-verity reste desactive : les blocs de vendor ne redeviennent pas identiques a l'image d'origine.
# Cree /sdcard/LibreHU/no-viper : le zip de la ROM LineageOS LibreHU, qui installe ou met a jour le pilote a chaque
# mise a jour, n'y touche plus (le zip viper4android-re supprime ce fichier).

ui_print "UJC201 - ViPER4Android RE : retrait du pilote"
ui_print "---------------------------------------------"
mount_rw
N=0
for f in $(effect_configs); do
	[ -f "$f.v4a-orig" ] || continue
	cat "$f.v4a-orig" > "$f" || abort "ecriture de $f impossible"
	cmp -s "$f.v4a-orig" "$f" || abort "verification de $f echouee"
	rm -f "$f.v4a-orig"
	ui_print "$f : remis d'origine"
	N=$((N + 1))
done
for arch in lib lib64; do
	f=$VENMNT/$arch/soundfx/libv4a_re.so
	[ -f $f ] && rm -f $f && ui_print "$f : supprime" && N=$((N + 1))
done
if [ -d $SDCARD ]; then
	mkdir -p $SDCARD/LibreHU && touch $SDCARD/LibreHU/no-viper || abort "$SDCARD/LibreHU/no-viper impossible"
	chown 1023:1023 $SDCARD/LibreHU $SDCARD/LibreHU/no-viper 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon u:object_r:media_rw_data_file:s0 $SDCARD/LibreHU $SDCARD/LibreHU/no-viper 2>/dev/null
	ui_print "$SDCARD/LibreHU/no-viper : les zips de la ROM LineageOS LibreHU ne remettront plus le pilote"
else
	ui_print "Memoire interne non montee : la ROM LineageOS LibreHU remettra le pilote a sa prochaine mise a jour"
fi
ui_print " "
[ $N -gt 0 ] && ui_print "Termine, redemarrer." || ui_print "Rien a retirer."
cleanup
exit 0
