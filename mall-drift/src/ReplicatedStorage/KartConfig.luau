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
-- LES PLACES DE L'EXPÉRIENCE (lobby + places de jeu)
-- Mets ici le numéro (PlaceId) de chaque place, visible sur le Creator Hub.
-- Tant que Lobby = 0, tout le jeu tourne dans UNE seule place (pratique pour
-- tester dans Studio). Le même fichier est publié dans toutes les places :
-- chacune reconnaît son rôle grâce à son PlaceId.
---------------------------------------------------------------------
Config.Places = {
	Lobby = 0, -- la place de départ (publique) : garage + menu + matchmaking
	Entrainement = 0, -- drift libre avec la police bot
	PoliceFugitifs = 0, -- les manches en équipes (serveurs privés créés par le matchmaking)
	DriftBattle = 0, -- le défi solo + classement mondial
	Jeu4 = 0, -- (réservée pour un 4e mode de jeu)
}

-- Le rôle de la place où tourne le jeu : "Lobby", "Entrainement", "PoliceFugitifs",
-- "DriftBattle", "Jeu4", ou "ToutEnUn" (tout dans une seule place)
function Config.TypeDePlace(): string
	if Config.Places.Lobby == 0 then
		return "ToutEnUn"
	end
	for nom, id in pairs(Config.Places) do
		if id ~= 0 and id == game.PlaceId then
			return nom
		end
	end
	return "ToutEnUn" -- (place inconnue, par exemple un fichier pas encore publié)
end

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
	-- ✨ KART EXCLUSIF : seulement en Robux (pas de niveau requis). Carrosserie
	-- arc-en-ciel animée, ailes néon, corne dorée, paillettes d'étoiles et
	-- traînée arc-en-ciel. Crée un « Produit pour développeurs » et mets son numéro ici.
	Galaxie = {
		Nom = "Licorne Galaxie", Niveau = 1, Ordre = 5,
		Exclusif = true, ProduitId = 0, PrixAffiche = "R$ 399",
		Description = "ÉDITION EXCLUSIVE ✨ Arc-en-ciel animé, ailes néon, paillettes d'étoiles !",
		VitesseMax = 76, Acceleration = 50, Freinage = 85,
		Rotation = 2.9, RotationDrift = 2.4, Adherence = 3.2, AdherenceDrift = 0.26, Boost = 28,
	},
}
for id, k in pairs(Config.Karts) do
	k.Kart = id -- (pratique pour les achats)
end

---------------------------------------------------------------------
-- PERSONNALISATION (le garage VIP)
---------------------------------------------------------------------
-- Les couleurs s'ACHÈTENT avec des pièces 💰 (Prix = 0 : gratuite). Une couleur
-- achetée sert partout : carrosserie, jantes, siège, bandes.
Config.Couleurs = {
	{ Nom = "Blanc", Couleur = Color3.fromRGB(240, 240, 240), Niveau = 1, Prix = 0 },
	{ Nom = "Noir", Couleur = Color3.fromRGB(25, 25, 28), Niveau = 1, Prix = 0 },
	{ Nom = "Bleu", Couleur = Color3.fromRGB(35, 105, 215), Niveau = 1, Prix = 0 },
	{ Nom = "Gris", Couleur = Color3.fromRGB(140, 145, 155), Niveau = 1, Prix = 5 },
	{ Nom = "Rouge", Couleur = Color3.fromRGB(215, 35, 40), Niveau = 1, Prix = 10 },
	{ Nom = "Jaune", Couleur = Color3.fromRGB(250, 205, 30), Niveau = 1, Prix = 10 },
	{ Nom = "Orange", Couleur = Color3.fromRGB(245, 130, 30), Niveau = 1, Prix = 50 },
	{ Nom = "Vert", Couleur = Color3.fromRGB(40, 170, 80), Niveau = 1, Prix = 50 },
	{ Nom = "Turquoise", Couleur = Color3.fromRGB(30, 200, 200), Niveau = 1, Prix = 50 },
	{ Nom = "Bleu nuit", Couleur = Color3.fromRGB(20, 35, 90), Niveau = 1, Prix = 75 },
	{ Nom = "Bordeaux", Couleur = Color3.fromRGB(110, 20, 40), Niveau = 1, Prix = 75 },
	{ Nom = "Rose", Couleur = Color3.fromRGB(245, 120, 180), Niveau = 1, Prix = 75 },
	{ Nom = "Violet", Couleur = Color3.fromRGB(130, 70, 200), Niveau = 1, Prix = 100 },
	{ Nom = "Sable", Couleur = Color3.fromRGB(215, 190, 140), Niveau = 1, Prix = 100 },
	{ Nom = "Vert menthe", Couleur = Color3.fromRGB(150, 230, 190), Niveau = 1, Prix = 150 },
	{ Nom = "Or", Couleur = Color3.fromRGB(225, 175, 45), Niveau = 1, Prix = 150 },
}

---------------------------------------------------------------------
-- LA MONNAIE DU JEU : les pièces 💰 (gagnées en jouant)
---------------------------------------------------------------------
Config.Monnaie = {
	PointsParPiece = 20, -- 1 pièce pour 20 points de drift
	XPParPiece = 10, -- et 1 pièce pour 10 XP gagnés dans les modes (victoires, défis…)
}

---------------------------------------------------------------------
-- LES PEINTURES PREMIUM (Robux) et LE MAGASIN
-- Crée chaque produit sur le Creator Hub (ton expérience > Monétisation >
-- Produits pour développeurs), puis colle son numéro dans ProduitId.
-- Tant que ProduitId = 0 : dans Studio, l'achat est GRATUIT (pour tester).
---------------------------------------------------------------------
Config.PeinturesPremium = {
	{ Nom = "Chrome miroir", Couleur = Color3.fromRGB(225, 228, 235), Materiau = Enum.Material.Foil, Reflet = 0.6, ProduitId = 0, PrixAffiche = "R$ 49" },
	{ Nom = "Or 24 carats", Couleur = Color3.fromRGB(240, 185, 40), Materiau = Enum.Material.Foil, Reflet = 0.45, ProduitId = 0, PrixAffiche = "R$ 49" },
	{ Nom = "Arc-en-ciel", Couleur = Color3.fromRGB(255, 80, 80), Materiau = Enum.Material.SmoothPlastic, Reflet = 0.2, ProduitId = 0, PrixAffiche = "R$ 99", ArcEnCiel = true },
	{ Nom = "Rouge bonbon", Couleur = Color3.fromRGB(200, 10, 30), Materiau = Enum.Material.SmoothPlastic, Reflet = 0.4, ProduitId = 0, PrixAffiche = "R$ 29" },
	{ Nom = "Cyan néon", Couleur = Color3.fromRGB(40, 230, 255), Materiau = Enum.Material.Neon, Reflet = 0, ProduitId = 0, PrixAffiche = "R$ 39" },
	{ Nom = "Vert toxique", Couleur = Color3.fromRGB(110, 255, 60), Materiau = Enum.Material.Neon, Reflet = 0, ProduitId = 0, PrixAffiche = "R$ 39" },
	-- ✦ Couleurs EXCLUSIVES
	{ Nom = "Licorne pastel", Couleur = Color3.fromRGB(255, 170, 230), Materiau = Enum.Material.SmoothPlastic, Reflet = 0.3, ProduitId = 0, PrixAffiche = "R$ 99", ArcEnCiel = true, Pastel = true, Exclusive = true },
	{ Nom = "Galaxie", Couleur = Color3.fromRGB(95, 40, 200), Materiau = Enum.Material.Glass, Reflet = 0.5, ProduitId = 0, PrixAffiche = "R$ 79", Exclusive = true },
	{ Nom = "Lave", Couleur = Color3.fromRGB(255, 90, 20), Materiau = Enum.Material.Neon, Reflet = 0, ProduitId = 0, PrixAffiche = "R$ 59", Exclusive = true },
	{ Nom = "Glace polaire", Couleur = Color3.fromRGB(170, 225, 255), Materiau = Enum.Material.Ice, Reflet = 0.3, ProduitId = 0, PrixAffiche = "R$ 59", Exclusive = true },
	{ Nom = "Carbone", Couleur = Color3.fromRGB(35, 35, 40), Materiau = Enum.Material.DiamondPlate, Reflet = 0.15, ProduitId = 0, PrixAffiche = "R$ 49", Exclusive = true },
	{ Nom = "Bonbon rose", Couleur = Color3.fromRGB(255, 70, 170), Materiau = Enum.Material.SmoothPlastic, Reflet = 0.45, ProduitId = 0, PrixAffiche = "R$ 39", Exclusive = true },
}

-- 🌈 TRAÎNÉES : un effet qui suit le kart quand il roule (achat en Robux)
local function sequence(...): ColorSequence
	local couleurs = { ... }
	local points = {}
	for k, c in ipairs(couleurs) do
		table.insert(points, ColorSequenceKeypoint.new((k - 1) / math.max(#couleurs - 1, 1), c))
	end
	return ColorSequence.new(points)
end
Config.Trainees = {
	{ Nom = "Aucune", Icone = "∅" },
	{ Nom = "Feu", Icone = "🔥", Couleurs = sequence(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 140, 20), Color3.fromRGB(220, 30, 20)), Particules = "Feu" },
	{ Nom = "Arc-en-ciel", Icone = "🌈", Couleurs = sequence(Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 200, 60), Color3.fromRGB(80, 230, 110), Color3.fromRGB(70, 160, 255), Color3.fromRGB(190, 90, 255)) },
	{ Nom = "Étoiles", Icone = "✨", Couleurs = sequence(Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 255, 255)), Particules = "Etoiles" },
	{ Nom = "Éclair", Icone = "⚡", Couleurs = sequence(Color3.fromRGB(220, 250, 255), Color3.fromRGB(60, 200, 255), Color3.fromRGB(40, 90, 255)), Particules = "Eclair" },
	{ Nom = "Cœurs", Icone = "💖", Couleurs = sequence(Color3.fromRGB(255, 200, 230), Color3.fromRGB(255, 70, 170)), Particules = "Coeurs" },
	{ Nom = "Galaxie", Icone = "🌌", Couleurs = sequence(Color3.fromRGB(255, 120, 230), Color3.fromRGB(130, 70, 255), Color3.fromRGB(20, 20, 80)), Particules = "Etoiles" },
}

-- 🛒 LE MAGASIN (Robux). Catégories : Offres, Traînées, Roue, Pièces.
-- Pour chaque offre : crée un « Produit pour développeurs » et mets son numéro dans ProduitId
-- (tant que c'est 0, l'achat est gratuit dans Studio pour tester).
Config.Boutique = {
	-- ⭐ OFFRES
	{ Id = "KartGalaxie", Categorie = "Offres", Nom = "🦄 Kart Licorne Galaxie", Description = "Le kart EXCLUSIF : arc-en-ciel animé, ailes néon, paillettes !", Kart = "Galaxie", ProduitId = 0, PrixAffiche = "R$ 399", Promo = true },
	{ Id = "PassVIP", Categorie = "Offres", Nom = "👑 Pass VIP", Description = "Pièces x2 À VIE + 2 tours de roue gratuits par jour + 👑 VIP", ProduitId = 0, PrixAffiche = "R$ 299", Unique = true },
	{ Id = "PackLegende", Categorie = "Offres", Nom = "🏆 Méga pack Légende", Description = "10 000 💰 + Chrome miroir + Lave + traînée de Feu + 5 tours de roue", Pieces = 10000, Premiums = { "Chrome miroir", "Lave" }, Trainee = "Feu", Tours = 5, ProduitId = 0, PrixAffiche = "R$ 799", Unique = true },
	{ Id = "PackDemarrage", Categorie = "Offres", Nom = "🎁 Pack de démarrage", Description = "1 000 💰 + la peinture Or 24 carats + 2 tours de roue", Pieces = 1000, Premium = "Or 24 carats", Tours = 2, ProduitId = 0, PrixAffiche = "R$ 45", Unique = true },
	-- 🌈 TRAÎNÉES
	{ Id = "TraineeFeu", Categorie = "Traînées", Nom = "🔥 Traînée de feu", Description = "Des flammes derrière ton kart", Trainee = "Feu", ProduitId = 0, PrixAffiche = "R$ 79", Unique = true },
	{ Id = "TraineeArcEnCiel", Categorie = "Traînées", Nom = "🌈 Traînée arc-en-ciel", Description = "Un arc-en-ciel qui te suit partout", Trainee = "Arc-en-ciel", ProduitId = 0, PrixAffiche = "R$ 99", Unique = true },
	{ Id = "TraineeEtoiles", Categorie = "Traînées", Nom = "✨ Traînée d'étoiles", Description = "Une pluie d'étoiles dorées", Trainee = "Étoiles", ProduitId = 0, PrixAffiche = "R$ 99", Unique = true },
	{ Id = "TraineeEclair", Categorie = "Traînées", Nom = "⚡ Traînée éclair", Description = "Des étincelles électriques bleues", Trainee = "Éclair", ProduitId = 0, PrixAffiche = "R$ 69", Unique = true },
	{ Id = "TraineeCoeurs", Categorie = "Traînées", Nom = "💖 Traînée de cœurs", Description = "Des cœurs roses partout derrière toi", Trainee = "Cœurs", ProduitId = 0, PrixAffiche = "R$ 59", Unique = true },
	{ Id = "TraineeGalaxie", Categorie = "Traînées", Nom = "🌌 Traînée galaxie", Description = "Le cosmos derrière ton kart", Trainee = "Galaxie", ProduitId = 0, PrixAffiche = "R$ 129", Unique = true },
	-- 🎡 ROUE
	{ Id = "Tours3", Categorie = "Roue", Nom = "🎡 3 tours de roue", Description = "3 tours de la roue des cadeaux", Tours = 3, ProduitId = 0, PrixAffiche = "R$ 49" },
	{ Id = "Tours10", Categorie = "Roue", Nom = "🎡 10 tours de roue", Description = "10 tours : le meilleur prix !", Tours = 10, ProduitId = 0, PrixAffiche = "R$ 129" },
	-- 💰 PIÈCES
	{ Id = "Pieces1000", Categorie = "Pièces", Nom = "💰 1 000 pièces", Description = "De quoi repeindre ton kart plusieurs fois", Pieces = 1000, ProduitId = 0, PrixAffiche = "R$ 49" },
	{ Id = "Pieces5000", Categorie = "Pièces", Nom = "💰 5 000 pièces", Description = "Le meilleur prix par pièce !", Pieces = 5000, ProduitId = 0, PrixAffiche = "R$ 199" },
	{ Id = "Pieces15000", Categorie = "Pièces", Nom = "💰 15 000 pièces", Description = "Le coffre géant : tout le garage pour toi", Pieces = 15000, ProduitId = 0, PrixAffiche = "R$ 499" },
}
Config.CategoriesBoutique = { "Offres", "Traînées", "Roue", "Pièces" }

-- 🖼️ ICÔNES du menu : les images PNG sont dans le dossier « icones » du projet.
-- Importe-les dans Studio (Affichage > Gestionnaire de ressources > Importation groupée),
-- clic droit sur chaque image > « Copier l'ID », et colle le numéro ici.
-- Tant que c'est 0, l'emoji s'affiche à la place.
Config.Icones = {
	Garage = 0, Roue = 0, Magasin = 0, Tuto = 0,
	Entrainement = 0, EnLigne = 0, Battle = 0,
	Cadeau = 0, Serie = 0, Amis = 0, Notif = 0, Groupe = 0,
	Pieces = 0, VIP = 0,
}
-- L'emoji remplacé par chaque icône
Config.IconeDeLEmoji = {
	["🔧"] = "Garage", ["🎡"] = "Roue", ["🛒"] = "Magasin", ["📖"] = "Tuto",
	["🏁"] = "Entrainement", ["🌐"] = "EnLigne", ["🔥"] = "Battle",
	["🎁"] = "Cadeau", ["📅"] = "Serie", ["👥"] = "Amis", ["🔔"] = "Notif", ["👪"] = "Groupe",
	["💰"] = "Pieces", ["👑"] = "VIP",
}
-- Renvoie l'image Roblox d'une icône (ou nil s'il faut garder l'emoji)
function Config.ImageIcone(emojiOuNom: string): string?
	local nom = Config.IconeDeLEmoji[emojiOuNom] or emojiOuNom
	local id = Config.Icones[nom]
	if type(id) == "number" and id > 0 then
		return "rbxassetid://" .. id
	end
	return nil
end

-- 🎁 CADEAUX GRATUITS (ce qui fait revenir les joueurs chaque jour)
Config.Cadeaux = {
	-- Cadeaux de temps de jeu (à chaque partie) : plus on reste, plus c'est gros
	TempsDeJeu = {
		{ Minutes = 3, Pieces = 50 },
		{ Minutes = 10, Pieces = 100 },
		{ Minutes = 20, Pieces = 200 },
		{ Minutes = 35, Tours = 1 },
		{ Minutes = 60, Pieces = 500 },
	},
	-- Série de connexion : 1 cadeau par jour, de plus en plus gros (jour 7 = énorme)
	Serie = {
		{ Pieces = 100 }, { Pieces = 150 }, { Tours = 1 }, { Pieces = 300 },
		{ Pieces = 400 }, { Tours = 2 }, { Pieces = 1000, Tours = 3 },
	},
	BonusAmi = 150, -- 💰 pour toi ET ton ami quand vous jouez ensemble (1 fois par serveur)
	GroupeId = 0, -- numéro de ton groupe Roblox (0 = pas de bonus de groupe)
	BonusGroupe = 500, -- 💰 une seule fois pour avoir rejoint le groupe
}
function Config.TexteCadeau(c): string
	local morceaux = {}
	if c.Pieces then
		table.insert(morceaux, ("%d 💰"):format(c.Pieces))
	end
	if c.Tours then
		table.insert(morceaux, ("%d tour%s 🎡"):format(c.Tours, if c.Tours > 1 then "s" else ""))
	end
	return table.concat(morceaux, " + ")
end

-- 🎡 LA ROUE DU JOUR : 1 tour gratuit par jour (2 avec le Pass VIP) + les tours achetés.
-- Poids = chances relatives (affichées en % dans le jeu, c'est obligatoire sur Roblox).
Config.Roue = {
	{ Nom = "50 💰", Type = "Pieces", Valeur = 50, Poids = 24, Couleur = Color3.fromRGB(60, 130, 230) },
	{ Nom = "150 💰", Type = "Pieces", Valeur = 150, Poids = 18, Couleur = Color3.fromRGB(230, 60, 70) },
	{ Nom = "300 XP", Type = "XP", Valeur = 300, Poids = 16, Couleur = Color3.fromRGB(60, 190, 110) },
	{ Nom = "COULEUR 🎨", Type = "Couleur", Valeur = 200, Poids = 14, Couleur = Color3.fromRGB(240, 150, 30) },
	{ Nom = "400 💰", Type = "Pieces", Valeur = 400, Poids = 12, Couleur = Color3.fromRGB(150, 70, 220) },
	{ Nom = "1000 💰", Type = "Pieces", Valeur = 1000, Poids = 7, Couleur = Color3.fromRGB(230, 60, 160) },
	{ Nom = "TRAÎNÉE ✨", Type = "Trainee", Valeur = 1500, Poids = 3, Couleur = Color3.fromRGB(40, 190, 210) },
	{ Nom = "🦄 JACKPOT", Type = "Kart", Valeur = 3000, Poids = 1, Couleur = Color3.fromRGB(255, 200, 40) },
}
-- (Valeur des cadeaux « objet » : pièces données à la place si on l'a déjà)


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
	Carrosserie = "Noir",
	Finition = "Brillant",
	Jantes = "Blanc",
	Siege = "Bleu",
	Bandes = "Blanc",
	BandesActives = false,
	Autocollant = "Étoile",
	Numero = 7,
	Neon = "Bleu",
	Trainee = "Aucune",
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
function Config.PeinturePremium(nom: string) return chercher(Config.PeinturesPremium, nom) end
function Config.Finition(nom: string) return chercher(Config.Finitions, nom) end
function Config.Autocollant(nom: string) return chercher(Config.Autocollants, nom) end
function Config.Neon(nom: string) return chercher(Config.Neons, nom) end
function Config.Trainee(nom: string) return chercher(Config.Trainees, nom) end
function Config.OffreBoutique(id: string)
	for _, offre in ipairs(Config.Boutique) do
		if offre.Id == id then
			return offre
		end
	end
	return nil
end
function Config.OffreTrainee(nom: string) -- l'offre du magasin qui vend cette traînée seule
	for _, offre in ipairs(Config.Boutique) do
		if offre.Categorie == "Traînées" and offre.Trainee == nom then
			return offre
		end
	end
	return nil
end

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
	-- ❤️ VIES : chaque joueur (police ET fugitifs) a 3 vies. Quand on en perd une, on choisit :
	--   • RÉAPPARAÎTRE (gratuit)   • ⚡ VENGEANCE (payant) : celui qui t'a eu perd une vie
	Vies = 3,
	DelaiChoix = 12, -- secondes pour choisir (sinon on réapparaît tout seul)
	ProtectionReapparition = 3, -- secondes où l'on ne peut pas être arrêté après être revenu
	ProduitVengeance = 0, -- numéro du Produit pour développeurs « Vengeance » (0 = gratuit dans Studio)
	PrixVengeance = "R$ 25",
	-- DRIFT BATTLE (défi solo, se lance tout de suite depuis le menu) : pas de police,
	-- 1 minute pour faire le plus de points de drift. XP = 50 + score / 20.
	DureeBattle = 60, -- 1 minute (mets 30 pour des parties encore plus courtes)
	-- BOTS DE TEST : s'il manque des joueurs, des bots complètent la partie
	-- (pratique pour tester seul). Mets 0 pour les désactiver.
	BotsTest = 1, -- (seulement dans Studio : dans le jeu publié, jamais de bots en ligne)
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
	VueParDefaut = "derriere", -- "derriere" (3e personne, derrière le kart) ou "gopro" (caméra sur la poitrine)
	ChampGoPro = 100, -- grand angle de la GoPro (degrés)
	Distance = 9.5, -- distance derrière le kart (plus petit = plus proche)
	Hauteur = 6.5, -- hauteur au-dessus du kart (plus grand = on voit mieux par-dessus)
	Souplesse = 4, -- plus c'est haut, plus la caméra suit vite (bas = plus "cinéma")
	SuiviGlisse = 0.5, -- 0 = regarde où pointe le kart, 1 = regarde où il glisse (on voit bien l'angle du drift)
	-- SENSATIONS : la caméra vit avec le kart
	ReculAcceleration = 0.03, -- la caméra recule quand on accélère fort (et avance au freinage)
	RoulisDrift = 0.005, -- la caméra penche dans les drifts
	TremblementVitesse = 0.05, -- petit tremblement à pleine vitesse
	TremblementBoost = 0.3, -- tremblement pendant le boost
	ChampBoost = 14, -- le champ de vision « s'ouvre » au boost (effet de vitesse)
}

function Config.AppliquerAmbiance(nuit: boolean)
	-- Rendu « poussé » : à utiliser avec Lighting.Technology = Future (réglé dans
	-- le fichier .rbxlx). Ombres douces, reflets sur le carrelage, brume de Dubaï.
	-- L'intérieur du mall reste bien éclairé jour et nuit (comme un vrai centre).
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1 -- vrais reflets sur le sol et les karts
	Lighting.GeographicLatitude = 25 -- Dubaï
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Parent = Lighting
	local ciel = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	ciel.SunAngularSize = 14
	ciel.MoonAngularSize = 9
	ciel.StarCount = 3500
	ciel.Parent = Lighting
	if nuit then
		Lighting.ClockTime = 21.5
		Lighting.Brightness = 1.2
		Lighting.ExposureCompensation = 0.1
		Lighting.Ambient = Color3.fromRGB(70, 72, 90)
		Lighting.OutdoorAmbient = Color3.fromRGB(60, 62, 92)
		Lighting.ColorShift_Top = Color3.fromRGB(120, 140, 255)
		Lighting.ColorShift_Bottom = Color3.fromRGB(40, 30, 80)
		atmo.Density = 0.32
		atmo.Offset = 0.1
		atmo.Color = Color3.fromRGB(70, 80, 130)
		atmo.Decay = Color3.fromRGB(40, 30, 90)
		atmo.Glare = 0
		atmo.Haze = 1.2
	else
		Lighting.ClockTime = 15.2 -- soleil un peu bas : ombres longues, lumière dorée
		Lighting.Brightness = 3
		Lighting.ExposureCompensation = -0.1
		Lighting.Ambient = Color3.fromRGB(105, 100, 95)
		Lighting.OutdoorAmbient = Color3.fromRGB(135, 128, 118)
		Lighting.ColorShift_Top = Color3.fromRGB(255, 225, 170)
		Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
		atmo.Density = 0.3
		atmo.Offset = 0.25
		atmo.Color = Color3.fromRGB(235, 205, 160) -- brume de sable
		atmo.Decay = Color3.fromRGB(150, 110, 75)
		atmo.Glare = 0.4
		atmo.Haze = 1.6
	end
	-- Effets d'image (créés une seule fois, réglés selon jour / nuit)
	local function effet(classe: string, nom: string): any
		local e = Lighting:FindFirstChild(nom)
		if not e then
			e = Instance.new(classe)
			e.Name = nom
			e.Parent = Lighting
		end
		return e
	end
	local bloom = effet("BloomEffect", "HaloMallDrift")
	bloom.Intensity = if nuit then 0.9 else 0.55
	bloom.Size = 28
	bloom.Threshold = if nuit then 0.85 else 1.1 -- les néons et enseignes « brillent »
	local rayons = effet("SunRaysEffect", "RayonsMallDrift")
	rayons.Intensity = if nuit then 0 else 0.07
	rayons.Spread = 0.75
	local cc = effet("ColorCorrectionEffect", "CouleursMallDrift")
	cc.Saturation = if nuit then 0.2 else 0.15
	cc.Contrast = 0.12
	cc.Brightness = if nuit then 0.02 else 0
	cc.TintColor = if nuit then Color3.fromRGB(235, 238, 255) else Color3.fromRGB(255, 248, 238)
	local flou = effet("DepthOfFieldEffect", "ProfondeurMallDrift")
	flou.FarIntensity = 0.12 -- le fond lointain se floute un peu (effet « caméra »)
	flou.FocusDistance = 60
	flou.InFocusRadius = 70
	flou.NearIntensity = 0
	Lighting:SetAttribute("Nuit", nuit)
end

return Config
