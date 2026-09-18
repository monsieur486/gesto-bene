-- Réglages de l'addon GestoBene.
-- C'est le seul fichier destiné à être édité à la main, hors du jeu.
-- Un changement prend effet au /reload ou à la reconnexion.

GestoBene_Config = {

  -- Valeurs admises : "Rois", "Puissance", "Sagesse", "Sanctuaire"
  -- Les porteurs de tissu vivent sur leur mana : Sagesse.
  -- Tous les autres profitent davantage des Rois.
  -- Le paladin, c'est toi.
  parClasse = {
    WARRIOR     = "Rois",
    PALADIN     = "Sagesse",
    HUNTER      = "Rois",
    ROGUE       = "Rois",
    PRIEST      = "Sagesse",
    DEATHKNIGHT = "Rois",
    SHAMAN      = "Rois",
    MAGE        = "Sagesse",
    WARLOCK     = "Sagesse",
    DRUID       = "Rois",
  },

  -- Sous ce nombre de secondes restantes, le carré passe en orange.
  seuilAlerte = 60,

  -- Position du cadre. « /gesto pos » imprime les valeurs courantes à recopier.
  ancrage = { point = "CENTER", x = 0, y = -200 },

  -- Taille d'un carré, en pixels.
  tailleCarre = 48,

  -- Le cadre démarre verrouillé. En donjon on clique partout, et un cadre qui
  -- se déplace par accident est une gêne. Le cadenas à gauche des carrés le
  -- libère d'un clic. L'état ne survit pas au /reload : sans SavedVariables,
  -- il repart toujours de cette valeur.
  verrouille = true,
}
