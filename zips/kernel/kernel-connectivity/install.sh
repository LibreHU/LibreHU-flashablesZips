# Ecrit le noyau LibreHU de la branche connectivity-builtin (boot_ac8257.img de sa release latest-connectivity-builtin) dans la partition boot.
ui_print "UJC201 - LibreHU kernel, built-in connectivity (experimental)"
ui_print "version $VERSION"
ui_print "-----------------------------------------------------------"
flash_image boot.img boot
ui_print " "
ui_print "connectivity-builtin kernel $VERSION written. Reboot."
ui_print "To go back: the backup above (TWRP: Install, Install Image, Boot)."
cleanup
exit 0
