-- Réglages de l'addon GestoBene.
-- C'est le seul fichier destiné à être édité à la main, hors du jeu.
-- Un changement prend effet au /reload ou à la reconnexion.

GestoBene_Config = {

  -- Valeurs admises : "Rois", "Puissance", "Sagesse", "Sanctuaire"
  -- Les porteurs de tissu vivent sur leur mana : Sagesse.
  -- Tous les autres profitent davantage des Rois.
  -- Le bouton au-dessus de chaque carré fait défiler les bénédictions que ce
  -- joueur sait lancer et surcharge son nom, en mémoire seulement
  -- (GestoBene_Suivi) : cette table-ci ne bouge jamais, elle ne sert que de
  -- point de départ.
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

  -- Le sceau suivi par le carré placé à gauche du cadenas.
  -- Valeurs admises : "Piete", "Sagesse", "Lumiere", "Justice",
  -- "Commandement", "Vengeance", "Corruption"
  -- Le clic droit sur ce carré passe au sceau suivant parmi ceux que tu
  -- connais ; ce choix est mémorisé dans GestoBene_Etat et l'emporte ensuite
  -- sur cette valeur, qui ne sert qu'à la toute première connexion.
  sceau = "Sagesse",

  -- Sous ce nombre de secondes restantes, le carré passe en orange.
  -- Le carré de sceau suit le même seuil.
  seuilAlerte = 60,

  -- Seuils du compteur de Symboles des rois (le réactif des bénédictions
  -- supérieures), affiché à droite des carrés. Au-dessus de seuilReactifBon,
  -- le compteur est vert ; au-dessus de seuilReactifFaible, orange ; à ce
  -- niveau ou en dessous, rouge : réserve basse. Ce sont des réglages, pas
  -- des constantes de code — à ajuster selon la longueur des donjons visés.
  seuilReactifBon = 10,
  seuilReactifFaible = 5,

  -- Position du cadre à la toute première connexion. Ensuite, la position
  -- mémorisée dans GestoBene_Etat après un déplacement l'emporte.
  -- « /gesto pos » imprime les valeurs courantes à recopier.
  ancrage = { point = "CENTER", x = 0, y = -200 },

  -- Dimensions d'un carré, en pixels : plus large que haut. Le carré de sceau
  -- prend les mêmes.
  largeurCarre = 48,
  hauteurCarre = 32,

  -- Le cadre démarre verrouillé. En donjon on clique partout, et un cadre qui
  -- se déplace par accident est une gêne. Le cadenas à gauche des carrés le
  -- libère d'un clic. Cette valeur ne sert qu'à la toute première
  -- connexion : ensuite, l'état du cadenas est mémorisé dans GestoBene_Etat
  -- et survit au /reload.
  verrouille = true,
}
