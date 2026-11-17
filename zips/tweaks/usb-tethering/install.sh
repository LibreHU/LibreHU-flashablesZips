# UJC201 - partage de connexion USB d'un telephone Android reconnu par Android 9 (zip TWRP)
# Android 9 (EthernetTracker) ne prend que les interfaces de config_ethernet_iface_regex = "eth\d" ; Linux nomme usb0
# le partage de connexion USB d'un telephone Android (rndis_host, cdc_ncm : lien point a point, adresse MAC locale).
# Surcouche statique (RRO) du framework dans /vendor/overlay : "(eth|usb)\d+", comme Android 15.
# Source et construction : overlay/ (AndroidManifest.xml, res/values/config.xml, build.sh).
# dm-verity : s'arrete sans rien modifier si /vendor est verifie.
# Retour : zip usb-tethering-restore.

ui_print "UJC201 - USB tethering of an Android phone"
ui_print "--------------------------------------------------------"
mount_rw
require_no_verity vendor
TMPD=${UJC_TMP:-/tmp}/ujc201_usbtether; rm -rf $TMPD; mkdir -p $TMPD
unzip -o -q "$ZIPFILE" 'files/*' -d $TMPD || abort "cannot extract the zip"
while read -r SUM NAME; do
	[ "$(sha256sum $TMPD/files/$NAME | cut -d' ' -f1)" = "$SUM" ] || abort "wrong checksum for $NAME"
done < $TMPD/files/SHA256SUMS
[ -d $VENMNT/overlay ] || abort "$VENMNT/overlay not found"

# Fichier pose directement dans /vendor/overlay : le zygote d'Android 9 (idmap --scan) n'y lit que les fichiers, pas les
# sous-dossiers ; sans son idmap, une surcouche statique du framework n'est pas appliquee.
rm -rf $VENMNT/overlay/LibreHUEthernetUsb
DST=$VENMNT/overlay/LibreHUEthernetUsb.apk
cp $TMPD/files/LibreHUEthernetUsb.apk $DST || abort "cannot copy the overlay (vendor full?)"
chmod 0644 $DST; chown 0:0 $DST 2>/dev/null
# contexte des surcouches de vendor (file_contexts d'Android 9)
[ -z "$UJC_TEST" ] && chcon u:object_r:vendor_overlay_file:s0 $DST
ui_print "$DST"
rm -rf $TMPD

ui_print " "
ui_print "Done. Reboot: Android then takes usb0 (USB tethering"
ui_print "of an Android phone) as a wired network."
ui_print "Check: adb shell dumpsys ethernet | grep -i filter"
ui_print "To go back: flash the usb-tethering-restore zip"
cleanup
exit 0
