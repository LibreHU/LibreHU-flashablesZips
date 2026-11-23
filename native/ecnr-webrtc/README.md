# WebRTC ECNR (`libEcnrForCustomer.so`)

Annulation d'écho et réduction de bruit des **appels Bluetooth** de l'UJC201 (Autochips AC8257), avec
[WebRTC audio processing](https://gitlab.freedesktop.org/pulseaudio/webrtc-audio-processing) (version 2.1, celle de
PulseAudio / PipeWire) : annulation d'écho **AEC3** (ou AECM, plus légère), **réduction de bruit**, **gain automatique**
(AGC2, numérique), filtre passe-haut. Remplace la bibliothèque ECNR tierce de Jancar (uVoice, licence activée en ligne
par l'appli JanEcnr) que la ROM LineageOS LibreHU retire.

## Comment le HAL audio l'appelle

Le son d'un appel Bluetooth ne passe pas par Android (AudioFlinger) : le Bluetooth envoie `hfp_enable=true` au HAL
audio, qui fait lui-même la boucle micro → téléphone et téléphone → haut-parleurs. Un effet Android (comme ViPER) ne le
voit donc pas. Le HAL audio de Jancar (`/vendor/lib/hw/audio.primary.ac8257.so`, 32 bits) a un point d'accroche pour
ça : `libecnrhelper.so` ouvre `/vendor/lib[64]/libEcnrForCustomer.so` (dlopen) au début de chaque appel quand
`vendor.audiohal.third_ecnr_lib.enable` vaut 1, et lit l'objet `AUDIO_ECNR_SYM`. Interface relevée par désassemblage de
`libecnrhelper.so` (`atcecnr::SpeechECNRController`, `DataCombiner::processThread`) :

| Champ | Rôle |
|---|---|
| 0, 1 | nom, version (journalisés) |
| 2 | doit être non nul (sinon process / deinit ne sont pas appelés) |
| 3 | appelé en premier, avec un pointeur vers la copie ; retour ignoré |
| 4 | `init(SYM, mEcnrMode, dataMode, débit source, débit cible)` ; retour ignoré |
| 5 | `process(SYM, entrée, sortie, octets d'entrée, &octets de sortie)` : 0 = OK |
| 6 | `deinit(SYM)` |
| 7 | jamais appelé |

L'objet est passé **par valeur** (copie de 8 pointeurs). Entrée : N trames de 4 × int16 `[micro G, micro D, réf G, réf D]`
(réf = ce que jouent les haut-parleurs, la voix du correspondant) au débit cible ; sortie : N × int16 mono.

Un vendor **sans** `libecnrhelper.so` (versions anciennes) n'a pas ce point d'accroche : la bibliothèque n'y sert à
rien, et les zips ne l'installent pas.

## Réglages

Propriétés système, relues au début de chaque appel puis chaque seconde (changement pris en compte pendant l'appel).
LibreHU-service les règle (Audio > Microphone) :

| Propriété | Valeurs (défaut en gras) |
|---|---|
| `persist.vendor.librehu.ecnr.aec` | 0 coupé, **1 AEC3**, 2 AECM |
| `persist.vendor.librehu.ecnr.ns` | 0 coupé, 1 faible, **2 moyen**, 3 fort, 4 très fort |
| `persist.vendor.librehu.ecnr.agc` | **0 coupé**, 1 gain automatique |
| `persist.vendor.librehu.ecnr.mic` | **0 micro gauche**, 1 droit, 2 moyenne des deux |
| `persist.vendor.librehu.ecnr.delay` | indication du retard de l'écho en ms (**0** ; AEC3 le trouve seul, AECM en a besoin) |

Journal : `adb logcat -s LibreHU-ECNR` (paramètres de chaque appel, puis statistiques toutes les 30 s : niveaux micro /
réf / sortie, ERLE, retard estimé).

## Construire

```sh
./build.sh host                            # PC : build + test (écho, voix proche, bruit, débits)
./build.sh android armeabi-v7a out/        # NDK (ANDROID_NDK_HOME), API 28
./build.sh android arm64-v8a out/
```

Il faut meson et ninja ; WebRTC et abseil viennent des fichiers wrap de `subprojects/` (aucune copie dans ce dépôt).
La CI (`.github/workflows/ecnr-webrtc.yml`) fait les trois, vérifie les bibliothèques Android (seules `libc`, `libm`,
`libdl`, `liblog` demandées ; seul `AUDIO_ECNR_SYM` exporté), publie la release `ecnr-webrtc` et relance la construction
des zips (`ecnr-webrtc` / `ecnr-webrtc-restore`, LibreHU Apps). La ROM LineageOS LibreHU prend la même release.

## Licences

Code LibreHU (`ecnr_webrtc.cpp`, `test/`, scripts) : Apache-2.0. WebRTC : BSD-3-Clause. Abseil : Apache-2.0. libc++ du
NDK (liée statiquement) : Apache-2.0 avec exceptions LLVM. Le fichier `NOTICE` de la release les reprend.
