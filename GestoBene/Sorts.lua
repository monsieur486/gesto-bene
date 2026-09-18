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
