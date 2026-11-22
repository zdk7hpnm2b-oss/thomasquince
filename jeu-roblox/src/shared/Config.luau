-- Salon Star : Coiffure Tycoon — configuration centrale.
-- Tout l'équilibrage (prix, gains, monétisation) se règle ici.

local Config = {}

Config.GameName = "Salon Star"
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
	premiumStyles = { Id = 0, Name = "Coiffures de Luxe", Icon = "💎", Desc = "Coupes Royale et Sirène + Couronne : les mieux payées du jeu" },
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
	starterPack = { Id = 0, Name = "Pack Débutant", Icon = "🎁", Kind = "starter", Desc = "25 000 $ + Coupe Bouclée + Teintures Fantaisie (une seule fois)" },
}

Config.RushDuration = 15 * 60
Config.RushMultiplier = 2

---------------------------------------------------------------------
-- COIFFURES
---------------------------------------------------------------------
export type StyleDef = { Id: string, Name: string, Icon: string, Value: number, Cost: number, Pass: string? }

Config.Styles = {
	{ Id = "pixie", Name = "Garçonne", Icon = "✂️", Value = 1, Cost = 0 },
	{ Id = "lisse", Name = "Lisse", Icon = "💇", Value = 1.3, Cost = 0 },
	{ Id = "queue", Name = "Queue de cheval", Icon = "🎀", Value = 1.8, Cost = 350 },
	{ Id = "boucle", Name = "Bouclée", Icon = "🌀", Value = 2.5, Cost = 1800 },
	{ Id = "chignon", Name = "Chignon", Icon = "🍩", Value = 3.4, Cost = 7500 },
	{ Id = "couettes", Name = "Couettes", Icon = "👧", Value = 4.8, Cost = 25000 },
	{ Id = "tresses", Name = "Tresses", Icon = "🪢", Value = 7, Cost = 90000 },
	{ Id = "afro", Name = "Afro", Icon = "☁️", Value = 10, Cost = 320000 },
	{ Id = "crete", Name = "Crête Punk", Icon = "🦔", Value = 15, Cost = 1200000 },
	{ Id = "sirene", Name = "Sirène", Icon = "🧜", Value = 24, Cost = 0, Pass = "premiumStyles" },
	{ Id = "royal", Name = "Royale", Icon = "👸", Value = 32, Cost = 0, Pass = "premiumStyles" },
} :: { StyleDef }

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
	{ Id = "neonrose", Name = "Néon Rose", Color = Color3.fromRGB(255, 60, 180), Value = 3, Tier = "neon", Material = Enum.Material.Neon },
	{ Id = "neoncyan", Name = "Néon Cyan", Color = Color3.fromRGB(40, 240, 255), Value = 3, Tier = "neon", Material = Enum.Material.Neon },
	{ Id = "or", Name = "Or Pur", Color = Color3.fromRGB(255, 200, 60), Value = 3, Tier = "neon", Material = Enum.Material.Foil },
	{ Id = "arcenciel", Name = "Arc-en-ciel", Color = Color3.fromRGB(255, 80, 80), Value = 3.5, Tier = "neon", Material = Enum.Material.Neon, Rainbow = true },
} :: { ColorDef }

Config.FantasyColorsCost = 4000

export type AccDef = { Id: string, Name: string, Icon: string, Cost: number, Pass: string? }
Config.Accessories = {
	{ Id = "aucun", Name = "Aucun", Icon = "🚫", Cost = 0 },
	{ Id = "noeud", Name = "Nœud", Icon = "🎀", Cost = 0 },
	{ Id = "barrette", Name = "Barrette", Icon = "📎", Cost = 900 },
	{ Id = "fleur", Name = "Fleur", Icon = "🌸", Cost = 6000 },
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
Config.CustomerPatience = 100 -- secondes
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
Config.ColorById = index(Config.Colors, "Id")
Config.AccById = index(Config.Accessories, "Id")

export type Look = { style: string, length: number, color: string, acc: string }

return Config
