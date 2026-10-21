# Ecrit le noyau LibreHU de la branche connectivity-builtin (boot_ac8257_bootmenu.img de sa release latest-connectivity-builtin) dans la partition boot.
ui_print "UJC201 - Noyau LibreHU, connectivite integree + menu de demarrage (experimental)"
ui_print "version $VERSION"
ui_print "-----------------------------------------------------------"
flash_image boot.img boot
ui_print " "
ui_print "Noyau connectivity-builtin $VERSION ecrit. Redemarrer."
ui_print "Retour arriere : la sauvegarde ci-dessus (TWRP : Install, Install Image, Boot)."
cleanup
exit 0
