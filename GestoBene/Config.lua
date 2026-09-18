-- Réglages de l'addon GestoBene.
-- C'est le seul fichier destiné à être édité à la main, hors du jeu.
-- Un changement prend effet au /reload ou à la reconnexion.

GestoBene_Config = {

  -- Valeurs admises : "Rois", "Puissance", "Sagesse", "Sanctuaire"
  -- Les porteurs de tissu vivent sur leur mana : Sagesse.
  -- Tous les autres profitent davantage des Rois.
  -- Le paladin, c'est toi : ta ligne sert de défaut au bouton au-dessus de
  -- ton carré, comme celle de tout joueur dont la classe est listée dans
  -- « bascules » plus bas. Le bouton surcharge le joueur nommément, en
  -- mémoire seulement (GestoBene_Suivi) : cette table-ci ne bouge jamais.
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

  -- Bascules par classe. Une classe listée ici gagne un bouton au-dessus de
  -- son carré, qui alterne la bénédiction du joueur entre les deux valeurs.
  -- Une classe absente n'a pas de bouton et sa ligne de parClasse ne bouge
  -- jamais.
  --
  -- La règle est par joueur, pas par classe : un guerrier Fureur et un
  -- guerrier Protection peuvent vouloir chacun autre chose, donc basculer
  -- au-dessus de l'un ne change que lui. La surcharge vit dans
  -- GestoBene_Suivi, jamais ici.
  bascules = {
    PALADIN     = { "Sagesse", "Puissance" },
    WARRIOR     = { "Rois", "Puissance" },
    HUNTER      = { "Rois", "Puissance" },
    ROGUE       = { "Rois", "Puissance" },
    DEATHKNIGHT = { "Rois", "Puissance" },
    SHAMAN      = { "Rois", "Puissance" },
    DRUID       = { "Rois", "Puissance" },
    -- Mage, prêtre, démoniste : aucune bascule, ils ne veulent que du mana.
  },
}
