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
