# UJC201 - retire les Google Apps de la ROM (installees par OpenGApps, Android 9) : Play Services, Play Store, Services
# Framework, synchronisations Google, applis Google, et leurs mises a jour / donnees dans /data.
# La liste vient de l'installeur lui-meme : list_files() de /system/addon.d/70-gapps.sh (fichiers poses par OpenGApps),
# sinon une liste connue des dossiers Google. Une version Google qui remplace une appli AOSP retiree par OpenGApps
# (ExtServices, ExtShared, installateur de paquets, WebView, clavier) est gardee si l'appli AOSP manque : sans elle,
# Android ne fonctionne plus correctement.
# Tout est d'abord sauvegarde (tar + contextes SELinux) dans /sdcard/LibreHU/backup/gapps-<date> ; une erreur pendant
# la suppression remet la sauvegarde. Retour : zip gapps-restore.

ui_print "UJC201 - suppression des Google Apps"
ui_print "------------------------------------"
mount_rw
S=$(sysdir)
[ -d $S/app ] || abort "dossier system introuvable ($S)"
DATA=${UJC_DATA:-/data}

# --- Detection d'OpenGApps
ADDOND=$S/addon.d/70-gapps.sh
GPROP=$S/etc/g.prop
gprop() { grep "^$1=" $GPROP 2>/dev/null | head -n1 | cut -d= -f2-; }
if [ -f $GPROP ]; then
	ui_print "OpenGApps : $(gprop ro.addon.open_type) $(gprop ro.addon.open_version) (Android $(gprop ro.addon.sdk), $(gprop ro.addon.arch))"
else
	ui_print "Pas de /system/etc/g.prop : OpenGApps non detecte"
fi

# --- Ce qui sera retire (chemins relatifs au dossier system)
L=${UJC_TMP:-/tmp}/librehu_gapps.list; : > $L
if [ -f $ADDOND ]; then
	# list_files() { cat <<EOF ... EOF } : un fichier par ligne (suivi parfois de son remplacant)
	sed -n '/^list_files() {/,/^}/p' $ADDOND | sed -e '1,/cat <<EOF/d' -e '/^EOF/,$d' | while read -r f r; do
		[ -n "$f" ] && echo "$f" >> $L
	done
	ui_print "Liste de l'installeur (70-gapps.sh) : $(wc -l < $L) fichiers"
fi
# Dossiers Google connus (ROM sans 70-gapps.sh, ou fichiers qu'il ne liste pas)
KNOWN="GmsCore PrebuiltGmsCore PrebuiltGmsCorePi PrebuiltGmsCorePix GoogleServicesFramework Phonesky GoogleLoginService
GoogleBackupTransport GoogleOneTimeInitializer GooglePartnerSetup SetupWizard GoogleFeedback GoogleCalendarSyncAdapter
GoogleContactsSyncAdapter ConfigUpdater AndroidPlatformServices GoogleRestore Turbo Velvet GoogleTTS Maps YouTube
Gmail2 Photos Chrome Drive Music2 Duo Hangouts Keep Books Newsstand PlayGames Wellbeing GoogleDialer GoogleContacts
PrebuiltBugle CalendarGoogle PrebuiltDeskClockGoogle CalculatorGoogle GoogleCamera Wallpapers Talkback GoogleExtServices
GoogleExtShared GooglePackageInstaller WebViewGoogle WebViewStub TrichromeLibrary LatinImeGoogle GoogleSpeechServices"
for d in $KNOWN; do
	for p in app priv-app product/app product/priv-app; do [ -d $S/$p/$d ] && echo "$p/$d" >> $L; done
done
for f in etc/g.prop addon.d/70-gapps.sh framework/com.google.android.maps.jar framework/com.google.android.media.effects.jar \
	framework/com.google.widevine.software.drm.jar etc/permissions/com.google.android.maps.xml \
	etc/permissions/com.google.android.media.effects.xml etc/permissions/com.google.widevine.software.drm.xml \
	etc/permissions/privapp-permissions-google.xml etc/default-permissions/opengapps-permissions.xml \
	etc/preferred-apps/google.xml etc/sysconfig/google.xml etc/sysconfig/google_build.xml \
	etc/sysconfig/google_exclusives_enable.xml etc/sysconfig/google-hiddenapi-package-whitelist.xml; do
	[ -e $S/$f ] && echo "$f" >> $L
done

# Fichier d'une appli (app/X/...) -> son dossier entier (apk, oat, lib)
T=$L.dirs; : > $T
while read -r f; do
	case "$f" in
		app/*/*|priv-app/*/*) echo "$f" | cut -d/ -f1-2 >> $T;;
		product/app/*/*|product/priv-app/*/*) echo "$f" | cut -d/ -f1-3 >> $T;;
		*) echo "$f" >> $T;;
	esac
done < $L
sort -u $T > $L; rm -f $T

# --- Gardes : ce qu'un lien symbolique restant dans le systeme designe reste aussi (OpenGApps remplace des
# bibliotheques AOSP, ex. libjni_latinime.so du clavier, par des liens vers celles de Google)
# a/b/../c -> a/c
norm() { echo "$1" | awk -F/ '{n=0; for(i=1;i<=NF;i++){ if($i==""||$i==".") continue; if($i==".."){ if(n>0) n--; continue } a[++n]=$i } s=""; for(i=1;i<=n;i++) s=s (i>1?"/":"") a[i]; print s}'; }
LK=$L.links; : > $LK
for top in lib lib64 app priv-app framework vendor product; do
	[ -d $S/$top ] || continue
	find $S/$top -type l 2>/dev/null | while read -r l; do
		rel=${l#$S/}
		# Liens qui partent avec le reste : sans importance
		gone=0; while read -r f; do case "$rel" in "$f"|"$f"/*) gone=1; break;; esac; done < $L
		[ $gone = 1 ] && continue
		t=$(readlink "$l")
		case "$t" in
			/*) t=${t#$S/}; t=${t#/system/}; t=${t#/};;
			*) t=$(norm "${rel%/*}/$t");;
		esac
		echo "$t $rel" >> $LK
	done
done
if [ -s $LK ]; then
	: > $L.k
	while read -r f; do
		used=$(while read -r t rel; do case "$t" in "$f"|"$f"/*) echo "$rel"; break;; esac; done < $LK)
		if [ -n "$used" ]; then ui_print "Garde $f (lien depuis $used)"; else echo "$f" >> $L.k; fi
	done < $L
	mv $L.k $L
fi
rm -f $LK

# --- Gardes : la version Google reste si l'appli AOSP qu'elle remplace n'est plus la
aosp() { for p in app priv-app product/app product/priv-app; do for n in "$@"; do [ -d $S/$p/$n ] && return 0; done; done; return 1; }
KEEP=""
keep_if_no_aosp() {
	pat=$1; shift
	if ! aosp "$@" && grep -qiE "$pat" $L; then
		KEEP="$KEEP|$pat"
		ui_print "Garde (pas d'equivalent AOSP $*) : $(grep -iE "$pat" $L | tr '\n' ' ')"
	fi
}
keep_if_no_aosp 'ExtServices' ExtServices
keep_if_no_aosp 'ExtShared' ExtShared
keep_if_no_aosp 'PackageInstaller' PackageInstaller
keep_if_no_aosp 'WebView|Trichrome|libwebviewchromium' webview WebViewStock
keep_if_no_aosp 'LatinIme|Gboard|latinimegoogle|libjni_keyboard' LatinIME
if [ -n "$KEEP" ]; then
	grep -viE "${KEEP#|}" $L > $L.k; mv $L.k $L
fi
# Rien d'autre que ce qui existe
: > $L.e; while read -r f; do [ -e $S/$f ] || [ -L $S/$f ] && echo "$f" >> $L.e; done < $L; mv $L.e $L
N=$(wc -l < $L)
if [ "$N" -eq 0 ]; then
	ui_print "Aucune Google App dans /system : rien a faire."
	rm -f $L; cleanup; exit 0
fi
ui_print "A retirer de /system : $N elements"
require_no_verity system

# Paquets Google dont les mises a jour (/data/app) et les donnees partent aussi
PKGS="com.google.android.gms com.google.android.gsf com.android.vending com.google.android.gsf.login
com.google.android.backuptransport com.google.android.onetimeinitializer com.google.android.partnersetup
com.google.android.setupwizard com.google.android.feedback com.google.android.syncadapters.calendar
com.google.android.syncadapters.contacts com.google.android.configupdater com.google.android.gms.policy_sidecar_aps
com.google.android.apps.restore com.google.android.apps.turbo com.google.android.googlequicksearchbox
com.google.android.tts com.google.android.apps.maps com.google.android.youtube com.google.android.gm
com.google.android.apps.photos com.android.chrome com.google.android.apps.docs com.google.android.music
com.google.android.apps.tachyon com.google.android.talk com.google.android.keep com.google.android.apps.books
com.google.android.apps.magazines com.google.android.play.games com.google.android.apps.wellbeing
com.google.android.dialer com.google.android.contacts com.google.android.apps.messaging com.google.android.calendar
com.google.android.deskclock com.google.android.calculator com.google.android.GoogleCamera
com.google.android.apps.wallpaper com.google.android.marvin.talkback"
echo "$KEEP" | grep -qi webview || PKGS="$PKGS com.google.android.webview com.google.android.trichromelibrary"
echo "$KEEP" | grep -qi latinime || PKGS="$PKGS com.google.android.inputmethod.latin"
DAPPS=""; DDATA=""
for p in $PKGS; do
	for d in $DATA/app/$p-*; do [ -d "$d" ] && DAPPS="$DAPPS ${d##*/}"; done
	for d in $DATA/data/$p $DATA/user_de/0/$p; do [ -d "$d" ] && DDATA="$DDATA $d"; done
done

# --- Sauvegarde (avant toute modification)
[ -d $SDCARD ] || abort "memoire interne non montee (/data dechiffre ?) : pas de sauvegarde possible, rien n'a ete modifie"
NEED=$(cd $S && du -sk $(cat $L) 2>/dev/null | awk '{s+=$1} END {print s+0}')
for d in $DAPPS; do NEED=$((NEED + $(du -sk $DATA/app/$d | cut -f1))); done
FREE=$(df -k $SDCARD | tail -n1 | awk '{print $4}')
[ -n "$FREE" ] && [ "$FREE" -gt $((NEED + NEED / 5 + 51200)) ] || abort "place insuffisante pour la sauvegarde ($((NEED / 1024)) Mo a sauvegarder, $((${FREE:-0} / 1024)) Mo libres), rien n'a ete modifie"
BK=$SDCARD/LibreHU/backup/gapps-$(date +%Y%m%d-%H%M%S)
mkdir -p $BK || abort "dossier $BK impossible"
(cd $S && tar -cf $BK/system.tar $(cat $L)) || abort "sauvegarde (tar) impossible, rien n'a ete modifie"
: > $BK/contexts.txt
(cd $S && find $(cat $L) 2>/dev/null) | while read -r f; do
	c=$(ls -Zd $S/$f 2>/dev/null | tr ' ' '\n' | grep '^u:object_r:' | head -n1)
	[ -n "$c" ] && echo "$c $f" >> $BK/contexts.txt
done
if [ -n "$DAPPS" ]; then
	(cd $DATA/app && tar -cf $BK/data_app.tar $DAPPS) || abort "sauvegarde des mises a jour Google ($DATA/app) impossible, rien n'a ete modifie"
fi
cp $L $BK/files.txt
[ -f $GPROP ] && cp $GPROP $BK/g.prop
echo "$DAPPS" > $BK/data_app.txt
ui_print "Sauvegarde : $BK ($((NEED / 1024)) Mo)"

# --- Retour a la sauvegarde si une etape echoue
rollback() {
	ui_print "ERREUR : $1 ; remise de la sauvegarde"
	(cd $S && tar -xpf $BK/system.tar) || ui_print "remise impossible : flasher le zip gapps-restore"
	while read -r c f; do chcon -h $c $S/$f 2>/dev/null; done < $BK/contexts.txt
	abort "Google Apps laissees en place"
}

# --- Suppression
while read -r f; do
	chattr -i $S/$f 2>/dev/null
	rm -rf $S/$f || rollback "$f"
	[ -e $S/$f ] && rollback "$f encore present"
done < $L
for d in $DAPPS; do rm -rf $DATA/app/$d; done
for d in $DDATA; do rm -rf $d; done
# Code compile des dossiers retires (dalvik-cache : system@priv-app@<Dossier>@...)
for f in $(cat $L); do
	b=${f##*/}
	case "$f" in *app/*) rm -f $DATA/dalvik-cache/*/*@$b@* 2>/dev/null;; esac
done
sync
ui_print " "
ui_print "Google Apps retirees ($N elements de /system, $(echo $DAPPS | wc -w) mises a jour)."
ui_print "Redemarrer (le premier demarrage est plus long)."
ui_print "Sans services Google : pas de Play Store ni de Google Maps ;"
ui_print "applis : LibreHU Apps, F-Droid, Aurora Store."
ui_print "Retour : zip gapps-restore (sauvegarde $BK)."
rm -f $L
cleanup
exit 0
