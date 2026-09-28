-- Table des bénédictions et des sceaux, et résolution de leurs noms.
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

-- Les sceaux, que le paladin ne pose que sur lui-même : un seul identifiant
-- chacun, pas de version supérieure. Vengeance (Alliance) et Corruption
-- (Horde) se partagent la table : seul celui de la faction du personnage
-- sera appris, l'autre sort simplement du cycle.
Sorts.sceaux = {
  Piete        = 21084,
  Sagesse      = 20166,
  Lumiere      = 20165,
  Justice      = 20164,
  Commandement = 20375,
  Vengeance    = 31801,
  Corruption   = 53736,
}

local ABREVIATIONS = {
  Rois = "ROI", Puissance = "PUI", Sagesse = "SAG", Sanctuaire = "SAN",
}

-- L'ordre du cycle, fixé une fois pour toutes. Parcourir Sorts.table avec
-- pairs() rendrait l'ordre imprévisible et il pourrait changer d'une session
-- à l'autre : un bouton dont l'enchaînement bouge est un bouton qu'on
-- n'apprend jamais.
Sorts.ORDRE = { "Rois", "Puissance", "Sagesse", "Sanctuaire" }

-- Même règle pour le cycle des sceaux, parcouru par le clic droit sur la
-- carré de sceau.
Sorts.ORDRE_SCEAUX = {
  "Piete", "Sagesse", "Lumiere", "Justice", "Commandement", "Vengeance", "Corruption",
}

-- Table à part : « Sagesse » désigne à la fois une bénédiction et un sceau.
local ABREVIATIONS_SCEAUX = {
  Piete = "PIE", Sagesse = "SAG", Lumiere = "LUM", Justice = "JUS",
  Commandement = "COM", Vengeance = "VEN", Corruption = "COR",
}

-- Cache rempli par Resoudre(), relu par Etat() et NomAUtiliser().
local etats = {}
local parSpellId = {}

-- Index par nom localisé, celui que rend UnitBuff en première valeur. La
-- plupart des bénédictions ont une dizaine de rangs, chacun son propre
-- identifiant de sort ; un rang avancé lancé à haut niveau n'a aucune chance
-- de correspondre à l'identifiant du rang 1 stocké dans Sorts.table. Le nom,
-- lui, est le même quel que soit le rang lancé : c'est sur lui que doit se
-- faire la détection, pas sur l'identifiant.
local parNom = {}

-- Les mêmes caches pour les sceaux, tenus à part des bénédictions.
local etatsSceaux = {}
local sceauParNom = {}

function Sorts.Abreger(cle)
  return ABREVIATIONS[cle] or "?"
end

function Sorts.AbregerSceau(cle)
  return ABREVIATIONS_SCEAUX[cle] or "?"
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
  parNom = {}
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
      if nomNormale then
        parSpellId[ids.normale] = cle
        parNom[nomNormale] = { cle = cle, superieure = false }
      end
      if nomSuperieure then
        parSpellId[ids.superieure] = cle
        parNom[nomSuperieure] = { cle = cle, superieure = true }
      end
    end
  end

  etatsSceaux = {}
  sceauParNom = {}
  for cle, id in pairs(Sorts.sceaux) do
    local nom, appris = ResoudreUn(id)
    if nom then
      etatsSceaux[cle] = { nom = nom, appris = appris }
      sceauParNom[nom] = cle
    end
  end
end

function Sorts.Etat(cle)
  return etats[cle]
end

function Sorts.CleParSpellId(spellId)
  return parSpellId[spellId]
end

-- Vrai si l'identifiant désigne la version supérieure d'une bénédiction.
-- Se fonde sur la table résolue (parSpellId puis Sorts.table), jamais sur une
-- comparaison écrite en dur : un identifiant étranger à la table, ou qui
-- n'est la supérieure d'aucune famille, rend faux.
function Sorts.EstSuperieure(spellId)
  local cle = parSpellId[spellId]
  if not cle then return false end
  local ids = Sorts.table[cle]
  return ids ~= nil and ids.superieure == spellId
end

-- La clé de bénédiction correspondant à ce nom localisé de sort, quel que
-- soit le rang lancé. C'est la fonction que doit utiliser tout code qui lit
-- un buff : UnitBuff rend le même nom pour tous les rangs d'une même
-- bénédiction, alors que chaque rang a son propre spellId.
function Sorts.CleParNom(nom)
  local info = parNom[nom]
  return info and info.cle
end

-- Vrai si ce nom localisé désigne la version supérieure d'une bénédiction.
-- Un nom étranger à la table rend faux, tout comme la normale.
function Sorts.EstSuperieureParNom(nom)
  local info = parNom[nom]
  return info ~= nil and info.superieure
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

-- Les bénédictions que le personnage sait réellement lancer, dans l'ordre du
-- cycle (Sorts.ORDRE). On se fonde sur la normale : c'est elle que pose le
-- clic gauche, et le clic droit s'y replie déjà quand la supérieure manque.
function Sorts.Lancables()
  local lancables = {}
  for _, cle in ipairs(Sorts.ORDRE) do
    local etat = etats[cle]
    if etat and etat.normaleApprise then
      lancables[#lancables + 1] = cle
    end
  end
  return lancables
end

-- L'élément de « liste » qui suit « cle », en bouclant après le dernier. Si
-- « cle » n'y figure pas, on repart du premier. Rend nil s'il n'y a nulle
-- part où aller : liste vide ou d'un seul élément.
local function SuivanteDans(liste, cle)
  if #liste < 2 then return nil end

  for index, courante in ipairs(liste) do
    if courante == cle then
      local suivant = index + 1
      if suivant > #liste then suivant = 1 end
      return liste[suivant]
    end
  end

  return liste[1]
end

-- La bénédiction lançable qui suit « cle » dans le cycle, en bouclant après
-- la dernière. Si « cle » n'est pas lançable (par exemple une bénédiction que
-- la configuration attend mais que le personnage n'a pas apprise), on repart
-- de la première. S'il n'y a nulle part où aller — aucune ou une seule
-- bénédiction lançable — rend nil.
function Sorts.Suivante(cle)
  return SuivanteDans(Sorts.Lancables(), cle)
end

-- L'état résolu d'un sceau : { nom, appris }, ou nil si le client l'ignore.
function Sorts.EtatSceau(cle)
  return etatsSceaux[cle]
end

-- La clé du sceau portant ce nom localisé, tel que le rend UnitBuff.
function Sorts.SceauParNom(nom)
  return sceauParNom[nom]
end

-- Le nom à poser dans l'attribut du bouton de sceau, ou nil si ce sceau
-- n'est pas appris : un bouton sans sort ne fait rien, ce qui vaut mieux
-- qu'une erreur rouge du client.
function Sorts.NomSceau(cle)
  local etat = etatsSceaux[cle]
  if etat and etat.appris then return etat.nom end
  return nil
end

-- Les sceaux que le personnage connaît, dans l'ordre de Sorts.ORDRE_SCEAUX.
function Sorts.SceauxLancables()
  local lancables = {}
  for _, cle in ipairs(Sorts.ORDRE_SCEAUX) do
    local etat = etatsSceaux[cle]
    if etat and etat.appris then
      lancables[#lancables + 1] = cle
    end
  end
  return lancables
end

-- Le sceau connu qui suit « cle », selon les mêmes règles que Suivante.
function Sorts.SceauSuivant(cle)
  return SuivanteDans(Sorts.SceauxLancables(), cle)
end

-- Vérifie GestoBene_Config.parClasse et ramène les valeurs fautives
-- sur "Puissance", puis GestoBene_Config.sceau, ramené sur "Sagesse".
-- Rend la liste des messages à imprimer dans le chat.
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

  -- pairs() ci-dessus ne voit que les clés présentes dans parClasse : une
  -- classe effacée par erreur ne produirait sinon aucun message, alors que
  -- son carré affiche un bouton mort faute de bénédiction attendue.
  for _, jeton in ipairs(CLASSES) do
    if not GestoBene_Config.parClasse[jeton] then
      avertissements[#avertissements + 1] =
        "classe manquante dans Config.lua : " .. jeton .. ", repli sur Puissance"
      GestoBene_Config.parClasse[jeton] = "Puissance"
    end
  end

  if not Sorts.sceaux[GestoBene_Config.sceau] then
    avertissements[#avertissements + 1] =
      "sceau inconnu dans Config.lua : " .. tostring(GestoBene_Config.sceau) .. ", repli sur Sagesse"
    GestoBene_Config.sceau = "Sagesse"
  end

  return avertissements
end
