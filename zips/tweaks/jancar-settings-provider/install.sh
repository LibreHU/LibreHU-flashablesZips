# UJC201 - fournisseur de reglages LibreHU a la place de celui de l'appli Reglages de Jancar (com.jancar.settings)
# La SystemUI d'origine (com.jancar.libsystemui, SettingModel) lit content://com.jancar.settings.provider/settings et
# s'y abonne : sans com.jancar.settings, l'abonnement leve une SecurityException et SystemUI plante en boucle.
# org.librehu.jacsettings (LibreHU-service, module jacsettings) fournit cette autorite, meme table, vide au depart.
# Tant que l'appli de Jancar est la, Android garde son fournisseur (le premier trouve) ; le notre prend le relais
# des qu'elle est retiree. Retour : zip jancar-settings-provider-restore.

ui_print "UJC201 - Jancar settings provider (LibreHU)"
ui_print "--------------------------------------------------"
TMPD=${UJC_TMP:-/tmp}/ujc201_jacsettings; rm -rf $TMPD; mkdir -p $TMPD
unzip -o -q "$ZIPFILE" 'files/*' -d $TMPD || abort "cannot extract the zip"
APK=$TMPD/files/LibreHUJacSettings.apk
[ -f $APK ] || abort "APK missing from the zip"
( cd $TMPD/files && sha256sum -c LibreHUJacSettings.apk.sha256 >/dev/null 2>&1 ) || abort "different APK checksum"
mount_rw
require_no_verity system
S=$(sysdir)
[ -d $S/app ] || abort "system/app folder not found ($S/app)"
DST=$S/app/LibreHUJacSettings
mkdir -p $DST || abort "cannot create folder $DST (system full?)"
cp $APK $DST/LibreHUJacSettings.apk || abort "cannot copy the APK (system full?)"
chmod 0755 $DST; chmod 0644 $DST/LibreHUJacSettings.apk; chown -R 0:0 $DST 2>/dev/null
[ -z "$UJC_TEST" ] && chcon -R u:object_r:system_file:s0 $DST
cmp -s $APK $DST/LibreHUJacSettings.apk || abort "check of the copy failed"
# Android garde en cache l'analyse des APK systeme : une ancienne version de celui-ci serait reprise.
rm -f ${UJC_DATA:-/data}/system/package_cache/*/LibreHUJacSettings* 2>/dev/null
rm -rf $TMPD
J=""
for d in $S/app $S/priv-app $VENMNT/app $VENMNT/priv-app; do
	for f in $d/*/*.apk; do
		[ -f "$f" ] && unzip -p "$f" AndroidManifest.xml 2>/dev/null | tr -d '\000' | grep -q 'com.jancar.settings' &&
			case "$f" in */LibreHUJacSettings/*) ;; *) J="$J ${f%/*}";; esac
	done
done
ui_print " "
ui_print "OK: $DST"
if [ -n "$J" ]; then
	ui_print "APK naming com.jancar.settings still present (the Jancar Settings app?):$J"
	ui_print "while it is there, its provider stays the Android one; ours takes over afterwards."
else
	ui_print "Jancar Settings app missing: our provider serves from the next boot on."
fi
ui_print "Reboot."
cleanup
exit 0
