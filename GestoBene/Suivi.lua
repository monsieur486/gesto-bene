-- Qui porte quelle bénédiction, et pour combien de temps.
-- Ce fichier ne touche aucun cadre : il reçoit des données, il en rend.

GestoBene_Suivi = GestoBene_Suivi or {}
local Suivi = GestoBene_Suivi

-- L'ordre des carrés, fixé une fois pour toutes.
Suivi.UNITES = { "player", "party1", "party2", "party3", "party4" }

-- Surcharges nominatives posées en jeu par les boutons de bascule. Elles
-- l'emportent sur la règle de classe, ne touchent jamais GestoBene_Config, et
-- meurent avec la session : le groupe change à chaque donjon. Elles restent
-- volontairement hors de GestoBene_Etat, qui ne garde que la position du
-- cadre et l'état du cadenas.
local surcharges = {}

-- Pose la surcharge du joueur nommé « nom » à « cle », ou la retire si
-- « cle » vaut nil.
function Suivi.Surcharger(nom, cle)
  surcharges[nom] = cle
end

-- La surcharge du joueur nommé « nom », ou nil s'il n'en a pas.
function Suivi.Surcharge(nom)
  return surcharges[nom]
end

-- Vide toutes les surcharges : la classe reprend la main pour tout le monde.
function Suivi.OublierSurcharges()
  surcharges = {}
end

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

-- La bénédiction attendue sur cette unité : sa surcharge nominative si le
-- joueur en a posé une, sinon la règle de sa classe.
function Suivi.Attendue(unite)
  if not UnitExists(unite) then return nil end

  local nom = UnitName(unite)
  local surcharge = nom and surcharges[nom]
  if surcharge then return surcharge end

  local _, jeton = UnitClass(unite)
  if not jeton then return nil end
  return GestoBene_Config.parClasse[jeton]
end

-- Vrai si l'on peut lancer une supérieure sur cette unité sans rien casser.
-- Le jeu applique une supérieure à tous les membres de la classe ciblée, et
-- elle remplace notre bénédiction sur chacun d'eux : si un autre porteur de
-- la même classe attend autre chose, elle écraserait son choix. Dans ce cas
-- le clic droit doit se contenter de la normale, qui ne touche que la cible.
function Suivi.SuperieurePermise(unite)
  if not UnitExists(unite) then return false end
  local _, jeton = UnitClass(unite)
  if not jeton then return false end
  local attendue = Suivi.Attendue(unite)

  for _, autre in ipairs(Suivi.Membres()) do
    if autre ~= unite then
      local _, jetonAutre = UnitClass(autre)
      if jetonAutre == jeton and Suivi.Attendue(autre) ~= attendue then
        return false
      end
    end
  end
  return true
end

-- Notre premier buff sur cette unité que « reconnaitre » identifie : cette
-- fonction reçoit le nom localisé du buff et rend sa clé, ou nil. Rend
-- { cle, nom, restant, duree, expiration }, ou nil.
-- Le filtre sur le lanceur est essentiel : la bénédiction d'un autre paladin
-- ne doit pas faire croire que le travail est fait, puisqu'on ne peut pas
-- la rafraîchir.
local function ChercherNotreBuff(unite, reconnaitre)
  if not UnitExists(unite) then return nil end
  local index = 1
  while true do
    local nom, _, _, _, _, duree, expiration, lanceur = UnitBuff(unite, index)
    if not nom then return nil end
    if lanceur == "player" then
      -- Le nom, pas le spellId : la plupart des bénédictions ont une
      -- dizaine de rangs, chacun son propre identifiant, alors que UnitBuff
      -- rend le même nom localisé quel que soit le rang lancé.
      local cle = reconnaitre(nom)
      if cle then
        local restant
        if expiration and expiration > 0 then
          restant = expiration - GetTime()
          if restant < 0 then restant = 0 end
        end
        -- Une expiration nulle signifie une durée indéterminée : restant vaut nil.
        local fin = (expiration and expiration > 0) and expiration or nil
        return { cle = cle, nom = nom, restant = restant, duree = duree, expiration = fin }
      end
    end
    index = index + 1
  end
end

-- Notre bénédiction sur cette unité, s'il y en a une.
function Suivi.LireUnite(unite)
  local portee = ChercherNotreBuff(unite, GestoBene_Sorts.CleParNom)
  if not portee then return nil end
  portee.superieure = GestoBene_Sorts.EstSuperieureParNom(portee.nom)
  portee.nom = nil
  return portee
end

-- L'état d'un buff attendu face à celui réellement porté, sans le nom du
-- joueur : partagé par les carrés de bénédiction et de sceau.
local function Qualifier(attendue, portee)
  if not portee then
    return { etat = "absente", cle = attendue }
  end

  local etat = "mauvaise"
  if portee.cle == attendue then
    etat = "posee"
    if portee.restant and portee.restant < GestoBene_Config.seuilAlerte then
      etat = "bientot"
    end
  end

  return {
    etat = etat, cle = attendue, clePortee = portee.cle,
    restant = portee.restant, expiration = portee.expiration,
    superieure = portee.superieure,
  }
end

-- L'état d'un carré, tel que Cadre.lua le peindra sans rien décider.
function Suivi.Etat(unite)
  if not UnitExists(unite) then
    return { etat = "vide" }
  end

  local etat = Qualifier(Suivi.Attendue(unite), Suivi.LireUnite(unite))
  etat.nom = UnitName(unite)
  return etat
end

-- Le sceau suivi : celui choisi au clic droit, mémorisé dans GestoBene_Etat,
-- sinon celui de Config.lua. Un choix mémorisé que la table ne connaît plus
-- (fichier retouché à la main, sceau retiré d'une version) est ignoré.
-- GestoBene_Etat est créée par Cadre.lua ; on la lit prudemment pour que ce
-- fichier reste chargeable seul, dans les tests.
function Suivi.SceauChoisi()
  local memorise = GestoBene_Etat and GestoBene_Etat.sceau
  if memorise and GestoBene_Sorts.sceaux[memorise] then
    return memorise
  end
  return GestoBene_Config.sceau
end

-- Mémorise le sceau choisi. Revenir sur celui de Config.lua efface la
-- mémoire plutôt que d'en poser une identique : la configuration reprend
-- alors la main, comme les bascules de bénédiction avec parClasse.
function Suivi.ChoisirSceau(cle)
  GestoBene_Etat = GestoBene_Etat or {}
  if cle == GestoBene_Config.sceau then
    GestoBene_Etat.sceau = nil
  else
    GestoBene_Etat.sceau = cle
  end
end

-- L'état du carré de sceau, sur le modèle de Suivi.Etat : le sceau est un
-- buff que le paladin ne pose que sur lui-même.
function Suivi.EtatSceau()
  return Qualifier(Suivi.SceauChoisi(), ChercherNotreBuff("player", GestoBene_Sorts.SceauParNom))
end
