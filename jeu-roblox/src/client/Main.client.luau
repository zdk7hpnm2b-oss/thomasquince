-- Client de Salon Star : interface, atelier de coiffure, effets.

local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HairBuilder = require(Shared:WaitForChild("HairBuilder"))
local Util = require(Shared:WaitForChild("Util"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Action: RemoteFunction = Remotes:WaitForChild("Action")
local StateEvent: RemoteEvent = Remotes:WaitForChild("State")
local NotifyEvent: RemoteEvent = Remotes:WaitForChild("Notify")
local SessionEvent: RemoteEvent = Remotes:WaitForChild("Session")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local C = Ui.Colors

local state: any = nil
local stateReceivedAt = os.clock()
local session: any = nil
local refreshers: { () -> () } = {}

local function refreshAll()
	for _, f in refreshers do
		task.spawn(f)
	end
end

---------------------------------------------------------------------
-- Sons (uniquement des sons intégrés au client Roblox)
---------------------------------------------------------------------
local function sound(id: string, volume: number?, pitch: number?)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(5, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end
local PING = "rbxasset://sounds/electronicpingshort.wav"

---------------------------------------------------------------------
-- Racine de l'interface
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SalonUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local hud = Ui.Frame({ Parent = gui, Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

---------------------------------------------------------------------
-- Argent (haut centre)
---------------------------------------------------------------------
local cashPill = Ui.Frame({ Parent = hud, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(300, 74), BackgroundColor3 = C.Bg })
Ui.Corner(cashPill, 37)
Ui.Stroke(cashPill, C.Gold, 3)
Ui.Gradient(cashPill, Color3.fromRGB(70, 44, 100), Color3.fromRGB(30, 20, 46))
local cashLabel = Ui.Label({ Parent = cashPill, Text = "💰 0 $", Size = UDim2.new(1, -24, 0, 42), Position = UDim2.fromOffset(12, 4), TextColor3 = C.Gold })
local rateLabel = Ui.Label({ Parent = cashPill, Text = "", Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 46), TextColor3 = C.Muted, Font = Enum.Font.GothamBold })

local rushBanner = Ui.Frame({ Parent = hud, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(360, 36), BackgroundColor3 = Color3.fromRGB(255, 110, 50), Visible = false })
Ui.Corner(rushBanner, 18)
Ui.Gradient(rushBanner, Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 60, 90), 0)
local rushLabel = Ui.Label({ Parent = rushBanner, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), Text = "" })

local streakLabel = Ui.Label({ Parent = hud, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 70), Size = UDim2.fromOffset(260, 30), Text = "", TextColor3 = Color3.fromRGB(255, 170, 80), TextXAlignment = Enum.TextXAlignment.Right })

local displayedCash = 0
RunService.RenderStepped:Connect(function(dt)
	if state then
		displayedCash += (state.Cash - displayedCash) * math.min(1, dt * 8)
		if math.abs(state.Cash - displayedCash) < 1 then
			displayedCash = state.Cash
		end
		cashLabel.Text = "💰 " .. Util.Money(displayedCash)
	end
	local rushUntil = ReplicatedStorage:GetAttribute("RushUntil") or 0
	local left = rushUntil - Workspace:GetServerTimeNow()
	rushBanner.Visible = left > 0 and not session
	if left > 0 then
		rushLabel.Text = "🔥 HEURE DE POINTE x2 — " .. Util.Time(left)
	end
end)

table.insert(refreshers, function()
	rateLabel.Text = string.format("≈ %s $/s  •  boost x%.1f", Util.Format(state.Rate), state.Mult)
	if state.Streak >= 2 then
		streakLabel.Text = string.format("🔥 Série parfaite x%d (+%d%%)", state.Streak, math.min(state.Streak, Config.StreakMax) * Config.StreakBonus * 100)
	else
		streakLabel.Text = ""
	end
end)

---------------------------------------------------------------------
-- Notifications
---------------------------------------------------------------------
local toastHolder = Ui.Frame({ Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 110), Size = UDim2.fromOffset(340, 400), ZIndex = 50 })
local toastLayout = Instance.new("UIListLayout")
toastLayout.Padding = UDim.new(0, 8)
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.Parent = toastHolder

local TOAST_COLORS = { info = C.Blue, success = C.Green, error = C.Red, money = C.Gold }

local function toast(text: string, kind: string?)
	local f = Ui.Frame({ Parent = toastHolder, Size = UDim2.fromOffset(340, 52), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.05 })
	Ui.Corner(f, 14)
	Ui.Stroke(f, TOAST_COLORS[kind or "info"] or C.Blue, 2.5)
	Ui.Label({ Parent = f, Text = text, Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6), Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
	Ui.Pop(f)
	if kind == "error" then
		sound(PING, 0.3, 0.6)
	end
	task.delay(4.5, function()
		Ui.Tween(f, 0.3, { BackgroundTransparency = 1 })
		task.wait(0.3)
		f:Destroy()
	end)
end

local announce = Ui.Label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.new(0.8, 0, 0, 46), Text = "", Visible = false, ZIndex = 60, TextColor3 = C.Gold })
local function showAnnounce(text: string, color: Color3?)
	announce.Text = text
	announce.TextColor3 = color or C.Gold
	announce.Visible = true
	announce.TextTransparency = 0
	Ui.Pop(announce)
	sound(PING, 0.5, 1.3)
	task.delay(5, function()
		if announce.Text == text then
			Ui.Tween(announce, 0.4, { TextTransparency = 1 })
			task.wait(0.4)
			if announce.Text == text then
				announce.Visible = false
			end
		end
	end)
end

-- « +120 $ » qui s'envole
local function payPopup(amount: number, perfect: boolean, streak: number)
	local text = "+" .. Util.Money(amount)
	if perfect then
		text = "✨ PARFAIT ! " .. text .. (streak >= 2 and ("  🔥x" .. streak) or "")
	end
	local l = Ui.Label({ Parent = gui, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(520, perfect and 64 or 48), Text = text, TextColor3 = perfect and C.Gold or C.Green, ZIndex = 70 })
	Ui.Pop(l)
	sound(PING, 0.6, perfect and 1.5 or 1.1)
	Ui.Tween(l, 1.4, { Position = UDim2.fromScale(0.5, 0.3), TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(1.5, function()
		l:Destroy()
	end)
end

-- Confettis
local function confetti()
	local colors = { C.Pink, C.Gold, C.Blue, C.Green, Color3.fromRGB(190, 120, 255) }
	for i = 1, 60 do
		local f = Ui.Frame({ Parent = gui, Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)), Position = UDim2.fromScale(math.random(), -0.05), BackgroundColor3 = colors[(i % #colors) + 1], Rotation = math.random(0, 360), ZIndex = 80 })
		local t = math.random(15, 30) / 10
		Ui.Tween(f, t, { Position = UDim2.fromScale(f.Position.X.Scale + math.random(-15, 15) / 100, 1.05), Rotation = f.Rotation + math.random(-400, 400) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(t, function()
			f:Destroy()
		end)
	end
	sound(PING, 0.6, 1.8)
end

---------------------------------------------------------------------
-- Achats Robux
---------------------------------------------------------------------
local priceCache: { [string]: string } = {}
local function priceText(id: number, isPass: boolean): string
	if id == 0 then
		return "Bientôt"
	end
	local key = (isPass and "p" or "d") .. id
	if priceCache[key] then
		return priceCache[key]
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, isPass and Enum.InfoType.GamePass or Enum.InfoType.Product)
	end)
	local text = (ok and info and info.PriceInRobux) and ("R$ " .. info.PriceInRobux) or "R$ ?"
	priceCache[key] = text
	return text
end

local function buyPass(key: string)
	local def = Config.GamePasses[key]
	if not def or def.Id == 0 then
		toast("Ce pass arrive bientôt !", "info")
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, def.Id)
end

local function buyProduct(key: string)
	local def = Config.Products[key]
	if not def or def.Id == 0 then
		toast("Ce pack arrive bientôt !", "info")
		return
	end
	MarketplaceService:PromptProductPurchase(player, def.Id)
end

local function call(...)
	local ok, res, msg = pcall(function(...)
		return Action:InvokeServer(...)
	end, ...)
	if not ok then
		return false
	end
	if not res and msg then
		toast(msg, "error")
	end
	return res
end

---------------------------------------------------------------------
-- Fenêtres
---------------------------------------------------------------------
local windows: { [string]: Frame } = {}
local function openWindow(name: string)
	for n, w in windows do
		w.Visible = (n == name) and not w.Visible
		if w.Visible then
			Ui.Pop(w)
		end
	end
	refreshAll()
end

-- Carte générique pour les listes
local function rowCard(parent: Instance, order: number, icon: string, title: string, desc: string, buttonText: string, buttonColor: Color3, onClick: (() -> ())?)
	local card = Ui.Frame({ Parent = parent, LayoutOrder = order, Size = UDim2.new(1, -10, 0, 78), BackgroundColor3 = C.Card })
	Ui.Corner(card, 16)
	Ui.Stroke(card, Color3.fromRGB(120, 80, 160), 1.5)
	Ui.Label({ Parent = card, Text = icon, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 11), NoStroke = true })
	Ui.Label({ Parent = card, Text = title, Size = UDim2.new(1, -250, 0, 30), Position = UDim2.fromOffset(76, 8), TextXAlignment = Enum.TextXAlignment.Left })
	Ui.Label({ Parent = card, Text = desc, Size = UDim2.new(1, -250, 0, 30), Position = UDim2.fromOffset(76, 40), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamMedium, TextColor3 = C.Muted, NoStroke = true })
	local btn = Ui.Button({ Parent = card, Text = buttonText, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 50), BackgroundColor3 = buttonColor }, onClick)
	return card, btn
end

local function sectionTitle(parent: Instance, order: number, text: string)
	Ui.Label({ Parent = parent, LayoutOrder = order, Text = text, Size = UDim2.new(1, -10, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Pink2 })
end

-- Boutique Robux ---------------------------------------------------
local shopWin, shopContent = Ui.Window(gui, "🛒 Boutique", C.Gold)
windows.shop = shopWin
local shopScroll = Ui.Scroll(shopContent)
local function buildShop()
	for _, c in shopScroll:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	sectionTitle(shopScroll, 0, "⚡ Boosts")
	local order = 1
	for _, key in { "rushHour", "celebrity", "starterPack" } do
		local def = Config.Products[key]
		if not (key == "starterPack" and state and state.StarterBought) then
			rowCard(shopScroll, order, def.Icon, def.Name, def.Desc or "", priceText(def.Id, false), C.Green, function()
				buyProduct(key)
			end)
			order += 1
		end
	end
	sectionTitle(shopScroll, 10, "💰 Argent (s'adapte à ton niveau)")
	order = 11
	for _, key in { "cashSmall", "cashMedium", "cashLarge", "cashHuge" } do
		local def = Config.Products[key]
		local amount = state and math.max(def.Min, state.Rate * 60 * def.Minutes) or def.Min
		rowCard(shopScroll, order, def.Icon, def.Name, "+" .. Util.Money(amount), priceText(def.Id, false), C.Green, function()
			buyProduct(key)
		end)
		order += 1
	end
	sectionTitle(shopScroll, 20, "💎 Passes (pour toujours)")
	order = 21
	for _, key in { "vip", "doubleCash", "neonColors", "premiumStyles", "autoStylist", "fastClients", "bigTips" } do
		local def = Config.GamePasses[key]
		local owned = state and state.Passes[key]
		rowCard(shopScroll, order, def.Icon, def.Name, def.Desc, owned and "✅ Possédé" or priceText(def.Id, true), owned and C.Card or C.Gold, function()
			if not owned then
				buyPass(key)
			end
		end)
		order += 1
	end
end

-- Améliorations du salon ------------------------------------------
local upWin, upContent = Ui.Window(gui, "⬆️ Mon Salon", C.Pink)
windows.upgrades = upWin
local upScroll = Ui.Scroll(upContent)
local function buildUpgrades()
	if not state then
		return
	end
	for _, c in upScroll:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	sectionTitle(upScroll, 0, "🏠 Améliorations")
	local order = 1
	for _, key in { "chairs", "stylists", "deco", "pub" } do
		local def = Config.Upgrades[key]
		local level = state.Upgrades[key]
		local cost = def.Costs[level + 1]
		local desc = def.Desc .. "  •  niveau " .. level
		local canBuy = cost ~= nil and state.Cash >= cost
		rowCard(upScroll, order, def.Icon, def.Name, desc, cost and Util.Money(cost) or "MAX", canBuy and C.Green or C.Card, function()
			if cost and call("Buy", "upgrade", key) then
				sound(PING, 0.5, 1.2)
			end
		end)
		order += 1
	end
	sectionTitle(upScroll, 10, "✂️ Coupes (les clients les demanderont)")
	order = 11
	for _, s in Config.Styles do
		local owned = state.Styles[s.Id] or (s.Pass and state.Passes[s.Pass])
		local text, color
		if owned then
			text, color = "✅ Débloqué", C.Card
		elseif s.Pass then
			text, color = "💎 Pass", C.Gold
		else
			text, color = Util.Money(s.Cost), state.Cash >= s.Cost and C.Green or C.Card
		end
		rowCard(upScroll, order, s.Icon, s.Name, "Valeur x" .. s.Value, text, color, function()
			if owned then
				return
			end
			if s.Pass then
				buyPass(s.Pass)
			else
				call("Buy", "style", s.Id)
			end
		end)
		order += 1
	end
	sectionTitle(upScroll, 30, "🎨 Teintures & accessoires")
	order = 31
	rowCard(upScroll, order, "🎨", "Teintures fantaisie", "Rose, bleu, lavande, menthe, platine (x1.6)", state.FantasyColors and "✅ Débloqué" or Util.Money(Config.FantasyColorsCost), state.FantasyColors and C.Card or C.Green, function()
		if not state.FantasyColors then
			call("Buy", "fantasy", "fantasy")
		end
	end)
	order += 1
	rowCard(upScroll, order, "🌈", "Teintures néon", "Néon, or pur, arc-en-ciel (x3)", state.Passes.neonColors and "✅ Possédé" or "💎 Pass", state.Passes.neonColors and C.Card or C.Gold, function()
		if not state.Passes.neonColors then
			buyPass("neonColors")
		end
	end)
	order += 1
	for _, a in Config.Accessories do
		if a.Id ~= "aucun" then
			local owned = state.Accs[a.Id] or (a.Pass and state.Passes[a.Pass])
			local text = owned and "✅ Débloqué" or (a.Pass and "💎 Pass" or Util.Money(a.Cost))
			rowCard(upScroll, order, a.Icon, a.Name, "Accessoire (+30% sur la coupe)", text, owned and C.Card or (a.Pass and C.Gold or C.Green), function()
				if owned then
					return
				end
				if a.Pass then
					buyPass(a.Pass)
				else
					call("Buy", "acc", a.Id)
				end
			end)
			order += 1
		end
	end
end

-- Franchise (renaissance) -----------------------------------------
local rbWin, rbContent = Ui.Window(gui, "🏆 Franchise", Color3.fromRGB(190, 120, 255))
windows.rebirth = rbWin
local rbText = Ui.Label({ Parent = rbContent, Size = UDim2.new(1, 0, 0.42, 0), Font = Enum.Font.GothamBold, Text = "" })
local rbBarBg = Ui.Frame({ Parent = rbContent, Position = UDim2.fromScale(0.08, 0.5), Size = UDim2.fromScale(0.84, 0.08), BackgroundColor3 = C.Bg2 })
Ui.Corner(rbBarBg, 20)
local rbBar = Ui.Frame({ Parent = rbBarBg, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(190, 120, 255) })
Ui.Corner(rbBar, 20)
local rbBtn = Ui.Button({ Parent = rbContent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromScale(0.5, 0.18), Text = "Ouvrir une franchise", BackgroundColor3 = Color3.fromRGB(190, 120, 255) }, function()
	if call("Rebirth") then
		confetti()
		rbWin.Visible = false
	end
end)
local function buildRebirth()
	if not state then
		return
	end
	local cost = Config.RebirthCost(state.Rebirths)
	local nextBonus = (state.Rebirths + 1) * Config.RebirthBonus * 100
	rbText.Text = string.format(
		"Franchises : %d  (bonus actuel +%d%%)\n\nRepars de zéro avec un salon tout neuf mais <font color='#FFC846'>+%d%% d'argent pour toujours</font>.\nTes coupes débloquées sont conservées.\n\nPrix : %s",
		state.Rebirths,
		state.Rebirths * Config.RebirthBonus * 100,
		nextBonus,
		Util.Money(cost)
	)
	rbBar.Size = UDim2.fromScale(math.clamp(state.Cash / cost, 0, 1), 1)
	rbBtn.BackgroundColor3 = state.Cash >= cost and Color3.fromRGB(190, 120, 255) or C.Card
end

-- Cadeaux de temps de jeu -----------------------------------------
local giftWin, giftContent = Ui.Window(gui, "🎁 Cadeaux", C.Green)
windows.gifts = giftWin
local giftScroll = Ui.Scroll(giftContent)
local giftButtons = {}
for i, g in Config.PlaytimeGifts do
	local _, btn = rowCard(giftScroll, i, "🎁", g.Name, "Après " .. g.Minutes .. " min de jeu", "...", C.Card, function()
		if call("Gift", i) then
			confetti()
		end
	end)
	giftButtons[i] = btn
end
local function giftReady(i: number): (boolean, number)
	if not state then
		return false, 0
	end
	local elapsed = (state.ServerNow - state.JoinTime) + (os.clock() - stateReceivedAt)
	local left = Config.PlaytimeGifts[i].Minutes * 60 - elapsed
	return left <= 0 and not state.Gifts[i], left
end

-- Bonus quotidien -------------------------------------------------
local dailyWin, dailyContent = Ui.Window(gui, "📅 Bonus quotidien", C.Blue)
windows.daily = dailyWin
local dailyGrid = Ui.Frame({ Parent = dailyContent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.7) })
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.13, 0, 0.9, 0)
grid.CellPadding = UDim2.new(0.012, 0, 0, 0)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.VerticalAlignment = Enum.VerticalAlignment.Center
grid.Parent = dailyGrid
local dayTiles = {}
for d = 1, #Config.DailyRewards do
	local tile = Ui.Frame({ Parent = dailyGrid, BackgroundColor3 = C.Card })
	Ui.Corner(tile, 14)
	Ui.Stroke(tile, C.Blue, 2)
	Ui.Label({ Parent = tile, Text = "Jour " .. d, Size = UDim2.fromScale(1, 0.25), Position = UDim2.fromScale(0, 0.05) })
	Ui.Label({ Parent = tile, Text = d == 7 and "💎" or "💰", Size = UDim2.fromScale(1, 0.35), Position = UDim2.fromScale(0, 0.32), NoStroke = true })
	Ui.Label({ Parent = tile, Text = "x" .. Config.DailyRewards[d], Size = UDim2.fromScale(1, 0.22), Position = UDim2.fromScale(0, 0.72), TextColor3 = C.Gold })
	dayTiles[d] = tile
end
local dailyBtn = Ui.Button({ Parent = dailyContent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(0.45, 0.2), Text = "Récupérer", BackgroundColor3 = C.Green }, function()
	call("Daily")
end)
local function dailyReady(): boolean
	if not state then
		return false
	end
	local now = state.ServerNow + (os.clock() - stateReceivedAt)
	return state.Daily.Last == 0 or (now // 86400) > (state.Daily.Last // 86400)
end
local function buildDaily()
	if not state then
		return
	end
	local ready = dailyReady()
	local nextDay = ready and (((state.Daily.Last > 0 and (state.ServerNow // 86400) - (state.Daily.Last // 86400) == 1) and state.Daily.Streak % 7 + 1) or 1) or state.Daily.Streak
	for d, tile in dayTiles do
		tile.BackgroundColor3 = d == nextDay and (ready and C.Green or C.Bg2) or (d < nextDay and C.Bg2 or C.Card)
	end
	dailyBtn.Text = ready and "Récupérer" or "Reviens demain ⏳"
	dailyBtn.BackgroundColor3 = ready and C.Green or C.Card
end

-- Codes -----------------------------------------------------------
local codeWin, codeContent = Ui.Window(gui, "🎟️ Codes", C.Pink)
windows.codes = codeWin
Ui.Label({ Parent = codeContent, Text = "Rejoins le groupe et suis les mises à jour pour de nouveaux codes !", Size = UDim2.new(1, 0, 0.2, 0), Font = Enum.Font.GothamBold })
local codeBox = Instance.new("TextBox")
codeBox.PlaceholderText = "Entre un code…"
codeBox.Text = ""
codeBox.Font = Enum.Font.FredokaOne
codeBox.TextScaled = true
codeBox.TextColor3 = C.Text
codeBox.BackgroundColor3 = C.Bg2
codeBox.AnchorPoint = Vector2.new(0.5, 0)
codeBox.Position = UDim2.fromScale(0.5, 0.3)
codeBox.Size = UDim2.fromScale(0.7, 0.2)
codeBox.ClearTextOnFocus = false
codeBox.Parent = codeContent
Ui.Corner(codeBox, 14)
Ui.Stroke(codeBox, C.Pink, 2)
Ui.Button({ Parent = codeContent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(0.4, 0.2), Text = "Valider", BackgroundColor3 = C.Green }, function()
	if call("Code", codeBox.Text) then
		codeBox.Text = ""
		confetti()
	end
end)

---------------------------------------------------------------------
-- Barre de boutons (gauche)
---------------------------------------------------------------------
local sideBar = Ui.Frame({ Parent = hud, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(84, 560) })
local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 8)
sideLayout.VerticalAlignment = Enum.VerticalAlignment.Center
sideLayout.Parent = sideBar
local sideScale = Instance.new("UIScale")
sideScale.Parent = sideBar

local badges = {}
local function sideButton(icon: string, label: string, color: Color3, onClick: () -> ())
	local b = Ui.Button({ Parent = sideBar, Size = UDim2.fromOffset(80, 66), Text = "", BackgroundColor3 = color }, onClick)
	Ui.Gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	Ui.Label({ Parent = b, Text = icon, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 4), NoStroke = true })
	Ui.Label({ Parent = b, Text = label, Size = UDim2.new(1, -6, 0, 20), Position = UDim2.fromOffset(3, 40) })
	local badge = Ui.Frame({ Parent = b, Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -14, 0, -4), BackgroundColor3 = C.Red, Visible = false })
	Ui.Corner(badge, 9)
	badges[label] = badge
	return b
end
sideButton("🛒", "Boutique", C.Gold, function()
	openWindow("shop")
end)
sideButton("⬆️", "Salon", C.Pink, function()
	openWindow("upgrades")
end)
sideButton("🏆", "Franchise", Color3.fromRGB(190, 120, 255), function()
	openWindow("rebirth")
end)
sideButton("🎁", "Cadeaux", C.Green, function()
	openWindow("gifts")
end)
sideButton("📅", "Bonus", C.Blue, function()
	openWindow("daily")
end)
sideButton("🎟️", "Codes", Color3.fromRGB(255, 140, 90), function()
	openWindow("codes")
end)
sideButton("🏠", "Mon salon", Color3.fromRGB(120, 200, 200), function()
	call("GoHome")
end)
sideButton("👥", "Inviter", Color3.fromRGB(100, 150, 255), function()
	pcall(function()
		SocialService:PromptGameInvite(player)
	end)
end)

local function adaptScale()
	local h = camera.ViewportSize.Y
	sideScale.Scale = math.clamp(h / 760, 0.62, 1.1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(adaptScale)
adaptScale()

table.insert(refreshers, function()
	if shopWin.Visible then
		buildShop()
	end
	if upWin.Visible then
		buildUpgrades()
	end
	buildRebirth()
	buildDaily()
	badges["Bonus"].Visible = dailyReady()
	badges["Franchise"].Visible = state.Cash >= Config.RebirthCost(state.Rebirths)
end)

-- Mise à jour des timers des cadeaux
task.spawn(function()
	while true do
		task.wait(1)
		if state then
			local any = false
			for i, btn in giftButtons do
				local ready, left = giftReady(i)
				if state.Gifts[i] then
					btn.Text = "✅ Reçu"
					btn.BackgroundColor3 = C.Card
				elseif ready then
					btn.Text = "Ouvrir !"
					btn.BackgroundColor3 = C.Green
					any = true
				else
					btn.Text = "⏳ " .. Util.Time(left)
					btn.BackgroundColor3 = C.Card
				end
			end
			badges["Cadeaux"].Visible = any
		end
	end
end)

---------------------------------------------------------------------
-- Atelier de coiffure (session)
---------------------------------------------------------------------
local studio = Ui.Frame({ Parent = gui, Name = "Studio", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(0.96, 0, 0.4, 0), BackgroundColor3 = C.Bg, Visible = false, ZIndex = 30 })
Ui.Corner(studio, 22)
Ui.Stroke(studio, C.Pink, 3)
Ui.Gradient(studio, Color3.fromRGB(64, 38, 96), Color3.fromRGB(26, 16, 40))
local studioMax = Instance.new("UISizeConstraint")
studioMax.MaxSize = Vector2.new(1100, 360)
studioMax.Parent = studio

local requestCard = Ui.Frame({ Parent = studio, Position = UDim2.fromOffset(14, 14), Size = UDim2.new(0.28, -14, 1, -28), BackgroundColor3 = C.Card })
Ui.Corner(requestCard, 16)
local requestTitle = Ui.Label({ Parent = requestCard, Text = "💬 Demande", Size = UDim2.new(1, -16, 0.18, 0), Position = UDim2.fromOffset(8, 6), TextColor3 = C.Pink2 })
local requestText = Ui.Label({ Parent = requestCard, Text = "", Size = UDim2.new(1, -16, 0.42, 0), Position = UDim2.new(0, 8, 0.2, 0), Font = Enum.Font.GothamBold })
local scoreText = Ui.Label({ Parent = requestCard, Text = "", Size = UDim2.new(1, -16, 0.18, 0), Position = UDim2.new(0, 8, 0.62, 0), TextColor3 = C.Gold })
local rotateLeft = Ui.Button({ Parent = requestCard, Text = "⟲", Size = UDim2.new(0.3, 0, 0.16, 0), Position = UDim2.new(0.05, 0, 0.82, 0), BackgroundColor3 = C.Bg2 })
local rotateRight = Ui.Button({ Parent = requestCard, Text = "⟳", Size = UDim2.new(0.3, 0, 0.16, 0), Position = UDim2.new(0.65, 0, 0.82, 0), BackgroundColor3 = C.Bg2 })

local tabsBar = Ui.Frame({ Parent = studio, BackgroundTransparency = 1, Position = UDim2.new(0.28, 14, 0, 14), Size = UDim2.new(0.52, -14, 0, 44) })
local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding = UDim.new(0, 8)
tabsLayout.Parent = tabsBar

local optionsFrame = Ui.Frame({ Parent = studio, BackgroundTransparency = 1, Position = UDim2.new(0.28, 14, 0, 66), Size = UDim2.new(0.52, -14, 1, -80) })
local optionsScroll = Instance.new("ScrollingFrame")
optionsScroll.BackgroundTransparency = 1
optionsScroll.BorderSizePixel = 0
optionsScroll.Size = UDim2.fromScale(1, 1)
optionsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
optionsScroll.CanvasSize = UDim2.new()
optionsScroll.ScrollBarThickness = 6
optionsScroll.Parent = optionsFrame
local optGrid = Instance.new("UIGridLayout")
optGrid.CellSize = UDim2.fromOffset(104, 92)
optGrid.CellPadding = UDim2.fromOffset(8, 8)
optGrid.SortOrder = Enum.SortOrder.LayoutOrder
optGrid.Parent = optionsScroll

local actionCol = Ui.Frame({ Parent = studio, BackgroundTransparency = 1, Position = UDim2.new(0.8, 14, 0, 14), Size = UDim2.new(0.2, -28, 1, -28) })
local finishBtn = Ui.Button({ Parent = actionCol, Text = "✅ Terminer", Size = UDim2.fromScale(1, 0.55), BackgroundColor3 = C.Green })
local cancelBtn = Ui.Button({ Parent = actionCol, Text = "✖ Annuler", Size = UDim2.fromScale(1, 0.35), Position = UDim2.fromScale(0, 0.65), BackgroundColor3 = C.Red })

local currentTab = "style"
local camAngle = 0

local function isUnlocked(kind: string, id: any): (boolean, string?)
	if not state then
		return false
	end
	if kind == "style" then
		local s = Config.StyleById[id]
		if state.Styles[id] then
			return true
		end
		if s.Pass then
			return state.Passes[s.Pass] == true, "pass:" .. s.Pass
		end
		return false, "money"
	elseif kind == "color" then
		local c = Config.ColorById[id]
		if c.Tier == "base" then
			return true
		elseif c.Tier == "fantasy" then
			return state.FantasyColors, "money"
		else
			return state.Passes.neonColors == true, "pass:neonColors"
		end
	elseif kind == "acc" then
		local a = Config.AccById[id]
		if state.Accs[id] then
			return true
		end
		if a.Pass then
			return state.Passes[a.Pass] == true, "pass:" .. a.Pass
		end
		return false, "money"
	end
	return true
end

local function updateScore()
	if not session then
		return
	end
	if session.Request then
		local score = HairBuilder.Score(session.Request, session.Look)
		local pct = math.floor(score * 100 + 0.5)
		scoreText.Text = (pct == 100 and "✨ " or "") .. "Ressemblance : " .. pct .. "%"
		scoreText.TextColor3 = pct == 100 and C.Gold or (pct >= 60 and C.Green or C.Red)
	else
		scoreText.Text = "Choisis ton style !"
		scoreText.TextColor3 = C.Gold
	end
end

local buildOptions

local function choose(field: string, value: any)
	local ok, unlockReason = isUnlocked(field, value)
	if not ok then
		if unlockReason and unlockReason:sub(1, 5) == "pass:" then
			buyPass(unlockReason:sub(6))
		else
			toast("🔒 Débloque-le dans ⬆️ Salon", "error")
		end
		return
	end
	if call("Apply", field, value) then
		session.Look[field] = value
		sound(PING, 0.25, 1.6)
		updateScore()
		buildOptions()
	end
end

function buildOptions()
	for _, c in optionsScroll:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local function option(order: number, icon: string, name: string, selected: boolean, wanted: boolean, locked: string?, color: Color3?, onClick: () -> ())
		local b = Ui.Button({ Parent = optionsScroll, LayoutOrder = order, Text = "", BackgroundColor3 = selected and C.Pink or C.Card }, onClick)
		if wanted then
			Ui.Stroke(b, C.Gold, 3)
		end
		if color then
			local sw = Ui.Frame({ Parent = b, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = color })
			Ui.Corner(sw, 22)
			Ui.Stroke(sw, Color3.new(1, 1, 1), 2)
		else
			Ui.Label({ Parent = b, Text = icon, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 6), NoStroke = true })
		end
		Ui.Label({ Parent = b, Text = name, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.new(0, 4, 1, -32) })
		if locked then
			local lock = Ui.Frame({ Parent = b, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45 })
			Ui.Corner(lock, 12)
			Ui.Label({ Parent = lock, Text = locked, Size = UDim2.fromScale(0.8, 0.4), Position = UDim2.fromScale(0.1, 0.25), NoStroke = true })
		end
	end
	local look, req = session.Look, session.Request
	if currentTab == "style" then
		for i, s in Config.Styles do
			local ok, why = isUnlocked("style", s.Id)
			option(i, s.Icon, s.Name, look.style == s.Id, req ~= nil and req.style == s.Id, (not ok) and (why == "money" and "🔒" or "💎") or nil, nil, function()
				choose("style", s.Id)
			end)
		end
	elseif currentTab == "length" then
		for i, l in Config.Lengths do
			option(i, ({ "✂️", "💇", "👸" })[i], l.Name, look.length == l.Id, req ~= nil and req.length == l.Id, nil, nil, function()
				choose("length", l.Id)
			end)
		end
	elseif currentTab == "color" then
		for i, c in Config.Colors do
			local ok, why = isUnlocked("color", c.Id)
			option(i, "", c.Name, look.color == c.Id, req ~= nil and req.color == c.Id, (not ok) and (why == "money" and "🔒" or "💎") or nil, c.Color, function()
				choose("color", c.Id)
			end)
		end
	elseif currentTab == "acc" then
		for i, a in Config.Accessories do
			local ok, why = isUnlocked("acc", a.Id)
			option(i, a.Icon, a.Name, look.acc == a.Id, req ~= nil and req.acc == a.Id, (not ok) and (why == "money" and "🔒" or "💎") or nil, nil, function()
				choose("acc", a.Id)
			end)
		end
	end
end

local tabButtons = {}
for _, t in { { "style", "✂️ Coupe" }, { "length", "📏 Longueur" }, { "color", "🎨 Couleur" }, { "acc", "🎀 Accessoire" } } do
	tabButtons[t[1]] = Ui.Button({ Parent = tabsBar, Text = t[2], Size = UDim2.new(0.25, -6, 1, 0), BackgroundColor3 = C.Bg2 }, function()
		currentTab = t[1]
		for k, b in tabButtons do
			b.BackgroundColor3 = k == currentTab and C.Pink or C.Bg2
		end
		buildOptions()
	end)
end

local camConn: RBXScriptConnection? = nil
local function closeStudio()
	session = nil
	studio.Visible = false
	hud.Visible = true
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	camera.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
end

local function openStudio(data: any)
	session = {
		Kind = data.Kind,
		Target = data.Target,
		Request = data.Request,
		Look = HairBuilder.Normalize(data.Look),
	}
	for _, w in windows do
		w.Visible = false
	end
	hud.Visible = false
	studio.Visible = true
	Ui.Pop(studio)
	currentTab = "style"
	for k, b in tabButtons do
		b.BackgroundColor3 = k == currentTab and C.Pink or C.Bg2
	end
	if data.Request then
		requestTitle.Text = "💬 " .. (data.Name or "Client") .. " veut :"
		requestText.Text = HairBuilder.Describe(data.Request)
		finishBtn.Text = "✅ Terminer"
	else
		requestTitle.Text = data.Kind == "self" and "✨ Ton nouveau look" or ("💇 Coiffe " .. (data.Name or ""))
		requestText.Text = "Crée la coiffure de tes rêves ! Elle sera sauvegardée."
		finishBtn.Text = "✅ Valider"
	end
	updateScore()
	buildOptions()
	-- Caméra face au visage
	camAngle = 0
	camera.CameraType = Enum.CameraType.Scriptable
	camConn = RunService.RenderStepped:Connect(function()
		local target = session and session.Target
		local head = target and target:FindFirstChild("Head")
		if not head then
			return
		end
		local cf = head.CFrame * CFrame.Angles(0, math.rad(camAngle), 0)
		local eye = (cf * CFrame.new(0, 0.6, -6.5)).Position
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, head.Position + Vector3.new(0, -0.6, 0)), 0.15)
	end)
end

rotateLeft.Activated:Connect(function()
	camAngle -= 45
end)
rotateRight.Activated:Connect(function()
	camAngle += 45
end)
finishBtn.Activated:Connect(function()
	if session then
		call("Finish")
	end
end)
cancelBtn.Activated:Connect(function()
	if session then
		call("Cancel")
		closeStudio()
	end
end)

SessionEvent.OnClientEvent:Connect(function(data)
	if data.Open then
		openStudio(data)
	else
		closeStudio()
	end
end)

---------------------------------------------------------------------
-- Visibilité des ProximityPrompts (chacun ne voit que ce qui le concerne)
---------------------------------------------------------------------
local salonsFolder = Workspace:WaitForChild("Salons")
local prompts: { [ProximityPrompt]: boolean } = {}
local function track(d: Instance)
	if d:IsA("ProximityPrompt") then
		prompts[d] = true
	end
end
for _, d in salonsFolder:GetDescendants() do
	track(d)
end
salonsFolder.DescendantAdded:Connect(track)
salonsFolder.DescendantRemoving:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		prompts[d] = nil
	end
end)

local function salonOwner(inst: Instance): number
	local node = inst
	while node and node.Parent ~= salonsFolder do
		node = node.Parent
	end
	return node and (node:GetAttribute("OwnerId") or 0) or 0
end

local function updatePrompts()
	for p in prompts do
		local kind = p:GetAttribute("Kind")
		local owner = salonOwner(p)
		local chair = p.Parent and p.Parent.Parent and p.Parent.Parent.Parent
		local visible = false
		if session == nil then
			if kind == "mirror" then
				visible = true
			elseif kind == "upgrades" then
				visible = owner == player.UserId
			elseif kind == "style" and chair then
				visible = owner == player.UserId and chair:GetAttribute("Occupied") == true and chair:GetAttribute("Busy") ~= true
				if visible then
					local sitter = chair:GetAttribute("SitterName")
					p.ObjectText = (sitter and sitter ~= "") and sitter or "Client"
				end
			elseif kind == "sit" and chair then
				visible = owner ~= 0 and owner ~= player.UserId and chair:GetAttribute("Taken") ~= true
			end
		end
		if p.Enabled ~= visible then
			p.Enabled = visible
		end
	end
end
task.spawn(function()
	while true do
		updatePrompts()
		task.wait(0.25)
	end
end)

---------------------------------------------------------------------
-- Effets visuels : cheveux arc-en-ciel, projecteurs
---------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, p in CollectionService:GetTagged("RainbowHair") do
		if p:IsA("BasePart") then
			p.Color = Color3.fromHSV((t * 0.25 + p.Position.Y * 0.08) % 1, 0.75, 1)
		end
	end
end)

local beams: { [BasePart]: CFrame } = {}
task.spawn(function()
	while true do
		for _, d in salonsFolder:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Sweep") and not beams[d] then
				beams[d] = d.CFrame
			end
		end
		for part in beams do
			if not part.Parent then
				beams[part] = nil
			end
		end
		task.wait(3)
	end
end)
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for part, base in beams do
		local dir = part:GetAttribute("Sweep") or 1
		part.CFrame = base * CFrame.Angles(math.sin(t * 0.7 * dir) * 0.35, 0, math.cos(t * 0.5) * 0.15)
	end
end)

---------------------------------------------------------------------
-- Tag VIP dans le chat
---------------------------------------------------------------------
pcall(function()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		if not source then
			return nil
		end
		local p = Players:GetPlayerByUserId(source.UserId)
		if p and p:GetAttribute("Pass_vip") then
			local props = Instance.new("TextChatMessageProperties")
			props.PrefixText = "<font color='#FFC846'>[👑 VIP]</font> " .. message.PrefixText
			return props
		end
		return nil
	end
end)

---------------------------------------------------------------------
-- Messages du serveur
---------------------------------------------------------------------
local tutorialShown = false

NotifyEvent.OnClientEvent:Connect(function(msg)
	if msg.Type == "toast" then
		toast(msg.Text, msg.Kind)
	elseif msg.Type == "announce" then
		showAnnounce(msg.Text, msg.Color)
	elseif msg.Type == "pay" then
		payPopup(msg.Amount, msg.Perfect, msg.Streak)
		if session and session.Kind == "npc" then
			closeStudio()
		end
	elseif msg.Type == "celebrate" then
		confetti()
	elseif msg.Type == "open" then
		openWindow(msg.Panel)
	elseif msg.Type == "offline" then
		showAnnounce("💤 Tes stylistes ont gagné " .. Util.Money(msg.Amount) .. " pendant ton absence !", C.Green)
	elseif msg.Type == "welcome" then
		if msg.First and not tutorialShown then
			tutorialShown = true
			task.spawn(function()
				task.wait(2)
				toast("👋 Bienvenue dans ton salon de coiffure !", "success")
				task.wait(3)
				toast("💺 Des clients vont s'asseoir sur tes fauteuils.", "info")
				task.wait(3)
				toast("✂️ Approche-toi et appuie sur E pour les coiffer.", "info")
				task.wait(3)
				toast("⭐ Fais exactement ce qu'ils demandent = gros pourboire !", "money")
			end)
		end
		-- Offre de bienvenue (une fois par session, si pas déjà acheté)
		task.delay(60, function()
			if state and not state.StarterBought and Config.Products.starterPack.Id ~= 0 and not session then
				openWindow("shop")
			end
		end)
	end
end)

StateEvent.OnClientEvent:Connect(function(s)
	local first = state == nil
	state = s
	stateReceivedAt = os.clock()
	if first then
		displayedCash = s.Cash
	end
	refreshAll()
end)

-- Quand on finit la session côté joueur/self, le serveur ferme via SessionEvent.
