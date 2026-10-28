# UJC201 - remet la liste blanche QuickBoot d'origine (/vendor/etc/qb_list.xml), gardee par le zip qb-whitelist

ui_print "UJC201 - liste blanche QuickBoot d'origine"
ui_print "-------------------------------------------"
mount_rw
F=$VENMNT/etc/qb_list.xml
ORIG=$F.librehu-orig
if [ -f $ORIG ]; then
	require_no_verity vendor
	cat $ORIG > $F || abort "ecriture de $F impossible"
	cmp -s $ORIG $F || abort "verification de $F echouee"
	rm -f $ORIG
	ui_print "$F : remis d'origine."
elif [ -f $F.librehu-created ]; then
	require_no_verity vendor
	rm -f $F $F.librehu-created
	ui_print "$F : cree par LibreHU, retire (il n'existait pas)."
elif [ -f $F ] && grep -q '<!-- LibreHU -->' $F; then
	require_no_verity vendor
	TMP=${UJC_TMP:-/tmp}/ujc201_qb_list.xml
	grep -v '<!-- LibreHU -->' $F > $TMP || abort "grep"
	cat $TMP > $F || abort "ecriture de $F impossible"
	rm -f $TMP
	ui_print "$F : lignes LibreHU retirees (pas de sauvegarde .librehu-orig)."
else
	ui_print "Pas de liste blanche LibreHU : rien a remettre."
	cleanup; exit 0
fi
ui_print "Redemarrer : QuickBoot arretera de nouveau les applis LibreHU a l'extinction de l'ecran."
cleanup
exit 0
