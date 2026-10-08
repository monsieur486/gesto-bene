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
en sac. À l'inverse, tant que les joueurs d'une même classe attendent la
même bénédiction, le clic droit sur l'un pose la supérieure sur tous : leurs
carrés changent ensemble, c'est voulu.

En combat, le bouton note le nouveau choix tout de suite, mais les carrés ne
le prennent qu'à la fin du combat — un message le rappelle. D'ici là, un clic
droit sur un autre joueur de la même classe lancerait encore la supérieure.

Tout tient sur une seule ligne. À gauche du cadenas, un carré suit ton sceau
(Sagesse par défaut), avec la même présentation et les mêmes couleurs. Un clic
gauche le lance ; un clic droit passe au sceau suivant parmi ceux que tu
connais. Ce choix est mémorisé et survit au `/reload`. En combat, ce carré
affiche tout de suite le nouveau choix, mais son clic gauche lance encore
l'ancien sceau jusqu'à la fin du combat.

Le cadenas à gauche des carrés verrouille ou libère le déplacement du cadre.
À droite, un compteur indique le nombre de Symboles des rois en sac.

## Installation

```bash
./installer.sh
```

Le script passe d'abord les tests et ne pose rien s'ils échouent, puis copie
`GestoBene/` dans `Interface/AddOns/` du client. Le jeu peut
rester ouvert : WoW ne réécrit jamais ce dossier, seul `WTF` l'est en
quittant, et l'installeur n'y touche pas. Un `/reload` suffit à prendre les
changements — sauf à la première installation, où il faut fermer et relancer
le client pour qu'il découvre le dossier.

## Réglages

Tout se règle dans `GestoBene/Config.lua`, éditable hors du jeu. L'addon ne
fait que le lire : rien de ce que tu y écris ne sera réécrit par le jeu.

Seules trois choses sont mémorisées d'une session à l'autre, dans la
SavedVariables `GestoBene_Etat` (sous `WTF`) : la position du cadre après un
déplacement, l'état du cadenas et le sceau choisi au clic droit. Elles
l'emportent sur `ancrage`, `verrouille` et `sceau` de `Config.lua`, qui ne
servent plus qu'à la toute première connexion.

## Commandes

| Commande | Effet |
|---|---|
| `/gesto` | Montrer ou cacher le cadre |
| `/gesto sorts` | Imprimer la résolution des identifiants de sorts, sceaux compris |
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
