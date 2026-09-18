-- Les cinq carrés : création, attributs sécurisés, couleurs.
-- Aucune décision ici. Tout vient de GestoBene_Suivi et GestoBene_Sorts.
-- Des boutons ordinaires s'y ajoutent : le cadenas (verrouille le cadre) et,
-- au-dessus de chaque carré dont la classe est basculable, une bascule qui
-- alterne sa bénédiction entre deux valeurs. Aucun d'eux ne lance de sort ;
-- seuls les cinq carrés sont protégés.

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

-- Le cadenas à gauche des carrés, et un bouton de bascule par carré, tenu
-- dans une table indexée par unité. Boutons ordinaires : les créer, les
-- montrer, les cacher ou les cliquer en combat est licite, contrairement aux
-- cinq carrés.
local cadenas, boutonsBascule = nil, {}

-- Déclarée ici pour que le clic d'un bouton (défini plus bas) puisse
-- l'appeler ; définie plus loin, une fois Disposer et compagnie en place.
local ActualiserBascules

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

-- Le vrai cadenas n'est pas garanti sur ce client : aucun addon installé ne
-- l'utilise. SetTexture rend false si le fichier manque, on se rabat alors
-- sur la case à cocher, présente partout. Rend vrai si la vraie texture a pu
-- être posée, pour que l'appelant sache s'il doit surimprimer une coche.
local function PoserTexture(texture, ferme)
  local chemin = ferme and "Interface\\Buttons\\LockButton-Locked-Up"
                       or "Interface\\Buttons\\LockButton-Unlocked-Up"
  if texture:SetTexture(chemin) then return true end
  texture:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
  return false
end

-- Reflète l'état verrouillé/déverrouillé : icône du cadenas (ou coche de
-- secours) et bordure du cadre parent. Appelée à la construction et après
-- chaque clic sur le cadenas.
local function ActualiserVerrou()
  local verrouille = GestoBene_Config.verrouille

  local reelle = PoserTexture(cadenas.icone, verrouille)
  if not reelle and verrouille then
    cadenas.coche:Show()
  else
    cadenas.coche:Hide()
  end

  if verrouille then
    parent:SetBackdropBorderColor(0, 0, 0, 0)
  else
    parent:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
  end
end

-- Le cadenas : verrouille le déplacement du cadre, et sert lui-même de
-- poignée quand il est ouvert. Flotte à gauche des carrés sans leur prendre
-- de place : Disposer ne le connaît pas.
local function CreerCadenas()
  local bouton = CreateFrame("Button", "GestoBeneCadenas", parent)
  bouton:SetWidth(16)
  bouton:SetHeight(16)
  bouton:SetPoint("RIGHT", parent, "LEFT", -ECART, 0)
  bouton:RegisterForClicks("LeftButtonUp")
  bouton:RegisterForDrag("LeftButton")

  bouton.icone = bouton:CreateTexture(nil, "ARTWORK")
  bouton.icone:SetAllPoints(bouton)

  bouton.coche = bouton:CreateTexture(nil, "OVERLAY")
  bouton.coche:SetAllPoints(bouton)
  bouton.coche:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  bouton.coche:Hide()

  bouton:SetScript("OnClick", function()
    GestoBene_Config.verrouille = not GestoBene_Config.verrouille
    ActualiserVerrou()
  end)

  -- Poignée soumise au même verrou que celle du cadre parent : verrouillé,
  -- glisser ne fait rien.
  bouton:SetScript("OnDragStart", function()
    if not GestoBene_Config.verrouille then parent:StartMoving() end
  end)
  bouton:SetScript("OnDragStop", function() parent:StopMovingOrSizing() end)

  bouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if GestoBene_Config.verrouille then
      GameTooltip:SetText("Cadre verrouillé — cliquer pour libérer")
    else
      GameTooltip:SetText("Cadre libre — glisser pour déplacer, cliquer pour verrouiller")
    end
    GameTooltip:Show()
  end)
  bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return bouton
end

-- Un bouton de bascule par carré, créé avec lui, qu'il serve un jour ou
-- jamais : la classe de l'occupant peut changer à chaque recomposition du
-- groupe, alors qu'un carré, lui, ne change pas d'unité. Caché à la
-- création ; c'est ActualiserBascules() qui décide, à chaque reprogrammation,
-- s'il a sa place.
--
-- N'écrit jamais Config.lua : seule la table GestoBene_Config.parClasse en
-- mémoire change. Un /reload repart donc de la valeur du fichier.
local function CreerBoutonBascule(unite, carre)
  local taille = GestoBene_Config.tailleCarre
  local bouton = CreateFrame("Button", nil, parent)
  bouton:SetWidth(taille)
  bouton:SetHeight(14)
  bouton:SetPoint("BOTTOM", carre, "TOP", 0, 2)
  bouton:RegisterForClicks("LeftButtonUp")
  bouton:Hide()

  bouton.fond = bouton:CreateTexture(nil, "BACKGROUND")
  bouton.fond:SetAllPoints(bouton)
  bouton.fond:SetTexture(0, 0, 0, 0.6)

  bouton.texte = bouton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  bouton.texte:SetPoint("CENTER", bouton, "CENTER", 0, 0)

  bouton.unite = unite

  bouton:SetScript("OnClick", function(self)
    local _, jeton = UnitClass(self.unite)
    local reglage = jeton and GestoBene_Config.bascules[jeton]
    if not reglage then return end

    local courante = GestoBene_Config.parClasse[jeton]
    local nouvelle = reglage[1]
    if courante == reglage[1] then nouvelle = reglage[2] end
    GestoBene_Config.parClasse[jeton] = nouvelle

    -- Reprogrammer gère déjà le verrou de combat en différant si besoin. Les
    -- boutons, eux, affichent tout de suite le nouvel état : le joueur a
    -- bien changé d'intention, seule l'application aux carrés peut attendre.
    Cadre.Reprogrammer()
    ActualiserBascules()
  end)

  bouton:SetScript("OnEnter", function(self)
    local _, jeton = UnitClass(self.unite)
    local reglage = jeton and GestoBene_Config.bascules[jeton]
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Bascule de bénédiction")
    if reglage then
      GameTooltip:AddLine(reglage[1] .. " / " .. reglage[2], 1, 1, 1)
      GameTooltip:AddLine("Change pour toute la classe", 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
  end)
  bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return bouton
end

-- Remet à jour la visibilité et le texte de tous les boutons de bascule.
-- Appelée après chaque reprogrammation (composition du groupe susceptible
-- d'avoir changé) et après chaque clic (règle par classe : deux carrés de
-- même classe doivent afficher la même chose). Aucun attribut protégé n'est
-- en jeu, donc rien ici ne se soucie du verrou de combat.
--
-- Le bouton affiche l'option vers laquelle il basculerait, pas la courante :
-- le carré juste en dessous montre déjà celle-ci, et « PUISSANCE » déborde
-- d'un carré de 48 pixels comme « MANQUE » l'a fait.
function ActualiserBascules()
  for _, unite in ipairs(GestoBene_Suivi.UNITES) do
    local bouton = boutonsBascule[unite]
    local carre = carres[unite]
    if bouton and carre then
      local autre = nil
      if carre:IsShown() then
        local _, jeton = UnitClass(unite)
        local reglage = jeton and GestoBene_Config.bascules[jeton]
        if reglage then
          local courante = GestoBene_Config.parClasse[jeton]
          if courante == reglage[1] then
            autre = reglage[2]
          elseif courante == reglage[2] then
            autre = reglage[1]
          end
          -- Une troisième valeur écrite à la main dans parClasse n'est ni
          -- l'une ni l'autre : on cache le bouton plutôt que de deviner.
        end
      end

      if autre then
        bouton.texte:SetText("→ " .. GestoBene_Sorts.Abreger(autre))
        bouton:Show()
      else
        bouton:Hide()
      end
    end
  end
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

  -- Le parent reste une seconde poignée, mais soumise au même verrou que le
  -- cadenas : verrouillé, un glisser sur le cadre lui-même ne fait rien.
  parent:SetScript("OnDragStart", function(self)
    if not GestoBene_Config.verrouille then self:StartMoving() end
  end)
  parent:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  -- Bordure du cadre : repère visuel du déverrouillage, cachée par défaut
  -- via l'alpha posé dans ActualiserVerrou.
  parent:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
  })

  for index, unite in ipairs(GestoBene_Suivi.UNITES) do
    local carre = CreerCarre(unite, index)
    carres[unite] = carre
    boutonsBascule[unite] = CreerBoutonBascule(unite, carre)
  end

  cadenas = CreerCadenas()

  ActualiserVerrou()

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
  ActualiserBascules()
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
