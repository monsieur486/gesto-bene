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
