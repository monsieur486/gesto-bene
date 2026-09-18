# Addon GestoBene — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un addon WoW 3.3.5a qui affiche un carré par membre du groupe avec la bénédiction que sa classe commande et le temps restant, et qui lance cette bénédiction au clic.

**Architecture:** Deux modules purs (`Sorts`, `Suivi`) qui ne touchent aucun cadre et se testent hors du jeu avec le Lua 5.1.5 du poste ; deux modules d'interface (`Cadre`, `GestoBene`) qui ne portent aucune décision. Les cinq carrés sont des `SecureActionButtonTemplate` créés une fois pour toutes hors combat ; seules leur visibilité et leurs attributs de sort varient, par une file d'attente qui se vide à `PLAYER_REGEN_ENABLED`.

**Tech Stack:** Lua 5.1 ; API WoW 3.3.5a (Interface 30300) ; aucune bibliothèque externe, aucune SavedVariables ; tests lancés par `lua tests.lua` sans le jeu.

**Spec:** `docs/conception.md`

## Global Constraints

- **Lua 5.1 uniquement.** Pas de `goto`, pas d'opérateur `#` sur les tables à trous, pas de `table.unpack` (c'est `unpack`). Le poste a `/usr/bin/lua` en 5.1.5, la même version que le client.
- **Aucune dépendance.** Ni Ace3, ni LibStub, ni aucune bibliothèque du dossier `AddOns`.
- **Aucune SavedVariables.** Le `.toc` ne déclare aucune variable sauvegardée. L'addon lit `Config.lua`, ne l'écrit jamais.
- **Aucun nom de sort en dur.** Les noms viennent toujours de `GetSpellInfo(identifiant)`. Le client est en `frFR` mais l'addon ne doit contenir aucun nom français de sort.
- **Interface : 30300** dans le `.toc`.
- **Commentaires et messages en français.** Les noms de variables et de fonctions aussi — c'est la convention de ce projet (voir `Config.lua` dans la spec).
- **Identifiants de sorts confirmés en jeu le 2026-09-18**, à utiliser tels quels :
  - `Rois = { normale = 20217, superieure = 25898 }`
  - `Puissance = { normale = 19740, superieure = 25782 }`
  - `Sagesse = { normale = 19742, superieure = 25894 }`
  - `Sanctuaire = { normale = 20911, superieure = 25899 }`
  - réactif `21177` (Symbole des rois)
  - La Lumière (19977 / 25890) **n'existe pas** sur ce client : ne pas l'ajouter.
- **Le Sanctuaire reste dans la table même s'il n'est jamais appris.** Talent de Protection : allumé pendant le leveling en donjon, éteint en Vindicte, et éteint pour de bon au niveau 80 (double spé Vindicte ou Heal prévue). Il se grise seul, ne coûte rien, et évite un travail à refaire.
- **Jetons de classe** attendus : `WARRIOR`, `PALADIN`, `HUNTER`, `ROGUE`, `PRIEST`, `DEATHKNIGHT`, `SHAMAN`, `MAGE`, `WARLOCK`, `DRUID`.
- **Dépôt git :** `/home/mr486/Developpement/Projets/Plugins-Wow/GestoBene`, branche `master`. Le code vit ici ; `./installer.sh` le copie dans le client.
- **Commits en français, Conventional Commits**, contributeur unique `monsieur486`, **sans ligne `Co-Authored-By`** — convention maison du projet.
- **L'addon n'est jamais édité dans `Interface/AddOns/`.** Cette copie est un produit de `installer.sh`, jamais une source.

## Structure des fichiers

| Fichier | Responsabilité | Testé ? |
|---|---|---|
| `GestoBene/GestoBene.toc` | Déclaration, ordre de chargement | non |
| `GestoBene/Config.lua` | Réglages utilisateur | non |
| `GestoBene/Sorts.lua` | Table des bénédictions, résolution des noms, disponibilité | **oui** |
| `GestoBene/Suivi.lua` | Composition du groupe, lecture des buffs, états | **oui** |
| `GestoBene/Cadre.lua` | Cinq carrés, boutons sécurisés, couleurs, file d'attente | non |
| `GestoBene/GestoBene.lua` | Événements, commandes `/gesto` | non |
| `tests/faux-api.lua` | Faux de l'API WoW pour les tests | — |
| `tests/tests.lua` | Les cas de test | — |

---

### Task 1 : Le faux de l'API et le lanceur de tests

Sans ce socle, aucune des tâches suivantes ne peut être testée. Il est donc en premier, et il est lui-même vérifié par un test.

**Files:**
- Create: `tests/faux-api.lua`
- Create: `tests/tests.lua`

**Interfaces:**
- Consumes: rien
- Produits pour les tâches suivantes :
  - `FauxAPI.Installer(monde)` — pose les fonctions globales `GetSpellInfo`, `GetItemCount`, `GetItemInfo`, `UnitClass`, `UnitExists`, `UnitName`, `UnitBuff`, `GetTime` d'après la table `monde`.
  - `FauxAPI.Reinitialiser()` — retire ces globales.
  - Forme de `monde` :
    ```lua
    {
      temps = 1000,                      -- ce que rend GetTime()
      sortsConnus = { [20217] = true },  -- identifiants dans le grimoire
      sortsExistants = { [20217] = "Bénédiction des rois" },
      sacs = { [21177] = 28 },
      unites = {
        player = { classe = "PALADIN", nom = "Kahalie" },
        party1 = { classe = "MAGE",    nom = "Zaza" },
      },
      buffs = {
        player = { { spellId = 20217, duree = 600, expiration = 1300, lanceur = "player" } },
      },
    }
    ```
  - `Test(nom, fonction)` — enregistre un cas.
  - `AssertEgal(obtenu, attendu, message)`, `AssertNil(obtenu, message)`, `AssertVrai(obtenu, message)`.
  - `LancerTests()` — exécute tout, imprime un résumé, rend le nombre d'échecs.

- [ ] **Étape 1 : écrire le test qui échoue**

Créer `tests/tests.lua` avec ce seul contenu pour l'instant :

```lua
-- Tests de l'addon GestoBene, lancés hors du jeu par « lua tests.lua ».
package.path = "./?.lua;" .. package.path
local FauxAPI = require("faux-api")

local cas, echecs = {}, 0

function Test(nom, fonction)
  cas[#cas + 1] = { nom = nom, fonction = fonction }
end

function AssertEgal(obtenu, attendu, message)
  if obtenu ~= attendu then
    error(string.format("%s : attendu <%s>, obtenu <%s>",
      message or "égalité", tostring(attendu), tostring(obtenu)), 2)
  end
end

function AssertNil(obtenu, message)
  if obtenu ~= nil then
    error(string.format("%s : attendu nil, obtenu <%s>",
      message or "nullité", tostring(obtenu)), 2)
  end
end

function AssertVrai(obtenu, message)
  if not obtenu then
    error((message or "vérité") .. " : attendu vrai", 2)
  end
end

-- Le faux doit installer une horloge pilotable.
Test("le faux rend le temps du monde", function()
  FauxAPI.Installer({ temps = 4242 })
  AssertEgal(GetTime(), 4242, "GetTime")
  FauxAPI.Reinitialiser()
end)

-- Le faux doit rendre le nom d'un sort existant, et nil sinon.
Test("le faux resout les sorts existants", function()
  FauxAPI.Installer({ sortsExistants = { [20217] = "Bénédiction des rois" } })
  AssertEgal(GetSpellInfo(20217), "Bénédiction des rois", "sort existant")
  AssertNil(GetSpellInfo(19977), "sort inexistant")
  FauxAPI.Reinitialiser()
end)

-- GetSpellInfo(nom) ne doit répondre que pour un sort appris.
Test("le faux distingue exister et connaitre", function()
  FauxAPI.Installer({
    sortsExistants = { [20217] = "Rois", [25898] = "Rois superieure" },
    sortsConnus    = { [20217] = true },
  })
  AssertEgal(GetSpellInfo("Rois"), "Rois", "sort appris")
  AssertNil(GetSpellInfo("Rois superieure"), "sort non appris")
  FauxAPI.Reinitialiser()
end)

-- UnitBuff doit rendre les onze valeurs du client 3.3.5a, dans l'ordre.
Test("le faux rend onze valeurs pour UnitBuff", function()
  FauxAPI.Installer({
    unites = { player = { classe = "PALADIN", nom = "Kahalie" } },
    buffs  = { player = { { spellId = 20217, duree = 600, expiration = 1300, lanceur = "player" } } },
  })
  local nom, rang, icone, nombre, type_, duree, expiration, lanceur, volable, groupable, spellId = UnitBuff("player", 1)
  AssertEgal(duree, 600, "duree")
  AssertEgal(expiration, 1300, "expiration")
  AssertEgal(lanceur, "player", "lanceur")
  AssertEgal(spellId, 20217, "spellId")
  AssertNil(UnitBuff("player", 2), "au-dela du dernier buff")
  FauxAPI.Reinitialiser()
end)

function LancerTests()
  for _, c in ipairs(cas) do
    local ok, err = pcall(c.fonction)
    if ok then
      print("  ok   " .. c.nom)
    else
      echecs = echecs + 1
      print("  ECHEC " .. c.nom)
      print("        " .. tostring(err))
    end
  end
  print(string.format("\n%d cas, %d echec(s)", #cas, echecs))
  return echecs
end

os.exit(LancerTests() == 0 and 0 or 1)
```

- [ ] **Étape 2 : lancer le test pour vérifier qu'il échoue**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : ÉCHEC, `module 'faux-api' not found`.

- [ ] **Étape 3 : écrire le faux**

Créer `tests/faux-api.lua` :

```lua
-- Faux de l'API WoW 3.3.5a, pour tester la logique pure hors du jeu.
-- Piloté par une table « monde » décrivant sorts, sacs, unités et buffs.
local FauxAPI = {}

local poseees = {}

local function poser(nom, fonction)
  poseees[#poseees + 1] = nom
  _G[nom] = fonction
end

function FauxAPI.Installer(monde)
  monde = monde or {}
  local sortsExistants = monde.sortsExistants or {}
  local sortsConnus    = monde.sortsConnus or {}
  local sacs           = monde.sacs or {}
  local unites         = monde.unites or {}
  local buffs          = monde.buffs or {}

  -- Nom par identifiant pour les sorts appris, afin de répondre à GetSpellInfo(nom).
  local nomsAppris = {}
  for id, connu in pairs(sortsConnus) do
    if connu and sortsExistants[id] then
      nomsAppris[sortsExistants[id]] = true
    end
  end

  poser("GetTime", function() return monde.temps or 0 end)

  -- GetSpellInfo(id) rend le nom même si le sort n'est pas appris.
  -- GetSpellInfo(nom) ne rend quelque chose que si le sort est au grimoire.
  poser("GetSpellInfo", function(cle)
    if type(cle) == "number" then
      return sortsExistants[cle]
    end
    if nomsAppris[cle] then return cle end
    return nil
  end)

  poser("GetItemCount", function(id) return sacs[id] or 0 end)
  poser("GetItemInfo", function(id)
    if sacs[id] then return "Symbole des rois" end
    return nil
  end)

  poser("UnitExists", function(unite) return unites[unite] ~= nil end)
  poser("UnitName", function(unite)
    local u = unites[unite]
    return u and u.nom or nil
  end)
  -- UnitClass rend le nom localisé puis le jeton ; seul le jeton nous sert.
  poser("UnitClass", function(unite)
    local u = unites[unite]
    if not u then return nil end
    return u.classe, u.classe
  end)

  -- Onze valeurs, dans l'ordre du client 3.3.5a.
  poser("UnitBuff", function(unite, index)
    local liste = buffs[unite]
    local b = liste and liste[index]
    if not b then return nil end
    return sortsExistants[b.spellId] or ("sort " .. b.spellId),
           b.rang or "",
           b.icone or "",
           b.nombre or 0,
           nil,
           b.duree,
           b.expiration,
           b.lanceur,
           false,
           false,
           b.spellId
  end)
end

function FauxAPI.Reinitialiser()
  for _, nom in ipairs(poseees) do _G[nom] = nil end
  poseees = {}
end

return FauxAPI
```

- [ ] **Étape 4 : lancer les tests pour vérifier qu'ils passent**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : `4 cas, 0 echec(s)`, code de sortie 0.

- [ ] **Étape 5 : commit**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene
lua -e 'os.exit(0)' && (cd tests && lua tests.lua)
git add tests/faux-api.lua tests/tests.lua
git commit -m "test: ajoute le faux de l'API WoW et le lanceur de tests"
```

Attendu : les 4 cas passent, puis le commit est créé.

---

### Task 2 : Config.lua et le squelette de l'addon

Produit un addon qui se charge en jeu sans rien faire d'autre qu'exister. C'est le premier jalon vérifiable dans le client.

**Files:**
- Create: `GestoBene/GestoBene.toc`
- Create: `GestoBene/Config.lua`
- Create: `GestoBene/GestoBene.lua`
- Modify: `tests/tests.lua` (ajouter le chargement de `Config.lua`)

**Interfaces:**
- Consumes: rien
- Produces:
  - `GestoBene_Config.parClasse` — table jeton de classe → clé de bénédiction
  - `GestoBene_Config.seuilAlerte` — nombre de secondes
  - `GestoBene_Config.ancrage` — `{ point = "CENTER", x = 0, y = -200 }`
  - `GestoBene_Config.tailleCarre` — nombre de pixels
  - `GestoBene` — table globale de l'addon, vide à ce stade

- [ ] **Étape 1 : écrire le test qui échoue**

Ajouter dans `tests/tests.lua`, juste avant `function LancerTests()` :

```lua
-- Config.lua doit se charger seul, sans API WoW, et fournir les dix classes.
Test("la config fournit les dix classes", function()
  dofile("../GestoBene/Config.lua")
  local attendues = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
                      "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
  for _, jeton in ipairs(attendues) do
    AssertVrai(GestoBene_Config.parClasse[jeton], "classe " .. jeton)
  end
  AssertEgal(GestoBene_Config.seuilAlerte, 60, "seuil")
  AssertEgal(GestoBene_Config.tailleCarre, 48, "taille")
  AssertEgal(GestoBene_Config.ancrage.point, "CENTER", "ancrage")
end)
```

- [ ] **Étape 2 : lancer le test pour vérifier qu'il échoue**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : ÉCHEC sur le nouveau cas, `cannot open ../GestoBene/Config.lua`.

- [ ] **Étape 3 : écrire les trois fichiers**

`GestoBene/GestoBene.toc` :

```
## Interface: 30300
## Title: GestoBene
## Notes: Suivi des benedictions du groupe, un carre par membre.
## Author: monsieur486
## Version: 1.0

Config.lua
Sorts.lua
Suivi.lua
Cadre.lua
GestoBene.lua
```

`GestoBene/Config.lua` :

```lua
-- Réglages de l'addon GestoBene.
-- C'est le seul fichier destiné à être édité à la main, hors du jeu.
-- Un changement prend effet au /reload ou à la reconnexion.

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

  -- Position du cadre. « /gesto pos » imprime les valeurs courantes à recopier.
  ancrage = { point = "CENTER", x = 0, y = -200 },

  -- Taille d'un carré, en pixels.
  tailleCarre = 48,
}
```

`GestoBene/GestoBene.lua` :

```lua
-- Addon GestoBene : point d'entrée.
-- Les événements et les commandes arrivent à la tâche 6.

GestoBene = GestoBene or {}
```

- [ ] **Étape 4 : lancer les tests pour vérifier qu'ils passent**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : `5 cas, 0 echec(s)`.

- [ ] **Étape 5 : vérifier la syntaxe puis commiter**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene
for f in GestoBene/*.lua; do lua -e 'assert(loadfile("'"$f"'"))' && echo "$f OK"; done
git add GestoBene/GestoBene.toc GestoBene/Config.lua GestoBene/GestoBene.lua tests/tests.lua
git commit -m "feat: ajoute le squelette de l'addon et sa configuration par classe"
```

Attendu : chaque fichier annoncé `OK`, puis le commit est créé.

---

### Task 3 : Sorts.lua — résolution et disponibilité

**Files:**
- Create: `GestoBene/Sorts.lua`
- Modify: `tests/tests.lua`

**Interfaces:**
- Consumes: `GestoBene_Config.parClasse` (tâche 2) ; `GetSpellInfo`, `GetItemCount` (faux de la tâche 1)
- Produces:
  - `GestoBene_Sorts.table` — `{ [cle] = { normale = id, superieure = id } }`
  - `GestoBene_Sorts.reactif` — `21177`
  - `GestoBene_Sorts.Abreger(cle)` → `"ROI"` / `"PUI"` / `"SAG"` / `"SAN"`, ou `"?"`
  - `GestoBene_Sorts.Resoudre()` → remplit un cache interne ; à appeler à la connexion et à `SPELLS_CHANGED`
  - `GestoBene_Sorts.Etat(cle)` → `{ nomNormale, nomSuperieure, normaleApprise, superieureApprise, existe }`
  - `GestoBene_Sorts.NomAUtiliser(cle, veutSuperieure)` → nom de sort à poser dans l'attribut, ou `nil` si rien n'est lançable. Avec `veutSuperieure` vrai mais la supérieure non apprise ou sans réactif, **rend le nom de la normale** (repli).
  - `GestoBene_Sorts.ValiderConfig()` → liste de messages d'avertissement (vide si tout va bien) ; une classe mal configurée est ramenée à `"Puissance"` dans `GestoBene_Config.parClasse`
  - `GestoBene_Sorts.CleParSpellId(spellId)` → clé de bénédiction, ou `nil`

- [ ] **Étape 1 : écrire les tests qui échouent**

Ajouter dans `tests/tests.lua`, avant `function LancerTests()` :

```lua
-- Le monde de référence : Kahalie niveau 55, Vindicte, relevé du 2026-09-18.
local function MondeKahalie55()
  return {
    temps = 1000,
    sortsExistants = {
      [20217] = "Bénédiction des rois",
      [25898] = "Bénédiction des rois supérieure",
      [19740] = "Bénédiction de puissance",
      [25782] = "Bénédiction de puissance supérieure",
      [19742] = "Bénédiction de sagesse",
      [25894] = "Bénédiction de sagesse supérieure",
      [20911] = "Bénédiction du sanctuaire",
      [25899] = "Bénédiction du sanctuaire supérieure",
    },
    sortsConnus = {
      [20217] = true, [19740] = true, [25782] = true,
      [19742] = true, [25894] = true,
      -- 25898 non : demande le niveau 60
      -- 20911 et 25899 non : talent de Protection
    },
    sacs = { [21177] = 28 },
  }
end

local function ChargerSorts(monde)
  FauxAPI.Installer(monde)
  dofile("../GestoBene/Config.lua")
  dofile("../GestoBene/Sorts.lua")
  GestoBene_Sorts.Resoudre()
end

Test("un sort appris est marque appris", function()
  ChargerSorts(MondeKahalie55())
  local etat = GestoBene_Sorts.Etat("Puissance")
  AssertVrai(etat.existe, "Puissance existe")
  AssertVrai(etat.normaleApprise, "Puissance normale apprise")
  AssertVrai(etat.superieureApprise, "Puissance superieure apprise")
  AssertEgal(etat.nomNormale, "Bénédiction de puissance", "nom normale")
  FauxAPI.Reinitialiser()
end)

Test("un sort non appris est distingue d un sort inexistant", function()
  ChargerSorts(MondeKahalie55())
  local sanctuaire = GestoBene_Sorts.Etat("Sanctuaire")
  AssertVrai(sanctuaire.existe, "Sanctuaire existe sur ce client")
  AssertEgal(sanctuaire.normaleApprise, false, "Sanctuaire non appris")
  AssertNil(GestoBene_Sorts.Etat("Lumiere"), "Lumiere absente de la table")
  FauxAPI.Reinitialiser()
end)

Test("un identifiant que le client ignore est retire sans erreur", function()
  local monde = MondeKahalie55()
  monde.sortsExistants[25899] = nil  -- comme si le client ignorait cet id
  ChargerSorts(monde)
  local etat = GestoBene_Sorts.Etat("Sanctuaire")
  AssertVrai(etat.existe, "la normale existe encore")
  AssertNil(etat.nomSuperieure, "la superieure disparait")
  AssertEgal(etat.superieureApprise, false, "superieure non apprise")
  FauxAPI.Reinitialiser()
end)

-- Le cas du jour : à 55, la supérieure des Rois n'est pas apprise.
Test("le clic droit se replie sur la normale quand la superieure manque", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.NomAUtiliser("Rois", true),
             "Bénédiction des rois", "repli des Rois")
  AssertEgal(GestoBene_Sorts.NomAUtiliser("Puissance", true),
             "Bénédiction de puissance supérieure", "Puissance superieure")
  FauxAPI.Reinitialiser()
end)

Test("sans reactif la superieure se replie aussi", function()
  local monde = MondeKahalie55()
  monde.sacs[21177] = 0
  ChargerSorts(monde)
  AssertEgal(GestoBene_Sorts.NomAUtiliser("Puissance", true),
             "Bénédiction de puissance", "repli faute de symbole")
  FauxAPI.Reinitialiser()
end)

Test("une benediction totalement inconnue ne rend aucun nom", function()
  ChargerSorts(MondeKahalie55())
  AssertNil(GestoBene_Sorts.NomAUtiliser("Sanctuaire", false), "Sanctuaire non lancable")
  FauxAPI.Reinitialiser()
end)

Test("une classe mal configuree tombe sur Puissance avec un avertissement", function()
  FauxAPI.Installer(MondeKahalie55())
  dofile("../GestoBene/Config.lua")
  GestoBene_Config.parClasse.MAGE = "Lumiere"
  GestoBene_Config.parClasse.ZORGLUB = "Rois"
  dofile("../GestoBene/Sorts.lua")
  GestoBene_Sorts.Resoudre()
  local avertissements = GestoBene_Sorts.ValiderConfig()
  AssertEgal(#avertissements, 2, "deux avertissements")
  AssertEgal(GestoBene_Config.parClasse.MAGE, "Puissance", "repli du mage")
  FauxAPI.Reinitialiser()
end)

Test("un spellId se retrouve dans sa benediction", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.CleParSpellId(25894), "Sagesse", "sagesse superieure")
  AssertEgal(GestoBene_Sorts.CleParSpellId(20217), "Rois", "rois normale")
  AssertNil(GestoBene_Sorts.CleParSpellId(12345), "sort etranger")
  FauxAPI.Reinitialiser()
end)

Test("les abreviations font trois lettres", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.Abreger("Rois"), "ROI", "ROI")
  AssertEgal(GestoBene_Sorts.Abreger("Sanctuaire"), "SAN", "SAN")
  AssertEgal(GestoBene_Sorts.Abreger("Inexistante"), "?", "inconnue")
  FauxAPI.Reinitialiser()
end)
```

- [ ] **Étape 2 : lancer les tests pour vérifier qu'ils échouent**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : ÉCHEC sur les neuf nouveaux cas, `cannot open ../GestoBene/Sorts.lua`.

- [ ] **Étape 3 : écrire Sorts.lua**

```lua
-- Table des bénédictions et résolution de leurs noms.
-- Aucun nom de sort n'est écrit en dur : ils viennent tous de GetSpellInfo.
-- Identifiants relevés sur le client le 2026-09-18.

GestoBene_Sorts = GestoBene_Sorts or {}
local Sorts = GestoBene_Sorts

Sorts.table = {
  Rois       = { normale = 20217, superieure = 25898 },
  Puissance  = { normale = 19740, superieure = 25782 },
  Sagesse    = { normale = 19742, superieure = 25894 },
  Sanctuaire = { normale = 20911, superieure = 25899 },
}

-- Symbole des rois, réactif des bénédictions supérieures.
Sorts.reactif = 21177

local ABREVIATIONS = {
  Rois = "ROI", Puissance = "PUI", Sagesse = "SAG", Sanctuaire = "SAN",
}

-- Cache rempli par Resoudre(), relu par Etat() et NomAUtiliser().
local etats = {}
local parSpellId = {}

function Sorts.Abreger(cle)
  return ABREVIATIONS[cle] or "?"
end

-- Un sort existe si GetSpellInfo(id) rend un nom ; il est appris si
-- GetSpellInfo(nom) rend quelque chose à son tour.
local function ResoudreUn(id)
  if not id then return nil, false end
  local nom = GetSpellInfo(id)
  if not nom then return nil, false end
  return nom, GetSpellInfo(nom) ~= nil
end

function Sorts.Resoudre()
  etats = {}
  parSpellId = {}
  for cle, ids in pairs(Sorts.table) do
    local nomNormale,    normaleApprise    = ResoudreUn(ids.normale)
    local nomSuperieure, superieureApprise = ResoudreUn(ids.superieure)
    if nomNormale or nomSuperieure then
      etats[cle] = {
        nomNormale = nomNormale,
        nomSuperieure = nomSuperieure,
        normaleApprise = normaleApprise,
        superieureApprise = superieureApprise,
        existe = true,
      }
      if nomNormale then parSpellId[ids.normale] = cle end
      if nomSuperieure then parSpellId[ids.superieure] = cle end
    end
  end
end

function Sorts.Etat(cle)
  return etats[cle]
end

function Sorts.CleParSpellId(spellId)
  return parSpellId[spellId]
end

-- Rend le nom du sort à poser dans l'attribut du bouton.
-- Le clic droit demande la supérieure ; faute de sort appris ou de réactif,
-- il se replie sur la normale plutôt que de ne rien faire.
function Sorts.NomAUtiliser(cle, veutSuperieure)
  local etat = etats[cle]
  if not etat then return nil end
  if veutSuperieure
     and etat.superieureApprise
     and GetItemCount(Sorts.reactif) > 0 then
    return etat.nomSuperieure
  end
  if etat.normaleApprise then return etat.nomNormale end
  return nil
end

-- Vérifie GestoBene_Config.parClasse et ramène les valeurs fautives
-- sur "Puissance". Rend la liste des messages à imprimer dans le chat.
local CLASSES = {
  "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
  "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

function Sorts.ValiderConfig()
  local avertissements = {}
  local connues = {}
  for _, jeton in ipairs(CLASSES) do connues[jeton] = true end

  for jeton, cle in pairs(GestoBene_Config.parClasse) do
    if not connues[jeton] then
      avertissements[#avertissements + 1] =
        "classe inconnue dans Config.lua : " .. tostring(jeton)
    elseif not Sorts.table[cle] then
      avertissements[#avertissements + 1] =
        "benediction inconnue pour " .. jeton .. " : " .. tostring(cle) .. ", repli sur Puissance"
      GestoBene_Config.parClasse[jeton] = "Puissance"
    end
  end
  return avertissements
end
```

- [ ] **Étape 4 : lancer les tests pour vérifier qu'ils passent**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : `14 cas, 0 echec(s)`.

- [ ] **Étape 5 : commit**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene
(cd tests && lua tests.lua)
git add GestoBene/Sorts.lua tests/tests.lua
git commit -m "feat: resout les benedictions et leur disponibilite"
```

Attendu : les 14 cas passent, puis le commit est créé.

---

### Task 4 : Suivi.lua — composition du groupe et lecture des buffs

**Files:**
- Create: `GestoBene/Suivi.lua`
- Modify: `tests/tests.lua`

**Interfaces:**
- Consumes: `GestoBene_Sorts.CleParSpellId`, `GestoBene_Sorts.Etat` (tâche 3) ; `GestoBene_Config.parClasse` (tâche 2) ; `UnitExists`, `UnitClass`, `UnitName`, `UnitBuff`, `GetTime`
- Produces:
  - `GestoBene_Suivi.UNITES` — `{ "player", "party1", "party2", "party3", "party4" }`, l'ordre des carrés
  - `GestoBene_Suivi.Membres()` → liste ordonnée des unités existantes ; `{ "player" }` en solo
  - `GestoBene_Suivi.Attendue(unite)` → clé de bénédiction voulue pour cette unité, ou `nil`
  - `GestoBene_Suivi.LireUnite(unite)` → `{ cle, restant, duree, expiration }` de **notre** bénédiction sur l'unité, ou `nil`
  - `GestoBene_Suivi.Etat(unite)` → `{ etat, cle, clePortee, restant, expiration, nom }` où `etat` vaut `"vide"`, `"absente"`, `"mauvaise"`, `"bientot"` ou `"posee"`

`expiration` est l'heure absolue de fin, telle que `UnitBuff` la rend, ou `nil`
si la durée est indéterminée. C'est elle qui permet à `Cadre.Rafraichir()`
(tâche 5) de recalculer le décompte sans relire aucun buff.

- [ ] **Étape 1 : écrire les tests qui échouent**

Ajouter dans `tests/tests.lua`, avant `function LancerTests()` :

```lua
local function ChargerSuivi(monde)
  FauxAPI.Installer(monde)
  dofile("../GestoBene/Config.lua")
  dofile("../GestoBene/Sorts.lua")
  dofile("../GestoBene/Suivi.lua")
  GestoBene_Sorts.Resoudre()
end

local function MondeGroupe()
  local monde = MondeKahalie55()
  monde.unites = {
    player = { classe = "PALADIN", nom = "Kahalie" },
    party1 = { classe = "WARRIOR", nom = "Gorkk" },
    party2 = { classe = "MAGE",    nom = "Zaza" },
  }
  monde.buffs = {}
  return monde
end

Test("en solo un seul membre", function()
  local monde = MondeKahalie55()
  monde.unites = { player = { classe = "PALADIN", nom = "Kahalie" } }
  ChargerSuivi(monde)
  local membres = GestoBene_Suivi.Membres()
  AssertEgal(#membres, 1, "un seul membre")
  AssertEgal(membres[1], "player", "c est le joueur")
  FauxAPI.Reinitialiser()
end)

Test("a trois les membres sont contigus et dans l ordre", function()
  ChargerSuivi(MondeGroupe())
  local membres = GestoBene_Suivi.Membres()
  AssertEgal(#membres, 3, "trois membres")
  AssertEgal(membres[1], "player", "1")
  AssertEgal(membres[2], "party1", "2")
  AssertEgal(membres[3], "party2", "3")
  FauxAPI.Reinitialiser()
end)

Test("la classe donne la benediction attendue", function()
  ChargerSuivi(MondeGroupe())
  AssertEgal(GestoBene_Suivi.Attendue("party2"), "Sagesse", "mage")
  AssertEgal(GestoBene_Suivi.Attendue("party1"), "Puissance", "guerrier")
  AssertNil(GestoBene_Suivi.Attendue("party3"), "unite absente")
  FauxAPI.Reinitialiser()
end)

Test("une unite inexistante est vide", function()
  ChargerSuivi(MondeGroupe())
  AssertEgal(GestoBene_Suivi.Etat("party4").etat, "vide", "party4")
  FauxAPI.Reinitialiser()
end)

Test("une benediction d un autre paladin ne compte pas", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 19742, duree = 600, expiration = 1500, lanceur = "party3" },
  }
  ChargerSuivi(monde)
  AssertNil(GestoBene_Suivi.LireUnite("party2"), "buff etranger ignore")
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "absente", "donc absente")
  FauxAPI.Reinitialiser()
end)

Test("le temps restant se calcule depuis l expiration", function()
  local monde = MondeGroupe()          -- temps = 1000
  monde.buffs.party2 = {
    { spellId = 19742, duree = 600, expiration = 1500, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.LireUnite("party2").restant, 500, "500 s restantes")
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "posee", "au-dessus du seuil")
  FauxAPI.Reinitialiser()
end)

Test("un restant negatif est ramene a zero", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 19742, duree = 600, expiration = 900, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.LireUnite("party2").restant, 0, "jamais negatif")
  FauxAPI.Reinitialiser()
end)

Test("sous le seuil l etat passe a bientot", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 19742, duree = 600, expiration = 1030, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "bientot", "30 s restantes")
  FauxAPI.Reinitialiser()
end)

Test("la mauvaise benediction est signalee comme telle", function()
  local monde = MondeGroupe()
  -- Le mage porte Puissance alors que la config demande Sagesse.
  monde.buffs.party2 = {
    { spellId = 19740, duree = 600, expiration = 1500, lanceur = "player" },
  }
  ChargerSuivi(monde)
  local etat = GestoBene_Suivi.Etat("party2")
  AssertEgal(etat.etat, "mauvaise", "etat")
  AssertEgal(etat.clePortee, "Puissance", "ce qu il porte")
  AssertEgal(etat.cle, "Sagesse", "ce qu il devrait porter")
  FauxAPI.Reinitialiser()
end)

Test("une expiration nulle rend une duree indeterminee", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 19742, duree = 0, expiration = 0, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertNil(GestoBene_Suivi.LireUnite("party2").restant, "restant indetermine")
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "posee", "posee quand meme")
  FauxAPI.Reinitialiser()
end)

-- L'expiration doit remonter telle quelle : Cadre.Rafraichir en dépend pour
-- recalculer le décompte sans relire les buffs.
Test("l expiration absolue est transmise", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 19742, duree = 600, expiration = 1500, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.LireUnite("party2").expiration, 1500, "expiration")
  AssertEgal(GestoBene_Suivi.Etat("party2").expiration, 1500, "via Etat")
  FauxAPI.Reinitialiser()
end)

Test("une expiration nulle ne remonte pas d expiration", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 19742, duree = 0, expiration = 0, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertNil(GestoBene_Suivi.LireUnite("party2").expiration, "pas d expiration")
  FauxAPI.Reinitialiser()
end)

Test("la superieure compte comme la benediction de sa famille", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 25894, duree = 1800, expiration = 2500, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "posee", "sagesse superieure")
  AssertEgal(GestoBene_Suivi.LireUnite("party2").cle, "Sagesse", "meme famille")
  FauxAPI.Reinitialiser()
end)
```

- [ ] **Étape 2 : lancer les tests pour vérifier qu'ils échouent**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : ÉCHEC sur les onze nouveaux cas, `cannot open ../GestoBene/Suivi.lua`.

- [ ] **Étape 3 : écrire Suivi.lua**

```lua
-- Qui porte quelle bénédiction, et pour combien de temps.
-- Ce fichier ne touche aucun cadre : il reçoit des données, il en rend.

GestoBene_Suivi = GestoBene_Suivi or {}
local Suivi = GestoBene_Suivi

-- L'ordre des carrés, fixé une fois pour toutes.
Suivi.UNITES = { "player", "party1", "party2", "party3", "party4" }

-- Les unités réellement présentes, dans l'ordre. En solo : { "player" }.
-- C'est cette liste qui décide des carrés visibles ; elle vit ici, et non
-- dans Cadre.lua, pour rester testable hors du jeu.
function Suivi.Membres()
  local membres = {}
  for _, unite in ipairs(Suivi.UNITES) do
    if UnitExists(unite) then
      membres[#membres + 1] = unite
    end
  end
  return membres
end

-- La bénédiction que la classe de cette unité commande.
function Suivi.Attendue(unite)
  if not UnitExists(unite) then return nil end
  local _, jeton = UnitClass(unite)
  if not jeton then return nil end
  return GestoBene_Config.parClasse[jeton]
end

-- Notre bénédiction sur cette unité, s'il y en a une.
-- Le filtre sur le lanceur est essentiel : la bénédiction d'un autre paladin
-- ne doit pas faire croire que le travail est fait, puisqu'on ne peut pas
-- la rafraîchir.
function Suivi.LireUnite(unite)
  if not UnitExists(unite) then return nil end
  local index = 1
  while true do
    local nom, _, _, _, _, duree, expiration, lanceur, _, _, spellId = UnitBuff(unite, index)
    if not nom then return nil end
    if lanceur == "player" then
      local cle = GestoBene_Sorts.CleParSpellId(spellId)
      if cle then
        local restant
        if expiration and expiration > 0 then
          restant = expiration - GetTime()
          if restant < 0 then restant = 0 end
        end
        -- Une expiration nulle signifie une durée indéterminée : restant vaut nil.
        local fin = (expiration and expiration > 0) and expiration or nil
        return { cle = cle, restant = restant, duree = duree, expiration = fin }
      end
    end
    index = index + 1
  end
end

-- L'état d'un carré, tel que Cadre.lua le peindra sans rien décider.
function Suivi.Etat(unite)
  if not UnitExists(unite) then
    return { etat = "vide" }
  end

  local attendue = Suivi.Attendue(unite)
  local nom = UnitName(unite)
  local portee = Suivi.LireUnite(unite)

  if not portee then
    return { etat = "absente", cle = attendue, nom = nom }
  end

  if portee.cle ~= attendue then
    return {
      etat = "mauvaise", cle = attendue, clePortee = portee.cle,
      restant = portee.restant, expiration = portee.expiration, nom = nom,
    }
  end

  local etat = "posee"
  if portee.restant and portee.restant < GestoBene_Config.seuilAlerte then
    etat = "bientot"
  end

  return {
    etat = etat, cle = attendue, clePortee = portee.cle,
    restant = portee.restant, expiration = portee.expiration, nom = nom,
  }
end
```

- [ ] **Étape 4 : lancer les tests pour vérifier qu'ils passent**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : `27 cas, 0 echec(s)`.

- [ ] **Étape 5 : commit**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene
(cd tests && lua tests.lua)
git add GestoBene/Suivi.lua tests/tests.lua
git commit -m "feat: suit les benedictions posees sur chaque membre du groupe"
```

Attendu : les 27 cas passent, puis le commit est créé.

---

### Task 5 : Cadre.lua — les carrés, les boutons sécurisés, la file d'attente

Ce fichier touche l'API graphique : il n'est pas couvert par les tests automatiques. Il ne porte donc aucune décision — il lit `GestoBene_Suivi.Etat` et peint.

**Files:**
- Create: `GestoBene/Cadre.lua`

**Interfaces:**
- Consumes: `GestoBene_Suivi.UNITES`, `GestoBene_Suivi.Membres`, `GestoBene_Suivi.Etat` (tâche 4) ; `GestoBene_Sorts.NomAUtiliser`, `GestoBene_Sorts.Abreger` (tâche 3) ; `GestoBene_Config` (tâche 2)
- Produces:
  - `GestoBene_Cadre.Construire()` — crée le cadre parent et les cinq carrés ; à appeler une seule fois, hors combat
  - `GestoBene_Cadre.Reprogrammer()` — met à jour attributs et visibilité, ou met en attente si en combat
  - `GestoBene_Cadre.Peindre()` — relit `Suivi.Etat` pour tous les carrés visibles et repeint ; appelé sur événement, jamais en boucle
  - `GestoBene_Cadre.PeindreUnite(unite)` — relit `Suivi.Etat` pour un carré, peint, et **mémorise l'état sur le carré**
  - `GestoBene_Cadre.Rafraichir()` — recalcule le décompte depuis l'expiration mémorisée et anime le clignotement, **sans lire aucun buff** ; c'est la seule fonction appelée par la boucle de 0,2 s
  - `GestoBene_Cadre.ViderFile()` — appelée à `PLAYER_REGEN_ENABLED`
  - `GestoBene_Cadre.Basculer()` — montre ou cache le cadre parent
  - `GestoBene_Cadre.Position()` → `point, x, y` du cadre parent

- [ ] **Étape 1 : écrire Cadre.lua**

```lua
-- Les cinq carrés : création, attributs sécurisés, couleurs.
-- Aucune décision ici. Tout vient de GestoBene_Suivi et GestoBene_Sorts.

GestoBene_Cadre = GestoBene_Cadre or {}
local Cadre = GestoBene_Cadre

local ECART = 4

local COULEURS = {
  posee    = { 0.10, 0.35, 0.10, 0.85 },
  bientot  = { 0.55, 0.35, 0.05, 0.90 },
  absente  = { 0.55, 0.10, 0.10, 0.90 },
  mauvaise = { 0.50, 0.45, 0.05, 0.90 },
}

local parent, carres, reprogrammationEnAttente = nil, {}, false

-- Format mm:ss. Rend "--:--" quand la durée est indéterminée.
local function FormaterTemps(restant)
  if not restant then return "--:--" end
  local minutes = math.floor(restant / 60)
  local secondes = math.floor(restant % 60)
  return string.format("%d:%02d", minutes, secondes)
end

local function CreerCarre(unite, index)
  local taille = GestoBene_Config.tailleCarre
  local carre = CreateFrame("Button", "GestoBeneCarre" .. index, parent,
                            "SecureActionButtonTemplate")
  carre:SetWidth(taille)
  carre:SetHeight(taille)
  carre:RegisterForClicks("AnyUp")

  -- La cible est gravée une fois pour toutes : elle ne changera jamais.
  -- C'est l'invariant qui rend l'addon compatible avec le verrou de combat.
  carre:SetAttribute("unit", unite)
  carre:SetAttribute("type1", "spell")
  carre:SetAttribute("type2", "spell")

  carre.fond = carre:CreateTexture(nil, "BACKGROUND")
  carre.fond:SetAllPoints(carre)
  carre.fond:SetTexture(0, 0, 0, 0.8)

  carre.bordure = CreateFrame("Frame", nil, carre)
  carre.bordure:SetAllPoints(carre)
  carre.bordure:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
  })
  carre.bordure:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

  carre.abreviation = carre:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  carre.abreviation:SetPoint("TOP", carre, "TOP", 0, -3)

  carre.temps = carre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  carre.temps:SetPoint("CENTER", carre, "CENTER", 0, -2)

  carre.nom = carre:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  carre.nom:SetPoint("TOP", carre, "BOTTOM", 0, -2)

  carre.unite = unite
  return carre
end

-- Crée le cadre parent et les cinq carrés. À n'appeler qu'une fois, hors
-- combat : créer un bouton protégé pendant un combat est impossible.
function Cadre.Construire()
  if parent then return end

  local ancrage = GestoBene_Config.ancrage
  parent = CreateFrame("Frame", "GestoBeneCadre", UIParent)
  parent:SetPoint(ancrage.point, UIParent, ancrage.point, ancrage.x, ancrage.y)
  parent:SetHeight(GestoBene_Config.tailleCarre + 16)
  parent:SetWidth(GestoBene_Config.tailleCarre)
  parent:SetMovable(true)
  parent:EnableMouse(true)
  parent:RegisterForDrag("LeftButton")
  parent:SetScript("OnDragStart", function(self) self:StartMoving() end)
  parent:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  for index, unite in ipairs(GestoBene_Suivi.UNITES) do
    carres[unite] = CreerCarre(unite, index)
  end

  Cadre.Reprogrammer()
end

-- Place les carrés visibles côte à côte et ajuste la largeur du parent.
local function Disposer(membres)
  local taille = GestoBene_Config.tailleCarre
  local decalage = 0
  for _, unite in ipairs(membres) do
    local carre = carres[unite]
    carre:ClearAllPoints()
    carre:SetPoint("LEFT", parent, "LEFT", decalage, 0)
    decalage = decalage + taille + ECART
  end
  local largeur = decalage - ECART
  if largeur < taille then largeur = taille end
  parent:SetWidth(largeur)
end

-- Met à jour les attributs de sort et la visibilité. Les deux opérations sont
-- interdites en combat sur un bouton protégé : si le verrou est posé, on met
-- en attente et PLAYER_REGEN_ENABLED finira le travail.
function Cadre.Reprogrammer()
  if not parent then return end

  if InCombatLockdown() then
    reprogrammationEnAttente = true
    for _, carre in pairs(carres) do
      if carre:IsShown() then
        carre.bordure:SetBackdropBorderColor(0.6, 0.6, 0.2, 1)
      end
    end
    return
  end

  reprogrammationEnAttente = false
  local membres = GestoBene_Suivi.Membres()
  local visible = {}
  for _, unite in ipairs(membres) do visible[unite] = true end

  for unite, carre in pairs(carres) do
    if visible[unite] then
      local cle = GestoBene_Suivi.Attendue(unite)
      carre:SetAttribute("spell1", cle and GestoBene_Sorts.NomAUtiliser(cle, false) or nil)
      carre:SetAttribute("spell2", cle and GestoBene_Sorts.NomAUtiliser(cle, true) or nil)
      carre:Show()
    else
      carre:Hide()
    end
  end

  Disposer(membres)
  Cadre.Peindre()
end

function Cadre.ViderFile()
  if reprogrammationEnAttente then
    Cadre.Reprogrammer()
  end
end

-- Lit l'état d'une unité et peint son carré. Mémorise l'état sur le carré
-- pour que Rafraichir puisse travailler ensuite sans relire les buffs.
function Cadre.PeindreUnite(unite)
  local carre = carres[unite]
  if not carre or not carre:IsShown() then return end

  local etat = GestoBene_Suivi.Etat(unite)
  carre.cache = etat
  carre.nom:SetText(etat.nom or "")

  if etat.etat == "absente" then
    carre.fond:SetTexture(unpack(COULEURS.absente))
    carre.abreviation:SetText(etat.cle and GestoBene_Sorts.Abreger(etat.cle) or "?")
    carre.temps:SetText("MANQUE")
  elseif etat.etat == "mauvaise" then
    carre.fond:SetTexture(unpack(COULEURS.mauvaise))
    carre.abreviation:SetText(GestoBene_Sorts.Abreger(etat.clePortee))
    carre.temps:SetText(FormaterTemps(etat.restant))
  else
    carre.fond:SetTexture(unpack(COULEURS[etat.etat]))
    carre.abreviation:SetText(GestoBene_Sorts.Abreger(etat.cle))
    carre.temps:SetText(FormaterTemps(etat.restant))
  end

  if not reprogrammationEnAttente then
    carre.bordure:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  end
end

function Cadre.Peindre()
  if not parent then return end
  for _, unite in ipairs(GestoBene_Suivi.Membres()) do
    Cadre.PeindreUnite(unite)
  end
end

-- Avance l'affichage sans lire un seul buff : le décompte se recalcule depuis
-- l'expiration mémorisée, et le carré absent pulse une fois par seconde.
-- UNIT_AURA reste seul chargé de dire qu'un buff a changé.
function Cadre.Rafraichir()
  if not parent or not parent:IsShown() then return end
  local maintenant = GetTime()

  for _, carre in pairs(carres) do
    local etat = carre.cache
    if carre:IsShown() and etat then

      if etat.etat == "absente" then
        -- Pulsation : l'alpha va et vient entre 0,45 et 0,90 en une seconde.
        local phase = maintenant % 1
        local alpha = 0.45 + 0.45 * math.abs(1 - 2 * phase)
        local r, v, b = COULEURS.absente[1], COULEURS.absente[2], COULEURS.absente[3]
        carre.fond:SetTexture(r, v, b, alpha)

      elseif etat.expiration then
        local restant = etat.expiration - maintenant
        if restant < 0 then restant = 0 end
        carre.temps:SetText(FormaterTemps(restant))

        -- Le franchissement du seuil se voit sans relire le buff.
        if etat.etat ~= "mauvaise" then
          local nouveau = "posee"
          if restant < GestoBene_Config.seuilAlerte then nouveau = "bientot" end
          if nouveau ~= etat.etat then
            etat.etat = nouveau
            carre.fond:SetTexture(unpack(COULEURS[nouveau]))
          end
        end
      end

    end
  end
end

function Cadre.Basculer()
  if not parent then return end
  if parent:IsShown() then parent:Hide() else parent:Show() end
end

function Cadre.Position()
  if not parent then return nil end
  local point, _, _, x, y = parent:GetPoint()
  return point, math.floor(x + 0.5), math.floor(y + 0.5)
end
```

- [ ] **Étape 2 : vérifier la syntaxe**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/GestoBene && lua -e 'assert(loadfile("Cadre.lua"))' && echo "syntaxe OK"
```

Attendu : `syntaxe OK`. Le fichier ne peut pas s'exécuter hors du jeu (il appelle `CreateFrame`), mais il doit être syntaxiquement valide.

- [ ] **Étape 3 : vérifier que les tests existants passent toujours**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : `27 cas, 0 echec(s)`. Cadre.lua n'est pas chargé par les tests, donc rien ne doit bouger.

- [ ] **Étape 4 : commit**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene
lua -e 'assert(loadfile("GestoBene/Cadre.lua"))'
(cd tests && lua tests.lua)
git add GestoBene/Cadre.lua
git commit -m "feat: affiche un carre cliquable par membre du groupe"
```

Attendu : syntaxe valide, 27 cas au vert, puis le commit est créé.

---

### Task 6 : GestoBene.lua — événements, rafraîchissement et commandes

Dernière tâche : l'addon devient vivant en jeu.

**Files:**
- Modify: `GestoBene/GestoBene.lua` (remplace le squelette de la tâche 2)

**Interfaces:**
- Consumes: tout ce que produisent les tâches 2 à 5
- Produces: l'addon complet ; commandes `/gesto`, `/gesto sorts`, `/gesto pos`, `/gesto etat`, avec `/ben` en alias

- [ ] **Étape 1 : écrire GestoBene.lua**

```lua
-- Addon GestoBene : événements, rafraîchissement, commandes.

GestoBene = GestoBene or {}

local INTERVALLE = 0.2   -- secondes entre deux repeints du décompte
local accumulateur = 0

local function Dire(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99GestoBene|r : " .. message)
end

-- « /gesto sorts » : reproduit le relevé des identifiants, pour refaire le point
-- après un niveau ou un changement de spécialisation.
local function ImprimerSorts()
  for cle in pairs(GestoBene_Sorts.table) do
    local etat = GestoBene_Sorts.Etat(cle)
    if not etat then
      Dire(cle .. " : absente de ce client")
    else
      Dire(string.format("%s : %s [%s] / %s [%s]",
        cle,
        etat.nomNormale or "INCONNU",
        etat.normaleApprise and "appris" or "non appris",
        etat.nomSuperieure or "INCONNU",
        etat.superieureApprise and "appris" or "non appris"))
    end
  end
  Dire(string.format("reactif : %d en sac", GetItemCount(GestoBene_Sorts.reactif)))
end

local function ImprimerEtat()
  for _, unite in ipairs(GestoBene_Suivi.Membres()) do
    local etat = GestoBene_Suivi.Etat(unite)
    local _, jeton = UnitClass(unite)
    Dire(string.format("%s (%s) : attendue %s, etat %s",
      etat.nom or unite, jeton or "?", tostring(etat.cle), etat.etat))
  end
end

local function ImprimerPosition()
  local point, x, y = GestoBene_Cadre.Position()
  if not point then
    Dire("cadre non construit")
    return
  end
  Dire(string.format("a recopier dans Config.lua : ancrage = { point = \"%s\", x = %d, y = %d }",
    point, x, y))
end

SLASH_GESTOBENE1 = "/gesto"
SLASH_GESTOBENE2 = "/ben"   -- alias court
SlashCmdList["GESTOBENE"] = function(argument)
  argument = string.lower(argument or "")
  if argument == "sorts" then
    ImprimerSorts()
  elseif argument == "pos" then
    ImprimerPosition()
  elseif argument == "etat" then
    ImprimerEtat()
  else
    GestoBene_Cadre.Basculer()
  end
end

local ecouteur = CreateFrame("Frame")
ecouteur:RegisterEvent("PLAYER_LOGIN")
ecouteur:RegisterEvent("PLAYER_ENTERING_WORLD")
ecouteur:RegisterEvent("PARTY_MEMBERS_CHANGED")
ecouteur:RegisterEvent("UNIT_AURA")
ecouteur:RegisterEvent("SPELLS_CHANGED")
ecouteur:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ecouteur:RegisterEvent("BAG_UPDATE")
ecouteur:RegisterEvent("PLAYER_REGEN_ENABLED")

ecouteur:SetScript("OnEvent", function(self, evenement, arg1)
  if evenement == "PLAYER_LOGIN" then
    GestoBene_Sorts.Resoudre()
    for _, avertissement in ipairs(GestoBene_Sorts.ValiderConfig()) do
      Dire(avertissement)
    end
    GestoBene_Cadre.Construire()

  elseif evenement == "PLAYER_ENTERING_WORLD"
      or evenement == "PARTY_MEMBERS_CHANGED" then
    GestoBene_Cadre.Reprogrammer()

  elseif evenement == "SPELLS_CHANGED"
      or evenement == "ACTIVE_TALENT_GROUP_CHANGED" then
    -- Un niveau, un rang appris ou un basculement de double spé peut changer
    -- ce qui est lançable. Le Sanctuaire apparaît en Protection et disparaît
    -- en Vindicte ou en Heal.
    GestoBene_Sorts.Resoudre()
    GestoBene_Cadre.Reprogrammer()

  elseif evenement == "BAG_UPDATE" then
    -- Le nombre de symboles décide de la disponibilité des supérieures.
    GestoBene_Cadre.Reprogrammer()

  elseif evenement == "UNIT_AURA" then
    GestoBene_Cadre.PeindreUnite(arg1)

  elseif evenement == "PLAYER_REGEN_ENABLED" then
    GestoBene_Cadre.ViderFile()
  end
end)

-- Le décompte se repeint seul, sans relire aucun buff : UNIT_AURA dit quand
-- un buff change, cette boucle ne fait qu'avancer l'affichage depuis
-- l'expiration déjà mémorisée. Appeler Peindre() ici balaierait UnitBuff
-- cinq fois par seconde pour chaque membre — ce que la spec interdit.
ecouteur:SetScript("OnUpdate", function(self, ecoule)
  accumulateur = accumulateur + ecoule
  if accumulateur < INTERVALLE then return end
  accumulateur = 0
  GestoBene_Cadre.Rafraichir()
end)
```

- [ ] **Étape 2 : vérifier la syntaxe**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/GestoBene && for f in *.lua; do lua -e 'assert(loadfile("'"$f"'"))' && echo "$f OK"; done
```

Attendu : les cinq fichiers annoncés `OK`.

- [ ] **Étape 3 : vérifier que les tests passent toujours**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene/tests && lua tests.lua
```

Attendu : `27 cas, 0 echec(s)`.

- [ ] **Étape 4 : vérifier la complétude puis commiter**

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene
ls -1 GestoBene/
git add GestoBene/GestoBene.lua
git commit -m "feat: branche les evenements du jeu et les commandes /gesto"
```

Attendu : six fichiers (`GestoBene.toc`, `Config.lua`, `Sorts.lua`, `Suivi.lua`, `Cadre.lua`, `GestoBene.lua`), puis le commit est créé.

- [ ] **Étape 5 : recette en jeu**

Installer d'abord l'addon dans le client :

```bash
cd /home/mr486/Developpement/Projets/Plugins-Wow/GestoBene && ./installer.sh
```

⚠️ **Un addon nouvellement installé n'apparaît pas au `/reload`.** Il faut
quitter le client entièrement et le relancer pour que WoW découvre le dossier,
puis cocher `GestoBene` dans la liste des extensions à l'écran de sélection du
personnage.

⚠️ **Ne jamais éditer la copie posée dans `Interface/AddOns/GestoBene`** : elle
est écrasée au prochain `installer.sh`. La source est le dépôt.

Recette, dans l'ordre :

1. Le cadre apparaît à la connexion.
2. Seul en ville, **un unique carré** s'affiche, celui de Kahalie, avec `ROI`.
3. `/gesto sorts` montre : Rois appris / supérieure non apprise, Puissance et
   Sagesse apprises dans les deux versions, Sanctuaire non appris, et 28 en sac.
4. Un clic gauche sur le carré pose la Bénédiction des rois ; le décompte
   démarre à `10:00` et descend.
5. Sous une minute, le carré passe en orange.
6. Un clic droit sur un carré de mage ou de guerrier pose la supérieure et le
   décompte démarre à `30:00` ; sur le carré paladin il se replie sur la
   normale, puisque la supérieure des Rois demande le niveau 60.
7. Entrer en groupe hors combat fait apparaître les carrés manquants et élargit
   le cadre.
8. Un changement de groupe en plein combat affiche une bordure jaune sans
   provoquer d'erreur Lua, et le rendu se corrige à la fin du combat.
9. `/gesto pos` imprime une ligne `ancrage` à recopier dans `Config.lua`.

Noter tout écart pour correction.

---

## Couverture de la spec

| Section de la spec | Tâche |
|---|---|
| 5. Config.lua | 2 |
| 5. Validation au chargement | 3 (`ValiderConfig`) |
| 6. Table, résolution, abréviations, repli | 3 |
| 7. `LireUnite`, `Attendue`, `Membres`, états | 4 |
| 8. Disposition, couleurs, boutons sécurisés | 5 |
| 9. Verrou de combat, file d'attente | 5 (`Reprogrammer`, `ViderFile`) |
| 10. Événements, rafraîchissement, commandes | 6 |
| 11. Tests, faux de l'API, recette en jeu | 1, 3, 4, 6 |
