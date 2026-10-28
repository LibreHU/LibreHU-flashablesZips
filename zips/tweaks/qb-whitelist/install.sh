# UJC201 - applis LibreHU dans la liste blanche de QuickBoot (/vendor/etc/qb_list.xml)
# Sur cette ROM chaque extinction de l'ecran est un "QuickBoot power off" : QuickBootManager
# (com.autochips.quickbootmanager) arrete de force (forceStopPackage) toute appli absente de sa liste blanche,
# le service LibreHU compris : plus d'alarme, plus de reponse au MCU au reveil. La liste est lue une fois, au demarrage
# de QuickBootManager (Utils.readList : elements <app_whitelist name="paquet"/>, a n'importe quel niveau du XML).
# Le fichier d'origine est garde a cote (qb_list.xml.librehu-orig) et copie dans /sdcard/LibreHU/backup.
# Retour : zip qb-whitelist-restore.

ui_print "UJC201 - liste blanche QuickBoot (applis LibreHU)"
ui_print "--------------------------------------------------"
mount_rw
F=$VENMNT/etc/qb_list.xml
ORIG=$F.librehu-orig
PKGS="org.librehu.service org.librehu.launcher org.librehu.dialer org.librehu.fm org.librehu.btnremap org.librehu.widgets
org.librehu.easysource org.librehu.headunit org.librehu.carplay org.librehu.disc org.librehu.ota org.librehu.helper
com.llsl.viper4android"
[ -d $VENMNT/etc ] || abort "dossier vendor introuvable ($VENMNT/etc)"

has() { grep -qE "<app_whitelist[^>]*name=\"$(echo $1 | sed 's/\./\\./g')\"" "$2"; }
SRC=$F; [ -f $ORIG ] && SRC=$ORIG
MISSING=""
if [ -f $F ]; then
	for p in $PKGS; do has $p $F || MISSING="$MISSING $p"; done
	if [ -z "$MISSING" ]; then
		ui_print "Toutes les applis LibreHU sont deja dans la liste : rien a faire."
		cleanup; exit 0
	fi
	ui_print "A ajouter :$MISSING"
else
	ui_print "$F absent : il sera cree"
	MISSING=$PKGS
fi
require_no_verity vendor

TMP=${UJC_TMP:-/tmp}/ujc201_qb_list.xml
if [ -f $F ]; then
	# Les lignes ajoutees vont avant la derniere balise fermante (celle de l'element racine).
	LAST=$(grep -n '</[A-Za-z_][A-Za-z0-9_.:-]*>' $F | tail -n1 | cut -d: -f1)
	[ -n "$LAST" ] || abort "pas de balise fermante dans $F : format inattendu, rien n'a ete change"
	ADD=""
	for p in $MISSING; do ADD="$ADD    <app_whitelist name=\"$p\"/><!-- LibreHU -->\n"; done
	# Balise seule sur sa ligne : lignes inserees avant ; sinon la ligne est coupee juste avant la balise.
	awk -v n=$LAST -v add="$ADD" '
		NR == n { i = 0; for (j = 1; j <= length($0) - 1; j++) if (substr($0, j, 2) == "</") i = j
			pre = substr($0, 1, i - 1)
			if (pre ~ /^[ \t]*$/) { printf "%s", add; print } else { print pre; printf "%s", add; print substr($0, i) }
			next }
		{ print }' $F > $TMP || abort "awk"
else
	{
		echo '<?xml version="1.0" encoding="utf-8"?>'
		echo '<!-- LibreHU : liste blanche de QuickBootManager (applis non arretees a l extinction de l ecran) -->'
		echo '<qb_list>'
		for p in $MISSING; do echo "    <app_whitelist name=\"$p\"/><!-- LibreHU -->"; done
		echo '</qb_list>'
	} > $TMP || abort "ecriture de $TMP impossible"
fi
for p in $PKGS; do has $p $TMP || abort "$p absent du fichier modifie : rien n'a ete change"; done
if [ -f $F ]; then
	# Rien d'autre ne change : le fichier modifie moins les lignes LibreHU = l'original (aux coupures de ligne pres)
	grep -v '<!-- LibreHU -->' $TMP | tr -d ' \t\n' > $TMP.a
	tr -d ' \t\n' < $F > $TMP.b
	cmp -s $TMP.a $TMP.b || abort "le fichier modifie differe de l'original hors lignes LibreHU : rien n'a ete change"
	rm -f $TMP.a $TMP.b
fi

if [ -d $SDCARD ]; then
	BK=$SDCARD/LibreHU/backup/qb_list-$(date +%Y%m%d-%H%M%S)
	mkdir -p $BK && { [ -f $F ] && cp -p $F $BK/qb_list.xml || echo absent > $BK/absent; } && ui_print "Copie : $BK"
fi
if [ -f $F ]; then
	if [ ! -f $ORIG ]; then
		cp -p $F $ORIG || abort "sauvegarde $ORIG impossible"
		ui_print "Sauvegarde : $ORIG"
	fi
	# reecriture sur place : garde l'inode, les droits et le contexte SELinux
	cat $TMP > $F || abort "ecriture de $F impossible (restaurer $ORIG)"
else
	: > $F.librehu-created
	cat $TMP > $F || abort "ecriture de $F impossible"
	chmod 644 $F; chown 0:0 $F 2>/dev/null
	chcon u:object_r:vendor_configs_file:s0 $F 2>/dev/null
fi
cmp -s $TMP $F || abort "verification de $F echouee"
rm -f $TMP
ui_print " "
ui_print "OK : applis LibreHU et ViPER4Android dans la liste blanche."
ui_print "Redemarrer (la liste est lue une fois, au demarrage)."
ui_print "Retour arriere : zip qb-whitelist-restore"
cleanup
exit 0
