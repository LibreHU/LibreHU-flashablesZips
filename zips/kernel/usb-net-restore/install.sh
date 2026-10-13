# UJC201 - retire les pilotes reseau USB installes par le zip usb-net (zip TWRP)
# dm-verity reste desactive : les blocs de vendor ne redeviennent pas identiques a l'image d'origine.

ui_print "UJC201 - Ethernet USB : retrait des pilotes"
ui_print "-------------------------------------------"
mount_rw
N=0
f=$VENMNT/etc/init/init.librehu_usbnet.rc
[ -f $f ] && rm -f $f && ui_print "$f : supprime" && N=$((N + 1))
d=$VENMNT/lib/modules/librehu-usbnet
[ -d $d ] && rm -rf $d && ui_print "$d : supprime" && N=$((N + 1))
ui_print " "
[ $N -gt 0 ] && ui_print "Termine, redemarrer." || ui_print "Rien a retirer."
cleanup
exit 0
