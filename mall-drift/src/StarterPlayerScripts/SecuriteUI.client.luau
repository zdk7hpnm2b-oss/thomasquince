--[[
	SecuriteUI  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : SecuriteUI

	Ce que le joueur voit quand la sécurité s'en mêle :
	  • « LA SÉCURITÉ T'A REPÉRÉ ! » + sirènes 🚨 (1 à 3 selon le nombre de gardes)
	  • les bords de l'écran clignotent en rouge et bleu pendant la poursuite
	  • « TU AS SEMÉ LA SÉCURITÉ ! +XP » quand tu leur échappes
	  • « LE GARDE A GLISSÉ ! 😂 » quand un garde tombe sur le sol mouillé
	  • « ATTRAPÉ ! » puis fondu au noir : retour au garage
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local joueur = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")

local gui = Instance.new("ScreenGui")
gui.Name = "SecuriteHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Parent = joueur:WaitForChild("PlayerGui")

-- Bords de l'écran qui clignotent (rouge / bleu, comme un gyrophare)
local bords = {}
for _, info in ipairs({
	{ UDim2.new(1, 0, 0, 26), UDim2.fromScale(0, 0) },
	{ UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 1, -26) },
	{ UDim2.new(0, 26, 1, 0), UDim2.fromScale(0, 0) },
	{ UDim2.new(0, 26, 1, 0), UDim2.new(1, -26, 0, 0) },
}) do
	local f = Instance.new("Frame")
	f.Size = info[1]
	f.Position = info[2]
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	f.BackgroundTransparency = 1
	f.Parent = gui
	table.insert(bords, f)
end

-- Barre d'alerte en haut au centre
local barre = Instance.new("TextLabel")
barre.AnchorPoint = Vector2.new(0.5, 0)
barre.Size = UDim2.new(0, 420, 0, 44)
barre.Position = UDim2.new(0.5, 0, 0, 52)
barre.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
barre.BackgroundTransparency = 0.25
barre.TextColor3 = Color3.fromRGB(255, 80, 80)
barre.Font = Enum.Font.GothamBlack
barre.TextScaled = true
barre.Visible = false
barre.Parent = gui
Instance.new("UICorner", barre).CornerRadius = UDim.new(0, 10)
local margeBarre = Instance.new("UIPadding")
margeBarre.PaddingTop = UDim.new(0, 6)
margeBarre.PaddingBottom = UDim.new(0, 6)
margeBarre.Parent = barre

-- Grand message au centre
local grandMessageActuel: TextLabel? = nil
local function grandMessage(texte: string, couleur: Color3, duree: number)
	if grandMessageActuel then
		grandMessageActuel:Destroy() -- (un seul grand message à la fois)
	end
	local l = Instance.new("TextLabel")
	grandMessageActuel = l
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.new(0.8, 0, 0, 70)
	l.Position = UDim2.fromScale(0.5, 0.42) -- (sous les messages de drift)
	l.BackgroundTransparency = 1
	l.TextColor3 = couleur
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = texte
	l.ZIndex = 5
	local contour = Instance.new("UIStroke")
	contour.Thickness = 3
	contour.Color = Color3.fromRGB(15, 15, 20)
	contour.Parent = l
	local echelle = Instance.new("UIScale")
	echelle.Scale = 0.3
	echelle.Parent = l
	l.Parent = gui
	TweenService:Create(echelle, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duree, function()
		TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(contour, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		task.wait(0.45)
		l:Destroy()
	end)
end

-- Écran noir (pour le retour au garage après une arrestation)
local noir = Instance.new("Frame")
noir.Size = UDim2.fromScale(1, 1)
noir.BackgroundColor3 = Color3.new(0, 0, 0)
noir.BackgroundTransparency = 1
noir.ZIndex = 10
noir.Parent = gui

local niveauAlerte = 0

local function afficherNiveau(niveau: number)
	niveauAlerte = niveau
	joueur:SetAttribute("Poursuivi", niveau > 0) -- (lu par le script de conduite : boost d'évasion)
	if niveau <= 0 then
		barre.Visible = false
		return
	end
	barre.Visible = true
	barre.Text = string.rep("🚨", niveau) .. string.rep("⚪", 3 - niveau) .. "  SÉCURITÉ À TES TROUSSES !"
end

-- Clignotement des bords pendant la poursuite
RunService.RenderStepped:Connect(function()
	if niveauAlerte <= 0 then
		for _, f in ipairs(bords) do
			f.BackgroundTransparency = 1
		end
		return
	end
	local t = os.clock()
	local rouge = math.floor(t * 4) % 2 == 0
	local force = 0.35 + 0.2 * math.sin(t * 12)
	for _, f in ipairs(bords) do
		f.BackgroundColor3 = if rouge then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(40, 90, 255)
		f.BackgroundTransparency = 1 - force * (0.5 + 0.25 * niveauAlerte)
	end
end)

remotes:WaitForChild("Alerte").OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	if info.etat == "repere" then
		afficherNiveau(info.niveau or 1)
		grandMessage("🚨 LA SÉCURITÉ T'A REPÉRÉ ! 🚨", Color3.fromRGB(255, 70, 70), 1.6)
	elseif info.etat == "niveau" then
		local avant = niveauAlerte
		afficherNiveau(info.niveau or 0)
		if (info.niveau or 0) > avant then
			grandMessage("RENFORTS EN APPROCHE !", Color3.fromRGB(255, 140, 60), 1.2)
		end
	elseif info.etat == "seme" then
		afficherNiveau(0)
		grandMessage(("TU AS SEMÉ LA SÉCURITÉ ! 😎  +%d XP"):format(info.bonus or 0), Color3.fromRGB(110, 255, 140), 2.2)
	elseif info.etat == "message" then
		grandMessage(tostring(info.texte or ""), Color3.fromRGB(110, 255, 140), 2.4)
	elseif info.etat == "glisse" then
		grandMessage(("LE GARDE A GLISSÉ ! 😂  +%d XP"):format(info.bonus or 0), Color3.fromRGB(120, 210, 255), 1.8)
	elseif info.etat == "attrape" then
		afficherNiveau(0)
		grandMessage("🚨 ATTRAPÉ ! 🚨", Color3.fromRGB(255, 60, 60), 1.6)
		task.delay(0.9, function()
			grandMessage("Le garde te raccompagne au garage...", Color3.new(1, 1, 1), 1.6)
		end)
		task.delay(1.6, function()
			TweenService:Create(noir, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
			task.wait(1.4)
			TweenService:Create(noir, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		end)
	end
end)
