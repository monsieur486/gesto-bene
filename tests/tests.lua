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

Test("un spellId se retrouve dans sa benediction", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.CleParSpellId(25894), "Sagesse", "sagesse superieure")
  AssertEgal(GestoBene_Sorts.CleParSpellId(20217), "Rois", "rois normale")
  AssertNil(GestoBene_Sorts.CleParSpellId(12345), "sort etranger")
  FauxAPI.Reinitialiser()
end)

Test("les abreviations font trois lettres", function()
  ChargerSorts(MondeKahalie55())
  AssertEgal(GestoBene_Sorts.Abreger("Rois"), "ROI", "ROI")
  AssertEgal(GestoBene_Sorts.Abreger("Sanctuaire"), "SAN", "SAN")
  AssertEgal(GestoBene_Sorts.Abreger("Inexistante"), "?", "inconnue")
  FauxAPI.Reinitialiser()
end)

function LancerTests()
  for _, c in ipairs(cas) do
    local ok, err = pcall(c.fonction)
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
