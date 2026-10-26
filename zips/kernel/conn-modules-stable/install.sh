# UJC201 - modules Wi-Fi / BT / GPS / FM recompiles pour le noyau LibreHU linux-stable (zip TWRP, sans KernelSU)
# Sur une branche stable-4.9.* du noyau, les CRC des symboles ne sont plus ceux du stock : les modules de
# /vendor/lib/modules sont refuses. Ce zip met a leur place les memes pilotes recompiles avec ce noyau (sources GPL
# MediaTek, docs/STABLE.md du depot du noyau), apres avoir verifie que la partition boot contient ce noyau.
# Sauvegardes : $SDCARD/LibreHU/backup/conn-modules-orig (modules d'origine, une seule fois, jamais ecrasee) et
# conn-modules-<date> (etat d'avant chaque passage). Retour : zip conn-modules-stable-restore.
# dm-verity : s'arrete sans rien modifier si /vendor est verifie.

MODS="wmt_drv wmt_chrdev_wifi bt_drv gps_drv fmradio_drv wlan_drv_gen4m"

ui_print "UJC201 - modules Wi-Fi / BT / GPS / FM (noyau linux-stable)"
ui_print "version $VERSION"
ui_print "-----------------------------------------------------------"
TMPD=${UJC_TMP:-/tmp}/ujc201_conn; rm -rf $TMPD; mkdir -p $TMPD
unzip -o -q "$ZIPFILE" 'files/*' -d $TMPD || abort "extraction du zip impossible"
F=$TMPD/files
ui_print "branche du noyau : $(cat $F/branch)"
while read -r SUM NAME; do
	[ "$(sha256sum $F/modules/$NAME | cut -d' ' -f1)" = "$SUM" ] || abort "empreinte de $NAME incorrecte"
done < $F/modules/SHA256SUMS

# 1. Le noyau de la partition boot doit etre celui de ces modules (section noyau de l'image de boot)
BOOT=${UJC_BOOT:-}
if [ -z "$BOOT" ]; then
	for _p in /dev/block/by-name/boot /dev/block/platform/*/by-name/boot /dev/block/platform/*/*/by-name/boot; do
		[ -e "$_p" ] && { BOOT=$_p; break; }
	done
fi
[ -n "$BOOT" ] || abort "partition boot introuvable"
[ "$(dd if=$BOOT bs=8 count=1 2>/dev/null)" = "ANDROID!" ] || abort "la partition boot n'a pas d'image de boot Android"
KSZ=$(od -An -tu4 -j8 -N4 $BOOT | tr -d ' ')
PAGE=$(od -An -tu4 -j36 -N4 $BOOT | tr -d ' ')
KSUM=$(dd if=$BOOT bs=$PAGE skip=1 2>/dev/null | head -c $KSZ | sha256sum | cut -d' ' -f1)
if ! grep -q "^$KSUM " $F/kernels.sha256; then
	ui_print " "
	ui_print "Le noyau de la partition boot n'est pas celui de ces modules :"
	ui_print "  $(cut -c1-60 $F/kernel_version)"
	ui_print "Flasher d'abord boot_ac8257.img (ou boot_ac8257_bootmenu.img) de la release"
	ui_print "latest-$(cat $F/branch) du depot du noyau, puis ce zip."
	abort "noyau different, rien n'a ete modifie"
fi
ui_print "noyau de boot : $(grep "^$KSUM " $F/kernels.sha256 | cut -d' ' -f3), conforme"

# 2. vendor en ecriture, sans dm-verity
mount_rw
require_no_verity vendor
MD=$VENMNT/lib/modules
MARK=$MD/.librehu_conn
[ -d $MD ] || abort "$MD introuvable"
[ -d $SDCARD ] || abort "memoire interne non montee : sauvegarde impossible, rien n'a ete modifie"
BK=$SDCARD/LibreHU/backup
mkdir -p $BK || abort "dossier $BK impossible"

# Sauvegarde de l'etat actuel de $MD dans $1 : fichiers, droits, proprietaire, contexte SELinux, empreintes
save_mods() {
	mkdir -p $1 || abort "dossier $1 impossible"
	: > $1/meta.txt; : > $1/SHA256SUMS
	for m in $MODS; do
		k=$MD/$m.ko
		if [ -f $k ]; then
			cp $k $1/ || abort "sauvegarde de $m.ko impossible (memoire pleine ?)"
			ctx=$(ls -Z $k 2>/dev/null | awk '{print $1}')
			case "$ctx" in u:*) ;; *) ctx=u:object_r:vendor_file:s0;; esac
			echo "$m $(stat -c '%a %u %g' $k) $ctx" >> $1/meta.txt
			echo "$(sha256sum $k | cut -d' ' -f1)  $m.ko" >> $1/SHA256SUMS
		else
			echo "$m absent" >> $1/meta.txt
		fi
	done
	[ -f $MARK ] && cp $MARK $1/librehu_conn.txt
}
if [ -f $MARK ]; then
	ui_print "modules deja remplaces par LibreHU : $(head -n1 $MARK)"
	[ -d $BK/conn-modules-orig ] || ui_print "attention : pas de sauvegarde des modules d'origine dans $BK"
elif [ -d $BK/conn-modules-orig ]; then
	ui_print "sauvegarde d'origine deja presente : $BK/conn-modules-orig"
else
	save_mods $BK/conn-modules-orig
	ui_print "modules d'origine sauvegardes : $BK/conn-modules-orig"
fi
DATED=$BK/conn-modules-$(date +%Y%m%d-%H%M%S)
save_mods $DATED
ui_print "etat actuel sauvegarde : $DATED"

# 3. Place libre (le plus gros module, wlan_drv_gen4m, est ecrit a cote avant de remplacer l'ancien)
NEED=$(( $(du -k $F/modules/wlan_drv_gen4m.ko | cut -f1) + 64 ))
FREE=$(df -k $VENMNT | tail -n1 | awk '{print $(NF-2)}')
[ -n "$FREE" ] && [ "$FREE" -lt "$NEED" ] && abort "vendor plein ($FREE Ko libres, $NEED necessaires)"

# 4. Remplacement : copie a cote (.librehu.new), droits et contexte de l'original, empreinte relue, puis renommage
for m in $MODS; do
	k=$MD/$m.ko
	line=$(grep "^$m " $DATED/meta.txt)
	set -- $line
	if [ "$2" = absent ]; then mode=644; uid=0; gid=0; ctx=u:object_r:vendor_file:s0; else mode=$2; uid=$3; gid=$4; ctx=$5; fi
	cp $F/modules/$m.ko $k.librehu.new || abort "copie de $m.ko impossible"
	chmod $mode $k.librehu.new; chown $uid:$gid $k.librehu.new 2>/dev/null
	[ -z "$UJC_TEST" ] && chcon $ctx $k.librehu.new
	[ "$(sha256sum $k.librehu.new | cut -d' ' -f1)" = "$(grep " $m.ko\$" $F/modules/SHA256SUMS | cut -d' ' -f1)" ] \
		|| abort "$m.ko relu different apres copie"
	mv -f $k.librehu.new $k || abort "remplacement de $m.ko impossible"
	ui_print "$m.ko remplace"
done
{ echo "$VERSION $(cat $F/branch)"; cat $F/kernel_version; } > $MARK
chmod 0644 $MARK
[ -z "$UJC_TEST" ] && chcon u:object_r:vendor_file:s0 $MARK
rm -rf $TMPD

ui_print " "
ui_print "Termine. Redemarrer : les scripts du vendor chargent ces modules comme avant."
ui_print "Retour aux modules d'origine (avant tout autre noyau) : zip conn-modules-stable-restore."
cleanup
exit 0
