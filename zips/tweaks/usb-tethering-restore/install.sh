# UJC201 - retire la surcouche du zip usb-tethering (zip TWRP)
# dm-verity reste desactive : les blocs de vendor ne redeviennent pas identiques a l'image d'origine.

ui_print "UJC201 - Partage de connexion USB : retrait de la surcouche"
ui_print "-----------------------------------------------------------"
mount_rw
N=0
for d in $VENMNT/overlay/LibreHUEthernetUsb.apk $VENMNT/overlay/LibreHUEthernetUsb; do
	[ -e $d ] && rm -rf $d && ui_print "$d : supprime" && N=$((N + 1))
done
ui_print " "
[ $N -gt 0 ] && ui_print "Termine, redemarrer." || ui_print "Rien a retirer."
cleanup
exit 0
