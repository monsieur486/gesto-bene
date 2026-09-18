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
