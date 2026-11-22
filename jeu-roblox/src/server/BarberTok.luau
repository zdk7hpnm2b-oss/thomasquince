-- BarberTok : le réseau social du jeu. Les belles coupes sont publiées en avant/après,
-- les joueurs likent, l'auteur gagne des abonnés (= bonus d'argent permanent).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HairBuilder = require(ReplicatedStorage.Shared.HairBuilder)
local Util = require(ReplicatedStorage.Shared.Util)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Progress = require(script.Parent.Progress)
local Stats = require(script.Parent.Stats)
local World = require(script.Parent.World)

local T = Config.BarberTok
local FIRE = Color3.fromRGB(255, 90, 140)

local BarberTok = {}

local posts: { any } = {}
local likedBy: { [number]: { [number]: boolean } } = {}
local lastPost: { [number]: number } = {}
local pinNext: { [number]: boolean } = {}
local nextId = 0

local function ordered()
	local now = os.time()
	local list = table.clone(posts)
	table.sort(list, function(a, b)
		local pa, pb = (a.PinnedUntil or 0) > now, (b.PinnedUntil or 0) > now
		if pa ~= pb then
			return pa
		end
		return a.Id > b.Id
	end)
	return list
end

local function broadcast()
	Net.Feed:FireAllClients(ordered())
end

function BarberTok.SendTo(player: Player)
	Net.Feed:FireClient(player, ordered())
end

function BarberTok.Post(player: Player, before: any, after: any, caption: string): boolean
	local profile = Data.Get(player)
	if not profile then
		return false
	end
	if os.clock() - (lastPost[player.UserId] or -1e9) < T.PostCooldown then
		return false
	end
	lastPost[player.UserId] = os.clock()
	nextId += 1
	local post = {
		Id = nextId,
		Author = player.DisplayName,
		AuthorId = player.UserId,
		Before = HairBuilder.Normalize(before),
		After = HairBuilder.Normalize(after),
		Caption = caption,
		Likes = 0,
		Viral = false,
		Time = os.time(),
		PinnedUntil = 0,
	}
	if pinNext[player.UserId] then
		pinNext[player.UserId] = nil
		post.PinnedUntil = os.time() + 600
	end
	table.insert(posts, post)
	likedBy[post.Id] = {}
	-- On garde les plus récentes (et les épinglées)
	while #posts > T.MaxPosts do
		local oldest = 1
		for i, p in posts do
			if (p.PinnedUntil or 0) <= os.time() and p.Id < posts[oldest].Id then
				oldest = i
			end
		end
		likedBy[posts[oldest].Id] = nil
		table.remove(posts, oldest)
	end
	profile.Posts += 1
	Progress.AddXp(player, Config.Xp.Post)
	Net.Notify:FireClient(player, { Type = "posted", Pinned = post.PinnedUntil > 0 })
	broadcast()
	return true
end

function BarberTok.Like(player: Player, postId: any): (boolean, string?)
	local post
	for _, p in posts do
		if p.Id == postId then
			post = p
		end
	end
	if not post then
		return false
	end
	if post.AuthorId == player.UserId then
		return false, "C'est ta propre publication 😄"
	end
	local set = likedBy[post.Id]
	if set[player.UserId] then
		return false, "Déjà liké"
	end
	set[player.UserId] = true
	post.Likes += 1
	local author = Players:GetPlayerByUserId(post.AuthorId)
	local aProfile = author and Data.Get(author)
	if author and aProfile then
		aProfile.Followers += 1
		Progress.AddXp(author, Config.Xp.Like)
		Stats.MarkDirty(author)
		Net.Toast(author, "❤️ " .. player.DisplayName .. " aime ta coupe : +1 abonné !", "success")
	end
	local needed = math.max(T.ViralLikes, math.ceil(#Players:GetPlayers() / 2))
	if not post.Viral and post.Likes >= needed then
		post.Viral = true
		Net.Announce("🔥 La coupe de " .. post.Author .. " est VIRALE sur BarberTok !", FIRE)
		if author and aProfile then
			local bonus = Stats.MinutesOfIncome(author, T.ViralBonusMinutes, 2000)
			Stats.AddCash(author, bonus, false)
			aProfile.Followers += 10
			Net.Toast(author, "🔥 VIRAL ! +" .. Util.Money(bonus) .. " et +10 abonnés", "money")
			Net.Notify:FireClient(author, { Type = "celebrate" })
		end
	end
	broadcast()
	return true
end

-- Produit Robux « Boost Viral » : la prochaine publication est épinglée 10 min.
function BarberTok.PinNext(player: Player)
	pinNext[player.UserId] = true
	lastPost[player.UserId] = nil
end

function BarberTok.Init()
	-- Écran géant BarberTok sur la place (le contenu est dessiné par chaque client)
	local wall = World.Part({ Name = "BarberTokWall", Size = Vector3.new(13, 22, 1), CFrame = CFrame.new(0, 12, -42) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(12, 10, 16) })
	World.Part({ Name = "BarberTokFrame", Size = Vector3.new(14, 23, 0.8), CFrame = CFrame.new(0, 12, -42.4), Color = Color3.fromRGB(255, 60, 130), Material = Enum.Material.Neon })
	for _, x in { -5, 5 } do
		World.Part({ Name = "BarberTokLeg", Size = Vector3.new(1, 1.5, 1), Position = Vector3.new(x, 0.75, -42.4), Color = Color3.fromRGB(40, 36, 50), Material = Enum.Material.Metal })
	end
	wall:SetAttribute("BarberTok", true)
	-- Mannequin utilisé par les clients pour afficher les avant/après
	task.spawn(function()
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(190, 135, 100)
		desc.HeadColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.TorsoColor = Color3.fromRGB(30, 28, 36)
		desc.LeftLegColor = Color3.fromRGB(30, 28, 36)
		desc.RightLegColor = Color3.fromRGB(30, 28, 36)
		local ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if ok and model then
			model.Name = "PostDummy"
			for _, d in model:GetDescendants() do
				if d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			model.Parent = ReplicatedStorage
		else
			warn("[BarberTok] Mannequin impossible :", model)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	lastPost[player.UserId] = nil
	pinNext[player.UserId] = nil
end)

return BarberTok
