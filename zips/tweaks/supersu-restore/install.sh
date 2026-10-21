# UJC201 - remet SuperSU (mode systeme) depuis la sauvegarde du zip supersu-remove (la plus recente de
# /sdcard/LibreHU/backup/supersu-<date>) : fichiers de /system tels qu'ils etaient (su, daemonsu, appli, app_process
# relie a daemonsu, install-recovery.sh...), contextes SELinux, et mise a jour de l'appli dans /data/app.
# SuperSU n'est pas fourni par ce zip (logiciel proprietaire) : sans sauvegarde, flasher soi-meme le zip officiel.

ui_print "UJC201 - remise de SuperSU (sauvegarde)"
ui_print "---------------------------------------"
[ -d $SDCARD ] || abort "memoire interne non montee (/data dechiffre ?) : sauvegarde inaccessible"
BK=""
for d in $SDCARD/LibreHU/backup/supersu-*; do
	[ -f $d/system.tar ] && [ -f $d/files.txt ] && BK=$d
done
[ -n "$BK" ] || abort "aucune sauvegarde dans $SDCARD/LibreHU/backup/supersu-* (zip supersu-remove). Pour une installation neuve : zip officiel SuperSU 2.82 SR5 a flasher soi-meme."
ui_print "Sauvegarde : $BK"
mount_rw
S=$(sysdir)
[ -d $S/bin ] || abort "dossier system introuvable ($S)"
DATAAPP=${UJC_DATAAPP:-/data/app}
require_no_verity system
# Essai d'extraction a part d'abord : rien n'est retire de /system si la sauvegarde est abimee
T=${UJC_TMP:-/tmp}/librehu_supersu; rm -rf $T; mkdir -p $T
(cd $T && tar -xpf $BK/system.tar) && [ -e $T/xbin/daemonsu ] || { rm -rf $T; abort "sauvegarde illisible ou incomplete ($BK/system.tar), rien n'a ete modifie"; }
rm -rf $T

# Les chemins de la sauvegarde remplacent ceux de maintenant (app_process redevient le lien vers daemonsu)
for f in $(cat $BK/files.txt); do
	chattr -i $S/$f 2>/dev/null
	if [ -d $S/$f ] && [ ! -L $S/$f ]; then rm -rf $S/$f; else rm -f $S/$f; fi
done
(cd $S && tar -xpf $BK/system.tar) || abort "extraction de la sauvegarde impossible : reflasher ce zip"
[ -f $BK/contexts.txt ] && while read -r c f; do chcon -h $c $S/$f 2>/dev/null; done < $BK/contexts.txt
if [ -f $BK/data_app.tar ] && [ -d $DATAAPP ]; then
	(cd $DATAAPP && tar -xpf $BK/data_app.tar) && chcon -R u:object_r:apk_data_file:s0 $DATAAPP/eu.chainfire.supersu* 2>/dev/null
fi
[ -e $S/xbin/daemonsu ] || abort "daemonsu absent apres la remise : sauvegarde incomplete ?"
for a in 32 64; do
	[ -e $S/bin/app_process${a}_original ] && [ ! -e $S/bin/app_process$a ] && [ ! -L $S/bin/app_process$a ] && abort "app_process$a manquant : ne pas redemarrer, reflasher ce zip"
done
sync
ui_print " "
ui_print "SuperSU remis. Redemarrer."
cleanup
exit 0
