# UJC201 - modules Wi-Fi / BT / GPS / FM du vendor d'origine (noyau 4.9.117 GPL ou stock), zip TWRP
# Les modules actuels sont sauvegardes (conn-modules-<date>), puis remplaces par ceux du zip (empreintes relues),
# droits 644 root:root et contexte vendor_file comme a l'origine ; marqueur LibreHU retire.

ui_print "UJC201 - original Wi-Fi / BT / GPS / FM modules (4.9.117)"
ui_print "version $VERSION"
ui_print "-----------------------------------------------------------"
CONN_TMP=${UJC_TMP:-/tmp}/ujc201_stockmods; rm -rf $CONN_TMP; mkdir -p $CONN_TMP
unzip -o -q "$ZIPFILE" 'files/*' -d $CONN_TMP || abort "cannot extract the zip"
F=$CONN_TMP/files
while read -r _sum _name; do
	[ "$(sha256sum $F/modules/$_name | cut -d' ' -f1)" = "$_sum" ] || abort "wrong checksum for $_name"
done < $F/modules/SHA256SUMS

# Avertissement si le noyau de boot n'est pas un 4.9.117 (ces modules y seraient refuses)
_bp=$(boot_part)
_ksz=$(od -An -tu4 -j8 -N4 $_bp | tr -d ' '); _page=$(od -An -tu4 -j36 -N4 $_bp | tr -d ' ')
_kv=$(dd if=$_bp bs=$_page skip=1 2>/dev/null | head -c $_ksz | gzip -dc 2>/dev/null | strings | grep -m1 '^Linux version ')
ui_print "boot kernel: $(echo "${_kv:-unknown}" | cut -c1-40)"
case "$_kv" in
	"Linux version 4.9.117"*) ;;
	*) ui_print "warning: this is not a 4.9.117 kernel; flash LibreHU-main or the stock one before rebooting" ;;
esac

mount_rw
require_no_verity vendor
MD=$VENMNT/lib/modules
MARK=$MD/.librehu_conn
[ -d $MD ] || abort "$MD not found"
[ -d $SDCARD ] || abort "internal storage not mounted: no backup possible, nothing was changed"
DATED=$SDCARD/LibreHU/backup/conn-modules-$(date +%Y%m%d-%H%M%S)
conn_save $DATED
ui_print "current state backed up: $DATED"
for m in $CONN_MODS; do
	k=$MD/$m.ko
	cp $F/modules/$m.ko $k.librehu.new || abort "cannot copy $m.ko"
	chmod 644 $k.librehu.new; chown 0:0 $k.librehu.new 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon u:object_r:vendor_file:s0 $k.librehu.new
	[ "$(sha256sum $k.librehu.new | cut -d' ' -f1)" = "$(grep " $m.ko\$" $F/modules/SHA256SUMS | cut -d' ' -f1)" ] \
		|| abort "$m.ko read back different after copy"
	mv -f $k.librehu.new $k || abort "cannot replace $m.ko"
	ui_print "original $m.ko put back"
done
rm -f $MARK
rm -rf $CONN_TMP

ui_print " "
ui_print "Done. With the 4.9.117 kernel (LibreHU-main or stock), reboot."
cleanup
exit 0
