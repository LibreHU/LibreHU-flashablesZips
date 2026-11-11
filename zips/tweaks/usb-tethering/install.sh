# UJC201 - partage de connexion USB d'un telephone Android reconnu par Android 9 (zip TWRP)
# Android 9 (EthernetTracker) ne prend que les interfaces de config_ethernet_iface_regex = "eth\d" ; Linux nomme usb0
# le partage de connexion USB d'un telephone Android (rndis_host, cdc_ncm : lien point a point, adresse MAC locale).
# Surcouche statique (RRO) du framework dans /vendor/overlay : "(eth|usb)\d+", comme Android 15.
# Source et construction : overlay/ (AndroidManifest.xml, res/values/config.xml, build.sh).
# dm-verity : s'arrete sans rien modifier si /vendor est verifie.
# Retour : zip usb-tethering-restore.

ui_print "UJC201 - Partage de connexion USB d'un telephone Android"
ui_print "--------------------------------------------------------"
mount_rw
require_no_verity vendor
TMPD=${UJC_TMP:-/tmp}/ujc201_usbtether; rm -rf $TMPD; mkdir -p $TMPD
unzip -o -q "$ZIPFILE" 'files/*' -d $TMPD || abort "extraction du zip impossible"
while read -r SUM NAME; do
	[ "$(sha256sum $TMPD/files/$NAME | cut -d' ' -f1)" = "$SUM" ] || abort "empreinte de $NAME incorrecte"
done < $TMPD/files/SHA256SUMS
[ -d $VENMNT/overlay ] || abort "$VENMNT/overlay introuvable"

DST=$VENMNT/overlay/LibreHUEthernetUsb
rm -rf $DST; mkdir -p $DST || abort "dossier $DST impossible (vendor plein ?)"
cp $TMPD/files/LibreHUEthernetUsb.apk $DST/ || abort "copie de la surcouche impossible (vendor plein ?)"
chmod 0755 $DST; chmod 0644 $DST/LibreHUEthernetUsb.apk; chown -R 0:0 $DST 2>/dev/null
# contexte des surcouches de vendor (file_contexts d'Android 9)
[ -z "$UJC_TEST" ] && chcon -R u:object_r:vendor_overlay_file:s0 $DST
ui_print "$DST/LibreHUEthernetUsb.apk"
rm -rf $TMPD

ui_print " "
ui_print "Termine. Redemarrer : Android prend alors usb0 (partage de"
ui_print "connexion USB d'un telephone Android) comme reseau filaire."
ui_print "Verifier : adb shell dumpsys ethernet | grep -i filter"
ui_print "Retour arriere : flasher le zip usb-tethering-restore"
cleanup
exit 0
