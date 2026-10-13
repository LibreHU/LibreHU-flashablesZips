# UJC201 - pilotes reseau USB (Ethernet Realtek, partage de connexion USB Android / iPhone, autres puces) (zip TWRP)
# Modules compiles pour le noyau stock 4.9.117+ (memes exports et CRC pour Jancar #25 et #72), source et
# verification : tools/usbnet du depot de l'appareil. Copies dans /vendor/lib/modules/librehu-usbnet, charges par
# /vendor/etc/init/init.librehu_usbnet.rc une fois Android demarre (comme les modules stock bt_drv, wmt_drv).
# dm-verity : s'arrete sans rien modifier si /vendor est verifie.
# Retour : zip usb-net-restore.

ui_print "UJC201 - Ethernet USB et partage de connexion USB"
ui_print "-------------------------------------------------"
KREL=$(uname -r)
ui_print "noyau (recovery) : $KREL"
[ -n "$UJC_TEST" ] || [ "$KREL" = "4.9.117+" ] || abort "noyau $KREL : ces modules sont pour le noyau stock 4.9.117+"
mount_rw
require_no_verity vendor
TMPD=${UJC_TMP:-/tmp}/ujc201_usbnet; rm -rf $TMPD; mkdir -p $TMPD
unzip -o -q "$ZIPFILE" 'files/*' -d $TMPD || abort "extraction du zip impossible"
# empreintes (sha256sum -c n'existe pas dans tous les TWRP : comparaison une par une)
while read -r SUM NAME; do
	[ "$(sha256sum $TMPD/files/modules/$NAME | cut -d' ' -f1)" = "$SUM" ] || abort "empreinte de $NAME incorrecte"
done < $TMPD/files/modules/SHA256SUMS

DST=$VENMNT/lib/modules/librehu-usbnet
rm -rf $DST; mkdir -p $DST || abort "dossier $DST impossible (vendor plein ?)"
for ko in $TMPD/files/modules/*.ko; do
	cp $ko $DST/ || abort "copie de $(basename $ko) impossible (vendor plein ?)"
done
chmod 0755 $DST; chmod 0644 $DST/*.ko; chown -R 0:0 $DST 2>/dev/null
[ -z "$UJC_TEST" ] && chcon -R u:object_r:vendor_file:s0 $DST
ui_print "$DST : $(ls $DST | wc -l) modules"

RC=$VENMNT/etc/init/init.librehu_usbnet.rc
cp $TMPD/files/init.librehu_usbnet.rc $RC || abort "copie de $RC impossible"
chmod 0644 $RC; chown 0:0 $RC 2>/dev/null
[ -z "$UJC_TEST" ] && chcon u:object_r:vendor_configs_file:s0 $RC
ui_print "$RC"
rm -rf $TMPD

ui_print " "
ui_print "Termine. Redemarrer : les pilotes se chargent une fois Android demarre."
ui_print "Etat et reactivation : LibreHU-service, carte Ethernet."
ui_print "Retour arriere : flasher le zip usb-net-restore"
cleanup
exit 0
