# UJC201 - remet les Google Apps depuis la sauvegarde du zip gapps-remove (la plus recente de
# /sdcard/LibreHU/backup/gapps-<date>) : fichiers de /system tels qu'ils etaient, contextes SELinux, mises a jour dans
# /data/app. Les donnees des applis Google (comptes, reglages) ne sont pas dans la sauvegarde : se reconnecter.
# Les Google Apps ne sont pas fournies par ce zip : sans sauvegarde, flasher soi-meme OpenGApps (arm64, Android 9).

ui_print "UJC201 - remise des Google Apps (sauvegarde)"
ui_print "--------------------------------------------"
[ -d $SDCARD ] || abort "memoire interne non montee (/data dechiffre ?) : sauvegarde inaccessible"
BK=""
for d in $SDCARD/LibreHU/backup/gapps-*; do
	[ -f $d/system.tar ] && [ -f $d/files.txt ] && BK=$d
done
[ -n "$BK" ] || abort "aucune sauvegarde dans $SDCARD/LibreHU/backup/gapps-* (zip gapps-remove). Pour une installation neuve : OpenGApps arm64 Android 9 a flasher soi-meme."
ui_print "Sauvegarde : $BK"
mount_rw
S=$(sysdir)
[ -d $S/app ] || abort "dossier system introuvable ($S)"
DATA=${UJC_DATA:-/data}
require_no_verity system
# La sauvegarde doit se lire en entier avant d'ecrire quoi que ce soit
tar -tf $BK/system.tar > /dev/null 2>&1 || abort "sauvegarde illisible ($BK/system.tar), rien n'a ete modifie"
NEED=$(($(stat -c %s $BK/system.tar) / 1024))
FREE=$(df -k $S | tail -n1 | awk '{print $4}')
[ -n "$FREE" ] && [ "$FREE" -gt $((NEED + 20480)) ] || abort "place insuffisante dans /system ($((NEED / 1024)) Mo a remettre, $((${FREE:-0} / 1024)) Mo libres), rien n'a ete modifie"

(cd $S && tar -xpf $BK/system.tar) || abort "extraction de la sauvegarde impossible : reflasher ce zip"
[ -f $BK/contexts.txt ] && while read -r c f; do chcon -h $c $S/$f 2>/dev/null; done < $BK/contexts.txt
if [ -f $BK/data_app.tar ] && [ -d $DATA/app ]; then
	(cd $DATA/app && tar -xpf $BK/data_app.tar) || ui_print "mises a jour Google non remises ($BK/data_app.tar) : le Play Store les reprendra"
	for d in $(cat $BK/data_app.txt 2>/dev/null); do chcon -R u:object_r:apk_data_file:s0 $DATA/app/$d 2>/dev/null; done
fi
missing=0
while read -r f; do [ -e $S/$f ] || [ -L $S/$f ] || missing=$((missing + 1)); done < $BK/files.txt
[ $missing = 0 ] || abort "$missing elements absents apres la remise : ne pas redemarrer, reflasher ce zip"
sync
ui_print " "
ui_print "Google Apps remises. Redemarrer, puis se reconnecter au compte Google."
cleanup
exit 0
