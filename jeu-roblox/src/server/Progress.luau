-- XP et Barber Pass (saison de 30 paliers, piste gratuite + piste Gold).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Stats = require(script.Parent.Stats)

local Progress = {}

-- Nouvelle saison : on repart de zéro (les teintures gagnées restent).
local function ensureSeason(profile)
	if profile.Pass.Season ~= Config.Season then
		profile.Pass = { Season = Config.Season, XP = 0, Free = 0, Gold = 0 }
	end
end

function Progress.Tier(profile): number
	return math.min(Config.PassTiers, profile.Pass.XP // Config.PassXpPerTier)
end

local function grant(player: Player, profile, reward, track: string, tier: number)
	if reward.Kind == "cash" then
		local amount = Stats.MinutesOfIncome(player, reward.Minutes, reward.Minutes * 150)
		Stats.AddCash(player, amount, false)
		Net.Toast(player, string.format("🎟️ Palier %d (%s) : +%s", tier, track, Util.Money(amount)), "money")
	elseif reward.Kind == "color" then
		profile.SeasonColors[reward.Id] = true
		Net.Toast(player, "🎟️ Palier " .. tier .. " : teinture exclusive « " .. Config.ColorById[reward.Id].Name .. " » !", "success")
		Net.Notify:FireClient(player, { Type = "celebrate" })
	end
end

-- Donne toutes les récompenses atteintes et pas encore reçues.
function Progress.Sync(player: Player)
	local profile = Data.Get(player)
	if not profile then
		return
	end
	ensureSeason(profile)
	local tier = Progress.Tier(profile)
	while profile.Pass.Free < tier do
		profile.Pass.Free += 1
		grant(player, profile, Config.PassRewards[profile.Pass.Free].Free, "gratuit", profile.Pass.Free)
	end
	if Stats.HasPass(player, "seasonPass") then
		while profile.Pass.Gold < tier do
			profile.Pass.Gold += 1
			grant(player, profile, Config.PassRewards[profile.Pass.Gold].Gold, "Gold", profile.Pass.Gold)
		end
	end
	Stats.MarkDirty(player)
end

function Progress.AddXp(player: Player, amount: number)
	local profile = Data.Get(player)
	if not profile or amount <= 0 then
		return
	end
	ensureSeason(profile)
	local before = Progress.Tier(profile)
	profile.Pass.XP = math.min(profile.Pass.XP + amount, Config.PassTiers * Config.PassXpPerTier)
	if Progress.Tier(profile) > before then
		Net.Notify:FireClient(player, { Type = "tierUp", Tier = Progress.Tier(profile) })
		Progress.Sync(player)
	end
	Stats.MarkDirty(player)
end

function Progress.SkipTiers(player: Player, tiers: number)
	local profile = Data.Get(player)
	if not profile then
		error("profil absent")
	end
	ensureSeason(profile)
	Progress.AddXp(player, tiers * Config.PassXpPerTier)
end

---------------------------------------------------------------------
-- Tâches
---------------------------------------------------------------------
local taskById = {}
for _, def in Config.Tasks do
	taskById[def.Id] = def
end
local rng = Random.new()

local function pickTask(profile): string
	local active = {}
	for _, t in profile.Tasks do
		active[t.Id] = true
	end
	local pool = {}
	for _, def in Config.Tasks do
		if not active[def.Id] then
			table.insert(pool, def.Id)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

function Progress.EnsureTasks(player: Player)
	local profile = Data.Get(player)
	if not profile then
		return
	end
	for i = #profile.Tasks, 1, -1 do
		if not taskById[profile.Tasks[i].Id] then
			table.remove(profile.Tasks, i)
		end
	end
	while #profile.Tasks < 3 do
		table.insert(profile.Tasks, { Id = pickTask(profile), Progress = 0 })
	end
	Stats.MarkDirty(player)
end

function Progress.Task(player: Player, kind: string, amount: number?)
	local profile = Data.Get(player)
	if not profile then
		return
	end
	for i = #profile.Tasks, 1, -1 do
		local t = profile.Tasks[i]
		local def = taskById[t.Id]
		if def and def.Kind == kind then
			t.Progress += amount or 1
			if t.Progress >= def.Goal then
				table.remove(profile.Tasks, i)
				local reward = Stats.MinutesOfIncome(player, def.Minutes, def.Minutes * 100)
				Stats.AddCash(player, reward, false)
				Progress.AddXp(player, def.Xp)
				Net.Toast(player, "✅ Tâche terminée : " .. def.Text .. "  +" .. Util.Money(reward), "money")
				Net.Notify:FireClient(player, { Type = "celebrate" })
			end
		end
	end
	Progress.EnsureTasks(player)
end

-- Remet à zéro les tâches d'un type (ex. « sans perdre de client »)
function Progress.ResetTask(player: Player, kind: string)
	local profile = Data.Get(player)
	if not profile then
		return
	end
	for _, t in profile.Tasks do
		local def = taskById[t.Id]
		if def and def.Kind == kind and t.Progress > 0 then
			t.Progress = 0
			Net.Toast(player, "❌ Client perdu : la tâche « " .. def.Text .. " » repart à zéro", "error")
		end
	end
	Stats.MarkDirty(player)
end

return Progress
