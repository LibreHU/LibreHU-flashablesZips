# UJC201 - remet les Google Apps depuis la sauvegarde du zip gapps-remove (la plus recente de
# /sdcard/LibreHU/backup/gapps-<date>) : fichiers de /system tels qu'ils etaient, contextes SELinux, mises a jour dans
# /data/app. Les donnees des applis Google (comptes, reglages) ne sont pas dans la sauvegarde : se reconnecter.
# Les Google Apps ne sont pas fournies par ce zip : sans sauvegarde, flasher soi-meme OpenGApps (arm64, Android 9).

ui_print "UJC201 - Google Apps put back (backup)"
ui_print "--------------------------------------------"
[ -d $SDCARD ] || abort "internal storage not mounted (/data decrypted?): backup not reachable"
BK=""
for d in $SDCARD/LibreHU/backup/gapps-*; do
	[ -f $d/system.tar ] && [ -f $d/files.txt ] && BK=$d
done
[ -n "$BK" ] || abort "no backup in $SDCARD/LibreHU/backup/gapps-* (gapps-remove zip). For a fresh install: flash OpenGApps arm64 Android 9 yourself."
ui_print "Backup: $BK"
mount_rw
S=$(sysdir)
[ -d $S/app ] || abort "system folder not found ($S)"
DATA=${UJC_DATA:-/data}
require_no_verity system
# La sauvegarde doit se lire en entier avant d'ecrire quoi que ce soit
tar -tf $BK/system.tar > /dev/null 2>&1 || abort "unreadable backup ($BK/system.tar), nothing was changed"
NEED=$(($(stat -c %s $BK/system.tar) / 1024))
FREE=$(df -k $S | tail -n1 | awk '{print $4}')
[ -n "$FREE" ] && [ "$FREE" -gt $((NEED + 20480)) ] || abort "not enough space in /system ($((NEED / 1024)) MB to put back, $((${FREE:-0} / 1024)) MB free), nothing was changed"

(cd $S && tar -xpf $BK/system.tar) || abort "cannot extract the backup: flash this zip again"
[ -f $BK/contexts.txt ] && while read -r c f; do chcon -h $c $S/$f 2>/dev/null; done < $BK/contexts.txt
if [ -f $BK/data_app.tar ] && [ -d $DATA/app ]; then
	(cd $DATA/app && tar -xpf $BK/data_app.tar) || ui_print "Google updates not put back ($BK/data_app.tar): the Play Store will get them again"
	for d in $(cat $BK/data_app.txt 2>/dev/null); do chcon -R u:object_r:apk_data_file:s0 $DATA/app/$d 2>/dev/null; done
fi
missing=0
while read -r f; do [ -e $S/$f ] || [ -L $S/$f ] || missing=$((missing + 1)); done < $BK/files.txt
[ $missing = 0 ] || abort "$missing items missing after putting back: do not reboot, flash this zip again"
sync
ui_print " "
ui_print "Google Apps put back. Reboot, then sign in to the Google account again."
cleanup
exit 0
