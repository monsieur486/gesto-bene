# Addon GestoBene — conception

Date : 2026-09-18
Client : WoW 3.3.5a (Interface 30300), locale `frFR`
Personnage visé : Kahalie, paladin (Vindicte en solo, Protection en donjon)

## 1. Intention

Suivre les bénédictions du groupe en donjon 5 joueurs. Un carré par membre
présent — cinq en groupe complet, **un seul en solo**. Chaque carré montre la
bénédiction que la classe de ce membre commande, le temps qu'il lui reste, et
alerte quand elle manque ou expire bientôt. Un clic sur un carré lance la
bénédiction.

L'addon ne décide rien : il montre l'état et sert de bouton. La table des
classes est écrite à la main dans un fichier, hors du jeu.

## 2. Décisions retenues

| Question | Choix | Raison |
|---|---|---|
| Ce que décompte un carré | Durée restante du buff, plus une alerte d'absence | Les bénédictions n'ont pas de temps de recharge en 3.3.5a, seulement le GCD |
| Type de bénédiction | Normale et supérieure, au choix du clic | L'addon suit la montée de niveau sans être refait |
| Granularité de la config | Par classe uniquement | Dix lignes, c'est la logique même des bénédictions supérieures du jeu |
| Effet du clic | Lancer la bénédiction prévue, jamais la changer | La config par classe est la seule source de vérité |
| Stockage des réglages | Fichier Lua de l'addon, aucune SavedVariables | Éditable hors du jeu, rien que WoW puisse réécrire en quittant |
| Groupe incomplet ou solo | Les carrés sans occupant sont **cachés**, pas grisés | En solo l'addon se réduit à un seul carré, celui de Kahalie |

## 3. Terrain vérifié

Constats établis sur le poste, avec la source :

- Interface 30300 et locale `frFR` — `WTF/Config.wtf` (`SET locale "frFR"`).
- `UnitBuff(unit, i)` rend ici onze valeurs, dont `expirationTime` et `spellId` —
  usage réel dans `Interface/AddOns/Grid2/modules/StatusAuras.lua:494`.
- Les boutons de lancement passent par `SecureActionButtonTemplate` et
  `SetAttribute("type"/"unit"/"spell")` — usage réel dans
  `Interface/AddOns/Bartender4/ActionButton.lua:80`.
- `InCombatLockdown` est employé par dix-huit addons du dossier : le verrou de
  combat est bien la contrainte attendue sur ce client.
- Lua 5.1.5 est installé sur le poste (`/usr/bin/lua`). C'est la version exacte
  qu'embarque WoW 3.3.5a, donc la logique pure se teste hors du jeu.

## 4. Découpage

```
GestoBene/
├── GestoBene.toc      déclaration, ## Interface: 30300
├── Config.lua            réglages — le seul fichier que l'utilisateur édite
├── Sorts.lua             table des bénédictions, résolution des noms      [pur]
├── Suivi.lua             qui porte quoi, combien de temps il reste        [pur]
├── Cadre.lua             les cinq carrés, boutons sécurisés, couleurs
└── GestoBene.lua      événements, commandes /ben
```

Ordre de chargement dans le `.toc` : `Config`, `Sorts`, `Suivi`, `Cadre`,
`GestoBene`.

`Sorts.lua` et `Suivi.lua` ne créent ni ne touchent aucun cadre. Ils reçoivent
des données, ils rendent des données. Ce sont les deux seuls fichiers couverts
par des tests.

`Cadre.lua` ne contient aucune décision : il peint ce que `Suivi.lua` lui donne.

## 5. Config.lua

Un unique tableau global, commenté en français, sans dépendance.

```lua
GestoBene_Config = {
  -- Une bénédiction par classe.
  -- Valeurs admises : "Rois", "Puissance", "Sagesse", "Sanctuaire"
  parClasse = {
    WARRIOR     = "Puissance",
    PALADIN     = "Rois",
    HUNTER      = "Puissance",
    ROGUE       = "Puissance",
    PRIEST      = "Sagesse",
    DEATHKNIGHT = "Puissance",
    SHAMAN      = "Sagesse",
    MAGE        = "Sagesse",
    WARLOCK     = "Sagesse",
    DRUID       = "Sagesse",
  },

  -- Sous ce nombre de secondes restantes, le carré passe en orange.
  seuilAlerte = 60,

  -- Position du cadre. « /ben pos » imprime les valeurs courantes à recopier.
  ancrage = { point = "CENTER", x = 0, y = -200 },

  -- Taille d'un carré, en pixels.
  tailleCarre = 48,
}
```

Un changement prend effet au `/reload` ou à la reconnexion. Aucune écriture :
le fichier est lu, jamais modifié par l'addon.

### Validation au chargement

`Sorts.lua` vérifie chaque valeur de `parClasse`. Une clé inconnue ou une
bénédiction non reconnue produit un message dans le chat nommant la ligne
fautive, et cette classe tombe sur `"Puissance"` par défaut. L'addon ne refuse
jamais de se charger à cause de la configuration.

## 6. Sorts.lua

### Table des bénédictions

Aucun nom français n'est écrit en dur. On part des identifiants, et le jeu
fournit le nom localisé.

```lua
GestoBene_Sorts.table = {
  Rois       = { normale = 20217, superieure = 25898 },
  Puissance  = { normale = 19740, superieure = 25782 },
  Sagesse    = { normale = 19742, superieure = 25894 },
  Sanctuaire = { normale = 20911, superieure = 25899 },
}
GestoBene_Sorts.reactif = 21177  -- Symbole des rois
```

**Quatre bénédictions, pas cinq.** La Lumière a été retirée : vérification faite
en jeu le 2026-09-18, les identifiants 19977 et 25890 rendent `INCONNU` sur ce
client. Elle n'existe pas en 3.3.5a.

### Résolution

```lua
local nom    = GetSpellInfo(id)          -- nom localisé, même sort non appris
local appris = nom and GetSpellInfo(nom) ~= nil
```

`GetSpellInfo(id)` rend toujours le nom. `GetSpellInfo(nom)` ne rend quelque
chose que si le sort est dans le grimoire. Les deux appels ensemble donnent
donc « existe » et « je le connais ».

La disponibilité d'une supérieure exige en plus `GetItemCount(21177) > 0`.

### Abréviations d'affichage

`Rois → ROI`, `Puissance → PUI`, `Sagesse → SAG`, `Sanctuaire → SAN`.
Écrites en dur : ce sont des étiquettes de l'addon, pas des
chaînes du jeu.

### Identifiants confirmés en jeu

Relevé sur le client le 2026-09-18, Kahalie niveau 55, spécialisation Vindicte :

| Identifiant | Nom rendu par le client | État |
|---|---|---|
| 20217 | Bénédiction des rois | appris |
| 25898 | Bénédiction des rois supérieure | **non appris** |
| 19740 | Bénédiction de puissance | appris |
| 25782 | Bénédiction de puissance supérieure | appris |
| 19742 | Bénédiction de sagesse | appris |
| 25894 | Bénédiction de sagesse supérieure | appris |
| 20911 | Bénédiction du sanctuaire | non appris |
| 25899 | Bénédiction du sanctuaire supérieure | non appris |
| 19977 | `INCONNU` | n'existe pas |
| 25890 | `INCONNU` | n'existe pas |

Réactif : `GetItemInfo(21177)` rend « Symbole des rois », 28 en sac.

Trois conséquences pour l'implémentation :

1. **La Lumière est retirée de la table** — ses identifiants n'existent pas.
2. **Le Sanctuaire reste dans la table mais se grise** : c'est le talent de
   Protection. Il s'allume pendant la montée de niveau, quand Kahalie passe
   Protection pour les donjons, et s'éteint en Vindicte.

   Au niveau 80, la double spécialisation prévue est **Vindicte ou Heal** — la
   Protection ne sert qu'au leveling. Le Sanctuaire finira donc éteint pour de
   bon. On le garde quand même : il ne coûte rien, il se grise seul, et il sert
   pendant toute la montée de niveau. Le supprimer serait un travail à refaire
   si la spé de protection revenait.

   Le changement de spécialisation se détecte par `ACTIVE_TALENT_GROUP_CHANGED`,
   présent sur ce client — Outfitter s'en sert pour la double spé
   (`Interface/AddOns/Outfitter/OutfitterScripting.lua:651`). `SPELLS_CHANGED`
   seul ne suffit pas à le garantir.
3. **La supérieure des Rois est le seul repli actif aujourd'hui.** Les
   supérieures de Puissance et de Sagesse sont déjà apprises à 55, mais celle
   des Rois demande le niveau 60. Le clic droit sur un membre configuré en Rois
   doit donc se replier sur la normale — cas courant, pas exceptionnel, et le
   test 4 doit le couvrir avec ces valeurs-là.

La commande `/ben sorts` reproduit ce tableau à la demande, pour refaire le
relevé après un niveau ou un changement de spécialisation. Une entrée dont
`GetSpellInfo(id)` rend `nil` est retirée de la table utilisable, sans erreur.

## 7. Suivi.lua

### Rôle

Pour une unité donnée, dire quelle bénédiction **que nous avons lancée** elle
porte, et combien de temps il lui reste.

```lua
GestoBene_Suivi.LireUnite(unite) -- → { cle, restant, duree } ou nil
```

### Lecture

Balayer `UnitBuff(unite, i)` de `i = 1` jusqu'au premier retour `nil`. Retenir
le premier buff dont le `spellId` appartient à la table **et** dont le `caster`
est `"player"`. Le filtre sur le lanceur est essentiel : la bénédiction d'un
autre paladin ne doit pas faire croire que le travail est fait, puisque nous ne
pouvons pas la rafraîchir.

```lua
local nom, _, _, _, _, duree, expiration, lanceur, _, _, spellId = UnitBuff(unite, i)
```

Temps restant : `expiration - GetTime()`, borné à zéro par le bas. Une expiration
nulle ou absente signifie une durée indéterminée : le carré affiche `--:--` au
lieu d'un nombre.

### Résolution de la bénédiction attendue

```lua
GestoBene_Suivi.Attendue(unite) -- → clé de bénédiction, ou nil
```

`select(2, UnitClass(unite))` donne le jeton de classe, `Config.parClasse` donne
la clé. Une unité inexistante ou hors ligne rend `nil`.

### Composition du groupe

```lua
GestoBene_Suivi.Membres() -- → { "player" }  en solo
                             -- → { "player", "party1", "party2" }  à trois
```

Cette fonction décide **quels carrés sont visibles**. Elle vit ici, et non dans
`Cadre.lua`, précisément pour être testable hors du jeu : le cas solo est une
règle, pas un détail d'affichage. `Cadre.lua` se contente de montrer les carrés
qu'elle nomme et de cacher les autres.

### États rendus

| État | Condition |
|---|---|
| `vide` | L'unité n'existe pas — solo, ou groupe de moins de cinq |
| `absente` | Aucune de nos bénédictions sur l'unité |
| `mauvaise` | Une des nôtres, mais pas celle que la classe commande |
| `bientot` | La bonne, restant sous `seuilAlerte` |
| `posee` | La bonne, au-dessus du seuil |

L'état `mauvaise` n'était pas dans la demande initiale. Il sort gratuitement de
la lecture et évite un mensonge : sans lui, un carré vert pourrait signifier
« il porte Puissance alors que tu as configuré Sagesse ».

## 8. Cadre.lua

### Disposition

Cinq carrés sont **créés** une fois pour toutes à la connexion, en ligne, de
gauche à droite, séparés de 4 pixels. Carré 1 = `player`, carrés 2 à 5 =
`party1` à `party4`.

Seuls les carrés dont l'unité existe sont **affichés**. En solo, un seul carré
reste visible, celui de Kahalie ; le cadre parent se réduit à sa largeur. Dans
un groupe de trois, trois carrés. Il n'y a jamais de trou : les carrés visibles
sont toujours contigus, puisque `party1` à `party4` se remplissent dans l'ordre.

Le cadre parent porte l'ancrage, se déplace à la souris, et redimensionne sa
largeur sur le nombre de carrés visibles.

Chaque carré porte trois textes : l'abréviation en haut, le temps restant au
centre, le nom du joueur en dessous.

Créer les cinq carrés d'emblée, puis n'en montrer qu'une partie, est un choix
délibéré : créer un bouton protégé en combat est impossible, alors que le
`Show` / `Hide` différé se traite avec la même file d'attente que les attributs
(section 9).

### Couleurs

| État | Rendu |
|---|---|
| `posee` | Fond vert sombre, texte clair |
| `bientot` | Bord orange, temps en orange |
| `absente` | Fond rouge, « MANQUE », clignotement lent (une pulsation par seconde) |
| `mauvaise` | Fond jaune, abréviation de la bénédiction **réellement portée** |
| `vide` | Carré caché, cadre parent rétréci |
| `en attente` | Bordure jaune — voir le verrou de combat |

### Boutons sécurisés

Chaque carré est un `SecureActionButtonTemplate`.

```lua
carre:SetAttribute("unit", "party2")      -- gravé une fois pour toutes
carre:SetAttribute("type1", "spell")
carre:SetAttribute("spell1", nomNormale)
carre:SetAttribute("type2", "spell")
carre:SetAttribute("spell2", nomSuperieure)
```

`RegisterForClicks("AnyUp")`.

Le clic droit ne pose la supérieure que si elle est apprise et qu'il reste un
symbole. Sinon `spell2` reçoit le nom de la normale : le clic droit se dégrade
au lieu de ne rien faire.

L'addon ne vérifie ni la portée, ni la ligne de vue, ni le mana. C'est le rôle
du jeu, qui refusera le lancement avec son propre message.

## 9. Le verrou de combat

C'est la seule difficulté réelle de l'addon.

Deux opérations sont interdites en combat sur un bouton protégé :

1. **changer ses attributs** — or `spell` dépend de la classe de l'occupant ;
2. **le montrer ou le cacher** — or le nombre de carrés visibles dépend de la
   taille du groupe.

Le premier point était connu dès la conception. Le second arrive avec le solo :
puisque les carrés inoccupés sont cachés et non grisés, passer de un à cinq
carrés est une opération protégée elle aussi.

La parade tient dans deux invariants :

- **Un carré ne change jamais de cible.** L'attribut `unit` est posé une fois à
  la création et n'est plus jamais touché.
- **Les cinq carrés existent toujours.** Ils sont créés à la connexion, hors
  combat ; seule leur visibilité varie.

Ne bougent donc que `spell1` / `spell2` et `Show` / `Hide`, et seulement quand
la composition du groupe change. Les deux passent par la même file.

Procédure :

1. `PARTY_MEMBERS_CHANGED`, `SPELLS_CHANGED` ou `BAG_UPDATE` demandent une
   reprogrammation — attributs et visibilité.
2. Si `InCombatLockdown()` est faux, elle se fait tout de suite.
3. Sinon, un drapeau `reprogrammationEnAttente` est levé, et les carrés déjà
   visibles passent en rendu « en attente » (bordure jaune).
4. `PLAYER_REGEN_ENABLED` vide la file, repositionne les carrés visibles,
   redimensionne le cadre parent et repeint.

Conséquences assumées, pendant un combat seulement :

- Quelqu'un rejoint le groupe : son carré n'apparaît qu'à la fin du combat.
- Quelqu'un quitte le groupe : son carré reste affiché, bordure jaune.
- Un carré déjà visible garde l'ancienne bénédiction s'il a changé d'occupant.

Le rendu le signale au lieu de mentir. Aucun addon ne peut faire mieux sur ce
client.

L'affichage, lui, n'est pas protégé : les couleurs et les décomptes continuent
de se mettre à jour normalement en combat.

## 10. GestoBene.lua

### Événements

| Événement | Effet |
|---|---|
| `PLAYER_LOGIN` | Construire les carrés, résoudre les sorts, premier rendu |
| `PLAYER_ENTERING_WORLD` | Relire le groupe entier |
| `PARTY_MEMBERS_CHANGED` | Reprogrammer les attributs, relire le groupe |
| `UNIT_AURA` | Relire la seule unité concernée, si elle est à nous |
| `SPELLS_CHANGED` | Re-résoudre les sorts appris (niveau, nouveau rang) |
| `ACTIVE_TALENT_GROUP_CHANGED` | Re-résoudre après un basculement de double spé |
| `BAG_UPDATE` | Recompter les symboles |
| `PLAYER_REGEN_ENABLED` | Vider la file de reprogrammation |
| `PLAYER_REGEN_DISABLED` | Marquer l'entrée en combat |

`PARTY_MEMBERS_CHANGED` est bien le nom de l'événement en 3.3.5a —
`GROUP_ROSTER_UPDATE` n'existe qu'à partir de la 5.0.

### Rafraîchissement

`UNIT_AURA` dit *quand* un buff change. Un `OnUpdate` limité à 0,2 seconde ne
repeint que le texte du décompte et le clignotement, sans relire aucun buff. Le
balayage des auras n'a donc lieu que sur événement.

### Commandes

| Commande | Effet |
|---|---|
| `/ben` | Montrer ou cacher le cadre |
| `/ben sorts` | Imprimer la résolution des identifiants et l'état appris |
| `/ben pos` | Imprimer l'ancrage courant à recopier dans `Config.lua` |
| `/ben etat` | Imprimer, pour chaque membre, classe, bénédiction attendue, état |

`/ben pos` est la contrepartie du choix « sans SavedVariables » : le cadre se
déplace à la souris, mais la position ne survit pas au rechargement tant qu'elle
n'est pas recopiée dans le fichier. C'est explicite et assumé.

## 11. Tests

Lua 5.1.5 étant sur le poste, `Sorts.lua` et `Suivi.lua` se testent hors du jeu,
avec le vrai interpréteur, en TDD — le test d'abord, à chaque fois.

```
tests/
├── faux-api.lua          faux de l'API WoW
└── tests.lua             les cas, lancés par « lua tests.lua »
```

Le faux couvre `UnitBuff`, `UnitClass`, `UnitExists`, `GetSpellInfo`, `GetTime`,
`GetItemCount`. Il est piloté par une table décrivant le groupe et les buffs,
pour qu'un cas de test tienne en quelques lignes.

### Cas couverts

Sur `Sorts.lua` :

1. Un identifiant connu rend son nom localisé.
2. Un sort non appris est marqué non appris, pas absent.
3. Un identifiant que le client ignore est retiré de la table sans erreur.
4. Une supérieure sans symbole en sac est indisponible.
5. Une classe inconnue dans `Config` produit un avertissement et un repli.

Sur `Suivi.lua` :

6. La classe d'un membre donne la bénédiction attendue.
7. Une bénédiction lancée par un autre paladin n'est pas comptée comme nôtre.
8. Le temps restant se calcule juste à partir de `expirationTime`.
9. Un temps restant négatif est ramené à zéro, jamais affiché négatif.
10. Une bénédiction à nous mais différente de l'attendue rend l'état `mauvaise`.
11. Une unité inexistante rend l'état `vide`.
12. Une expiration nulle rend une durée indéterminée, pas une erreur.
13. **En solo, `Membres()` ne rend que `player`** — un seul carré.
14. Dans un groupe de trois, `Membres()` rend `player`, `party1`, `party2`, dans
    cet ordre et sans trou.
15. Un membre hors ligne reste dans `Membres()` : son carré s'affiche, à l'état
    `absente`, plutôt que de faire glisser les autres.

`Cadre.lua` et `GestoBene.lua` ne sont pas couverts : ils touchent l'API
graphique et le système d'événements, qu'on ne simule pas raisonnablement. C'est
précisément pourquoi ils ne portent aucune décision. Ils se vérifient en jeu.

### Vérification en jeu

Une fois les tests au vert, la recette manuelle tient en sept points :

1. Le cadre apparaît à la connexion.
2. **Seul en ville, un unique carré s'affiche** — celui de Kahalie.
3. `/ben sorts` montre des identifiants valides.
4. Un clic gauche pose la bonne bénédiction et le décompte démarre.
5. Un clic droit pose la supérieure et consomme un symbole.
6. **Entrer en groupe hors combat fait apparaître les carrés manquants** et
   élargit le cadre.
7. Entrer en combat après un changement de groupe affiche la bordure jaune sans
   provoquer d'erreur Lua, et le rendu se corrige à la fin du combat.

## 12. Hors périmètre

Retiré volontairement, faute d'usage établi :

- Annonce dans le canal du groupe.
- Bénédiction automatique sans clic.
- Coordination entre plusieurs paladins.
- Raid à 40, et donc plus de cinq carrés.
- Exceptions par rôle ou par nom de joueur — écartées au profit de la table par
  classe, qui suffit en donjon 5.

## 13. Risques

| Risque | Parade |
|---|---|
| Identifiants de sorts faux | `/ben sorts` les montre ; une entrée non résolue est ignorée, pas fatale |
| Une bénédiction apprise plus tard (supérieure des Rois à 60, Sanctuaire au changement de spé) | `SPELLS_CHANGED` re-résout la table ; le carré s'allume sans rien éditer |
| Changement de groupe en combat | Rendu « en attente », reprogrammation différée à `PLAYER_REGEN_ENABLED` |
| `Show` / `Hide` interdits en combat sur un bouton protégé | Les cinq carrés sont créés hors combat une fois pour toutes ; seule leur visibilité varie, par la même file d'attente |
| `UnitBuff` muet sur une unité hors de portée | État `absente` affiché ; on ne peut pas distinguer, et c'est sans conséquence puisque le clic échouerait de toute façon |
| Le dossier du client n'est pas sous git | La spec et l'addon ne sont pas versionnés ; accepté pour ce projet |
