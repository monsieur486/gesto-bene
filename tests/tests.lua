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

-- UnitClass doit rendre deux valeurs distinctes : le second est le jeton.
Test("le faux rend un nom de classe distinct du jeton", function()
  FauxAPI.Installer({ unites = { player = { classe = "PALADIN", nom = "Kahalie" } } })
  local nomLocalise, jeton = UnitClass("player")
  AssertEgal(jeton, "PALADIN", "jeton")
  AssertVrai(nomLocalise ~= jeton, "le nom localise differe du jeton")
  AssertNil(UnitClass("party1"), "unite absente")
  FauxAPI.Reinitialiser()
end)

Test("le faux dit qui existe et comment il s appelle", function()
  FauxAPI.Installer({ unites = { player = { classe = "PALADIN", nom = "Kahalie" } } })
  AssertVrai(UnitExists("player"), "player existe")
  AssertNil(UnitExists("party3"), "party3 n existe pas")
  AssertEgal(UnitName("player"), "Kahalie", "nom")
  AssertNil(UnitName("party3"), "pas de nom sans unite")
  FauxAPI.Reinitialiser()
end)

Test("le faux compte les objets en sac", function()
  FauxAPI.Installer({ sacs = { [21177] = 28 } })
  AssertEgal(GetItemCount(21177), 28, "symboles en sac")
  AssertEgal(GetItemCount(12345), 0, "objet absent rend zero")
  FauxAPI.Reinitialiser()
end)

-- GetItemInfo doit dépendre de l'identifiant, pas rendre un nom en dur.
Test("le faux nomme l objet demande et pas un autre", function()
  FauxAPI.Installer({ nomsObjets = { [21177] = "Symbole des rois", [4291] = "Fil de soie" } })
  AssertEgal(GetItemInfo(21177), "Symbole des rois", "reactif")
  AssertEgal(GetItemInfo(4291), "Fil de soie", "autre objet")
  AssertNil(GetItemInfo(99999), "objet inconnu")
  FauxAPI.Reinitialiser()
end)

Test("Reinitialiser retire bien toutes les globales", function()
  FauxAPI.Installer({ temps = 1 })
  AssertVrai(GetTime ~= nil, "posee")
  FauxAPI.Reinitialiser()
  AssertNil(GetTime, "GetTime retiree")
  AssertNil(UnitBuff, "UnitBuff retiree")
  AssertNil(GetItemCount, "GetItemCount retiree")
end)

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

-- pairs(parClasse) ne juge que les clés présentes : une classe effacée par
-- erreur du fichier édité à la main doit produire son propre avertissement.
Test("une classe absente de Config produit son propre avertissement", function()
  FauxAPI.Installer(MondeKahalie55())
  dofile("../GestoBene/Config.lua")
  GestoBene_Config.parClasse.MAGE = nil
  dofile("../GestoBene/Sorts.lua")
  GestoBene_Sorts.Resoudre()
  local avertissements = GestoBene_Sorts.ValiderConfig()
  AssertEgal(#avertissements, 1, "un seul avertissement")
  AssertVrai(string.find(avertissements[1], "MAGE") ~= nil, "nomme la classe manquante")
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

Test("une benediction normale n est pas marquee superieure", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.EstSuperieure(20217), false, "rois normale")
  FauxAPI.Reinitialiser()
end)

Test("une benediction superieure est marquee comme telle", function()
  ChargerSorts(MondeKahalie55())
  AssertVrai(GestoBene_Sorts.EstSuperieure(25894), "sagesse superieure")
  FauxAPI.Reinitialiser()
end)

Test("un identifiant etranger a la table n est pas marque superieure", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.EstSuperieure(12345), false, "identifiant inconnu")
  FauxAPI.Reinitialiser()
end)

Test("les abreviations font trois lettres", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.Abreger("Rois"), "ROI", "ROI")
  AssertEgal(GestoBene_Sorts.Abreger("Sanctuaire"), "SAN", "SAN")
  AssertEgal(GestoBene_Sorts.Abreger("Inexistante"), "?", "inconnue")
  FauxAPI.Reinitialiser()
end)

Test("Lancables rend les benedictions apprises dans l ordre du cycle", function()
  ChargerSorts(MondeKahalie55())
  local lancables = GestoBene_Sorts.Lancables()
  AssertEgal(#lancables, 3, "trois benedictions apprises, le sanctuaire absent")
  AssertEgal(lancables[1], "Rois", "1")
  AssertEgal(lancables[2], "Puissance", "2")
  AssertEgal(lancables[3], "Sagesse", "3")
  FauxAPI.Reinitialiser()
end)

-- Le cas qui donne son sens au cycle : Kahalie passe en Protection et
-- apprend le Sanctuaire. Resoudre() est deja rappele par SPELLS_CHANGED et
-- ACTIVE_TALENT_GROUP_CHANGED ; ici on verifie juste que Lancables() en tient
-- compte une fois rappelee.
Test("Lancables suit un changement d apprentissage apres Resoudre", function()
  local monde = MondeKahalie55()
  monde.sortsConnus[20911] = true
  ChargerSorts(monde)
  local lancables = GestoBene_Sorts.Lancables()
  AssertEgal(#lancables, 4, "les quatre benedictions apprises")
  AssertEgal(lancables[4], "Sanctuaire", "le sanctuaire entre a sa place dans l ordre")
  FauxAPI.Reinitialiser()
end)

Test("Suivante avance dans le cycle", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.Suivante("Rois"), "Puissance", "Rois vers Puissance")
  FauxAPI.Reinitialiser()
end)

Test("Suivante boucle depuis la derniere vers la premiere", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.Suivante("Sagesse"), "Rois", "retour au debut du cycle")
  FauxAPI.Reinitialiser()
end)

Test("Suivante sur une cle non apprise rend la premiere lancable", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.Suivante("Sanctuaire"), "Rois", "Sanctuaire non appris a 55")
  FauxAPI.Reinitialiser()
end)

Test("Suivante rend nil quand une seule benediction est apprise", function()
  local monde = MondeKahalie55()
  monde.sortsConnus = { [19740] = true }  -- seule la Puissance normale est apprise
  ChargerSorts(monde)
  AssertEgal(#GestoBene_Sorts.Lancables(), 1, "une seule benediction lancable")
  AssertNil(GestoBene_Sorts.Suivante("Puissance"), "nulle part ou aller")
  FauxAPI.Reinitialiser()
end)

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

-- Deux guerriers dans le même groupe : sert à vérifier qu'une surcharge
-- nominative ne déborde pas sur l'autre porteur de la même classe.
local function MondeDeuxGuerriers()
  local monde = MondeKahalie55()
  monde.unites = {
    player = { classe = "PALADIN", nom = "Kahalie" },
    party1 = { classe = "WARRIOR", nom = "Gorkk" },
    party2 = { classe = "WARRIOR", nom = "Thoromir" },
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
  AssertEgal(GestoBene_Suivi.Attendue("party1"), "Rois", "guerrier")
  AssertNil(GestoBene_Suivi.Attendue("party3"), "unite absente")
  FauxAPI.Reinitialiser()
end)

-- Sans surcharge, rien ne change : la classe seule commande.
Test("sans surcharge Attendue rend la valeur de la classe", function()
  ChargerSuivi(MondeGroupe())
  AssertNil(GestoBene_Suivi.Surcharge("Gorkk"), "aucune surcharge posee")
  AssertEgal(GestoBene_Suivi.Attendue("party1"), "Rois", "guerrier sans surcharge")
  FauxAPI.Reinitialiser()
end)

-- Une surcharge nominative l'emporte sur la regle de classe.
Test("une surcharge l emporte sur la valeur de classe", function()
  ChargerSuivi(MondeGroupe())
  GestoBene_Suivi.Surcharger("Gorkk", "Puissance")
  AssertEgal(GestoBene_Suivi.Surcharge("Gorkk"), "Puissance", "surcharge lue")
  AssertEgal(GestoBene_Suivi.Attendue("party1"), "Puissance", "surcharge appliquee")
  FauxAPI.Reinitialiser()
end)

-- L'objection de l'utilisateur : deux guerriers de besoins differents ne
-- doivent plus etre solidaires.
Test("deux joueurs de meme classe peuvent diverger", function()
  ChargerSuivi(MondeDeuxGuerriers())
  GestoBene_Suivi.Surcharger("Gorkk", "Puissance")
  AssertEgal(GestoBene_Suivi.Attendue("party1"), "Puissance", "Gorkk surcharge")
  AssertEgal(GestoBene_Suivi.Attendue("party2"), "Rois", "Thoromir garde la classe")
  FauxAPI.Reinitialiser()
end)

-- Surcharger(nom, nil) retire la surcharge : la classe reprend la main.
Test("Surcharger avec nil retire la surcharge", function()
  ChargerSuivi(MondeGroupe())
  GestoBene_Suivi.Surcharger("Gorkk", "Puissance")
  GestoBene_Suivi.Surcharger("Gorkk", nil)
  AssertNil(GestoBene_Suivi.Surcharge("Gorkk"), "surcharge retiree")
  AssertEgal(GestoBene_Suivi.Attendue("party1"), "Rois", "la classe reprend la main")
  FauxAPI.Reinitialiser()
end)

-- OublierSurcharges() vide tout, pour tout le monde a la fois.
Test("OublierSurcharges vide toutes les surcharges", function()
  ChargerSuivi(MondeDeuxGuerriers())
  GestoBene_Suivi.Surcharger("Gorkk", "Puissance")
  GestoBene_Suivi.Surcharger("Thoromir", "Puissance")
  GestoBene_Suivi.OublierSurcharges()
  AssertEgal(GestoBene_Suivi.Attendue("party1"), "Rois", "Gorkk revient a la classe")
  AssertEgal(GestoBene_Suivi.Attendue("party2"), "Rois", "Thoromir revient a la classe")
  FauxAPI.Reinitialiser()
end)

-- Une surcharge sur un absent ne doit rien casser ni deborder sur les autres.
Test("une surcharge sur un nom absent du groupe n a aucun effet", function()
  ChargerSuivi(MondeGroupe())
  GestoBene_Suivi.Surcharger("Fantome", "Puissance")
  AssertEgal(GestoBene_Suivi.Attendue("party1"), "Rois", "guerrier present inchange")
  AssertEgal(GestoBene_Suivi.Attendue("party2"), "Sagesse", "mage present inchange")
  AssertEgal(GestoBene_Suivi.Surcharge("Fantome"), "Puissance", "la surcharge existe, sans effet sur le groupe")
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

-- Une normale posee ne doit pas remonter marquee superieure via Etat.
Test("Etat transmet superieure a faux pour une normale posee", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 19742, duree = 600, expiration = 1500, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.Etat("party2").superieure, false, "sagesse normale")
  FauxAPI.Reinitialiser()
end)

-- L'information doit traverser Etat pour les etats posee et bientot.
Test("Etat transmet superieure a vrai pour une superieure posee", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 25894, duree = 1800, expiration = 2500, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "posee", "posee")
  AssertVrai(GestoBene_Suivi.Etat("party2").superieure, "sagesse superieure transmise")
  FauxAPI.Reinitialiser()
end)

Test("Etat transmet superieure pour l etat bientot", function()
  local monde = MondeGroupe()
  monde.buffs.party2 = {
    { spellId = 25894, duree = 1800, expiration = 1030, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "bientot", "bientot")
  AssertVrai(GestoBene_Suivi.Etat("party2").superieure, "sagesse superieure transmise en bientot")
  FauxAPI.Reinitialiser()
end)

-- L'etat mauvaise doit porter l'information de la benediction reellement
-- portee (clePortee), pas de celle attendue.
Test("l etat mauvaise porte l information de la benediction reellement posee", function()
  local monde = MondeGroupe()
  -- Le mage porte Puissance superieure alors que la config demande Sagesse.
  monde.buffs.party2 = {
    { spellId = 25782, duree = 1800, expiration = 2500, lanceur = "player" },
  }
  ChargerSuivi(monde)
  local etat = GestoBene_Suivi.Etat("party2")
  AssertEgal(etat.etat, "mauvaise", "etat")
  AssertEgal(etat.clePortee, "Puissance", "ce qu il porte")
  AssertVrai(etat.superieure, "la puissance reellement portee est superieure")
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

-- Le relecteur a montré qu'un balayage qui abandonne au premier buff étranger
-- passait les 32 cas : tous les mondes ne posaient qu'un seul buff. En donjon
-- la bénédiction est rarement le premier buff d'un joueur.
Test("le balayage traverse les buffs etrangers", function()
  local monde = MondeGroupe()
  monde.sortsExistants[1126] = "Don du sauvage"
  monde.buffs.party2 = {
    { spellId = 1126,  duree = 3600, expiration = 4600, lanceur = "party1" },
    { spellId = 20217, duree = 600,  expiration = 1500, lanceur = "party1" },
    { spellId = 19742, duree = 600,  expiration = 1500, lanceur = "player" },
  }
  ChargerSuivi(monde)
  local porte = GestoBene_Suivi.LireUnite("party2")
  AssertVrai(porte ~= nil, "notre benediction est trouvee en 3e position")
  AssertEgal(porte.cle, "Sagesse", "la bonne cle")
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "posee", "etat")
  FauxAPI.Reinitialiser()
end)

-- La règle du seuil existe en double : Suivi.Etat et Cadre.Rafraichir. Ce cas
-- fixe la frontière pour qu'une divergence future se voie.
Test("la frontiere du seuil est stricte", function()
  local monde = MondeGroupe()          -- temps = 1000, seuilAlerte = 60
  monde.buffs.party2 = {
    { spellId = 19742, duree = 600, expiration = 1060, lanceur = "player" },
  }
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.LireUnite("party2").restant, 60, "exactement 60")
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "posee", "60 n est pas encore bientot")
  FauxAPI.Reinitialiser()

  monde.buffs.party2[1].expiration = 1059
  ChargerSuivi(monde)
  AssertEgal(GestoBene_Suivi.Etat("party2").etat, "bientot", "59 bascule")
  FauxAPI.Reinitialiser()
end)

-- Cas n° 15 de la conception § 11 : un membre hors ligne garde son carré.
Test("un membre hors ligne garde son carre", function()
  local monde = MondeGroupe()
  monde.unites.party3 = { classe = "PRIEST", nom = "Lumen" }
  -- Aucun buff lisible pour lui : c'est ce que voit le client d'un déconnecté.
  ChargerSuivi(monde)
  local membres = GestoBene_Suivi.Membres()
  AssertEgal(#membres, 4, "il reste dans la liste")
  AssertEgal(membres[4], "party3", "et a sa place, sans faire glisser les autres")
  AssertEgal(GestoBene_Suivi.Etat("party3").etat, "absente", "son carre signale le manque")
  FauxAPI.Reinitialiser()
end)

function LancerTests()
  for _, c in ipairs(cas) do
    local ok, err = pcall(c.fonction)
    -- Un cas qui casse avant sa propre Reinitialiser() laisserait les
    -- globales du faux en place et ferait cascader les cas suivants : on la
    -- rappelle donc ici, sans condition sur le résultat.
    FauxAPI.Reinitialiser()
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
