-- Passes de jeu et produits Robux.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local BarberTok = require(script.Parent.BarberTok)
local Data = require(script.Parent.Data)
local Progress = require(script.Parent.Progress)
local Net = require(script.Parent.Net)
local Salons = require(script.Parent.Salons)
local Stats = require(script.Parent.Stats)

local Monetization = {}

local GOLD = Color3.fromRGB(255, 200, 70)

local passByAssetId: { [number]: string } = {}
for key, def in Config.GamePasses do
	if def.Id ~= 0 then
		passByAssetId[def.Id] = key
	end
end
local productById: { [number]: string } = {}
for key, def in Config.Products do
	if def.Id ~= 0 then
		productById[def.Id] = key
	end
end

local function onPassOwned(player: Player, key: string)
	Stats.SetPass(player, key, true)
	player:SetAttribute("Pass_" .. key, true)
	if key == "autoStylist" then
		Salons.Rebuild(player, false)
	elseif key == "seasonPass" then
		Progress.Sync(player) -- donne d'un coup toutes les récompenses Gold déjà atteintes
	end
end

function Monetization.CheckPasses(player: Player)
	for key, def in Config.GamePasses do
		if def.Id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.Id)
			end)
			if ok and owns then
				onPassOwned(player, key)
			end
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local key = passByAssetId[passId]
	if purchased and key then
		onPassOwned(player, key)
		local def = Config.GamePasses[key]
		Net.Announce(def.Icon .. " " .. player.DisplayName .. " a acheté " .. def.Name .. " !", GOLD)
		Net.Notify:FireClient(player, { Type = "celebrate" })
	end
end)

---------------------------------------------------------------------
-- Produits (achats répétables)
---------------------------------------------------------------------
local handlers: { [string]: (Player, any) -> () } = {}

handlers.cash = function(player, def)
	local amount = Stats.MinutesOfIncome(player, def.Minutes, def.Min)
	Stats.AddCash(player, amount, false)
	Net.Toast(player, def.Icon .. " +" .. Util.Money(amount) .. " !", "money")
	Net.Notify:FireClient(player, { Type = "celebrate" })
end

handlers.rush = function(player, _def)
	local now = Workspace:GetServerTimeNow()
	local current = ReplicatedStorage:GetAttribute("RushUntil") or 0
	ReplicatedStorage:SetAttribute("RushUntil", math.max(now, current) + Config.RushDuration)
	Net.Announce("🔥 " .. player.DisplayName .. " lance l'HEURE DE POINTE ! Clients x2 et paie x2 pour TOUT le serveur !", Color3.fromRGB(255, 120, 60))
	for _, p in Players:GetPlayers() do
		Stats.MarkDirty(p)
	end
end

handlers.passSkip = function(player, _def)
	Progress.SkipTiers(player, 5)
	Net.Toast(player, "⏩ +5 paliers de Barber Pass !", "success")
end

handlers.viral = function(player, _def)
	BarberTok.PinNext(player)
	Net.Toast(player, "🚀 Ta prochaine coupe sera épinglée en tête de BarberTok !", "success")
end

handlers.celebrity = function(player, _def)
	Salons.AddCelebrity(player)
	Net.Toast(player, "🌟 Une célébrité arrive dans ton salon !", "success")
end

handlers.starter = function(player, _def)
	local profile = Data.Get(player)
	if not profile then
		error("profil absent")
	end
	Stats.AddCash(player, 25000, false)
	if not profile.StarterBought then
		profile.StarterBought = true
		profile.Styles.twists = true
		profile.Clippers = true
		profile.FantasyColors = true
	end
	Stats.MarkDirty(player)
	Net.Toast(player, "🎁 Pack Débutant reçu ! +25K $, Twists, Tondeuse Pro et teintures fantaisie", "success")
	Net.Notify:FireClient(player, { Type = "celebrate" })
end

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Data.Get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if table.find(profile.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- déjà donné
	end
	local key = productById[info.ProductId]
	local def = key and Config.Products[key]
	local handler = def and handlers[def.Kind]
	if not handler then
		warn("[Monetization] Produit inconnu :", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(handler, player, def)
	if not ok then
		warn("[Monetization] Erreur :", err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Data.AddReceipt(profile, purchaseId)
	if not Data.Save(player) then
		-- Roblox redemandera : le reçu est déjà noté en mémoire, il ne sera pas donné deux fois.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return Monetization
