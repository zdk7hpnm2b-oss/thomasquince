-- Barber Legends — configuration centrale.
-- Tout l'équilibrage (prix, gains, monétisation) se règle ici.

local Config = {}

Config.GameName = "Barber Legends"
Config.DataStoreName = "SalonStar_v1"
Config.LeaderboardStoreName = "SalonStar_TopEarned_v1"

-- ⚠️ Remplace par l'ID de ton groupe Roblox (0 = désactivé).
Config.GroupId = 0

---------------------------------------------------------------------
-- MONÉTISATION : colle ici les IDs créés sur create.roblox.com
-- (0 = pas encore créé ; le bouton affiche alors « Bientôt »)
---------------------------------------------------------------------
Config.GamePasses = {
	vip = { Id = 0, Name = "VIP", Icon = "👑", Desc = "+50% d'argent, ciseaux dorés, tag VIP et clients VIP x2 plus fréquents" },
	doubleCash = { Id = 0, Name = "Argent x2", Icon = "💸", Desc = "Double tout l'argent gagné, pour toujours" },
	fastClients = { Id = 0, Name = "Clients Express", Icon = "⚡", Desc = "Les clients arrivent 40% plus vite" },
	neonColors = { Id = 0, Name = "Couleurs Néon", Icon = "🌈", Desc = "Teintures néon et arc-en-ciel : les clients paient x3" },
	premiumStyles = { Id = 0, Name = "Coupes de Luxe", Icon = "💎", Desc = "Afro XXL et Sirène : les coupes les mieux payées du jeu" },
	seasonPass = { Id = 0, Name = "Barber Pass Gold", Icon = "🎟️", Desc = "Débloque la piste Gold de la saison : x3 récompenses + teintures exclusives" },
	battlePro = { Id = 0, Name = "Battle Pro", Icon = "⚔️", Desc = "Gains de Battle x2 et +15 s de temps pour coiffer" },
	autoStylist = { Id = 0, Name = "Styliste Star", Icon = "🤖", Desc = "+2 stylistes gratuits qui coiffent pour toi, même hors ligne" },
	bigTips = { Id = 0, Name = "Gros Pourboires", Icon = "🪙", Desc = "Pourboires x2 sur les coiffures parfaites" },
}

-- Packs d'argent : donnent le MAX entre un montant fixe et X minutes de tes gains.
-- (Ils restent intéressants à chaque niveau du jeu → achats répétés.)
Config.Products = {
	cashSmall = { Id = 0, Name = "Petite Caisse", Icon = "💵", Minutes = 10, Min = 2500, Kind = "cash" },
	cashMedium = { Id = 0, Name = "Coffre", Icon = "💰", Minutes = 45, Min = 15000, Kind = "cash" },
	cashLarge = { Id = 0, Name = "Banque", Icon = "🏦", Minutes = 180, Min = 75000, Kind = "cash" },
	cashHuge = { Id = 0, Name = "Empire", Icon = "🏰", Minutes = 720, Min = 400000, Kind = "cash" },
	rushHour = { Id = 0, Name = "Heure de Pointe (serveur)", Icon = "🔥", Kind = "rush", Desc = "Tout le serveur : clients x2 et paie x2 pendant 15 min" },
	celebrity = { Id = 0, Name = "Client Célébrité", Icon = "🌟", Kind = "celebrity", Desc = "Une star arrive dans ton salon et paie x10" },
	passSkip = { Id = 0, Name = "+5 paliers de Pass", Icon = "⏩", Kind = "passSkip", Desc = "Avance de 5 paliers dans le Barber Pass" },
	viralBoost = { Id = 0, Name = "Boost Viral", Icon = "🚀", Kind = "viral", Desc = "Ta prochaine publication BarberTok est épinglée en tête pendant 10 min" },
	starterPack = { Id = 0, Name = "Pack Débutant", Icon = "🎁", Kind = "starter", Desc = "25 000 $ + Twists + Tondeuse Pro + Teintures Fantaisie (une seule fois)" },
}

Config.RushDuration = 15 * 60
Config.RushMultiplier = 2

---------------------------------------------------------------------
-- COIFFURES
---------------------------------------------------------------------
export type StyleDef = { Id: string, Name: string, Icon: string, Value: number, Cost: number, Pass: string?, Fade: boolean?, Trend: boolean?, Gender: string }

-- Chaque coupe = des longueurs de mèches (en « tailles de tête ») : Top (dessus), Front (frange),
-- Side (côtés), Back (nuque). Texture : lisse / boucle / twists / locs.
-- Fade = true : accepte les dégradés. Trend = tendance TikTok 2026 (demandée 2x plus, badge 🔥).
-- Gender : "H" homme, "F" femme, "U" mixte. Ordre = du moins cher au plus cher.
export type StyleDef = {
	Id: string,
	Name: string,
	Icon: string,
	Value: number,
	Cost: number,
	Gender: string,
	Top: number,
	Front: number,
	Side: number,
	Back: number,
	Texture: string?,
	Fade: boolean?,
	Trend: boolean?,
	Mohawk: boolean?,
	Pass: string?,
}

Config.Styles = {
	{ Id = "buzz", Name = "Buzz cut", Icon = "🪒", Value = 1, Cost = 0, Gender = "H", Fade = true, Trend = true, Top = 0.12, Front = 0.1, Side = 0.08, Back = 0.08 },
	{ Id = "courte", Name = "Coupe courte", Icon = "✂️", Value = 1.1, Cost = 0, Gender = "U", Fade = true, Top = 0.35, Front = 0.3, Side = 0.18, Back = 0.18 },
	{ Id = "longs", Name = "Longs lisses", Icon = "💇", Value = 1.3, Cost = 0, Gender = "F", Top = 1.2, Front = 1.0, Side = 1.6, Back = 1.8 },
	{ Id = "frenchcrop", Name = "French crop", Icon = "🥖", Value = 1.5, Cost = 300, Gender = "H", Fade = true, Trend = true, Top = 0.4, Front = 0.3, Side = 0.14, Back = 0.14 },
	{ Id = "pixie", Name = "Pixie", Icon = "🧚", Value = 1.8, Cost = 500, Gender = "F", Fade = true, Top = 0.45, Front = 0.5, Side = 0.22, Back = 0.2 },
	{ Id = "curtain", Name = "Curtain hair", Icon = "🎭", Value = 2, Cost = 900, Gender = "H", Fade = true, Trend = true, Top = 0.7, Front = 0.9, Side = 0.22, Back = 0.3 },
	{ Id = "waves", Name = "Waves 360", Icon = "🌊", Value = 2.2, Cost = 1300, Gender = "H", Fade = true, Top = 0.12, Front = 0.12, Side = 0.1, Back = 0.1, Texture = "boucle" },
	{ Id = "pixieboucle", Name = "Pixie bouclé", Icon = "🌸", Value = 2.4, Cost = 1500, Gender = "F", Trend = true, Top = 0.5, Front = 0.45, Side = 0.25, Back = 0.25, Texture = "boucle" },
	{ Id = "twists", Name = "Twists", Icon = "🧽", Value = 2.8, Cost = 4000, Gender = "U", Fade = true, Trend = true, Top = 0.6, Front = 0.5, Side = 0.2, Back = 0.2, Texture = "twists" },
	{ Id = "edgar", Name = "Edgar cut", Icon = "📏", Value = 3.1, Cost = 6000, Gender = "H", Fade = true, Trend = true, Top = 0.4, Front = 0.38, Side = 0.15, Back = 0.15 },
	{ Id = "frangerideau", Name = "Frange rideau", Icon = "🪟", Value = 3.6, Cost = 9000, Gender = "F", Trend = true, Top = 1.3, Front = 0.7, Side = 1.4, Back = 1.7 },
	{ Id = "bob", Name = "Bob italien", Icon = "🇮🇹", Value = 3.8, Cost = 11000, Gender = "F", Trend = true, Top = 0.8, Front = 0.7, Side = 1.0, Back = 1.0 },
	{ Id = "mullet", Name = "Mulet moderne", Icon = "🦅", Value = 4.6, Cost = 22000, Gender = "U", Fade = true, Trend = true, Top = 0.45, Front = 0.35, Side = 0.2, Back = 1.3 },
	{ Id = "boucles", Name = "Longs bouclés", Icon = "🌀", Value = 5, Cost = 30000, Gender = "F", Top = 1.0, Front = 0.9, Side = 1.1, Back = 1.2, Texture = "boucle" },
	{ Id = "wolfcut", Name = "Wolf cut", Icon = "🐺", Value = 5.8, Cost = 45000, Gender = "U", Trend = true, Top = 0.6, Front = 0.75, Side = 0.9, Back = 1.4 },
	{ Id = "locs", Name = "Dreadlocks", Icon = "🦁", Value = 6.5, Cost = 65000, Gender = "U", Fade = true, Top = 1.3, Front = 1.1, Side = 1.3, Back = 1.5, Texture = "locs" },
	{ Id = "butterfly", Name = "Butterfly cut", Icon = "🦋", Value = 7.5, Cost = 100000, Gender = "F", Trend = true, Top = 0.9, Front = 1.0, Side = 1.5, Back = 1.9 },
	{ Id = "afro", Name = "Afro", Icon = "☁️", Value = 11, Cost = 350000, Gender = "U", Fade = true, Top = 0.9, Front = 0.8, Side = 0.8, Back = 0.8, Texture = "boucle" },
	{ Id = "crete", Name = "Crête punk", Icon = "🦔", Value = 15, Cost = 1200000, Gender = "U", Mohawk = true, Top = 1.0, Front = 1.0, Side = 0.03, Back = 0.03 },
	{ Id = "afroxxl", Name = "Afro XXL", Icon = "🌩️", Value = 24, Cost = 0, Gender = "U", Pass = "premiumStyles", Top = 1.5, Front = 1.3, Side = 1.4, Back = 1.4, Texture = "boucle" },
	{ Id = "sirene", Name = "Sirène", Icon = "🧜", Value = 32, Cost = 0, Gender = "F", Pass = "premiumStyles", Top = 1.4, Front = 1.2, Side = 1.9, Back = 2.0 },
} :: { StyleDef }

-- Textures naturelles des cheveux
Config.Textures = {
	{ Id = "lisse", Name = "Lisses", Icon = "💇" },
	{ Id = "boucle", Name = "Bouclés", Icon = "🌀" },
	{ Id = "twists", Name = "Twists", Icon = "🧽" },
	{ Id = "locs", Name = "Locs", Icon = "🦁" },
}

-- Dégradés : demandent la « Tondeuse Pro ». Hauteurs sur la tête : 1 = sommet, 0 = tempes, -0.5 = nuque.
-- From = où le dégradé commence, To = où il atteint Bottom (longueur en bas). Burst = autour de l'oreille.
Config.Fades = {
	{ Id = "aucun", Name = "Sans dégradé", Icon = "⬛", Mult = 1, Bands = { 0, 0, 0, 0, 0 } },
	{ Id = "taper", Name = "Taper", Icon = "🔻", Mult = 1.15, Bands = { 0, 0, 0.1, 0.45, 0.9 }, From = -0.1, To = -0.45, Bottom = 0.06, Trend = true },
	{ Id = "bas", Name = "Dégradé bas", Icon = "▁", Mult = 1.2, Bands = { 0, 0.08, 0.3, 0.6, 0.85 }, From = 0.1, To = -0.4, Bottom = 0.03 },
	{ Id = "moyen", Name = "Dégradé moyen", Icon = "▄", Mult = 1.25, Bands = { 0.1, 0.4, 0.65, 0.85, 0.96 }, From = 0.3, To = -0.15, Bottom = 0.03 },
	{ Id = "haut", Name = "Dégradé haut", Icon = "█", Mult = 1.3, Bands = { 0.45, 0.7, 0.88, 0.97, 1 }, From = 0.5, To = 0.05, Bottom = 0.03 },
	{ Id = "blanc", Name = "Dégradé à blanc", Icon = "⚪", Mult = 1.35, Bands = { 0.55, 0.85, 0.97, 1, 1 }, From = 0.45, To = 0.1, Bottom = 0, Trend = true },
	{ Id = "burst", Name = "Burst fade", Icon = "💥", Mult = 1.4, Bands = { 0.15, 0.55, 0.85, 0.97, 1 }, From = 0.3, To = -0.2, Bottom = 0, Burst = true, Trend = true },
}

-- Outils de l'atelier (la tondeuse demande la Tondeuse Pro)
Config.Guards = { 0.03, 0.08, 0.15, 0.25, 0.4 } -- sabots n°0 à 4 (longueur laissée)
Config.BrushSizes = { { Name = "S", Radius = math.rad(9) }, { Name = "M", Radius = math.rad(15) }, { Name = "L", Radius = math.rad(24) } }
Config.ClippersCost = 2500

Config.Beards = {
	{ Id = "aucune", Name = "Sans barbe", Icon = "🙂", Mult = 1, Cost = 0 },
	{ Id = "trois", Name = "Barbe de 3 jours", Icon = "🧔", Mult = 1.1, Cost = 0 },
	{ Id = "bouc", Name = "Bouc", Icon = "🐐", Mult = 1.2, Cost = 1200 },
	{ Id = "collier", Name = "Collier", Icon = "📿", Mult = 1.3, Cost = 8000 },
	{ Id = "pleine", Name = "Barbe pleine", Icon = "🧔‍♂️", Mult = 1.45, Cost = 30000 },
}

Config.Lengths = {
	{ Id = 1, Name = "Court", Mult = 1 },
	{ Id = 2, Name = "Mi-long", Mult = 1.1 },
	{ Id = 3, Name = "Long", Mult = 1.25 },
}

export type ColorDef = {
	Id: string,
	Name: string,
	Color: Color3,
	Value: number,
	Tier: string, -- "base" | "fantasy" | "neon"
	Material: Enum.Material?,
	Rainbow: boolean?,
}

Config.Colors = {
	{ Id = "noir", Name = "Noir", Color = Color3.fromRGB(28, 22, 20), Value = 1, Tier = "base" },
	{ Id = "brun", Name = "Brun", Color = Color3.fromRGB(92, 56, 34), Value = 1, Tier = "base" },
	{ Id = "blond", Name = "Blond", Color = Color3.fromRGB(238, 200, 118), Value = 1, Tier = "base" },
	{ Id = "roux", Name = "Roux", Color = Color3.fromRGB(198, 86, 34), Value = 1, Tier = "base" },
	{ Id = "rose", Name = "Rose Bonbon", Color = Color3.fromRGB(255, 140, 196), Value = 1.6, Tier = "fantasy" },
	{ Id = "bleu", Name = "Bleu Ciel", Color = Color3.fromRGB(96, 160, 255), Value = 1.6, Tier = "fantasy" },
	{ Id = "violet", Name = "Lavande", Color = Color3.fromRGB(160, 110, 240), Value = 1.6, Tier = "fantasy" },
	{ Id = "menthe", Name = "Menthe", Color = Color3.fromRGB(110, 230, 180), Value = 1.6, Tier = "fantasy" },
	{ Id = "platine", Name = "Platine", Color = Color3.fromRGB(240, 240, 250), Value = 1.6, Tier = "fantasy" },
	{ Id = "cendre", Name = "Blond cendré", Color = Color3.fromRGB(205, 198, 182), Value = 1.6, Tier = "fantasy" },
	{ Id = "cerise", Name = "Rouge cerise", Color = Color3.fromRGB(150, 16, 52), Value = 1.6, Tier = "fantasy", Trend = true },
	{ Id = "neonrose", Name = "Néon Rose", Color = Color3.fromRGB(255, 60, 180), Value = 3, Tier = "neon", Material = Enum.Material.Neon },
	{ Id = "neoncyan", Name = "Néon Cyan", Color = Color3.fromRGB(40, 240, 255), Value = 3, Tier = "neon", Material = Enum.Material.Neon },
	{ Id = "or", Name = "Or Pur", Color = Color3.fromRGB(255, 200, 60), Value = 3, Tier = "neon", Material = Enum.Material.Foil },
	{ Id = "orrose", Name = "Or rose", Color = Color3.fromRGB(240, 170, 160), Value = 3.2, Tier = "season", Material = Enum.Material.Foil },
	{ Id = "chrome", Name = "Chrome", Color = Color3.fromRGB(215, 220, 230), Value = 3.4, Tier = "season", Material = Enum.Material.Foil },
	{ Id = "galaxie", Name = "Galaxie", Color = Color3.fromRGB(90, 40, 200), Value = 4, Tier = "season", Material = Enum.Material.Neon },
	{ Id = "arcenciel", Name = "Arc-en-ciel", Color = Color3.fromRGB(255, 80, 80), Value = 3.5, Tier = "neon", Material = Enum.Material.Neon, Rainbow = true },
} :: { ColorDef }

Config.FantasyColorsCost = 4000

export type AccDef = { Id: string, Name: string, Icon: string, Cost: number, Pass: string? }
Config.Accessories = {
	{ Id = "aucun", Name = "Aucun", Icon = "🚫", Cost = 0 },
	{ Id = "noeud", Name = "Nœud", Icon = "🎀", Cost = 0 },
	{ Id = "barrette", Name = "Barrette", Icon = "📎", Cost = 900 },
	{ Id = "trait", Name = "Trait rasé", Icon = "⚡", Cost = 2000, Trend = true },
	{ Id = "pince", Name = "Pince crabe", Icon = "🦀", Cost = 2500, Trend = true },
	{ Id = "oreille", Name = "Boucle d'oreille", Icon = "💎", Cost = 3500 },
	{ Id = "fleur", Name = "Fleur", Icon = "🌸", Cost = 6000 },
	{ Id = "chaine", Name = "Chaîne en or", Icon = "⛓️", Cost = 15000 },
	{ Id = "couronne", Name = "Couronne", Icon = "👑", Cost = 0, Pass = "premiumStyles" },
} :: { AccDef }

---------------------------------------------------------------------
-- ÉCONOMIE
---------------------------------------------------------------------
Config.BasePay = 12
Config.PerfectTip = 0.5 -- +50 % si coiffure parfaite
Config.StreakBonus = 0.05 -- +5 % par coiffure parfaite d'affilée
Config.StreakMax = 10
Config.VipChance = 0.05
Config.VipPay = 4
Config.CelebrityPay = 10
Config.CustomerPatience = 150 -- secondes (chaises d'attente + fauteuil)
Config.WaitSeats = 5 -- chaises d'attente par salon

-- Note du client (1 à 5 étoiles) selon la ressemblance
function Config.Stars(score: number): number
	if score >= 0.92 then
		return 5
	elseif score >= 0.8 then
		return 4
	elseif score >= 0.65 then
		return 3
	elseif score >= 0.45 then
		return 2
	end
	return 1
end

function Config.StarText(stars: number): string
	return string.rep("★", stars) .. string.rep("☆", 5 - stars)
end
Config.StylistWorkTime = 14 -- secondes par client pour un styliste
Config.StylistScore = 0.85
Config.OfflineMaxSeconds = 3 * 3600
Config.OfflineRate = 0.5

-- Améliorations : Costs[i] = prix pour passer au niveau i (le niveau 1 est gratuit si Costs[1] == 0)
Config.Upgrades = {
	chairs = {
		Name = "Fauteuils", Icon = "💺", Desc = "Plus de clients en même temps",
		Costs = { 0, 250, 1500, 7500, 35000, 160000 },
	},
	stylists = {
		Name = "Stylistes", Icon = "🧑‍🎨", Desc = "Ils coiffent tout seuls pour toi",
		Costs = { 700, 4500, 22000, 100000, 450000, 2000000 },
	},
	deco = {
		Name = "Décoration", Icon = "✨", Desc = "Un salon plus chic = clients qui paient plus",
		Costs = { 0, 3000, 30000, 250000, 1800000 },
		Mult = { 1, 1.35, 1.85, 2.6, 3.8 },
	},
	cleaning = {
		Name = "Nettoyage", Icon = "🧹", Desc = "Balai → Aspirateur (aspire tout autour) → Robot aspirateur (nettoie tout seul)",
		Costs = { 0, 2500, 40000 },
		Levels = { "Balai", "Aspirateur", "Robot aspirateur" },
	},
	pub = {
		Name = "Publicité", Icon = "📣", Desc = "Les clients arrivent plus vite",
		Costs = { 450, 3500, 20000, 120000, 700000 },
		Interval = { 13, 10.5, 8.5, 7, 5.5, 4.2 }, -- index = niveau + 1
	},
}

-- Franchise (renaissance) : remet l'argent et les améliorations à zéro, garde les coupes débloquées.
Config.RebirthBaseCost = 4000000
Config.RebirthGrowth = 4
Config.RebirthBonus = 0.5

function Config.RebirthCost(rebirths: number): number
	return Config.RebirthBaseCost * Config.RebirthGrowth ^ rebirths
end

---------------------------------------------------------------------
-- PROPRETÉ : chaque coupe laisse des cheveux par terre
---------------------------------------------------------------------
Config.Cleaning = {
	PilesPerCut = 2,
	MaxPiles = 14,
	PatiencePerPile = 0.08, -- chaque tas fait perdre patience 8 % plus vite
	DirtyThreshold = 6, -- à partir de 6 tas, les clients enlèvent 1 étoile
	VacuumRadius = 12,
	RobotInterval = 4, -- secondes entre deux tas nettoyés par le robot
}

---------------------------------------------------------------------
-- TÂCHES (3 en même temps, une nouvelle dès qu'une est finie)
---------------------------------------------------------------------
Config.Tasks = {
	{ Id = "cut5", Kind = "cut", Goal = 5, Text = "Fais 5 coupes", Minutes = 6, Xp = 30 },
	{ Id = "cut15", Kind = "cut", Goal = 15, Text = "Fais 15 coupes", Minutes = 15, Xp = 80 },
	{ Id = "star3", Kind = "fivestar", Goal = 3, Text = "Obtiens 3 notes ★★★★★", Minutes = 10, Xp = 60 },
	{ Id = "star10", Kind = "fivestar", Goal = 10, Text = "Obtiens 10 notes ★★★★★", Minutes = 25, Xp = 150 },
	{ Id = "clean10", Kind = "clean", Goal = 10, Text = "Nettoie 10 tas de cheveux", Minutes = 5, Xp = 30 },
	{ Id = "clean30", Kind = "clean", Goal = 30, Text = "Nettoie 30 tas de cheveux", Minutes = 12, Xp = 70 },
	{ Id = "battle1", Kind = "battle", Goal = 1, Text = "Participe à une Battle", Minutes = 8, Xp = 50 },
	{ Id = "post2", Kind = "post", Goal = 2, Text = "Publie 2 coupes sur BarberTok", Minutes = 6, Xp = 40 },
	{ Id = "fade3", Kind = "fade", Goal = 3, Text = "Réussis 3 dégradés (4★ ou plus)", Minutes = 12, Xp = 70 },
	{ Id = "nolose", Kind = "served", Goal = 8, Text = "Sers 8 clients sans en perdre un", Minutes = 15, Xp = 90 },
}

---------------------------------------------------------------------
-- SONS : colle des IDs de la boutique Roblox (create.roblox.com → Creator Store → Audio).
-- Vide = un son intégré à Roblox est utilisé à la place.
---------------------------------------------------------------------
Config.Sounds = {
	Clipper = "", -- bourdonnement de tondeuse (en boucle)
	ClipperFallback = "rbxasset://sounds/action_swim.mp3",
	Snip = "", -- coup de ciseaux
	SnipFallback = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Vacuum = "", -- aspirateur
	VacuumFallback = "rbxasset://sounds/action_swim.mp3",
	Broom = "", -- balai
	BroomFallback = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Star = "", -- note / pièce
	Music = "", -- musique d'ambiance du salon (en boucle)
	BattleMusic = "", -- musique pendant les Battles
	MusicVolume = 0.25,
}

---------------------------------------------------------------------
-- RÉCOMPENSES GRATUITES (rétention)
---------------------------------------------------------------------
Config.DailyRewards = { 1, 1.5, 2, 3, 4, 6, 10 } -- multiplicateurs (x minutes de gains, min 500 $)
Config.DailyBaseMinutes = 5
Config.DailyMin = 500

Config.PlaytimeGifts = {
	{ Minutes = 5, Name = "Petit cadeau", Kind = "cash", Amount = 8 },
	{ Minutes = 15, Name = "Cadeau", Kind = "cash", Amount = 20 },
	{ Minutes = 30, Name = "Gros cadeau", Kind = "cash", Amount = 45 },
	{ Minutes = 60, Name = "Méga cadeau", Kind = "cash", Amount = 120 },
}
-- Amount = minutes de gains (min Amount * 100 $)

Config.Codes = {
	SALONSTAR = 1500,
	COIFFURE = 5000,
	MERCI = 10000,
}

Config.FriendBoostPerFriend = 0.1
Config.FriendBoostMax = 0.4
Config.GroupBoost = 0.1
Config.PremiumBoost = 0.1
Config.VipBoost = 0.5

---------------------------------------------------------------------
-- Aides
---------------------------------------------------------------------
local function index(list, key)
	local map = {}
	for i, v in list do
		map[v[key]] = v
		v.Order = i
	end
	return map
end

Config.StyleById = index(Config.Styles, "Id")
Config.TextureById = index(Config.Textures, "Id")
Config.FadeById = index(Config.Fades, "Id")
Config.BeardById = index(Config.Beards, "Id")
Config.ColorById = index(Config.Colors, "Id")
Config.AccById = index(Config.Accessories, "Id")

export type Look = { style: string, length: number, fade: string, beard: string, color: string, acc: string, gender: string? }

---------------------------------------------------------------------
-- BARBER PASS (saison de 30 paliers, piste gratuite + piste Gold payante)
---------------------------------------------------------------------
Config.Season = 1 -- change ce numéro pour lancer une nouvelle saison (remet les paliers à zéro)
Config.SeasonName = "Saison 1 : Fresh Cut"
Config.PassTiers = 30
Config.PassXpPerTier = 120
Config.Xp = { Cut = 10, Perfect = 10, Battle = 40, BattleWin = 100, Like = 15, Post = 5 }
-- Récompenses : argent = X minutes de gains. Teintures « season » débloquées sur la piste Gold.
Config.PassRewards = {}
for tier = 1, 30 do
	local free = { Kind = "cash", Minutes = 2 + tier }
	local gold = { Kind = "cash", Minutes = (2 + tier) * 3 }
	if tier == 10 then
		gold = { Kind = "color", Id = "orrose" }
	elseif tier == 20 then
		gold = { Kind = "color", Id = "chrome" }
	elseif tier == 30 then
		gold = { Kind = "color", Id = "galaxie" }
	end
	if tier % 5 == 0 then
		free.Minutes *= 3
	end
	Config.PassRewards[tier] = { Free = free, Gold = gold }
end

---------------------------------------------------------------------
-- BARBERTOK (réseau social du jeu : avant/après, likes, abonnés)
---------------------------------------------------------------------
Config.BarberTok = {
	MinScoreToPost = 0.9, -- coupe de client publiée si ressemblance >= 90 %
	PostCooldown = 45, -- secondes entre deux publications d'un même joueur
	MaxPosts = 30,
	ViralLikes = 3, -- likes minimum pour devenir viral (ou la moitié du serveur)
	ViralBonusMinutes = 10,
	FollowerBoost = 0.002, -- +0.2 % d'argent par abonné…
	FollowerBoostMax = 0.5, -- …jusqu'à +50 %
}

---------------------------------------------------------------------
-- BATTLE DE BARBIERS (sur la scène, toutes les quelques minutes)
---------------------------------------------------------------------
Config.Battle = {
	Interval = 210, -- secondes entre deux battles
	Lobby = 25, -- temps pour s'inscrire
	Duration = 70, -- temps pour coiffer
	Vote = 15, -- vote du public
	MaxPlayers = 4,
	PrizeMinutes = 15, -- prix du vainqueur = 15 min de gains…
	PrizeMin = 3000, -- …avec un minimum
}

return Config
