# UJC201 - modules Wi-Fi / BT / GPS / FM recompiles pour un noyau LibreHU linux-stable (zip TWRP, sans KernelSU)
# Modules seuls : la partition boot doit deja contenir ce noyau (zip kernel-stable-* ou image de la release).
# Fonctions : common/conn-modules.sh. dm-verity : s'arrete sans rien modifier si /vendor est verifie.

ui_print "UJC201 - modules Wi-Fi / BT / GPS / FM (noyau linux-stable)"
ui_print "version $VERSION"
ui_print "-----------------------------------------------------------"
conn_extract
conn_check_boot
mount_rw
require_no_verity vendor
conn_install

ui_print " "
ui_print "Termine. Redemarrer : les scripts du vendor chargent ces modules comme avant."
ui_print "Retour aux modules d'origine (avant tout autre noyau) : zip conn-modules-stable-restore."
cleanup
exit 0
