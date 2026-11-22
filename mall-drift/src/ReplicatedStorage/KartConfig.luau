--[[
	KartConfig  (ModuleScript)
	À placer dans : ReplicatedStorage   — nom exact : KartConfig

	Le fichier des RÉGLAGES. Change les chiffres ici pour modifier le jeu
	sans toucher au reste du code.
]]

local Lighting = game:GetService("Lighting")

local Config = {}

Config.NomDuJeu = "Golden Mall Drift"
Config.Lieu = "Dubaï"

---------------------------------------------------------------------
-- LES KARTS  (Niveau = niveau du joueur nécessaire pour le débloquer)
-- VitesseMax     : vitesse de pointe (≈ km/h affichés)
-- Acceleration   : vitesse pour atteindre la vitesse max
-- Freinage       : puissance du frein
-- Rotation       : vitesse de rotation en conduite normale
-- RotationDrift  : multiplicateur de rotation en drift (360 !)
-- Adherence      : plus c'est haut, moins ça glisse (conduite normale)
-- AdherenceDrift : adhérence en drift (bas = grosse glissade)
-- Boost          : vitesse gagnée après un beau drift (2 étoiles ou +)
---------------------------------------------------------------------
Config.Karts = {
	Basique = {
		Nom = "Kart Basique", Niveau = 1, Ordre = 1,
		Description = "Équilibré, parfait pour apprendre.",
		VitesseMax = 50, Acceleration = 32, Freinage = 70,
		Rotation = 2.5, RotationDrift = 2.1, Adherence = 2.6, AdherenceDrift = 0.35, Boost = 16,
	},
	Chariot = {
		Nom = "Chariot Turbo", Niveau = 3, Ordre = 2,
		Description = "Un caddie motorisé. Glisse énormément !",
		VitesseMax = 46, Acceleration = 30, Freinage = 60,
		Rotation = 3.1, RotationDrift = 2.3, Adherence = 1.8, AdherenceDrift = 0.2, Boost = 15,
	},
	Bolide = {
		Nom = "Bolide Sport", Niveau = 6, Ordre = 3,
		Description = "Rapide et précis, avec un aileron.",
		VitesseMax = 66, Acceleration = 42, Freinage = 80,
		Rotation = 2.6, RotationDrift = 2.2, Adherence = 3, AdherenceDrift = 0.3, Boost = 22,
	},
	ProDubai = {
		Nom = "Kart Pro Dubaï", Niveau = 10, Ordre = 4,
		Description = "Le kart des champions. Finitions dorées.",
		VitesseMax = 74, Acceleration = 48, Freinage = 85,
		Rotation = 2.8, RotationDrift = 2.3, Adherence = 3.3, AdherenceDrift = 0.28, Boost = 26,
	},
}

---------------------------------------------------------------------
-- PERSONNALISATION (le garage VIP)
---------------------------------------------------------------------
Config.Couleurs = {
	{ Nom = "Blanc", Couleur = Color3.fromRGB(240, 240, 240), Niveau = 1 },
	{ Nom = "Noir", Couleur = Color3.fromRGB(25, 25, 28), Niveau = 1 },
	{ Nom = "Rouge", Couleur = Color3.fromRGB(215, 35, 40), Niveau = 1 },
	{ Nom = "Bleu", Couleur = Color3.fromRGB(35, 105, 215), Niveau = 1 },
	{ Nom = "Gris", Couleur = Color3.fromRGB(140, 145, 155), Niveau = 1 },
	{ Nom = "Jaune", Couleur = Color3.fromRGB(250, 205, 30), Niveau = 2 },
	{ Nom = "Vert", Couleur = Color3.fromRGB(40, 170, 80), Niveau = 2 },
	{ Nom = "Orange", Couleur = Color3.fromRGB(245, 130, 30), Niveau = 2 },
	{ Nom = "Rose", Couleur = Color3.fromRGB(245, 120, 180), Niveau = 4 },
	{ Nom = "Violet", Couleur = Color3.fromRGB(130, 70, 200), Niveau = 4 },
	{ Nom = "Turquoise", Couleur = Color3.fromRGB(30, 200, 200), Niveau = 4 },
	{ Nom = "Bleu nuit", Couleur = Color3.fromRGB(20, 35, 90), Niveau = 5 },
	{ Nom = "Bordeaux", Couleur = Color3.fromRGB(110, 20, 40), Niveau = 5 },
	{ Nom = "Sable", Couleur = Color3.fromRGB(215, 190, 140), Niveau = 7 },
	{ Nom = "Vert menthe", Couleur = Color3.fromRGB(150, 230, 190), Niveau = 7 },
	{ Nom = "Or", Couleur = Color3.fromRGB(225, 175, 45), Niveau = 10 },
}

-- Finition de la peinture (aspect réaliste)
Config.Finitions = {
	{ Nom = "Brillant", Materiau = Enum.Material.SmoothPlastic, Reflet = 0.12, Niveau = 1 },
	{ Nom = "Mat", Materiau = Enum.Material.SmoothPlastic, Reflet = 0, Niveau = 2 },
	{ Nom = "Métallisé", Materiau = Enum.Material.Metal, Reflet = 0.1, Niveau = 4 },
	{ Nom = "Nacré", Materiau = Enum.Material.SmoothPlastic, Reflet = 0.35, Niveau = 8 },
	{ Nom = "Chrome", Materiau = Enum.Material.Foil, Reflet = 0.55, Niveau = 12 },
}

-- Néons sous le kart (ils éclairent le sol, comme dans les vidéos TikTok)
Config.Neons = {
	{ Nom = "Aucun", Couleur = Color3.new(0, 0, 0), Niveau = 1 },
	{ Nom = "Bleu", Couleur = Color3.fromRGB(40, 110, 255), Niveau = 1 },
	{ Nom = "Violet", Couleur = Color3.fromRGB(170, 60, 255), Niveau = 1 },
	{ Nom = "Rose", Couleur = Color3.fromRGB(255, 60, 200), Niveau = 2 },
	{ Nom = "Cyan", Couleur = Color3.fromRGB(40, 230, 255), Niveau = 3 },
	{ Nom = "Vert", Couleur = Color3.fromRGB(60, 255, 110), Niveau = 4 },
	{ Nom = "Rouge", Couleur = Color3.fromRGB(255, 40, 50), Niveau = 5 },
	{ Nom = "Blanc", Couleur = Color3.fromRGB(240, 245, 255), Niveau = 6 },
	{ Nom = "Or", Couleur = Color3.fromRGB(255, 190, 50), Niveau = 9 },
	{ Nom = "Arc-en-ciel", Couleur = Color3.fromRGB(255, 255, 255), Niveau = 12 }, -- change de couleur en continu
}

-- Autocollants sur les flancs du kart
Config.Autocollants = {
	{ Nom = "Aucun", Texte = "", Niveau = 1 },
	{ Nom = "Étoile", Texte = "⭐", Niveau = 1 },
	{ Nom = "Lunettes", Texte = "😎", Niveau = 2 },
	{ Nom = "Chat", Texte = "🐱", Niveau = 3 },
	{ Nom = "Donut", Texte = "🍩", Niveau = 5 },
	{ Nom = "Éclair", Texte = "⚡", Niveau = 7 },
	{ Nom = "Couronne", Texte = "👑", Niveau = 9 },
	{ Nom = "Diamant", Texte = "💎", Niveau = 12 },
}

-- Le kart d'un nouveau joueur
Config.PersoParDefaut = {
	Kart = "Basique",
	Carrosserie = "Bleu",
	Finition = "Brillant",
	Jantes = "Blanc",
	Siege = "Noir",
	Bandes = "Blanc",
	BandesActives = true,
	Autocollant = "Étoile",
	Numero = 7,
	Neon = "Bleu",
}

-- Petites fonctions pour retrouver un élément par son nom
local function chercher(liste, nom)
	for _, element in ipairs(liste) do
		if element.Nom == nom then
			return element
		end
	end
	return nil
end
function Config.Couleur(nom: string) return chercher(Config.Couleurs, nom) end
function Config.Finition(nom: string) return chercher(Config.Finitions, nom) end
function Config.Autocollant(nom: string) return chercher(Config.Autocollants, nom) end
function Config.Neon(nom: string) return chercher(Config.Neons, nom) end

---------------------------------------------------------------------
-- PROGRESSION : les drifts donnent de l'XP → le niveau du joueur monte
-- → débloque karts, couleurs, finitions, autocollants
---------------------------------------------------------------------
Config.NiveauMax = 30
function Config.XPPourNiveauSuivant(niveau: number): number
	return 800 + 400 * (niveau - 1) -- niv.1→2 : 800 XP, niv.2→3 : 1200 XP, etc.
end
function Config.NiveauDepuisXP(xp: number): (number, number, number)
	local niveau = 1
	local reste = xp
	while niveau < Config.NiveauMax and reste >= Config.XPPourNiveauSuivant(niveau) do
		reste -= Config.XPPourNiveauSuivant(niveau)
		niveau += 1
	end
	return niveau, reste, Config.XPPourNiveauSuivant(niveau)
end

---------------------------------------------------------------------
-- LA SÉCURITÉ DU MALL (les gardes qui veulent t'arrêter)
-- Les gardes ne s'occupent que des karts : à pied, tu es un client normal.
-- Dehors (parking, garage), tu es en sécurité.
---------------------------------------------------------------------
Config.Securite = {
	Policiers = 3, -- nombre de policiers au rez-de-chaussée (ils patrouillent à pied)
	PoliciersEtage = 2, -- nombre de policiers au 1er étage
	VitessePatrouille = 10, -- à pied, en patrouille
	TempsMonteeKart = 0.8, -- quand il te voit, il saute dans son kart de police (secondes)
	VitessePoursuite = 44, -- en kart de police (le kart Basique monte à 50 : ça se joue à peu !)
	DistanceVue = 110, -- jusqu'où un policier voit
	AngleVue = 75, -- largeur du regard (degrés de chaque côté)
	DistanceOuie = 20, -- trop près = il t'entend même de dos
	Radio = 3, -- secondes pendant lesquelles il sait encore où tu es après t'avoir perdu de vue
	DistanceRenfort = 160, -- les collègues à cette distance viennent en renfort
	DistanceArrestation = 6, -- si un policier arrive aussi près de ton kart : attrapé !
	TempsPourSemer = 7, -- secondes sans être vu pour le semer
	DureeGlissade = 2.5, -- un policier sur le sol mouillé glisse et tombe
	BonusSemer = 150, -- XP gagnée quand tu sèmes la police
	BonusGlissade = 100, -- XP gagnée quand un policier qui te poursuit glisse
}

---------------------------------------------------------------------
-- LE MODE EN LIGNE « POLICE CONTRE FUGITIFS »
-- Dès qu'il y a assez de joueurs : tirage au sort des équipes (moitié police,
-- moitié fugitifs), puis une manche. La police doit attraper tous les fugitifs
-- avant la fin du temps ; sinon, les fugitifs gagnent.
---------------------------------------------------------------------
Config.Partie = {
	JoueursMin = 2, -- joueurs nécessaires pour lancer une manche
	Intermission = 12, -- secondes sur la page d'attente avant le tirage au sort
	DureeManche = 300, -- durée d'une manche (5 minutes)
	AvanceFugitifs = 8, -- secondes d'avance des fugitifs (la police reste bloquée après le vert)
	DistanceArrestation = 8, -- distance entre les centres des deux karts (un kart fait 6 de long) : ils se touchent = arrestation
	XPVictoire = 300, -- XP pour chaque joueur de l'équipe gagnante
	XPParticipation = 50, -- XP pour tous les participants
	XPArrestation = 100, -- XP pour le policier qui arrête un fugitif
	XPRoiDuDrift = 150, -- bonus pour le joueur qui a fait le plus de points de drift dans la manche
	-- DRIFT BATTLE : pas de police, celui qui fait le plus de points de drift gagne
	DureeBattle = 60, -- 1 minute (mets 30 pour des parties encore plus courtes)
	BattleJoueursMin = 1, -- seul, ça devient un défi contre le chrono
	XPPodium = { 300, 200, 100 }, -- XP pour le 1er, le 2e et le 3e
	-- BOTS DE TEST : s'il manque des joueurs, des bots complètent la partie
	-- (pratique pour tester seul). Mets 0 pour les désactiver.
	BotsTest = 1,
	VitesseBotPolice = 40, -- vitesse d'un bot policier (ton kart Basique monte à 50)
	VitesseBotFugitif = 36, -- vitesse d'un bot fugitif
}

---------------------------------------------------------------------
-- LES TAPIS ROULANTS (les rampes entre les 2 étages)
---------------------------------------------------------------------
Config.Tapis = {
	Vitesse = 32, -- vitesse minimum à laquelle le tapis t'emporte (montée ou descente)
}

---------------------------------------------------------------------
-- LES GENS DANS LE MALL (vendeurs à la caisse, clients dans les boutiques)
---------------------------------------------------------------------
Config.PNJ = {
	Max = 220, -- nombre maximum de personnes (baisse-le, par ex. à 100, si le jeu rame sur téléphone)
	ChanceClient = 0.75, -- chance qu'il y ait un client dans une boutique
}

---------------------------------------------------------------------
-- LE SOL MOUILLÉ
---------------------------------------------------------------------
-- La glisse en fonction de la vitesse : à fond, les pneus accrochent moins
Config.Glisse = {
	PerteAdherenceAFond = 0.45, -- à vitesse max, l'adhérence est multipliée par (1 - 0.45)
	CoupDeVolant = 1.6, -- l'arrière décroche quand on déclenche le drift en tournant
}

Config.Mouille = {
	Adherence = 0.3, -- adhérence x0.3 = encore 3x plus glissant
	Acceleration = 0.5, -- on accélère 2x moins bien sur l'eau
	BonusPoints = 1.5, -- un drift sur l'eau rapporte x1,5
}

---------------------------------------------------------------------
-- LE SCORE DE DRIFT
---------------------------------------------------------------------
Config.Score = {
	VitesseMin = 10, -- en dessous, pas de points
	AngleMin = 12, -- angle de glisse minimum (degrés)
	Tolerance = 0.35, -- secondes sans glisser avant d'encaisser le drift
	ComboParSeconde = 0.6, -- le multiplicateur monte de 0.6 par seconde
	ComboMax = 5,
	PointsParStud = 0.5,
	Bonus360 = 150, -- bonus par 360° (x combo)
	SeuilChoc = 22, -- perte de vitesse brutale = choc = drift perdu
	Minimum = 20,
	Etoiles = { 150, 500, 1200 }, -- points pour 1, 2, 3 étoiles
	DureeBoost = 1.5,
	-- Un beau drift = un BOOST, selon les étoiles (durée en secondes, puissance x le Boost du kart)
	BoostEtoiles = {
		[1] = { Duree = 0.8, Force = 0.6 },
		[2] = { Duree = 1.4, Force = 1 },
		[3] = { Duree = 2.2, Force = 1.4 },
	},
	BoostEvasion = 1.5, -- si la police te poursuit, le boost est multiplié par 1,5
	MaxParDrift = 8000, -- sécurité anti-triche côté serveur
}

---------------------------------------------------------------------
-- SONS (optionnel) : colle un identifiant de la Boîte à outils > Audio
-- ex. "rbxassetid://1234567". Vide = pas de son.
---------------------------------------------------------------------
Config.Sons = {
	Moteur = "",
	Drift = "",
	Eclaboussure = "",
}

---------------------------------------------------------------------
-- JOUR / NUIT
---------------------------------------------------------------------
Config.NuitParDefaut = false -- le jeu démarre de jour (touche N pour passer en nuit)

---------------------------------------------------------------------
-- CAMÉRA (elle suit le kart toute seule)
---------------------------------------------------------------------
Config.Camera = {
	VueParDefaut = "gopro", -- "gopro" (caméra sur la poitrine, comme les vidéos TikTok) ou "derriere"
	ChampGoPro = 100, -- grand angle de la GoPro (degrés)
	Distance = 13, -- distance derrière le kart
	Hauteur = 5.5, -- hauteur au-dessus du kart
	Souplesse = 5, -- plus c'est haut, plus la caméra suit vite (bas = plus "cinéma")
	SuiviGlisse = 0.35, -- 0 = regarde où pointe le kart, 1 = regarde où il glisse
}

function Config.AppliquerAmbiance(nuit: boolean)
	-- L'intérieur du mall reste bien éclairé dans les deux cas (comme un vrai
	-- centre commercial) : c'est surtout le ciel et le parking qui changent.
	-- Lumière naturelle : ni trop sombre, ni éblouissante.
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6 -- reflets légers sur le carrelage
	Lighting.ExposureCompensation = 0
	if nuit then
		Lighting.ClockTime = 21.5
		Lighting.Brightness = 1
		Lighting.Ambient = Color3.fromRGB(95, 95, 108)
		Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 90)
	else
		Lighting.ClockTime = 14
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.fromRGB(118, 116, 112)
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end
	Lighting:SetAttribute("Nuit", nuit)
end

return Config
