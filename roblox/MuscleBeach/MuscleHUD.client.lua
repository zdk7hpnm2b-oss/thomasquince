--[[
	MUSCLE BEACH : affichage pour le joueur

	OÙ LE METTRE : StarterPlayer > StarterPlayerScripts > LocalScript, nommé « MuscleHUD ».

	CE QU'IL FAIT
	- Un compteur « FORCE » en haut de l'écran, qui rebondit à chaque gain.
	- Des « +X FORCE » qui s'envolent à chaque répétition.
	- Un message si l'appareil est trop lourd, et un message de bienvenue.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local joueur = Players.LocalPlayer
local evenement = ReplicatedStorage:WaitForChild("MuscleEvent")

local OR = Color3.fromRGB(255, 200, 40)
local ROUGE = Color3.fromRGB(255, 80, 80)
local CYAN = Color3.fromRGB(40, 230, 255)

local ecran = Instance.new("ScreenGui")
ecran.Name = "MuscleHUD"
ecran.ResetOnSpawn = false
ecran.IgnoreGuiInset = false
ecran.Parent = joueur:WaitForChild("PlayerGui")

-- Compteur de force
local compteur = Instance.new("TextLabel")
compteur.Name = "Compteur"
compteur.AnchorPoint = Vector2.new(0.5, 0)
compteur.Position = UDim2.new(0.5, 0, 0, 10)
compteur.Size = UDim2.fromOffset(260, 50)
compteur.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
compteur.BackgroundTransparency = 0.2
compteur.TextColor3 = OR
compteur.TextScaled = true
compteur.Font = Enum.Font.FredokaOne
compteur.Text = "FORCE : 0"
compteur.Parent = ecran

local coins = Instance.new("UICorner")
coins.CornerRadius = UDim.new(0, 12)
coins.Parent = compteur

local contour = Instance.new("UIStroke")
contour.Color = OR
contour.Thickness = 2
contour.Parent = compteur

local echelle = Instance.new("UIScale")
echelle.Parent = compteur

local function formater(n)
	-- 12345 -> "12 345"
	local s = tostring(math.floor(n))
	local resultat = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (resultat:gsub("^ ", ""))
end

local function rebond()
	echelle.Scale = 1.15
	TweenService:Create(echelle, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- Texte qui s'envole et disparaît
local function message(texte, couleur, taille, duree)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.15, 0.55)
	label.Size = UDim2.fromOffset(taille or 260, 50)
	label.BackgroundTransparency = 1
	label.TextColor3 = couleur
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = texte
	label.Parent = ecran

	local info = TweenInfo.new(duree or 1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, {
		Position = label.Position - UDim2.fromScale(0, 0.15),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(label, (duree or 1) + 0.1)
end

evenement.OnClientEvent:Connect(function(type, a, b)
	if type == "Gain" then
		compteur.Text = "FORCE : " .. formater(b)
		rebond()
		message("+" .. a .. " FORCE", OR)
	elseif type == "TropLourd" then
		message("Trop lourd ! Il faut " .. formater(a) .. " de force", ROUGE, 420, 1.6)
	elseif type == "Init" then
		compteur.Text = "FORCE : " .. formater(a)
		if b and b > 0 then
			message("Tes muscles ont fondu de " .. formater(b) .. " pendant ton absence !", ROUGE, 520, 3)
		else
			message("Bienvenue à Muscle Beach !", CYAN, 420, 2.5)
		end
	end
end)
