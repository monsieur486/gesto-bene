# GestoBene

Addon World of Warcraft 3.3.5a (WotLK) qui suit les bénédictions du groupe.

Un carré par membre présent — cinq en groupe complet, un seul en solo. Chaque
carré montre la bénédiction attendue pour ce membre, le temps qu'il lui reste,
et alerte quand elle manque ou expire bientôt. Un clic sur un carré
lance la bénédiction : clic gauche pour la normale, clic droit pour la
supérieure.

La bénédiction attendue vient d'abord de la classe du membre, selon
`Config.lua`. Le bouton au-dessus de chaque carré la change pour ce joueur
seul : chaque clic passe à la suivante parmi celles que tu sais lancer, et le
bouton affiche celle qui est choisie. Deux joueurs de même classe peuvent
ainsi recevoir des bénédictions différentes. Ce choix est gardé en mémoire
jusqu'au prochain `/reload` ou à la déconnexion ; `Config.lua` n'est jamais
modifié.

La supérieure s'applique en jeu à tous les membres de la classe ciblée et
remplace ta bénédiction sur chacun d'eux. Quand deux joueurs de la même
classe attendent des bénédictions différentes, le clic droit pose donc la
normale, qui ne touche que la cible : la supérieure écraserait le choix de
l'autre. Il la pose aussi faute de supérieure apprise ou de Symbole des rois
en sac.

Le cadenas à gauche des carrés verrouille ou libère le déplacement du cadre.
À droite, un compteur indique le nombre de Symboles des rois en sac.

## Installation

```bash
./installer.sh
```

Le script copie `GestoBene/` dans `Interface/AddOns/` du client. Le jeu peut
rester ouvert : WoW ne réécrit jamais ce dossier, seul `WTF` l'est en
quittant, et l'installeur n'y touche pas. Un `/reload` suffit à prendre les
changements — sauf à la première installation, où il faut fermer et relancer
le client pour qu'il découvre le dossier.

## Réglages

Tout se règle dans `GestoBene/Config.lua`, éditable hors du jeu. L'addon ne
fait que le lire : rien de ce que tu y écris ne sera réécrit par le jeu.

Seules deux choses sont mémorisées d'une session à l'autre, dans la
SavedVariables `GestoBene_Etat` (sous `WTF`) : la position du cadre après un
déplacement, et l'état du cadenas. Elles l'emportent sur `ancrage` et
`verrouille` de `Config.lua`, qui ne servent plus qu'à la toute première
connexion.

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
