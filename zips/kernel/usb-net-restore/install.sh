# UJC201 - retire les pilotes reseau USB installes par le zip usb-net (zip TWRP)
# dm-verity reste desactive : les blocs de vendor ne redeviennent pas identiques a l'image d'origine.

ui_print "UJC201 - USB Ethernet: driver removal"
ui_print "-------------------------------------------"
mount_rw
N=0
f=$VENMNT/etc/init/init.librehu_usbnet.rc
[ -f $f ] && rm -f $f && ui_print "$f: deleted" && N=$((N + 1))
d=$VENMNT/lib/modules/librehu-usbnet
[ -d $d ] && rm -rf $d && ui_print "$d: deleted" && N=$((N + 1))
ui_print " "
[ $N -gt 0 ] && ui_print "Done, reboot." || ui_print "Nothing to remove."
cleanup
exit 0
