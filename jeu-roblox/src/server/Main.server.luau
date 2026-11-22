-- Point d'entrée serveur de Barber Legends.

local Players = game:GetService("Players")

local BarberTok = require(script.Parent.BarberTok)
local Battle = require(script.Parent.Battle)
local Data = require(script.Parent.Data)
local Monetization = require(script.Parent.Monetization)
local Net = require(script.Parent.Net)
local Progress = require(script.Parent.Progress)
local Rewards = require(script.Parent.Rewards)
local Salons = require(script.Parent.Salons)
local Stats = require(script.Parent.Stats)
local World = require(script.Parent.World)

World.Build()
Salons.Init()
Rewards.Init()
Battle.Init()
BarberTok.Init()

local function onCharacter(player: Player, character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not hrp then
		return
	end
	task.wait(0.1)
	local home = Salons.HomeCFrame(player)
	if home then
		character:PivotTo(home)
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum and Stats.HasPass(player, "vip") then
		hum.WalkSpeed = 22
	end
	Salons.ApplyLook(player)
end

local function onPlayerAdded(player: Player)
	Stats.Init(player)
	Stats.CreateLeaderstats(player)
	local profile = Data.Load(player)
	if not profile or not player.Parent then
		return
	end
	Monetization.CheckPasses(player)
	Rewards.CheckGroup(player)
	Rewards.RefreshFriends()
	Rewards.Offline(player)
	Progress.Sync(player)
	BarberTok.SendTo(player)

	if not Salons.Assign(player) then
		Net.Toast(player, "Tous les salons sont pris sur ce serveur, tu peux visiter et te faire coiffer !", "error")
	end
	player.CharacterAppearanceLoaded:Connect(function()
		Salons.ApplyLook(player)
	end)
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	Stats.PushNow(player)
	Net.Notify:FireClient(player, { Type = "welcome", First = profile.Served == 0 })
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local profile = Data.Get(player)
	if profile then
		profile.OfflineRate = Stats.Rate(player)
	end
	Salons.OnPlayerRemoving(player)
	Data.Release(player)
	Stats.Cleanup(player)
	task.defer(Rewards.RefreshFriends)
end)

---------------------------------------------------------------------
-- Actions du client (toutes vérifiées côté serveur)
---------------------------------------------------------------------
local lastCall: { [Player]: number } = {}

Net.Action.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
	if typeof(action) ~= "string" then
		return false
	end
	local now = os.clock()
	if now - (lastCall[player] or 0) < 0.08 then
		return false, "Doucement !"
	end
	lastCall[player] = now
	if not Data.IsLoaded(player) then
		return false, "Chargement…"
	end

	if action == "Apply" then
		return Salons.Apply(player, a, b)
	elseif action == "Finish" then
		Salons.EndSession(player, true)
		return true
	elseif action == "Cancel" then
		Salons.EndSession(player, false)
		return true
	elseif action == "Buy" then
		if typeof(a) ~= "string" or typeof(b) ~= "string" then
			return false
		end
		return Salons.Buy(player, a, b)
	elseif action == "Rebirth" then
		return Salons.Rebirth(player)
	elseif action == "Daily" then
		return Rewards.ClaimDaily(player)
	elseif action == "Gift" then
		return Rewards.ClaimGift(player, a)
	elseif action == "Code" then
		return Rewards.RedeemCode(player, a)
	elseif action == "Like" then
		return BarberTok.Like(player, a)
	elseif action == "JoinBattle" then
		return Battle.Join(player)
	elseif action == "GoHome" then
		local home = Salons.HomeCFrame(player)
		if home and player.Character and not Salons.HasSession(player) then
			player.Character:PivotTo(home)
		end
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)
