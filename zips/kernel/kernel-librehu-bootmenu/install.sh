# Ecrit le noyau LibreHU de la branche LibreHU-main (boot_ac8257_bootmenu.img de sa release latest-LibreHU-main) dans la partition boot.
ui_print "UJC201 - LibreHU kernel + boot menu (LibreHU-main)"
ui_print "version $VERSION"
ui_print "-----------------------------------------------------------"
flash_image boot.img boot
ui_print " "
ui_print "LibreHU-main kernel $VERSION written. Reboot."
ui_print "To go back: the backup above (TWRP: Install, Install Image, Boot)."
cleanup
exit 0
