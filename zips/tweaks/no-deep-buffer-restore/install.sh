# UJC201 - remet la sortie audio deep_buffer (fichier d'origine sauvegarde par ujc201_nodeepbuffer_install)

ui_print "UJC201 - deep_buffer audio output put back"
ui_print "-----------------------------------------"
mount_rw
f=$(policy_file)
[ -n "$f" ] && [ -f "$f.nodeep-orig" ] || { ui_print "No .nodeep-orig backup: nothing to put back."; cleanup; exit 0; }
cat "$f.nodeep-orig" > "$f" || abort "cannot write $f"
cmp -s "$f.nodeep-orig" "$f" || abort "check of $f failed"
rm -f "$f.nodeep-orig"
ui_print "$f: original put back. Reboot."
cleanup
exit 0
