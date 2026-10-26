# UJC201 - modules Wi-Fi / BT / GPS / FM du vendor d'origine (noyau 4.9.117 GPL ou stock), zip TWRP
# Les modules actuels sont sauvegardes (conn-modules-<date>), puis remplaces par ceux du zip (empreintes relues),
# droits 644 root:root et contexte vendor_file comme a l'origine ; marqueur LibreHU retire.

ui_print "UJC201 - modules Wi-Fi / BT / GPS / FM d'origine (4.9.117)"
ui_print "version $VERSION"
ui_print "-----------------------------------------------------------"
CONN_TMP=${UJC_TMP:-/tmp}/ujc201_stockmods; rm -rf $CONN_TMP; mkdir -p $CONN_TMP
unzip -o -q "$ZIPFILE" 'files/*' -d $CONN_TMP || abort "extraction du zip impossible"
F=$CONN_TMP/files
while read -r _sum _name; do
	[ "$(sha256sum $F/modules/$_name | cut -d' ' -f1)" = "$_sum" ] || abort "empreinte de $_name incorrecte"
done < $F/modules/SHA256SUMS

# Avertissement si le noyau de boot n'est pas un 4.9.117 (ces modules y seraient refuses)
_bp=$(boot_part)
_ksz=$(od -An -tu4 -j8 -N4 $_bp | tr -d ' '); _page=$(od -An -tu4 -j36 -N4 $_bp | tr -d ' ')
_kv=$(dd if=$_bp bs=$_page skip=1 2>/dev/null | head -c $_ksz | gzip -dc 2>/dev/null | strings | grep -m1 '^Linux version ')
ui_print "noyau de boot : $(echo "${_kv:-inconnu}" | cut -c1-40)"
case "$_kv" in
	"Linux version 4.9.117"*) ;;
	*) ui_print "attention : ce n'est pas un noyau 4.9.117 ; flasher LibreHU-main ou le stock avant de redemarrer" ;;
esac

mount_rw
require_no_verity vendor
MD=$VENMNT/lib/modules
MARK=$MD/.librehu_conn
[ -d $MD ] || abort "$MD introuvable"
[ -d $SDCARD ] || abort "memoire interne non montee : sauvegarde impossible, rien n'a ete modifie"
DATED=$SDCARD/LibreHU/backup/conn-modules-$(date +%Y%m%d-%H%M%S)
conn_save $DATED
ui_print "etat actuel sauvegarde : $DATED"
for m in $CONN_MODS; do
	k=$MD/$m.ko
	cp $F/modules/$m.ko $k.librehu.new || abort "copie de $m.ko impossible"
	chmod 644 $k.librehu.new; chown 0:0 $k.librehu.new 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon u:object_r:vendor_file:s0 $k.librehu.new
	[ "$(sha256sum $k.librehu.new | cut -d' ' -f1)" = "$(grep " $m.ko\$" $F/modules/SHA256SUMS | cut -d' ' -f1)" ] \
		|| abort "$m.ko relu different apres copie"
	mv -f $k.librehu.new $k || abort "remplacement de $m.ko impossible"
	ui_print "$m.ko d'origine remis"
done
rm -f $MARK
rm -rf $CONN_TMP

ui_print " "
ui_print "Termine. Avec le noyau 4.9.117 (LibreHU-main ou stock), redemarrer."
cleanup
exit 0
