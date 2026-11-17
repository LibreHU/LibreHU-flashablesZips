# UJC201 - remet les modules Wi-Fi / BT / GPS / FM d'origine (noyau 4.9.117 : GPL LibreHU-main ou stock), sauvegardes
# sur l'autoradio par les zips kernel-stable-4.9.* / conn-modules-stable-4.9.* avant toute modification (zip TWRP).
# Les modules stock ne sont pas dans le zip : rien de /vendor n'est publie.
# Source : $SDCARD/LibreHU/backup/conn-modules-orig (empreintes verifiees), droits, proprietaire et contexte SELinux
# d'origine. Un module absent a l'origine est retire. A flasher avant de revenir a LibreHU-main ou au noyau stock.

MODS="wmt_drv wmt_chrdev_wifi bt_drv gps_drv fmradio_drv wlan_drv_gen4m"

ui_print "UJC201 - original Wi-Fi / BT / GPS / FM modules"
ui_print "-----------------------------------------------"
[ -d $SDCARD ] || abort "internal storage not mounted"
SRC=$SDCARD/LibreHU/backup/conn-modules-orig
mount_rw
if [ ! -f $VENMNT/lib/modules/.librehu_conn ] && [ ! -f $SRC/meta.txt ]; then
	ui_print "The modules of /vendor were never replaced by LibreHU:"
	ui_print "they are already the original ones, nothing to do."
	cleanup
	exit 0
fi
[ -f $SRC/meta.txt ] || abort "no original backup ($SRC): nothing was changed"
while read -r SUM NAME; do
	[ "$(sha256sum $SRC/$NAME | cut -d' ' -f1)" = "$SUM" ] || abort "damaged backup: $NAME (nothing was changed)"
done < $SRC/SHA256SUMS
ui_print "backup: $SRC"

require_no_verity vendor
MD=$VENMNT/lib/modules
for m in $MODS; do
	k=$MD/$m.ko
	line=$(grep "^$m " $SRC/meta.txt)
	[ -n "$line" ] || abort "$m missing from $SRC/meta.txt"
	set -- $line
	if [ "$2" = absent ]; then
		rm -f $k && ui_print "$m.ko removed (not there originally)"
		continue
	fi
	cp $SRC/$m.ko $k.librehu.new || abort "cannot copy $m.ko"
	chmod $2 $k.librehu.new; chown $3:$4 $k.librehu.new 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon $5 $k.librehu.new
	[ "$(sha256sum $k.librehu.new | cut -d' ' -f1)" = "$(grep " $m.ko\$" $SRC/SHA256SUMS | cut -d' ' -f1)" ] \
		|| abort "$m.ko read back different after copy"
	mv -f $k.librehu.new $k || abort "cannot replace $m.ko"
	ui_print "$m.ko put back"
done
rm -f $MD/.librehu_conn

ui_print " "
ui_print "Done. Original modules put back: they only work with the LibreHU-main kernel"
ui_print "or the stock kernel. Now flash that kernel (kernel-librehu zip, Install Image"
ui_print "with a boot-<date>.img backup, or fastboot flash boot), then reboot."
cleanup
exit 0
