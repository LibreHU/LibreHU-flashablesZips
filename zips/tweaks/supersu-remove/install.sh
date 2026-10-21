# UJC201 - retire SuperSU (mode systeme, installe dans la ROM) : le root passe alors par KernelSU Next (noyau LibreHU).
# Defait ce que fait l'installeur de SuperSU (update-binary, mode systeme) : su, daemonsu, supolicy, libsupol.so,
# bin/.ext/.su, appli SuperSU, install-recovery.sh (l'original "_original" remis), 99SuperSUDaemon, et app_process
# (lien vers daemonsu) : app_process32 / 64 d'origine ("_original") remis, app_process relie a app_process64.
# Tout est d'abord sauvegarde (tar + contextes SELinux) dans /sdcard/LibreHU/backup/supersu-<date> ; une erreur pendant
# la suppression remet la sauvegarde. Retour : zip supersu-restore.

ui_print "UJC201 - suppression de SuperSU"
ui_print "-------------------------------"
mount_rw
S=$(sysdir)
[ -d $S/bin ] || abort "dossier system introuvable ($S)"
DATAAPP=${UJC_DATAAPP:-/data/app}

# Fichiers que l'installeur de SuperSU cree, deplace ou remplace (relatifs au dossier system)
SU_FILES="xbin/su xbin/daemonsu xbin/sugote xbin/sugote-mksh xbin/supolicy bin/.ext/.su lib/libsupol.so lib64/libsupol.so
etc/init.d/99SuperSUDaemon etc/.installed_su_daemon bin/app_process_init
etc/install-recovery.sh etc/install-recovery_original.sh bin/install-recovery.sh bin/install-recovery_original.sh
bin/app_process bin/app_process32 bin/app_process64 bin/app_process32_original bin/app_process64_original
app/SuperSU app/SuperSU.apk priv-app/SuperSU bin/su"

present=""
for f in xbin/daemonsu app/SuperSU priv-app/SuperSU bin/app_process64_original bin/app_process32_original; do
	[ -e $S/$f ] && present="$present $f"
done
if [ -z "$present" ]; then
	ui_print "SuperSU absent de /system : rien a faire."
	cleanup; exit 0
fi
ui_print "SuperSU trouve :$present"
require_no_verity system

# Le root doit rester possible : le noyau de la partition boot doit contenir KernelSU (noyau LibreHU).
# Image de boot : taille du noyau a l'octet 8, taille de page a l'octet 36 ; noyau gzip (+ DTB a la suite).
le32() { dd if="$1" bs=1 skip=$2 count=4 2>/dev/null | od -An -tu4 | tr -d ' '; }
BOOT=""
for p in /dev/block/by-name/boot $BYNAME/boot; do [ -e $p ] && { BOOT=$p; break; }; done
if [ -n "$UJC_BOOTIMG" ]; then BOOT=$UJC_BOOTIMG; fi
KSU=unknown
if [ -n "$BOOT" ] && [ "$(dd if=$BOOT bs=8 count=1 2>/dev/null)" = "ANDROID!" ]; then
	KS=$(le32 $BOOT 8); PS=$(le32 $BOOT 36)
	if [ -n "$KS" ] && [ -n "$PS" ] && [ "$PS" -gt 0 ]; then
		KI=${UJC_TMP:-/tmp}/librehu_kernel; rm -f $KI
		dd if=$BOOT bs=$PS skip=1 2>/dev/null | head -c $KS | gzip -dc > $KI 2>/dev/null
		# Noyau decompresse (plus de 4 Mo) : sinon gzip a echoue, rien n'est conclu
		if [ "$(stat -c %s $KI 2>/dev/null || echo 0)" -gt 4000000 ]; then
			if grep -q KernelSU $KI 2>/dev/null || [ "$(tr -c '[:print:]' '\n' < $KI | grep -c KernelSU)" -gt 0 ]; then
				KSU=yes
			else
				KSU=no
			fi
		fi
		rm -f $KI
	fi
fi
case $KSU in
	yes) ui_print "Noyau de boot avec KernelSU : OK";;
	no) abort "le noyau de la partition boot n'a pas KernelSU : sans SuperSU il n'y aurait plus de root. Flasher d'abord un noyau LibreHU (zips Noyau). Rien n'a ete modifie.";;
	*) ui_print "Noyau de boot non verifiable : verifier soi-meme qu'il a KernelSU (noyau LibreHU)";;
esac

# --- Sauvegarde
[ -d $SDCARD ] || abort "memoire interne non montee (/data dechiffre ?) : pas de sauvegarde possible, rien n'a ete modifie"
BK=$SDCARD/LibreHU/backup/supersu-$(date +%Y%m%d-%H%M%S)
mkdir -p $BK || abort "dossier $BK impossible"
LIST=""
for f in $SU_FILES; do [ -e $S/$f ] || [ -L $S/$f ] && LIST="$LIST $f"; done
(cd $S && tar -cf $BK/system.tar $LIST) || abort "sauvegarde (tar) impossible, rien n'a ete modifie"
# Contextes SELinux : champ u:object_r:... de ls -Z (toybox ou busybox)
: > $BK/contexts.txt
for f in $LIST; do
	c=$(ls -Zd $S/$f 2>/dev/null | tr ' ' '\n' | grep '^u:object_r:' | head -n1)
	[ -n "$c" ] && echo "$c $f" >> $BK/contexts.txt
done
DAPPS=""
for d in $DATAAPP/eu.chainfire.supersu*; do [ -d "$d" ] && DAPPS="$DAPPS ${d##*/}"; done
if [ -n "$DAPPS" ]; then
	(cd $DATAAPP && tar -cf $BK/data_app.tar $DAPPS) || abort "sauvegarde de la mise a jour de SuperSU ($DATAAPP) impossible, rien n'a ete modifie"
fi
echo "$LIST" > $BK/files.txt
ui_print "Sauvegarde : $BK"

# --- Retour a la sauvegarde si une etape echoue
rollback() {
	ui_print "ERREUR : $1 ; remise de la sauvegarde"
	for f in $LIST; do [ -d $S/$f ] && [ ! -L $S/$f ] && rm -rf $S/$f || rm -f $S/$f; done
	(cd $S && tar -xpf $BK/system.tar) || ui_print "remise impossible : flasher le zip supersu-restore"
	while read -r c f; do chcon -h $c $S/$f 2>/dev/null; done < $BK/contexts.txt
	abort "SuperSU laisse en place"
}
is_elf() { [ -f "$1" ] && [ ! -L "$1" ] && [ "$(head -c 4 "$1" | tail -c 3)" = ELF ]; }

for f in $LIST; do chattr -i $S/$f 2>/dev/null; done

# --- app_process : les originaux reviennent
for a in 32 64; do
	if [ -e $S/bin/app_process${a}_original ]; then
		is_elf $S/bin/app_process${a}_original || rollback "app_process${a}_original n'est pas un executable"
		rm -f $S/bin/app_process$a && mv $S/bin/app_process${a}_original $S/bin/app_process$a || rollback "app_process$a"
	fi
done
Z=app_process64; [ -e $S/bin/app_process64 ] || Z=app_process32
if [ -L $S/bin/app_process ] || [ ! -e $S/bin/app_process ]; then
	case "$(readlink $S/bin/app_process)" in
		*daemonsu*|"") rm -f $S/bin/app_process; ln -s $Z $S/bin/app_process || rollback "lien app_process";;
	esac
fi
for a in 32 64; do
	[ -e $S/bin/app_process$a ] || [ -L $S/bin/app_process$a ] || continue
	is_elf $S/bin/app_process$a || rollback "app_process$a n'est pas l'executable d'origine (encore un lien vers daemonsu ?)"
	chcon u:object_r:zygote_exec:s0 $S/bin/app_process$a 2>/dev/null
done
is_elf $S/bin/$Z || rollback "$Z absent"
chcon -h u:object_r:zygote_exec:s0 $S/bin/app_process 2>/dev/null
rm -f $S/bin/app_process_init

# --- install-recovery.sh : l'original revient, sinon celui de SuperSU est retire
for d in etc bin; do
	if [ -e $S/$d/install-recovery_original.sh ] || [ -L $S/$d/install-recovery_original.sh ]; then
		rm -f $S/$d/install-recovery.sh && mv $S/$d/install-recovery_original.sh $S/$d/install-recovery.sh || rollback "install-recovery.sh ($d)"
	elif [ -L $S/$d/install-recovery.sh ] || grep -q daemonsu $S/$d/install-recovery.sh 2>/dev/null; then
		rm -f $S/$d/install-recovery.sh
	fi
done

# --- Le reste
[ -f $S/bin/su ] && [ -f $S/xbin/su ] && cmp -s $S/bin/su $S/xbin/su && rm -f $S/bin/su
for f in xbin/su xbin/daemonsu xbin/sugote xbin/sugote-mksh xbin/supolicy bin/.ext/.su lib/libsupol.so lib64/libsupol.so \
	etc/init.d/99SuperSUDaemon etc/.installed_su_daemon app/SuperSU.apk; do
	rm -f $S/$f
done
rmdir $S/bin/.ext 2>/dev/null
rm -rf $S/app/SuperSU $S/priv-app/SuperSU
for d in $DAPPS; do rm -rf $DATAAPP/$d; done
[ -e $S/xbin/daemonsu ] && rollback "daemonsu encore present"
sync
ui_print " "
ui_print "SuperSU retire. Redemarrer : le root passe par KernelSU Next"
ui_print "(appli KernelSU Next, liste Superuser : y autoriser les applis LibreHU)."
ui_print "Retour : zip supersu-restore (sauvegarde $BK)."
cleanup
exit 0
