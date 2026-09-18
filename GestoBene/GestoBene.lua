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
    local raison = GestoBene_Cadre.Basculer()
    if raison then Dire(raison) end
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
