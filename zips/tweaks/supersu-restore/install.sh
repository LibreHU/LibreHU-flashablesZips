# UJC201 - remet SuperSU (mode systeme) depuis la sauvegarde du zip supersu-remove (la plus recente de
# /sdcard/LibreHU/backup/supersu-<date>) : fichiers de /system tels qu'ils etaient (su, daemonsu, appli, app_process
# relie a daemonsu, install-recovery.sh...), contextes SELinux, et mise a jour de l'appli dans /data/app.
# SuperSU n'est pas fourni par ce zip (logiciel proprietaire) : sans sauvegarde, flasher soi-meme le zip officiel.

ui_print "UJC201 - SuperSU put back (backup)"
ui_print "---------------------------------------"
[ -d $SDCARD ] || abort "internal storage not mounted (/data decrypted?): backup not reachable"
BK=""
for d in $SDCARD/LibreHU/backup/supersu-*; do
	[ -f $d/system.tar ] && [ -f $d/files.txt ] && BK=$d
done
[ -n "$BK" ] || abort "no backup in $SDCARD/LibreHU/backup/supersu-* (supersu-remove zip). For a fresh install: flash the official SuperSU 2.82 SR5 zip yourself."
ui_print "Backup: $BK"
mount_rw
S=$(sysdir)
[ -d $S/bin ] || abort "system folder not found ($S)"
DATAAPP=${UJC_DATAAPP:-/data/app}
require_no_verity system
# Essai d'extraction a part d'abord : rien n'est retire de /system si la sauvegarde est abimee
T=${UJC_TMP:-/tmp}/librehu_supersu; rm -rf $T; mkdir -p $T
(cd $T && tar -xpf $BK/system.tar) && [ -e $T/xbin/daemonsu ] || { rm -rf $T; abort "unreadable or incomplete backup ($BK/system.tar), nothing was changed"; }
rm -rf $T

# Les chemins de la sauvegarde remplacent ceux de maintenant (app_process redevient le lien vers daemonsu)
for f in $(cat $BK/files.txt); do
	chattr -i $S/$f 2>/dev/null
	if [ -d $S/$f ] && [ ! -L $S/$f ]; then rm -rf $S/$f; else rm -f $S/$f; fi
done
(cd $S && tar -xpf $BK/system.tar) || abort "cannot extract the backup: flash this zip again"
[ -f $BK/contexts.txt ] && while read -r c f; do chcon -h $c $S/$f 2>/dev/null; done < $BK/contexts.txt
if [ -f $BK/data_app.tar ] && [ -d $DATAAPP ]; then
	(cd $DATAAPP && tar -xpf $BK/data_app.tar) && chcon -R u:object_r:apk_data_file:s0 $DATAAPP/eu.chainfire.supersu* 2>/dev/null
fi
[ -e $S/xbin/daemonsu ] || abort "daemonsu missing after putting back: incomplete backup?"
for a in 32 64; do
	[ -e $S/bin/app_process${a}_original ] && [ ! -e $S/bin/app_process$a ] && [ ! -L $S/bin/app_process$a ] && abort "app_process$a missing: do not reboot, flash this zip again"
done
sync
ui_print " "
ui_print "SuperSU put back. Reboot."
cleanup
exit 0
