-- Récompenses gratuites (rétention) et classement mondial.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Stats = require(script.Parent.Stats)
local World = require(script.Parent.World)

local Rewards = {}

local function dayIndex(t: number): number
	return t // 86400
end

---------------------------------------------------------------------
-- Récompense quotidienne (série de 7 jours)
---------------------------------------------------------------------
function Rewards.ClaimDaily(player: Player): (boolean, string?)
	local profile = Data.Get(player)
	if not profile then
		return false
	end
	local today = dayIndex(os.time())
	local last = dayIndex(profile.Daily.Last)
	if profile.Daily.Last > 0 and last >= today then
		return false, "Reviens demain !"
	end
	if profile.Daily.Last > 0 and today - last == 1 then
		profile.Daily.Streak = profile.Daily.Streak % #Config.DailyRewards + 1
	else
		profile.Daily.Streak = 1
	end
	profile.Daily.Last = os.time()
	local mult = Config.DailyRewards[profile.Daily.Streak]
	local amount = Stats.MinutesOfIncome(player, Config.DailyBaseMinutes * mult, Config.DailyMin * mult)
	Stats.AddCash(player, amount, false)
	Net.Toast(player, "📅 Jour " .. profile.Daily.Streak .. " : +" .. Util.Money(amount), "money")
	Net.Notify:FireClient(player, { Type = "celebrate" })
	Stats.MarkDirty(player)
	return true
end

---------------------------------------------------------------------
-- Cadeaux de temps de jeu
---------------------------------------------------------------------
function Rewards.ClaimGift(player: Player, index: number): (boolean, string?)
	local s = Stats.Session(player)
	local gift = typeof(index) == "number" and Config.PlaytimeGifts[index]
	if not s or not gift then
		return false
	end
	if s.Gifts[index] then
		return false, "Déjà récupéré"
	end
	if os.time() - s.JoinTime < gift.Minutes * 60 then
		return false, "Pas encore prêt"
	end
	s.Gifts[index] = true
	local amount = Stats.MinutesOfIncome(player, gift.Amount, gift.Amount * 100)
	Stats.AddCash(player, amount, false)
	Net.Toast(player, "🎁 " .. gift.Name .. " : +" .. Util.Money(amount), "money")
	Stats.MarkDirty(player)
	return true
end

---------------------------------------------------------------------
-- Codes
---------------------------------------------------------------------
function Rewards.RedeemCode(player: Player, code: any): (boolean, string?)
	local profile = Data.Get(player)
	if not profile or typeof(code) ~= "string" then
		return false
	end
	code = code:upper():gsub("%s", "")
	local amount = Config.Codes[code]
	if not amount then
		return false, "Code invalide"
	end
	if profile.Codes[code] then
		return false, "Code déjà utilisé"
	end
	profile.Codes[code] = true
	Stats.AddCash(player, amount, false)
	Net.Toast(player, "🎟️ Code " .. code .. " : +" .. Util.Money(amount), "money")
	return true
end

---------------------------------------------------------------------
-- Boosts amis / groupe
---------------------------------------------------------------------
local friendCache: { [string]: boolean } = {}

local function areFriends(a: Player, b: Player): boolean
	local k = math.min(a.UserId, b.UserId) .. "-" .. math.max(a.UserId, b.UserId)
	if friendCache[k] == nil then
		local ok, res = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		friendCache[k] = ok and res or false
	end
	return friendCache[k]
end

function Rewards.RefreshFriends()
	local list = Players:GetPlayers()
	for _, p in list do
		local count = 0
		for _, q in list do
			if p ~= q and areFriends(p, q) then
				count += 1
			end
		end
		Stats.SetFriends(p, count)
	end
end

function Rewards.CheckGroup(player: Player)
	if Config.GroupId == 0 then
		return
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroup(Config.GroupId)
	end)
	Stats.SetGroup(player, ok and inGroup or false)
	player:SetAttribute("InGroup", ok and inGroup or false)
end

---------------------------------------------------------------------
-- Gains hors ligne (les stylistes travaillent pendant ton absence)
---------------------------------------------------------------------
function Rewards.Offline(player: Player)
	local profile = Data.Get(player)
	if not profile or profile.LastOnline == 0 or profile.Upgrades.stylists <= 0 then
		return
	end
	local elapsed = math.min(os.time() - profile.LastOnline, Config.OfflineMaxSeconds)
	if elapsed < 120 then
		return
	end
	local share = math.min(1, profile.Upgrades.stylists / 3)
	local amount = math.floor(elapsed * (profile.OfflineRate or 0) * Config.OfflineRate * share)
	if amount > 0 then
		Stats.AddCash(player, amount)
		task.delay(4, function()
			Net.Notify:FireClient(player, { Type = "offline", Amount = amount, Seconds = elapsed })
		end)
	end
end

---------------------------------------------------------------------
-- Classement mondial (panneau physique)
---------------------------------------------------------------------
local board: ScrollingFrame? = nil

local function buildBoard()
	local part = World.Part({
		Name = "Leaderboard",
		Size = Vector3.new(16, 20, 1),
		CFrame = CFrame.new(0, 11, 42),
		Color = Color3.fromRGB(26, 20, 38),
	})
	World.Part({ Name = "LeaderboardFrame", Size = Vector3.new(17, 21, 0.8), CFrame = CFrame.new(0, 11, 42.3), Color = Color3.fromRGB(255, 200, 70), Material = Enum.Material.Foil })
	for _, x in { -6, 6 } do
		World.Part({ Name = "LeaderboardLeg", Size = Vector3.new(1, 2, 1), Position = Vector3.new(x, 1, 42.3), Color = Color3.fromRGB(255, 200, 70), Material = Enum.Material.Foil })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = part
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.13)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 210, 90)
	title.Text = "🏆 MEILLEURS COIFFEURS DU MONDE"
	title.Parent = gui
	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromScale(0.04, 0.15)
	list.Size = UDim2.fromScale(0.92, 0.82)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 0
	list.CanvasSize = UDim2.new()
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.01, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	board = list
end

local nameCache: { [number]: string } = {}
local function nameOf(userId: number): string
	if not nameCache[userId] then
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		nameCache[userId] = ok and name or ("#" .. userId)
	end
	return nameCache[userId]
end

local function refreshBoard()
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LeaderboardStoreName)
	end)
	if not ok then
		return
	end
	for _, player in Players:GetPlayers() do
		local profile = Data.Get(player)
		if profile and profile.TotalEarned > 0 then
			pcall(function()
				store:SetAsync("u" .. player.UserId, math.floor(math.min(profile.TotalEarned, 2 ^ 52)))
			end)
		end
	end
	local okPage, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if not okPage or not board then
		return
	end
	for _, c in board:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local medals = { "🥇", "🥈", "🥉" }
	for rank, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 2)) or 0
		local row = Instance.new("TextLabel")
		row.LayoutOrder = rank
		row.Size = UDim2.fromScale(1, 0.09)
		row.BackgroundColor3 = rank % 2 == 0 and Color3.fromRGB(40, 32, 56) or Color3.fromRGB(52, 40, 72)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = rank <= 3 and Color3.fromRGB(255, 215, 110) or Color3.new(1, 1, 1)
		row.Text = "  " .. (medals[rank] or ("#" .. rank)) .. "  " .. nameOf(userId) .. "  —  " .. Util.Money(entry.value)
		Instance.new("UICorner", row).CornerRadius = UDim.new(0.3, 0)
		row.Parent = board
	end
end

function Rewards.Init()
	buildBoard()
	task.spawn(function()
		task.wait(10)
		while true do
			pcall(refreshBoard)
			task.wait(120)
		end
	end)
end

return Rewards
