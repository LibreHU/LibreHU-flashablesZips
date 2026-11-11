# UJC201 - retire la surcouche du zip usb-tethering (zip TWRP)
# dm-verity reste desactive : les blocs de vendor ne redeviennent pas identiques a l'image d'origine.

ui_print "UJC201 - Partage de connexion USB : retrait de la surcouche"
ui_print "-----------------------------------------------------------"
mount_rw
d=$VENMNT/overlay/LibreHUEthernetUsb
if [ -d $d ]; then
	rm -rf $d && ui_print "$d : supprime"
	ui_print " "
	ui_print "Termine, redemarrer."
else
	ui_print "Rien a retirer."
fi
cleanup
exit 0
