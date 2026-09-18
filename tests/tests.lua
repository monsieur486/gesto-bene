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
