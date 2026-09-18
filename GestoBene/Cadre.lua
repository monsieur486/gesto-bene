-- Les cinq carrés : création, attributs sécurisés, couleurs.
-- Aucune décision ici. Tout vient de GestoBene_Suivi et GestoBene_Sorts.

GestoBene_Cadre = GestoBene_Cadre or {}
local Cadre = GestoBene_Cadre

local ECART = 4

-- Texte du carré quand la bénédiction manque. Court volontairement : un mot
-- entier déborde d'un carré de 48 pixels, et le fond rouge qui pulse dit déjà
-- de quoi il retourne.
local TEXTE_ABSENTE = "X"

local COULEURS = {
  posee    = { 0.10, 0.35, 0.10, 0.85 },
  bientot  = { 0.55, 0.35, 0.05, 0.90 },
  absente  = { 0.55, 0.10, 0.10, 0.90 },
  mauvaise = { 0.50, 0.45, 0.05, 0.90 },
}

local parent, carres, reprogrammationEnAttente = nil, {}, false
local constructionEnAttente = false

-- Ce qui a réellement été appliqué au dernier Reprogrammer() réussi : par
-- unité, sa visibilité et les noms posés dans spell1/spell2. Sert à ne pas
-- lever le drapeau d'attente en combat quand l'ensemble visé n'a pas changé
-- (section 9 du plan : un BAG_UPDATE de butin ne doit pas noyer le signal).
local dernierApplique = {}

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

  -- Créer un bouton protégé et lui poser un attribut est interdit en combat.
  -- Un /reload en plein combat arrive ici avec le verrou encore posé : on
  -- diffère, et ViderFile rappellera Construire à la fin du combat.
  if InCombatLockdown() then
    constructionEnAttente = true
    return
  end
  constructionEnAttente = false

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

-- Calcule ce que Reprogrammer poserait sur chaque carré : visibilité et noms
-- de sorts spell1/spell2. Ne touche à rien ; sert à comparer l'ensemble visé
-- à ce qui est réellement appliqué (dernierApplique).
local function CalculerVise()
  local membres = GestoBene_Suivi.Membres()
  local visible = {}
  for _, unite in ipairs(membres) do visible[unite] = true end

  local vise = {}
  for _, unite in ipairs(GestoBene_Suivi.UNITES) do
    if visible[unite] then
      local cle = GestoBene_Suivi.Attendue(unite)
      vise[unite] = {
        visible = true,
        spell1 = cle and GestoBene_Sorts.NomAUtiliser(cle, false) or nil,
        spell2 = cle and GestoBene_Sorts.NomAUtiliser(cle, true) or nil,
      }
    else
      vise[unite] = { visible = false }
    end
  end
  return vise, membres
end

-- Vrai si l'ensemble visé ne diffère en rien de ce qui a été appliqué au
-- dernier Reprogrammer() réussi.
local function VisePareilQuApplique(vise)
  for unite, cible in pairs(vise) do
    local applique = dernierApplique[unite]
    if not applique
        or applique.visible ~= cible.visible
        or applique.spell1 ~= cible.spell1
        or applique.spell2 ~= cible.spell2 then
      return false
    end
  end
  return true
end

-- Met à jour les attributs de sort et la visibilité. Les deux opérations sont
-- interdites en combat sur un bouton protégé : si le verrou est posé, on met
-- en attente et PLAYER_REGEN_ENABLED finira le travail.
--
-- Un mouvement de sac (butin, potion, Symbole des rois consommé) déclenche
-- aussi cet appel via BAG_UPDATE. En combat, si le groupe et les sorts posés
-- n'ont pas changé, lever le drapeau d'attente serait un mensonge : la
-- bordure jaune ne doit dire « mon affichage est périmé » que lorsque c'est
-- vrai, sous peine de devenir du bruit permanent dès le premier pull.
function Cadre.Reprogrammer()
  if not parent then return end

  local vise, membres = CalculerVise()

  if InCombatLockdown() then
    if VisePareilQuApplique(vise) then
      return
    end
    reprogrammationEnAttente = true
    for _, carre in pairs(carres) do
      if carre:IsShown() then
        carre.bordure:SetBackdropBorderColor(0.6, 0.6, 0.2, 1)
      end
    end
    return
  end

  reprogrammationEnAttente = false
  for unite, carre in pairs(carres) do
    local cible = vise[unite]
    if cible.visible then
      carre:SetAttribute("spell1", cible.spell1)
      carre:SetAttribute("spell2", cible.spell2)
      carre:Show()
    else
      carre:Hide()
    end
  end
  dernierApplique = vise

  Disposer(membres)
  Cadre.Peindre()
end

function Cadre.ViderFile()
  if constructionEnAttente then
    Cadre.Construire()
    return
  end
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

  -- L'unité a disparu (membre parti) mais le carré est encore visible : la
  -- reprogrammation n'a pas encore tourné. On ne peint rien, et on oublie la
  -- mémoire pour que Rafraichir n'anime pas un décompte périmé.
  if etat.etat == "vide" then
    carre.cache = nil
    return
  end

  carre.cache = etat
  carre.nom:SetText(etat.nom or "")

  if etat.etat == "absente" then
    carre.fond:SetTexture(unpack(COULEURS.absente))
    carre.abreviation:SetText(etat.cle and GestoBene_Sorts.Abreger(etat.cle) or "?")
    carre.temps:SetText(TEXTE_ABSENTE)
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

-- Montre ou cache le cadre parent. Rend une raison quand rien ne s'est passé
-- (nil sinon), à charge de l'appelant de l'imprimer dans le chat.
function Cadre.Basculer()
  if not parent then
    return "cadre non construit : /reload en combat, ou pas encore a la connexion"
  end
  -- Le cadre parent n'est pas un widget protégé, mais il porte des boutons
  -- SecureActionButtonTemplate : RaidBuffStatus garde la même prudence sur
  -- son équivalent (RaidBuffStatus/Core.lua:1513-1525).
  if InCombatLockdown() then
    return "impossible en combat"
  end
  if parent:IsShown() then parent:Hide() else parent:Show() end
  return nil
end

function Cadre.Position()
  if not parent then return nil end
  local point, _, _, x, y = parent:GetPoint()
  return point, math.floor(x + 0.5), math.floor(y + 0.5)
end
