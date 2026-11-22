-- Sauvegarde des joueurs : verrou de session (anti-duplication entre serveurs),
-- sauvegarde automatique, sauvegarde à la fermeture du serveur.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local Data = {}

local LOCK_TIMEOUT = 15 * 60 -- un verrou plus vieux que ça est considéré abandonné
local AUTOSAVE = 90

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStore indisponible (active « Enable Studio Access to API Services ») :", result)
	end
end

local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

export type Profile = {
	Cash: number,
	TotalEarned: number,
	Served: number,
	Perfect: number,
	Streak: number,
	Rebirths: number,
	Upgrades: { chairs: number, stylists: number, deco: number, pub: number },
	Styles: { [string]: boolean },
	Beards: { [string]: boolean },
	Clippers: boolean,
	Trophies: number,
	Followers: number,
	Posts: number,
	SeasonColors: { [string]: boolean },
	Pass: { Season: number, XP: number, Free: number, Gold: number },
	BattleWins: number,
	Accs: { [string]: boolean },
	FantasyColors: boolean,
	Look: { style: string, length: number, color: string, acc: string }?,
	Daily: { Last: number, Streak: number },
	Codes: { [string]: boolean },
	Receipts: { string },
	StarterBought: boolean,
	LastOnline: number,
	OfflineRate: number,
	FirstJoin: number,
}

local function defaults(): Profile
	return {
		Cash = 0,
		TotalEarned = 0,
		Served = 0,
		Perfect = 0,
		Streak = 0,
		Rebirths = 0,
		Upgrades = { chairs = 1, stylists = 0, deco = 1, pub = 0 },
		Styles = { pixie = true, buzz = true, lisse = true },
		Beards = { aucune = true, trois = true },
		Clippers = false,
		Trophies = 0,
		Followers = 0,
		Posts = 0,
		SeasonColors = {},
		Pass = { Season = 0, XP = 0, Free = 0, Gold = 0 },
		BattleWins = 0,
		Accs = { aucun = true, noeud = true },
		FantasyColors = false,
		Look = nil,
		Daily = { Last = 0, Streak = 0 },
		Codes = {},
		Receipts = {},
		StarterBought = false,
		LastOnline = 0,
		OfflineRate = 0,
		FirstJoin = os.time(),
	}
end

local function reconcile(target: any, template: any)
	for k, v in template do
		if target[k] == nil then
			target[k] = typeof(v) == "table" and table.clone(v) or v
		elseif typeof(v) == "table" and typeof(target[k]) == "table" then
			reconcile(target[k], v)
		end
	end
end

local profiles: { [Player]: Profile } = {}
local noSave: { [Player]: boolean } = {}
local loadedSignal = Instance.new("BindableEvent")

function Data.Get(player: Player): Profile?
	return profiles[player]
end

function Data.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

Data.Loaded = loadedSignal.Event -- (player, profile)

local function key(player: Player)
	return "p_" .. player.UserId
end

local function tryLoad(player: Player): (boolean, any)
	local acquired = false
	local result
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function(old)
			old = old or {}
			local lock = old.Lock
			if lock and lock.JobId ~= jobId and os.time() - (lock.Time or 0) < LOCK_TIMEOUT then
				acquired = false
				return nil -- quelqu'un d'autre l'utilise : on annule
			end
			acquired = true
			old.Lock = { JobId = jobId, Time = os.time() }
			result = old.Data
			return old
		end)
	end)
	if not ok then
		warn("[Data] Erreur de chargement :", err)
		return false, nil
	end
	return acquired, result
end

function Data.Load(player: Player): Profile?
	local profile: Profile
	if store then
		local loaded = false
		local result
		for attempt = 1, 6 do
			local acquired, data = tryLoad(player)
			if acquired then
				loaded, result = true, data
				break
			end
			if not player.Parent then
				return nil
			end
			task.wait(attempt * 2)
		end
		if not loaded then
			-- Dernier recours : on vole le verrou (serveur précédent probablement mort)
			local ok = pcall(function()
				(store :: DataStore):UpdateAsync(key(player), function(old)
					old = old or {}
					old.Lock = { JobId = jobId, Time = os.time() }
					result = old.Data
					return old
				end)
			end)
			if not ok then
				player:Kick("Impossible de charger ta sauvegarde, réessaie dans une minute.")
				return nil
			end
		end
		profile = typeof(result) == "table" and result or defaults()
	else
		profile = defaults()
		noSave[player] = true
	end
	reconcile(profile, defaults())
	if not player.Parent then
		Data.Release(player)
		return nil
	end
	profiles[player] = profile
	loadedSignal:Fire(player, profile)
	return profile
end

-- Sauvegarde (bloquante). release = libérer le verrou (le joueur part).
function Data.Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or noSave[player] or not store then
		return noSave[player] == true
	end
	profile.LastOnline = os.time()
	local stillOwner = true
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function(old)
			old = old or {}
			if old.Lock and old.Lock.JobId ~= jobId then
				stillOwner = false
				return nil -- un autre serveur a pris la main : ne pas écraser
			end
			old.Data = profile
			old.Lock = (not release) and { JobId = jobId, Time = os.time() } or nil
			return old
		end)
	end)
	if not ok then
		warn("[Data] Erreur de sauvegarde :", err)
		return false
	end
	if not stillOwner then
		warn("[Data] Verrou perdu pour", player.Name)
		player:Kick("Ta partie a été ouverte sur un autre serveur.")
		return false
	end
	return true
end

function Data.Release(player: Player)
	if profiles[player] then
		Data.Save(player, true)
	end
	profiles[player] = nil
	noSave[player] = nil
end

function Data.AddReceipt(profile: Profile, purchaseId: string)
	table.insert(profile.Receipts, purchaseId)
	while #profile.Receipts > 60 do
		table.remove(profile.Receipts, 1)
	end
end

task.spawn(function()
	while true do
		task.wait(AUTOSAVE)
		for player in profiles do
			task.spawn(Data.Save, player)
		end
	end
end)

game:BindToClose(function()
	if RunService:IsStudio() and not store then
		return
	end
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			Data.Save(player, true)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

return Data
