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
	premiumStyles = { Id = 0, Name = "Coiffures de Luxe", Icon = "💎", Desc = "Coupes Royale et Sirène + Couronne : les mieux payées du jeu" },
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

-- Fade = true : côtés courts, compatible avec les dégradés.
-- Trend = true : coupe tendance sur TikTok en 2026 (les clients la demandent 2x plus, badge 🔥).
-- Gender : "H" homme, "F" femme, "U" mixte (les clients et clientes demandent selon leur genre).
-- Ordre = du moins cher au plus cher.
Config.Styles = {
	{ Id = "pixie", Name = "Coupe courte", Icon = "✂️", Value = 1, Cost = 0, Fade = true, Gender = "U" },
	{ Id = "buzz", Name = "Buzz cut", Icon = "🪒", Value = 1.1, Cost = 0, Fade = true, Trend = true, Gender = "H" },
	{ Id = "lisse", Name = "Lisse", Icon = "💇", Value = 1.3, Cost = 0, Gender = "F" },
	{ Id = "frenchcrop", Name = "French crop", Icon = "🥖", Value = 1.5, Cost = 300, Fade = true, Trend = true, Gender = "H" },
	{ Id = "queue", Name = "Queue de cheval", Icon = "🎀", Value = 1.8, Cost = 500, Gender = "F" },
	{ Id = "curtain", Name = "Curtain hair", Icon = "🎭", Value = 2, Cost = 900, Fade = true, Trend = true, Gender = "H" },
	{ Id = "waves", Name = "Waves 360", Icon = "🌊", Value = 2.2, Cost = 1300, Fade = true, Gender = "H" },
	{ Id = "pixieboucle", Name = "Pixie bouclé", Icon = "🌸", Value = 2.4, Cost = 1500, Trend = true, Gender = "F" },
	{ Id = "boucle", Name = "Bouclée", Icon = "🌀", Value = 2.5, Cost = 1800, Gender = "F" },
	{ Id = "twists", Name = "Twists", Icon = "🧽", Value = 2.8, Cost = 4000, Fade = true, Trend = true, Gender = "U" },
	{ Id = "edgar", Name = "Edgar cut", Icon = "📏", Value = 3.1, Cost = 6000, Fade = true, Trend = true, Gender = "H" },
	{ Id = "chignon", Name = "Chignon", Icon = "🍩", Value = 3.4, Cost = 7500, Gender = "F" },
	{ Id = "frangerideau", Name = "Frange rideau", Icon = "🪟", Value = 3.6, Cost = 9000, Trend = true, Gender = "F" },
	{ Id = "bob", Name = "Bob italien", Icon = "🇮🇹", Value = 3.8, Cost = 11000, Trend = true, Gender = "F" },
	{ Id = "cornrows", Name = "Nattes collées", Icon = "〰️", Value = 4.2, Cost = 15000, Fade = true, Gender = "U" },
	{ Id = "mullet", Name = "Mulet moderne", Icon = "🦅", Value = 4.6, Cost = 22000, Fade = true, Trend = true, Gender = "U" },
	{ Id = "couettes", Name = "Couettes", Icon = "👧", Value = 5, Cost = 30000, Gender = "F" },
	{ Id = "wolfcut", Name = "Wolf cut", Icon = "🐺", Value = 5.8, Cost = 45000, Trend = true, Gender = "U" },
	{ Id = "blowout", Name = "Brushing volume", Icon = "💨", Value = 6.2, Cost = 55000, Trend = true, Gender = "F" },
	{ Id = "locs", Name = "Dreadlocks", Icon = "🦁", Value = 6.5, Cost = 65000, Fade = true, Gender = "U" },
	{ Id = "butterfly", Name = "Butterfly cut", Icon = "🦋", Value = 7.5, Cost = 100000, Trend = true, Gender = "F" },
	{ Id = "tresses", Name = "Tresses", Icon = "🪢", Value = 9, Cost = 150000, Gender = "F" },
	{ Id = "afro", Name = "Afro", Icon = "☁️", Value = 11, Cost = 350000, Fade = true, Gender = "U" },
	{ Id = "crete", Name = "Crête Punk", Icon = "🦔", Value = 15, Cost = 1200000, Gender = "U" },
	{ Id = "sirene", Name = "Sirène", Icon = "🧜", Value = 24, Cost = 0, Pass = "premiumStyles", Gender = "F" },
	{ Id = "royal", Name = "Royale", Icon = "👸", Value = 32, Cost = 0, Pass = "premiumStyles", Gender = "F" },
} :: { StyleDef }

-- Dégradés : demandent la « Tondeuse Pro » (sauf « Sans dégradé »).
-- Bands = transparence de chaque bande, de la tempe vers la nuque.
-- Burst = le dégradé tourne autour de l'oreille, la nuque reste pleine.
Config.Fades = {
	{ Id = "aucun", Name = "Sans dégradé", Icon = "⬛", Mult = 1, Bands = { 0, 0, 0, 0, 0 } },
	{ Id = "taper", Name = "Taper", Icon = "🔻", Mult = 1.15, Bands = { 0, 0, 0.1, 0.45, 0.9 }, Trend = true },
	{ Id = "bas", Name = "Dégradé bas", Icon = "▁", Mult = 1.2, Bands = { 0, 0.08, 0.3, 0.6, 0.85 } },
	{ Id = "moyen", Name = "Dégradé moyen", Icon = "▄", Mult = 1.25, Bands = { 0.1, 0.4, 0.65, 0.85, 0.96 } },
	{ Id = "haut", Name = "Dégradé haut", Icon = "█", Mult = 1.3, Bands = { 0.45, 0.7, 0.88, 0.97, 1 } },
	{ Id = "blanc", Name = "Dégradé à blanc", Icon = "⚪", Mult = 1.35, Bands = { 0.55, 0.85, 0.97, 1, 1 }, Trend = true },
	{ Id = "burst", Name = "Burst fade", Icon = "💥", Mult = 1.4, Bands = { 0.15, 0.55, 0.85, 0.97, 1 }, Burst = true, Trend = true },
}
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
Config.FadeById = index(Config.Fades, "Id")
Config.BeardById = index(Config.Beards, "Id")
Config.ColorById = index(Config.Colors, "Id")
Config.AccById = index(Config.Accessories, "Id")

export type Look = { style: string, length: number, fade: string, beard: string, color: string, acc: string }

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
