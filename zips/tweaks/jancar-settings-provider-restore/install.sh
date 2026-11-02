# UJC201 - retrait du fournisseur de reglages LibreHU (zip jancar-settings-provider)
# Sans lui et sans com.jancar.settings, la SystemUI d'origine plante en boucle : remettre l'appli de Jancar avant.

ui_print "UJC201 - fournisseur de reglages Jancar (LibreHU) : retrait"
ui_print "--------------------------------------------------"
mount_rw
S=$(sysdir)
DST=$S/app/LibreHUJacSettings
if [ ! -d $DST ]; then
	ui_print "$DST absent : rien a faire."
	cleanup; exit 0
fi
require_no_verity system
rm -rf $DST || abort "suppression de $DST impossible"
rm -f ${UJC_DATA:-/data}/system/package_cache/*/LibreHUJacSettings* 2>/dev/null
ui_print " "
ui_print "OK : fournisseur retire. Redemarrer."
ui_print "Sans com.jancar.settings, SystemUI plantera : remettre l'appli de Jancar d'abord."
cleanup
exit 0
