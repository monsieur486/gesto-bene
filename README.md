# GestoBene

Addon World of Warcraft 3.3.5a (WotLK) qui suit les bénédictions du groupe.

Un carré par membre présent — cinq en groupe complet, un seul en solo. Chaque
carré montre la bénédiction que la classe de ce membre commande, le temps qu'il
lui reste, et alerte quand elle manque ou expire bientôt. Un clic sur un carré
lance la bénédiction : clic gauche pour la normale, clic droit pour la
supérieure.

## Installation

```bash
./installer.sh
```

Le script copie `GestoBene/` dans `Interface/AddOns/` du client. Il refuse de
tourner si le jeu est lancé, car WoW réécrit son dossier en quittant.

⚠️ Un addon nouvellement installé n'apparaît pas au `/reload` : il faut fermer
le client entièrement et le relancer pour que WoW découvre le dossier.

## Réglages

Tout se règle dans `GestoBene/Config.lua`, éditable hors du jeu. L'addon
n'utilise aucune SavedVariables : rien de ce que tu écris ne sera réécrit par
le jeu.

## Commandes

| Commande | Effet |
|---|---|
| `/gesto` | Montrer ou cacher le cadre |
| `/gesto sorts` | Imprimer la résolution des identifiants de sorts |
| `/gesto pos` | Imprimer l'ancrage courant à recopier dans `Config.lua` |
| `/gesto etat` | Imprimer l'état de chaque membre |

`/ben` est un alias de `/gesto`.

## Tests

La logique pure se teste hors du jeu, avec le Lua 5.1 du système :

```bash
cd tests && lua tests.lua
```

## Documentation

- `docs/conception.md` — la conception et les décisions
- `docs/plan.md` — le plan d'implémentation
