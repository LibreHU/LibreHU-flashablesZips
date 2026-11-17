# UJC201 - remet la liste blanche QuickBoot d'origine (/vendor/etc/qb_list.xml), gardee par le zip qb-whitelist

ui_print "UJC201 - original QuickBoot whitelist"
ui_print "-------------------------------------------"
mount_rw
F=$VENMNT/etc/qb_list.xml
ORIG=$F.librehu-orig
if [ -f $ORIG ]; then
	require_no_verity vendor
	cat $ORIG > $F || abort "cannot write $F"
	cmp -s $ORIG $F || abort "check of $F failed"
	rm -f $ORIG
	ui_print "$F: original put back."
elif [ -f $F.librehu-created ]; then
	require_no_verity vendor
	rm -f $F $F.librehu-created
	ui_print "$F: created by LibreHU, removed (it did not exist)."
elif [ -f $F ] && grep -q '<!-- LibreHU -->' $F; then
	require_no_verity vendor
	TMP=${UJC_TMP:-/tmp}/ujc201_qb_list.xml
	grep -v '<!-- LibreHU -->' $F > $TMP || abort "grep"
	cat $TMP > $F || abort "cannot write $F"
	rm -f $TMP
	ui_print "$F: LibreHU lines removed (no .librehu-orig backup)."
else
	ui_print "No LibreHU whitelist: nothing to put back."
	cleanup; exit 0
fi
ui_print "Reboot: QuickBoot will stop the LibreHU apps again when the screen turns off."
cleanup
exit 0
