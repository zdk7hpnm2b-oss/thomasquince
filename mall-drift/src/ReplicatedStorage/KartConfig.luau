--[[
	KartConfig  (ModuleScript)
	À placer dans : ReplicatedStorage   — nom exact : KartConfig

	C'est le fichier des RÉGLAGES. Tu peux changer les chiffres ici
	pour modifier le ressenti du jeu sans toucher au reste du code.
]]

local Lighting = game:GetService("Lighting")

local Config = {}

---------------------------------------------------------------------
-- LES KARTS
-- VitesseMax      : vitesse de pointe (en studs/s ≈ km/h affichés)
-- Acceleration    : à quelle vitesse on atteint la vitesse max
-- Freinage        : puissance du frein
-- Rotation        : vitesse à laquelle le kart tourne (normal)
-- RotationDrift   : multiplicateur de rotation quand on drifte (360 !)
-- Adherence       : plus c'est haut, moins le kart glisse (conduite normale)
-- AdherenceDrift  : adhérence pendant le drift (bas = grosse glissade)
-- Boost           : vitesse gagnée après un beau drift (2 étoiles ou +)
---------------------------------------------------------------------
Config.Karts = {
	Basique = {
		Nom = "Kart Basique",
		Couleur = Color3.fromRGB(35, 105, 215),
		VitesseMax = 50,
		Acceleration = 32,
		Freinage = 70,
		Rotation = 2.4,
		RotationDrift = 1.7,
		Adherence = 9,
		AdherenceDrift = 1.4,
		Boost = 16,
	},
	Chariot = {
		Nom = "Chariot Turbo",
		Couleur = Color3.fromRGB(165, 170, 180),
		VitesseMax = 42,
		Acceleration = 28,
		Freinage = 60,
		Rotation = 3.1,
		RotationDrift = 2.1,
		Adherence = 6,
		AdherenceDrift = 0.9,
		Boost = 14,
	},
	Bolide = {
		Nom = "Bolide Rouge",
		Couleur = Color3.fromRGB(215, 40, 40),
		VitesseMax = 68,
		Acceleration = 42,
		Freinage = 80,
		Rotation = 2.5,
		RotationDrift = 1.9,
		Adherence = 10,
		AdherenceDrift = 1.1,
		Boost = 22,
	},
}

-- L'ordre dans lequel les karts sont garés au départ
Config.OrdreKarts = { "Basique", "Chariot", "Basique", "Bolide" }

---------------------------------------------------------------------
-- LE SOL MOUILLÉ
---------------------------------------------------------------------
Config.Mouille = {
	Adherence = 0.25, -- l'adhérence est multipliée par ce chiffre (0.25 = 4x plus glissant)
	Acceleration = 0.5, -- on accélère 2x moins bien sur l'eau
	BonusPoints = 1.5, -- un drift sur l'eau rapporte 1,5x plus de points
}

---------------------------------------------------------------------
-- LE SCORE DE DRIFT
---------------------------------------------------------------------
Config.Score = {
	VitesseMin = 10, -- en dessous de cette vitesse, pas de points
	AngleMin = 12, -- angle de glisse minimum (en degrés) pour compter un drift
	Tolerance = 0.35, -- secondes "sans glisser" avant que le drift soit encaissé
	ComboParSeconde = 0.6, -- le multiplicateur monte de 0.6 par seconde de drift
	ComboMax = 5, -- multiplicateur maximum (x5)
	PointsParStud = 0.5, -- points de base
	Bonus360 = 150, -- bonus pour chaque 360° (multiplié par le combo)
	SeuilChoc = 22, -- perte de vitesse brutale = choc contre un mur = drift raté
	Minimum = 20, -- en dessous, le drift ne compte pas
	Etoiles = { 150, 500, 1200 }, -- points pour 1, 2 et 3 étoiles
	DureeBoost = 1.5, -- durée du boost après un drift 2 étoiles ou +
}

---------------------------------------------------------------------
-- LES SONS (optionnel)
-- Mets ici l'identifiant d'un son trouvé dans la Boîte à outils
-- (Toolbox > Audio) de Roblox Studio, par exemple "rbxassetid://1234567".
-- Laisse vide ("") pour ne pas avoir de son.
---------------------------------------------------------------------
Config.Sons = {
	Moteur = "",
	Drift = "",
	Eclaboussure = "",
}

---------------------------------------------------------------------
-- LES NIVEAUX (la progression du jeu)
-- Seul le niveau 1 est construit dans ce prototype. Les autres sont
-- la feuille de route : chaque nouveau niveau = un centre plus grand.
---------------------------------------------------------------------
Config.Niveaux = {
	{ Nom = "Le Petit Marché", Lieu = "Ton quartier", Pret = true },
	{ Nom = "Hyper Géant", Lieu = "Zone commerciale", Pret = false },
	{ Nom = "Galerie Lumière", Lieu = "Centre-ville", Pret = false },
	{ Nom = "Mega Mall", Lieu = "Grande métropole", Pret = false },
	{ Nom = "Golden Mall", Lieu = "Dubaï", Pret = false },
}
Config.NiveauActuel = 1

---------------------------------------------------------------------
-- JOUR / NUIT
---------------------------------------------------------------------
Config.NuitParDefaut = true

function Config.AppliquerAmbiance(nuit: boolean)
	if nuit then
		Lighting.ClockTime = 0
		Lighting.Brightness = 1
		Lighting.Ambient = Color3.fromRGB(70, 70, 95)
		Lighting.OutdoorAmbient = Color3.fromRGB(45, 45, 70)
	else
		Lighting.ClockTime = 13
		Lighting.Brightness = 2.5
		Lighting.Ambient = Color3.fromRGB(140, 140, 140)
		Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
	end
	Lighting:SetAttribute("Nuit", nuit)
end

return Config
