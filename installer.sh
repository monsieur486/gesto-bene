#!/usr/bin/env bash
# Pose l'addon GestoBene dans le client WoW.
# Le jeu doit être fermé : il réécrit son dossier en quittant.
set -euo pipefail

ici="$(cd "$(dirname "$0")" && pwd)"
client="${WOW_CLIENT:-$HOME/Programmes/wow-woe}"
cible="$client/Interface/AddOns/GestoBene"

if [[ ! -d "$client/Interface/AddOns" ]]; then
  echo "Client introuvable : $client" >&2
  echo "Renseigne WOW_CLIENT si ton client est ailleurs." >&2
  exit 1
fi

if pgrep -x Wow.exe >/dev/null; then
  echo "Le jeu tourne encore : quitte-le d'abord." >&2
  exit 1
fi

rm -rf "$cible"
cp -r "$ici/GestoBene" "$cible"
echo "GestoBene installé dans $cible"
echo "Ferme et relance le client pour qu'il découvre l'addon."
