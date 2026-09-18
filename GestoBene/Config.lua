-- Réglages de l'addon GestoBene.
-- C'est le seul fichier destiné à être édité à la main, hors du jeu.
-- Un changement prend effet au /reload ou à la reconnexion.

GestoBene_Config = {

  -- Une bénédiction par classe.
  -- Valeurs admises : "Rois", "Puissance", "Sagesse", "Sanctuaire"
  parClasse = {
    WARRIOR     = "Puissance",
    PALADIN     = "Rois",
    HUNTER      = "Puissance",
    ROGUE       = "Puissance",
    PRIEST      = "Sagesse",
    DEATHKNIGHT = "Puissance",
    SHAMAN      = "Sagesse",
    MAGE        = "Sagesse",
    WARLOCK     = "Sagesse",
    DRUID       = "Sagesse",
  },

  -- Sous ce nombre de secondes restantes, le carré passe en orange.
  seuilAlerte = 60,

  -- Position du cadre. « /gesto pos » imprime les valeurs courantes à recopier.
  ancrage = { point = "CENTER", x = 0, y = -200 },

  -- Taille d'un carré, en pixels.
  tailleCarre = 48,
}
