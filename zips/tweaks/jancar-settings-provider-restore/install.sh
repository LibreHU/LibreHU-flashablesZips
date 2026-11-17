# UJC201 - retrait du fournisseur de reglages LibreHU (zip jancar-settings-provider)
# Sans lui et sans com.jancar.settings, la SystemUI d'origine plante en boucle : remettre l'appli de Jancar avant.

ui_print "UJC201 - Jancar settings provider (LibreHU): removal"
ui_print "--------------------------------------------------"
mount_rw
S=$(sysdir)
DST=$S/app/LibreHUJacSettings
if [ ! -d $DST ]; then
	ui_print "$DST missing: nothing to do."
	cleanup; exit 0
fi
require_no_verity system
rm -rf $DST || abort "cannot delete $DST"
rm -f ${UJC_DATA:-/data}/system/package_cache/*/LibreHUJacSettings* 2>/dev/null
ui_print " "
ui_print "OK: provider removed. Reboot."
ui_print "Without com.jancar.settings, SystemUI will crash: put the Jancar app back first."
cleanup
exit 0
