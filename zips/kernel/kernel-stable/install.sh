# UJC201 - noyau LibreHU linux-stable + ses modules Wi-Fi / BT / GPS / FM (zip TWRP, sans KernelSU)
# Tout est verifie avant d'ecrire : empreintes, noyau de l'image = celui des modules, dm-verity coupe sur /vendor,
# memoire interne montee (sauvegardes). Puis boot (sauvegarde boot-<date>.img), puis les modules (common/conn-modules.sh).

ui_print "UJC201 - noyau linux-stable + modules Wi-Fi / BT / GPS / FM"
ui_print "version $VERSION"
ui_print "-----------------------------------------------------------"
conn_extract
[ "$(sha256sum $F/boot.img | cut -d' ' -f1)" = "$(cut -d' ' -f1 $F/boot.img.sha256)" ] || abort "image de boot abimee (empreinte)"
grep -q "^$(kernel_sum $F/boot.img) " $F/kernels.sha256 || abort "le noyau de l'image n'est pas celui des modules"
mount_rw
require_no_verity vendor
[ -d $SDCARD ] || abort "memoire interne non montee : sauvegardes impossibles, rien n'a ete modifie"

flash_image boot.img boot
conn_check_boot
conn_install

ui_print " "
ui_print "Termine. Redemarrer (menu de demarrage TWRP / Android / Fastboot, Android au bout de 3 s)."
ui_print "Retour arriere : boot-<date>.img ci-dessus (TWRP : Install, Install Image, Boot)"
ui_print "et zip conn-modules-stable-restore pour les modules d'origine."
cleanup
exit 0
