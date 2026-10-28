# LibreHU flashable zips

Zips flashables (TWRP) pour les autoradios Jancar / Autochips AC8257 (UJC201), classés par **catégories**, construits
par la CI et publiés dans la release [`zips`](../../releases/tag/zips) avec un **`index.json`** que lit
[LibreHU Apps (OTA)](https://github.com/LibreHU/LibreHU-OTA-app) (onglet **Zips** : filtre par catégorie, flash par
TWRP, ou écriture directe d'une image en root).

## Catégories et zips

| Catégorie | Zip | Rôle |
|---|---|---|
| `recovery` | `twrp-ujc201` | **dernière release TWRP** (hors pré-releases : les builds de test de la CI) UJC201 du dépôt [android_device_alps_ac8257_demo](https://github.com/LibreHU/android_device_alps_ac8257_demo/releases) (reprise toutes les heures par la CI), vérifiée puis écrite dans la partition recovery, l'actuelle sauvegardée dans `/sdcard/LibreHU/backup` ; l'image seule est publiée aussi (`twrp-ujc201.img`) |
| `recovery` | `twrp-ujc201-beta` | **TWRP bêta** : la dernière build de test de la CI (pré-releases comprises) — touches au volant dans tout TWRP (keynav), boîtiers CAN Hiworld (Clio 3…) en plus du volant câblé, version affichée au démarrage ; même vérification, sauvegarde et relecture que le zip stable. Version `b<build>` |
| `drivers` | `viper4android-re` / `-restore` | pilote **ViPER4Android RE** (`libv4a_re.so` du module officiel [ViPERFX_RE](https://github.com/likelikeslike/ViPERFX_RE) v2.1.1, empreinte vérifiée) dans `/vendor/lib[64]/soundfx` + déclaration dans `audio_effects.xml`, sans Magisk ; et son retrait |
| `tweaks` | `no-deep-buffer` / `-restore` | sortie audio `deep_buffer` retirée de la politique audio (musique muette, sonneries OK) ; et sa remise |
| `tweaks` | `supersu-remove` / `supersu-restore` | **suppression de SuperSU** (mode système, installé dans la ROM) pour passer au root **KernelSU Next** du noyau LibreHU : défait ce que fait l'installeur de SuperSU (`su`, `daemonsu`, `supolicy`, `libsupol.so`, `bin/.ext/.su`, appli, `install-recovery.sh` et son `_original`, `99SuperSUDaemon`, `app_process32/64_original` remis à la place des liens vers `daemonsu`, `app_process` → `app_process64`) ; tout est sauvegardé d'abord (tar + contextes SELinux) dans `/sdcard/LibreHU/backup/supersu-<date>`, une erreur remet la sauvegarde ; s'arrête si le noyau de boot n'a pas KernelSU. **Installer SuperSU** = remise depuis cette sauvegarde (SuperSU, propriétaire, n'est pas redistribué ici) |
| `tweaks` | `gapps-remove` / `gapps-restore` | **suppression des Google Apps** de la ROM (OpenGApps, Android 9 ; détecté par `/system/etc/g.prop`) : la liste vient de l'installeur OpenGApps lui-même (`list_files()` de `/system/addon.d/70-gapps.sh`), plus une liste connue des dossiers Google ; mises à jour (`/data/app`), données et code compilé des paquets Google retirés aussi. **Gardés** : les versions Google qui remplacent une appli AOSP qu'OpenGApps a retirée (ExtServices, ExtShared, installateur de paquets, WebView, clavier) quand l'équivalent AOSP manque, et tout ce que désigne un lien symbolique qui reste (OpenGApps remplace par exemple `libjni_latinime.so` par un lien vers la bibliothèque du clavier Google). Tout est sauvegardé d'abord (tar + contextes SELinux, place libre vérifiée) dans `/sdcard/LibreHU/backup/gapps-<date>`, une erreur remet la sauvegarde ; `gapps-restore` remet cette sauvegarde (les Google Apps ne sont pas redistribuées ici). Sans services Google : ni Play Store, ni Google Maps, ni localisation par réseau (le GPS marche) |
| `updates` | — | à venir |
| `kernel` | `kernel-librehu` / `kernel-librehu-bootmenu` | **noyau LibreHU** (branche `LibreHU-main` du [dépôt du noyau](https://github.com/LibreHU/android_kernel_autochips_ac8257_4.9)) : image `boot_ac8257.img` de sa release `latest-LibreHU-main` (refaite par sa CI à chaque build, version `r<build>-<commit>`), seule ou avec le **menu de démarrage** TWRP / Android / Fastboot (`boot_ac8257_bootmenu.img`) ; vérifiée (empreinte, en-tête `ANDROID!`, pied AVB, 10 Mio au plus), écrite dans la partition **boot**, l'actuelle sauvegardée dans `/sdcard/LibreHU/backup` ; vbmeta n'est pas touché ; l'image seule est publiée aussi (`<id>.img`) |
| `kernel` | `kernel-connectivity` / `kernel-connectivity-bootmenu` | même chose pour la branche **`connectivity-builtin`** (Wi-Fi, Bluetooth, GPS, FM intégrés au noyau), release `latest-connectivity-builtin` : **expérimental**, pas encore testée sur l'unité |
| `kernel` | `kernel-stable-4.9.<N>` / `conn-modules-stable-4.9.<N>` / `conn-modules-stable-restore` | pour chaque branche **linux-stable** du noyau (`stable-4.9.150`, `-200`, `-225`, `-250`, `-300`, `-319`, `-337` ; `docs/STABLE.md` du dépôt du noyau), deux zips construits depuis la release `latest-stable-4.9.<N>` : **`kernel-stable-4.9.<N>`** = noyau (`boot_ac8257_bootmenu.img`, menu de démarrage TWRP / Android / Fastboot) **+ ses modules** Wi-Fi / Bluetooth / GPS / FM ; **`conn-modules-stable-4.9.<N>`** = **modules seuls**, pour ce noyau déjà flashé (vérifie que la section noyau de la partition boot est celle de `boot_ac8257.img` ou `_bootmenu.img` de la release). Les modules (contenu du module KernelSU `librehu_connectivity_ksu.zip`) remplacent ceux de `/vendor/lib/modules`, refusés par ces noyaux (CRC des symboles différents). Tout est vérifié avant d'écrire (empreintes, noyau de l'image = celui des modules, dm-verity coupé sur `/vendor`, mémoire interne montée) ; sauvegardes dans `/sdcard/LibreHU/backup` : `boot-<date>.img`, modules d'origine une fois dans `conn-modules-orig` (jamais écrasés), état d'avant chaque passage dans `conn-modules-<date>` ; `conn-modules-stable-restore` (visible dans l'OTA : « Modules … d'origine, retour au noyau 4.9.117 GPL ou stock ») remet les modules d'origine depuis cette sauvegarde faite sur l'autoradio (empreintes vérifiées, droits et contexte SELinux d'origine ; les fichiers stock ne sont pas publiés ; ne fait rien si les modules n'ont jamais été remplacés), à flasher avant de revenir à `LibreHU-main` (zip `kernel-librehu`) ou au stock (sauvegarde `boot-<date>.img`). **`conn-modules-stock-4.9.117`** : les six modules stock eux-mêmes (`/vendor/lib/modules` d'origine de l'UJC201, licences GPL / Dual BSD-GPL, publiés avec l'accord du propriétaire de l'unité), pour revenir au noyau 4.9.117 même sans sauvegarde sur l'autoradio ; modules actuels sauvegardés d'abord (`conn-modules-<date>`), avertit si le noyau de boot n'est pas un 4.9.117. Un seul modèle par type (`zips/kernel/kernel-stable`, `zips/kernel/conn-modules-stable`, champ `variants` de `zip.json`), fonctions communes dans `common/conn-modules.sh` ; **expérimental** (lot 1 validé, lot 2 démarre, lots 3 à 7 pas encore testés sur l'unité) |
| `kernel` | `usb-net` / `-restore` | pilotes **réseau USB** absents du noyau stock (4.9.117+, Jancar #25 et #72) : adaptateurs Ethernet **Realtek RTL8152 / RTL8153**, **partage de connexion USB** d'un téléphone Android (RNDIS) et d'un iPhone (expérimental), LAN78xx, LAN95xx / 75xx, DM9601, SR9700 / SR9800, MCS7830, CH9200, RTL8150, Pegasus, CDC EEM ; modules dans `/vendor/lib/modules/librehu-usbnet`, chargés une fois Android démarré avec protection contre les redémarrages (source et vérification des CRC : `tools/ac8257/usbnet` du dépôt du noyau) ; et leur retrait |

Les zips qui modifient `/vendor` ou `/system` s'arrêtent **sans rien modifier** si la partition est protégée par
dm-verity (l'autoradio ne démarrerait plus) : la désactiver d'abord (`fastboot --disable-verity flash vbmeta vbmeta.img`).
Chaque zip vérifie l'appareil (`ro.product.device` = `ac8257_demo`).

## Ajouter un zip
Un dossier `zips/<catégorie>/<id>/` :
- `zip.json` : `id`, `name`, `category` (une de [categories.json](categories.json)), `description`, et selon le cas
  `warning`, `devices` (valeurs de `ro.product.device`), `restore` (id du zip qui annule), `hidden` (zip de
  restauration, montré seulement depuis l'autre), `version` (ou écrite par `prepare.sh`), `image` + `partition`
  (image aussi publiée seule, que l'appli peut écrire directement), `upstream`, `license`, `include` (fichiers de
  `common/` ajoutés à `update-binary`, ex. `common/conn-modules.sh`), `variants` (un zip par entrée : `{clé}` remplacé
  dans les textes de `zip.json`, entrée passée à `prepare.sh` en `ZIP_<CLÉ>`) ;
  pour le tri dans LibreHU Apps : `subcategory` (une des `subcategories` de sa catégorie dans `categories.json`,
  affichées dans cet ordre), `group` (zips montrés sur une seule carte, avec `group_name` / `group_description` ; chaque
  zip y est une `variant`, ex. sans / avec menu de démarrage), `order` (nombre, le plus petit d'abord), `screenshots`
  (images PNG / JPEG, chemin relatif au zip ou au dépôt, ex. `common/screenshots/bootmenu.png`, publiées à côté des zips
  sous `shot-<nom>`) ;
- `install.sh` : corps de `update-binary`, après [common/twrp-common.sh](common/twrp-common.sh) (`ui_print`, `abort`,
  `mount_rw`, `require_no_verity`, `flash_image <image> <partition>`, `$SDCARD`…) et la vérification de l'appareil ; variables `$ZIPFILE`, `$VERSION` ;
- facultatif : `files/` (mis dans le zip sous `files/`) et `prepare.sh <dossier>` (remplit `<dossier>/files` et
  `<dossier>/version` avant l'empaquetage : téléchargement d'une release, avec vérification d'empreinte). Les zips de noyau appellent
  `tools/kernel_prepare.sh <dossier> <branche> <image>`, ceux des modules `tools/conn_prepare.sh <dossier> <branche>`.

`python3 tools/build.py` construit tout dans `dist/` (zips, images, `index.json`) ; la CI le fait à chaque push et
toutes les heures (nouvelle release TWRP ou nouveau noyau repris ainsi ; rien n'est republié si aucun zip n'a changé), puis publie la release `zips` (les fichiers qui ne sont plus construits sont retirés).

## index.json
```json
{"generated": 0, "repo": "LibreHU/LibreHU-flashablesZips",
 "categories": [{"id": "recovery", "name": "Recovery", "name_fr": "Recovery", "description_fr": "..."}],
 "zips": [{"id": "twrp-ujc201", "name": "...", "category": "recovery", "description": "...", "warning": "...",
           "devices": ["ac8257_demo"], "version": "v8", "url": "https://.../twrp-ujc201.zip", "size": 0, "sha256": "...",
           "image_url": "https://.../twrp-ujc201.img", "image_size": 0, "image_sha256": "...", "partition": "recovery",
           "restore": "...", "hidden": false, "upstream": "...", "license": "..."}]}
```

## Origine
Les scripts audio viennent de `tools/ac8257/audio/twrp/` du dépôt du noyau [android_kernel_autochips_ac8257_4.9](https://github.com/LibreHU/android_kernel_autochips_ac8257_4.9/tree/reverse-engineering/tools/ac8257/audio), qui reste la référence pour leur analyse
([docs/ujc201/audio_deep_buffer.md](https://github.com/LibreHU/android_kernel_autochips_ac8257_4.9/blob/reverse-engineering/docs/ujc201/audio_deep_buffer.md)).
Licences : celles des projets d'origine (TWRP GPL-3.0, ViPERFX_RE GPL-2.0, fichier `LICENSE` inclus dans le zip du
pilote) ; scripts LibreHU sous la même licence que le dépôt de l'appareil.

## Soutenir le projet

LibreHU est développé bénévolement, sur le temps libre, et toutes ses applis restent gratuites. Si le projet vous est
utile, vous pouvez le soutenir par un don sur [Liberapay](https://liberapay.com/DokT/donate) (association française à
but non lucratif, dons récurrents) :

[![Faire un don avec Liberapay](https://liberapay.com/assets/widgets/donate.svg)](https://liberapay.com/DokT/donate)
[![Donateurs sur Liberapay](https://img.shields.io/liberapay/patrons/DokT.svg?logo=liberapay)](https://liberapay.com/DokT/)
