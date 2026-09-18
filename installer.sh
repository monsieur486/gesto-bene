#!/usr/bin/env bash
# Pose l'addon GestoBene dans le client WoW.
#
# Le jeu peut rester ouvert : WoW lit « Interface/AddOns » au chargement et n'y
# écrit jamais. Seul « WTF » est réécrit en quittant, et l'addon n'y touche pas
# puisqu'il n'utilise aucune SavedVariables. Un /reload suffit donc à prendre
# les changements — sauf à la toute première installation, où il faut fermer et
# relancer le client pour qu'il découvre le dossier.
set -euo pipefail

ici="$(cd "$(dirname "$0")" && pwd)"
client="${WOW_CLIENT:-$HOME/Programmes/wow-woe}"
cible="$client/Interface/AddOns/GestoBene"

if [[ ! -d "$client/Interface/AddOns" ]]; then
  echo "Client introuvable : $client" >&2
  echo "Renseigne WOW_CLIENT si ton client est ailleurs." >&2
  exit 1
fi

premiere_pose=true
[[ -d "$cible" ]] && premiere_pose=false

rm -rf "$cible"
cp -r "$ici/GestoBene" "$cible"
echo "GestoBene installé dans $cible"

if [[ "$premiere_pose" == true ]]; then
  echo "Première installation : ferme et relance le client, puis coche GestoBene"
  echo "dans la liste des extensions à l'écran de sélection du personnage."
elif pgrep -x Wow.exe >/dev/null; then
  echo "Le jeu tourne : tape /reload pour prendre les changements."
fi
