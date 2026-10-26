# UJC201 - remet les modules Wi-Fi / BT / GPS / FM d'origine (noyau 4.9.117 : GPL LibreHU-main ou stock), sauvegardes
# sur l'autoradio par les zips kernel-stable-4.9.* / conn-modules-stable-4.9.* avant toute modification (zip TWRP).
# Les modules stock ne sont pas dans le zip : rien de /vendor n'est publie.
# Source : $SDCARD/LibreHU/backup/conn-modules-orig (empreintes verifiees), droits, proprietaire et contexte SELinux
# d'origine. Un module absent a l'origine est retire. A flasher avant de revenir a LibreHU-main ou au noyau stock.

MODS="wmt_drv wmt_chrdev_wifi bt_drv gps_drv fmradio_drv wlan_drv_gen4m"

ui_print "UJC201 - modules Wi-Fi / BT / GPS / FM d'origine"
ui_print "-----------------------------------------------"
[ -d $SDCARD ] || abort "memoire interne non montee"
SRC=$SDCARD/LibreHU/backup/conn-modules-orig
mount_rw
if [ ! -f $VENMNT/lib/modules/.librehu_conn ] && [ ! -f $SRC/meta.txt ]; then
	ui_print "Les modules de /vendor n'ont jamais ete remplaces par LibreHU :"
	ui_print "ce sont deja ceux d'origine, rien a faire."
	cleanup
	exit 0
fi
[ -f $SRC/meta.txt ] || abort "pas de sauvegarde d'origine ($SRC) : rien n'a ete modifie"
while read -r SUM NAME; do
	[ "$(sha256sum $SRC/$NAME | cut -d' ' -f1)" = "$SUM" ] || abort "sauvegarde abimee : $NAME (rien n'a ete modifie)"
done < $SRC/SHA256SUMS
ui_print "sauvegarde : $SRC"

require_no_verity vendor
MD=$VENMNT/lib/modules
for m in $MODS; do
	k=$MD/$m.ko
	line=$(grep "^$m " $SRC/meta.txt)
	[ -n "$line" ] || abort "$m absent de $SRC/meta.txt"
	set -- $line
	if [ "$2" = absent ]; then
		rm -f $k && ui_print "$m.ko retire (absent a l'origine)"
		continue
	fi
	cp $SRC/$m.ko $k.librehu.new || abort "copie de $m.ko impossible"
	chmod $2 $k.librehu.new; chown $3:$4 $k.librehu.new 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon $5 $k.librehu.new
	[ "$(sha256sum $k.librehu.new | cut -d' ' -f1)" = "$(grep " $m.ko\$" $SRC/SHA256SUMS | cut -d' ' -f1)" ] \
		|| abort "$m.ko relu different apres copie"
	mv -f $k.librehu.new $k || abort "remplacement de $m.ko impossible"
	ui_print "$m.ko remis"
done
rm -f $MD/.librehu_conn

ui_print " "
ui_print "Termine. Modules d'origine remis : ils ne marchent qu'avec le noyau LibreHU-main"
ui_print "ou le noyau stock. Flasher maintenant ce noyau (zip kernel-librehu, Install Image"
ui_print "avec une sauvegarde boot-<date>.img, ou fastboot flash boot), puis redemarrer."
cleanup
exit 0
