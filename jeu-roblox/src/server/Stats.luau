-- Argent, multiplicateurs, passes possédés, état envoyé au client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)

local Stats = {}

local passes: { [Player]: { [string]: boolean } } = {}
local boosts: { [Player]: { friends: number, group: boolean } } = {}
local rate: { [Player]: number } = {} -- gains moyens / seconde (moyenne glissante)
local earnedThisSecond: { [Player]: number } = {}
local dirty: { [Player]: boolean } = {}
local session: { [Player]: { JoinTime: number, Gifts: { [number]: boolean }, SalonIndex: number? } } = {}

function Stats.Init(player: Player)
	passes[player] = passes[player] or {}
	boosts[player] = { friends = 0, group = false }
	rate[player] = 0
	earnedThisSecond[player] = 0
	session[player] = { JoinTime = os.time(), Gifts = {}, SalonIndex = nil }
end

function Stats.Cleanup(player: Player)
	passes[player] = nil
	boosts[player] = nil
	rate[player] = nil
	earnedThisSecond[player] = nil
	dirty[player] = nil
	session[player] = nil
end

function Stats.Session(player: Player)
	return session[player]
end

---------------------------------------------------------------------
-- Passes
---------------------------------------------------------------------
function Stats.SetPass(player: Player, key: string, owned: boolean)
	passes[player] = passes[player] or {}
	passes[player][key] = owned
	Stats.MarkDirty(player)
end

function Stats.HasPass(player: Player, key: string): boolean
	local p = passes[player]
	return p ~= nil and p[key] == true
end

---------------------------------------------------------------------
-- Boosts (amis, groupe, premium, heure de pointe)
---------------------------------------------------------------------
function Stats.SetFriends(player: Player, count: number)
	if boosts[player] then
		boosts[player].friends = count
		Stats.MarkDirty(player)
	end
end

function Stats.SetGroup(player: Player, inGroup: boolean)
	if boosts[player] then
		boosts[player].group = inGroup
		Stats.MarkDirty(player)
	end
end

function Stats.RushActive(): boolean
	local untilT = ReplicatedStorage:GetAttribute("RushUntil") or 0
	return Workspace:GetServerTimeNow() < untilT
end

function Stats.BoostBreakdown(player: Player)
	local profile = Data.Get(player)
	local b = boosts[player] or { friends = 0, group = false }
	local friend = math.min(b.friends * Config.FriendBoostPerFriend, Config.FriendBoostMax)
	return {
		Rebirth = profile and profile.Rebirths * Config.RebirthBonus or 0,
		Friends = friend,
		Group = b.group and Config.GroupBoost or 0,
		Premium = player.MembershipType == Enum.MembershipType.Premium and Config.PremiumBoost or 0,
		Vip = Stats.HasPass(player, "vip") and Config.VipBoost or 0,
		Double = Stats.HasPass(player, "doubleCash"),
		Rush = Stats.RushActive(),
	}
end

function Stats.Multiplier(player: Player): number
	local b = Stats.BoostBreakdown(player)
	local m = (1 + b.Rebirth) * (1 + b.Friends + b.Group + b.Premium) * (1 + b.Vip)
	if b.Double then
		m *= 2
	end
	if b.Rush then
		m *= Config.RushMultiplier
	end
	return m
end

---------------------------------------------------------------------
-- Argent
---------------------------------------------------------------------
function Stats.AddCash(player: Player, amount: number, countsAsEarned: boolean?)
	local profile = Data.Get(player)
	if not profile or amount ~= amount then
		return
	end
	amount = math.floor(amount)
	profile.Cash += amount
	if countsAsEarned ~= false and amount > 0 then
		profile.TotalEarned += amount
		earnedThisSecond[player] = (earnedThisSecond[player] or 0) + amount
	end
	Stats.MarkDirty(player)
end

function Stats.Spend(player: Player, amount: number): boolean
	local profile = Data.Get(player)
	if not profile or amount < 0 or profile.Cash < amount then
		return false
	end
	profile.Cash -= amount
	Stats.MarkDirty(player)
	return true
end

-- Gains par seconde estimés (sert à dimensionner les packs et récompenses).
function Stats.Rate(player: Player): number
	local profile = Data.Get(player)
	local floorRate = 2
	if profile then
		floorRate = math.max(2, profile.Upgrades.stylists * Config.BasePay * 0.15 * Stats.Multiplier(player))
	end
	return math.max(rate[player] or 0, floorRate)
end

-- N minutes de gains (avec un minimum)
function Stats.MinutesOfIncome(player: Player, minutes: number, minimum: number): number
	return math.floor(math.max(minimum, Stats.Rate(player) * 60 * minutes))
end

---------------------------------------------------------------------
-- État envoyé au client
---------------------------------------------------------------------
function Stats.MarkDirty(player: Player)
	dirty[player] = true
end

local function snapshot(player: Player)
	local profile = Data.Get(player)
	if not profile then
		return nil
	end
	local ownedPasses = {}
	for key in Config.GamePasses do
		ownedPasses[key] = Stats.HasPass(player, key)
	end
	local s = session[player]
	return {
		Cash = profile.Cash,
		TotalEarned = profile.TotalEarned,
		Served = profile.Served,
		Perfect = profile.Perfect,
		Streak = profile.Streak,
		Rebirths = profile.Rebirths,
		Upgrades = profile.Upgrades,
		Styles = profile.Styles,
		Accs = profile.Accs,
		FantasyColors = profile.FantasyColors,
		Look = profile.Look,
		Daily = profile.Daily,
		StarterBought = profile.StarterBought,
		Passes = ownedPasses,
		Mult = Stats.Multiplier(player),
		Boosts = Stats.BoostBreakdown(player),
		Rate = Stats.Rate(player),
		JoinTime = s and s.JoinTime or os.time(),
		Gifts = s and s.Gifts or {},
		SalonIndex = s and s.SalonIndex,
		ServerNow = os.time(),
	}
end

function Stats.PushNow(player: Player)
	local snap = snapshot(player)
	if snap then
		dirty[player] = nil
		Net.State:FireClient(player, snap)
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			local cash = ls:FindFirstChild("Argent") :: StringValue
			local served = ls:FindFirstChild("Clients") :: IntValue
			cash.Value = Util.Format(snap.Cash)
			served.Value = snap.Served
		end
	end
end

function Stats.CreateLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Argent"
	cash.Value = "0"
	cash.Parent = ls
	local served = Instance.new("IntValue")
	served.Name = "Clients"
	served.Parent = ls
	ls.Parent = player
end

task.spawn(function()
	local acc = 0
	while true do
		local dt = task.wait(0.25)
		acc += dt
		if acc >= 1 then
			acc -= 1
			for player, earned in earnedThisSecond do
				-- moyenne glissante sur ~3 minutes
				rate[player] = (rate[player] or 0) * (1 - 1 / 180) + earned / 180
				earnedThisSecond[player] = 0
			end
		end
		for player in dirty do
			if player.Parent then
				Stats.PushNow(player)
			else
				dirty[player] = nil
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	dirty[player] = nil
end)

return Stats
