# Addon GestoBene — conception

Date : 2026-09-18 — mis à jour le 2026-09-28
Client : WoW 3.3.5a (Interface 30300), locale `frFR`
Personnage visé : Kahalie, paladin (Vindicte en solo, Protection en donjon)

## 1. Intention

Suivre les bénédictions du groupe en donjon 5 joueurs. Un carré par membre
présent — cinq en groupe complet, **un seul en solo**. Chaque carré montre la
bénédiction attendue pour ce membre, le temps qu'il lui reste, et alerte quand
elle manque ou expire bientôt. Un clic sur un carré lance la bénédiction.
Sous le carré du paladin, un carré de sceau suit de la même façon son propre sceau.

L'addon ne décide rien : il montre l'état et sert de bouton. La table des
classes est écrite à la main dans un fichier, hors du jeu ; un bouton au-dessus
de chaque carré permet d'y déroger pour un joueur, le temps de la session.

## 2. Décisions retenues

| Question | Choix | Raison |
|---|---|---|
| Ce que décompte un carré | Durée restante du buff, plus une alerte d'absence | Les bénédictions n'ont pas de temps de recharge en 3.3.5a, seulement le GCD |
| Type de bénédiction | Normale et supérieure, au choix du clic | L'addon suit la montée de niveau sans être refait |
| Granularité de la config | Par classe dans `Config.lua`, surchargeable par joueur en jeu | Deux joueurs de même classe peuvent avoir des besoins différents (un guerrier Fureur et un guerrier Protection) |
| Effet du clic sur un carré | Lancer la bénédiction prévue, jamais la changer | Changer de bénédiction passe par le bouton de bascule, pas par le carré |
| Supérieure quand la classe diverge | Le clic droit pose la normale | Une supérieure touche toute la classe et écraserait le choix de l'autre joueur |
| Stockage des réglages | `Config.lua` en lecture seule ; `GestoBene_Etat` pour la position, le cadenas et le sceau choisi | Éditable hors du jeu ; seul ce que l'addon produit lui-même est mémorisé |
| Changer de sceau | Clic droit sur le carré de sceau | Le sceau n'a pas de supérieure : le clic droit est libre, et évite un bouton de plus |
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
  qu'embarque WoW 3.3.5a, donc la logique pure se teste hors du jeu. Sur un
  poste qui ne l'a pas : `sudo apt install lua5.1`.

## 4. Découpage

```
GestoBene/
├── GestoBene.toc      déclaration, ## Interface: 30300, SavedVariables
├── Config.lua            réglages — le seul fichier que l'utilisateur édite
├── Sorts.lua             table des bénédictions et des sceaux,
│                         résolution des noms                              [pur]
├── Suivi.lua             qui porte quoi, combien de temps il reste,
│                         surcharges par joueur, sceau choisi              [pur]
├── Cadre.lua             les cinq carrés, boutons sécurisés, couleurs,
│                         bascules, cadenas, compteur de symboles,
│                         carré de sceau
└── GestoBene.lua      événements, commandes /gesto (alias /ben)
```

Ordre de chargement dans le `.toc` : `Config`, `Sorts`, `Suivi`, `Cadre`,
`GestoBene`.

`Sorts.lua` et `Suivi.lua` ne créent ni ne touchent aucun cadre. Ils reçoivent
des données, ils rendent des données. Ce sont les deux seuls fichiers couverts
par des tests.

`Cadre.lua` ne porte aucune règle de résolution de bénédiction : c'est
`Suivi.lua` qui décide qui porte quoi, et `Cadre.lua` peint ce résultat sans le
remettre en question. Il contient malgré tout ses propres décisions
d'affichage — le formatage mm:ss, la formule de pulsation, la réévaluation du
seuil hors de `Suivi.Etat` (section 8) — assumées et non testées (section 11).

## 5. Config.lua

Un unique tableau global, commenté en français, sans dépendance.

```lua
GestoBene_Config = {
  -- Valeurs admises : "Rois", "Puissance", "Sagesse", "Sanctuaire"
  -- Les porteurs de tissu vivent sur leur mana : Sagesse.
  -- Tous les autres profitent davantage des Rois.
  parClasse = {
    WARRIOR     = "Rois",
    PALADIN     = "Sagesse",
    HUNTER      = "Rois",
    ROGUE       = "Rois",
    PRIEST      = "Sagesse",
    DEATHKNIGHT = "Rois",
    SHAMAN      = "Rois",
    MAGE        = "Sagesse",
    WARLOCK     = "Sagesse",
    DRUID       = "Rois",
  },

  -- Le sceau suivi sous le carré du paladin, à la première connexion.
  sceau = "Sagesse",

  -- Sous ce nombre de secondes restantes, le carré passe en orange.
  seuilAlerte = 60,

  -- Seuils du compteur de Symboles des rois : vert au-dessus du premier,
  -- orange au-dessus du second, rouge en dessous.
  seuilReactifBon = 10,
  seuilReactifFaible = 5,

  -- Position du cadre à la toute première connexion.
  ancrage = { point = "CENTER", x = 0, y = -200 },

  -- Taille d'un carré, en pixels.
  tailleCarre = 48,

  -- État du cadenas à la toute première connexion.
  verrouille = true,
}
```

Un changement prend effet au `/reload` ou à la reconnexion. Aucune écriture :
le fichier est lu, jamais modifié par l'addon. `ancrage` et `verrouille` ne
servent plus qu'à la première connexion : ensuite, `GestoBene_Etat` l'emporte
(section 8). Il en va de même pour `sceau`, dès qu'un clic droit a changé le
choix.

### Validation au chargement

`Sorts.lua` vérifie chaque valeur de `parClasse`. Une clé inconnue ou une
bénédiction non reconnue produit un message dans le chat nommant la ligne
fautive, et cette classe tombe sur `"Puissance"` par défaut. Un `sceau`
inconnu tombe de même sur `"Sagesse"`. L'addon ne refuse jamais de se charger
à cause de la configuration.

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

### Table des sceaux

```lua
GestoBene_Sorts.sceaux = {
  Piete = 21084, Sagesse = 20166, Lumiere = 20165, Justice = 20164,
  Commandement = 20375, Vengeance = 31801, Corruption = 53736,
}
```

Un identifiant par sceau : pas de rang supérieur, pas de réactif. Vengeance
(Alliance) et Corruption (Horde) cohabitent ; seul celui de la faction est
appris. `Sorts.ORDRE_SCEAUX` fixe l'ordre du cycle, et `Sorts.SceauSuivant`
le parcourt parmi les sceaux appris, comme `Sorts.Suivante` pour les
bénédictions. Les sceaux ont leurs propres caches et abréviations : `Sagesse`
désigne à la fois une bénédiction et un sceau. Identifiants non encore relevés
en jeu : `/gesto sorts` les imprime pour vérification.

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
chaînes du jeu. Pour les sceaux : `PIE`, `SAG`, `LUM`, `JUS`, `COM`, `VEN`,
`COR`.

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

La commande `/gesto sorts` reproduit ce tableau à la demande, pour refaire le
relevé après un niveau ou un changement de spécialisation. Une entrée dont
`GetSpellInfo(id)` rend `nil` est retirée de la table utilisable, sans erreur.

## 7. Suivi.lua

### Rôle

Pour une unité donnée, dire quelle bénédiction **que nous avons lancée** elle
porte, et combien de temps il lui reste.

```lua
GestoBene_Suivi.LireUnite(unite)
-- → { cle, restant, duree, expiration, superieure } ou nil
```

### Lecture

Balayer `UnitBuff(unite, i)` de `i = 1` jusqu'au premier retour `nil`. Retenir
le premier buff dont le **nom** appartient à la table **et** dont le `caster`
est `"player"`. Le filtre sur le lanceur est essentiel : la bénédiction d'un
autre paladin ne doit pas faire croire que le travail est fait, puisque nous ne
pouvons pas la rafraîchir.

La reconnaissance se fait par le nom localisé, pas par le `spellId` : la
plupart des bénédictions ont une dizaine de rangs, chacun avec son propre
identifiant, alors que `UnitBuff` rend le même nom quel que soit le rang. Le
nom dit aussi si la bénédiction portée est la supérieure, ce que le carré
signale d'un `+`.

```lua
local nom, _, _, _, _, duree, expiration, lanceur = UnitBuff(unite, i)
```

Temps restant : `expiration - GetTime()`, borné à zéro par le bas. Une expiration
nulle ou absente signifie une durée indéterminée : le carré affiche `--:--` au
lieu d'un nombre.

### Résolution de la bénédiction attendue

```lua
GestoBene_Suivi.Attendue(unite) -- → clé de bénédiction, ou nil
```

Si le joueur porte une surcharge nominative, c'est elle qui gagne. Sinon,
`select(2, UnitClass(unite))` donne le jeton de classe, `Config.parClasse`
donne la clé. Une unité inexistante ou hors ligne rend `nil`.

### Surcharges par joueur

```lua
GestoBene_Suivi.Surcharger(nom, cle)  -- cle = nil retire la surcharge
GestoBene_Suivi.Surcharge(nom)
GestoBene_Suivi.OublierSurcharges()
```

Posées par les boutons de bascule (section 8), rangées par **nom de joueur** et
non par unité : `party2` peut changer d'occupant, un nom non. Elles ne
touchent jamais `GestoBene_Config` et meurent avec la session — le groupe
change à chaque donjon. Elles restent volontairement hors de `GestoBene_Etat`.

### Supérieure permise

```lua
GestoBene_Suivi.SuperieurePermise(unite) -- → vrai ou faux
```

Le jeu applique une supérieure à **tous les membres de la classe ciblée**, et
elle remplace notre bénédiction sur chacun d'eux. Si un autre porteur de la
même classe attend une bénédiction différente, la supérieure écraserait son
choix et ferait virer son carré en `mauvaise`. La fonction rend donc faux dans
ce cas, et `Cadre.lua` pose alors la normale sur le clic droit. Une classe
seule dans le groupe, ou unanime, garde la supérieure.

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
| `mauvaise` | Une des nôtres, mais pas celle attendue pour ce joueur |
| `bientot` | La bonne, restant sous `seuilAlerte` |
| `posee` | La bonne, au-dessus du seuil |

`Suivi.EtatSceau()` rend les mêmes états, sauf `vide`, pour le sceau que porte
le paladin face à `Suivi.SceauChoisi()` : le choix mémorisé dans
`GestoBene_Etat.sceau` s'il est connu, sinon `Config.sceau`.
`Suivi.ChoisirSceau` efface la mémoire quand le choix revient sur celui de
`Config.lua`, comme la bascule retire une surcharge égale à la règle de classe.

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

Le cadre parent porte l'ancrage, se déplace à la souris quand le cadenas est
ouvert, et redimensionne sa largeur sur le nombre de carrés visibles.

Chaque carré porte trois textes : l'abréviation en haut (suivie d'un `+` pour
une supérieure), le temps restant au centre, le nom du joueur en dessous.

### Carré de sceau

Sous le carré du paladin et son nom, un carré de même taille affiche sur deux
lignes l'abréviation du sceau en haut et le temps restant au centre, avec les
couleurs des carrés. Une première version tenait sur une barre de 18 pixels
et une seule ligne, `SAG 29:12` : trop tassée dans 48 pixels de large. C'est un
`SecureActionButtonTemplate` à l'unité `player`. Seul `type1` est posé : le
clic gauche lance le sceau choisi. Le clic droit ne déclenche donc aucune
action protégée ; `PostClick` passe au sceau suivant, repeint aussitôt et
appelle `Reprogrammer`. Le joueur existant toujours, ce carré ne se montre ni
ne se cache jamais : il suit le cadre parent.

### Boutons ordinaires autour des carrés

Aucun de ces boutons ne lance de sort ; seuls les cinq carrés sont protégés.

- **Bascule** — au-dessus de chaque carré. Elle affiche l'abréviation de la
  bénédiction choisie pour ce joueur ; un clic passe à la suivante parmi
  celles que le paladin sait lancer (`Sorts.Suivante`), et pose une surcharge
  nominative. Revenir sur la valeur de la classe retire la surcharge. Cachée
  quand il n'y a nulle part où aller.
- **Cadenas** — à gauche, 20 pixels. Gris sombre et `V` verrouillé, jaune et
  `L` libre ; ouvert, il sert aussi de poignée.
- **Compteur de Symboles des rois** — à droite. Vert, orange ou rouge selon
  `seuilReactifBon` et `seuilReactifFaible`. Il se repeint même en combat : ce
  n'est qu'un texte.

### Mémoire entre les sessions

La SavedVariables `GestoBene_Etat`, déclarée dans le `.toc`, ne garde que ce
que l'addon produit lui-même : la position du cadre, mémorisée au relâcher
d'un glisser, l'état du cadenas, mémorisé à chaque bascule, et le sceau
choisi au clic droit. Tous l'emportent sur `Config.lua` dès qu'ils existent. Rien d'autre n'y entre — en
particulier pas les surcharges par joueur.

Créer les cinq carrés d'emblée, puis n'en montrer qu'une partie, est un choix
délibéré : créer un bouton protégé en combat est impossible, alors que le
`Show` / `Hide` différé se traite avec la même file d'attente que les attributs
(section 9).

### Couleurs

| État | Rendu |
|---|---|
| `posee` | Fond vert sombre, texte clair |
| `bientot` | Bord orange, temps en orange |
| `absente` | Fond rouge, « X », clignotement lent (une pulsation par seconde) |
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

Le clic droit ne pose la supérieure que si elle est apprise, qu'il reste un
symbole, et que `Suivi.SuperieurePermise` l'autorise — aucun autre porteur de
la même classe n'attend une bénédiction différente. Sinon `spell2` reçoit le
nom de la normale : le clic droit se dégrade au lieu de ne rien faire, ou de
casser le choix d'un autre joueur.

L'addon ne vérifie ni la portée, ni la ligne de vue, ni le mana. C'est le rôle
du jeu, qui refusera le lancement avec son propre message.

## 9. Le verrou de combat

C'est la seule difficulté réelle de l'addon.

Deux opérations sont interdites en combat sur un bouton protégé :

1. **changer ses attributs** — or `spell` dépend de la bénédiction attendue
   pour l'occupant ;
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
la composition du groupe, les sorts appris, le stock de symboles ou un choix de
bascule changent. Les deux passent par la même file.

Procédure :

1. `PARTY_MEMBERS_CHANGED`, `SPELLS_CHANGED`, `BAG_UPDATE` ou un clic sur une
   bascule demandent une reprogrammation — attributs et visibilité.
2. Si `InCombatLockdown()` est faux, elle se fait tout de suite.
3. Sinon, si l'ensemble visé diffère de ce qui est déjà appliqué, un drapeau
   `reprogrammationEnAttente` est levé, et les carrés déjà visibles passent en
   rendu « en attente » (bordure jaune). Un `BAG_UPDATE` de butin qui ne change
   rien ne lève donc pas le drapeau.
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
| `UNIT_AURA` | Relire la seule unité concernée, si elle est à nous ; pour `player`, repeindre aussi le carré de sceau |
| `SPELLS_CHANGED` | Re-résoudre les sorts appris (niveau, nouveau rang) |
| `ACTIVE_TALENT_GROUP_CHANGED` | Re-résoudre après un basculement de double spé |
| `BAG_UPDATE` | Recompter les symboles, repeindre le compteur |
| `PLAYER_REGEN_ENABLED` | Vider la file de reprogrammation |

`PARTY_MEMBERS_CHANGED` est bien le nom de l'événement en 3.3.5a —
`GROUP_ROSTER_UPDATE` n'existe qu'à partir de la 5.0.

`PLAYER_REGEN_DISABLED` n'est volontairement pas enregistré : rien dans
l'addon n'a besoin de savoir *quand* le combat commence, seulement de savoir
*si* on y est au moment d'agir, et `InCombatLockdown()` répond à cette
question directement, sans état à tenir à jour ni risque de le désynchroniser
de la réalité du jeu.

### Rafraîchissement

`UNIT_AURA` dit *quand* un buff change. Un `OnUpdate` limité à 0,2 seconde ne
repeint que le texte du décompte et le clignotement, sans relire aucun buff. Le
balayage des auras n'a donc lieu que sur événement.

### Commandes

| Commande | Effet |
|---|---|
| `/gesto` | Montrer ou cacher le cadre |
| `/gesto sorts` | Imprimer la résolution des identifiants et l'état appris, sceaux compris |
| `/gesto pos` | Imprimer l'ancrage courant à recopier dans `Config.lua` |
| `/gesto etat` | Imprimer, pour chaque membre, classe, bénédiction attendue, état |

`/gesto` est la commande principale ; `/ben` est un alias court, plus rapide à
taper en jeu.

`/gesto pos` servait à l'origine à recopier la position dans `Config.lua`,
faute de SavedVariables. Depuis que `GestoBene_Etat` mémorise la position, ce
n'est plus nécessaire ; la commande reste utile pour fixer l'ancrage de départ
d'une nouvelle installation.

`/gesto etat` montre la bénédiction attendue, surcharge comprise : on y voit qui
est dévié de la règle de classe.

## 11. Tests

Lua 5.1.5 étant sur le poste, `Sorts.lua` et `Suivi.lua` se testent hors du jeu,
avec le vrai interpréteur, en TDD — le test d'abord, à chaque fois.

```
tests/
├── faux-api.lua          faux de l'API WoW
└── tests.lua             les cas, lancés par « lua tests.lua »
```

Le faux couvre `UnitBuff`, `UnitClass`, `UnitExists`, `UnitName`,
`GetSpellInfo`, `GetTime`, `GetItemCount`, `GetItemInfo`. Il est piloté par une table décrivant le groupe et les buffs,
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
16. Une surcharge nominative l'emporte sur la classe, et deux joueurs de même
    classe peuvent diverger.
17. Une supérieure est refusée quand deux porteurs de même classe attendent des
    bénédictions différentes, permise quand la classe est unanime ou seule.
18. Une bénédiction est reconnue par son nom quel que soit son rang, et la
    supérieure est distinguée de la normale.
19. Le cycle des sceaux ne passe que par les sceaux appris ; un sceau mal
    configuré tombe sur Sagesse.
20. Le sceau choisi vient de `GestoBene_Etat` s'il est connu, sinon de
    `Config` ; le carré de sceau rend `absente`, `posee`, `bientot` ou `mauvaise`, et
    ni le sceau ni la bénédiction de sagesse ne passent l'un pour l'autre.

Cette liste donne les familles de cas ; `lua tests.lua` en compte 76 au
2026-09-28.

`Cadre.lua` et `GestoBene.lua` ne sont pas couverts : ils touchent l'API
graphique et le système d'événements, qu'on ne simule pas raisonnablement.
Aucun des deux ne porte de règle de résolution de bénédiction — c'est tout ce
que ce choix garantit. `Cadre.lua` contient tout de même des décisions
d'affichage assumées et non testées (section 4). Ils se vérifient en jeu.

### Vérification en jeu

Une fois les tests au vert, la recette manuelle tient en huit points :

1. Le cadre apparaît à la connexion.
2. **Seul en ville, un unique carré s'affiche** — celui de Kahalie.
3. `/gesto sorts` montre des identifiants valides.
4. Un clic gauche pose la bonne bénédiction et le décompte démarre.
5. Un clic droit pose la supérieure et consomme un symbole.
   Avec deux joueurs de même classe basculés sur des bénédictions
   différentes, il pose la normale et le carré de l'autre ne change pas.
6. **Entrer en groupe hors combat fait apparaître les carrés manquants** et
   élargit le cadre.
7. Entrer en combat après un changement de groupe affiche la bordure jaune sans
   provoquer d'erreur Lua, et le rendu se corrige à la fin du combat.
8. Le carré de sceau décompte le sceau posé ; un clic droit passe au suivant et
   le choix survit au `/reload`. En combat, le clic droit change l'affichage
   tout de suite, le borde de jaune, et le clic gauche lance le nouveau
   sceau à la fin du combat.

## 12. Hors périmètre

Retiré volontairement, faute d'usage établi :

- Annonce dans le canal du groupe.
- Bénédiction automatique sans clic.
- Coordination entre plusieurs paladins.
- Raid à 40, et donc plus de cinq carrés.
- Exceptions par rôle — la bascule par nom de joueur, ajoutée depuis, couvre
  le besoin en donjon 5.

## 13. Risques

| Risque | Parade |
|---|---|
| Identifiants de sorts faux | `/gesto sorts` les montre ; une entrée non résolue est ignorée, pas fatale |
| Une bénédiction apprise plus tard (supérieure des Rois à 60, Sanctuaire au changement de spé) | `SPELLS_CHANGED` re-résout la table ; le carré s'allume sans rien éditer |
| Changement de groupe en combat | Rendu « en attente », reprogrammation différée à `PLAYER_REGEN_ENABLED` |
| `Show` / `Hide` interdits en combat sur un bouton protégé | Les cinq carrés sont créés hors combat une fois pour toutes ; seule leur visibilité varie, par la même file d'attente |
| `UnitBuff` muet sur une unité hors de portée | Pas de rebasculement en `absente` : le carré garde son dernier état connu, `Cadre.Rafraichir` continue le décompte depuis l'expiration mémorisée sans relire de buff, jusqu'au prochain `UNIT_AURA` qui, lui, dira la vérité |
| Identifiants de sceaux non relevés en jeu | `/gesto sorts` les imprime ; un sceau que le client ignore sort du cycle |
| Une supérieure écrase la bénédiction d'un autre joueur de la même classe | `Suivi.SuperieurePermise` fait retomber le clic droit sur la normale |
| Le dossier du client n'est pas sous git | L'addon vit dans ce dépôt ; `installer.sh` le recopie dans le client |
