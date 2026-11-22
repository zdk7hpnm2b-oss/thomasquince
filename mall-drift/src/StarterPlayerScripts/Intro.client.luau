--[[
	Intro  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : Intro

	La petite séquence d'ouverture (environ 6 secondes) quand on rejoint le jeu :
	  1. fondu depuis le noir, bandes « cinéma » en haut et en bas
	  2. la caméra tourne autour de la fontaine du Golden Mall
	  3. elle survole le parking jusqu'au Garage VIP
	  4. le titre du jeu apparaît, puis on rend la main au joueur
	Un bouton « Passer » permet de la sauter.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local controles = require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local SOL = 1
local DUREE_FONTAINE = 2.8 -- secondes autour de la fontaine
local DUREE_SURVOL = 3.2 -- secondes pour aller du mall au garage

---------------------------------------------------------------------
-- L'écran de l'intro
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "IntroGoldenMall"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Parent = joueur:WaitForChild("PlayerGui")

local noir = Instance.new("Frame")
noir.Size = UDim2.fromScale(1, 1)
noir.BackgroundColor3 = Color3.new(0, 0, 0)
noir.ZIndex = 1
noir.Parent = gui

local function bande(position: UDim2): Frame
	local b = Instance.new("Frame")
	b.Size = UDim2.new(1, 0, 0.11, 0)
	b.Position = position
	b.BackgroundColor3 = Color3.new(0, 0, 0)
	b.BorderSizePixel = 0
	b.ZIndex = 2
	b.Parent = gui
	return b
end
local bandeHaut = bande(UDim2.fromScale(0, 0))
local bandeBas = bande(UDim2.fromScale(0, 0.89))

local function texte(taille: UDim2, position: UDim2, couleur: Color3, police: Enum.Font): TextLabel
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Size = taille
	t.Position = position
	t.BackgroundTransparency = 1
	t.TextColor3 = couleur
	t.Font = police
	t.TextScaled = true
	t.TextTransparency = 1
	t.ZIndex = 3
	local contour = Instance.new("UIStroke")
	contour.Thickness = 3
	contour.Color = Color3.fromRGB(20, 15, 5)
	contour.Transparency = 1
	contour.Parent = t
	t.Parent = gui
	return t
end

local titre = texte(UDim2.fromScale(0.8, 0.13), UDim2.fromScale(0.5, 0.44), Color3.fromRGB(255, 205, 70), Enum.Font.GothamBlack)
titre.Text = string.upper(Config.NomDuJeu)
local echelleTitre = Instance.new("UIScale")
echelleTitre.Scale = 0.6
echelleTitre.Parent = titre
local degrade = Instance.new("UIGradient")
degrade.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 170)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 170)),
})
degrade.Rotation = 90
degrade.Parent = titre

local sousTitre = texte(UDim2.fromScale(0.5, 0.05), UDim2.fromScale(0.5, 0.54), Color3.new(1, 1, 1), Enum.Font.GothamBold)
sousTitre.Text = "✦  " .. Config.Lieu .. "  ✦"
local slogan = texte(UDim2.fromScale(0.6, 0.04), UDim2.fromScale(0.5, 0.95), Color3.fromRGB(220, 220, 230), Enum.Font.GothamMedium)
slogan.Text = "Drifte. Personnalise. Deviens une légende."
slogan.ZIndex = 4

local boutonPasser = Instance.new("TextButton")
boutonPasser.AnchorPoint = Vector2.new(1, 0)
boutonPasser.Size = UDim2.new(0, 130, 0, 40)
boutonPasser.Position = UDim2.new(1, -20, 0, 14)
boutonPasser.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
boutonPasser.BackgroundTransparency = 0.2
boutonPasser.TextColor3 = Color3.new(1, 1, 1)
boutonPasser.Font = Enum.Font.GothamBold
boutonPasser.TextScaled = true
boutonPasser.Text = "Passer ▶"
boutonPasser.ZIndex = 5
boutonPasser.Parent = gui
Instance.new("UICorner", boutonPasser).CornerRadius = UDim.new(0, 10)
local margePasser = Instance.new("UIPadding")
margePasser.PaddingTop = UDim.new(0, 8)
margePasser.PaddingBottom = UDim.new(0, 8)
margePasser.Parent = boutonPasser

local function apparaitre(t: TextLabel, duree: number)
	TweenService:Create(t, TweenInfo.new(duree), { TextTransparency = 0 }):Play()
	local c = t:FindFirstChildOfClass("UIStroke")
	if c then
		TweenService:Create(c, TweenInfo.new(duree), { Transparency = 0 }):Play()
	end
end

local function disparaitre(t: TextLabel, duree: number)
	TweenService:Create(t, TweenInfo.new(duree), { TextTransparency = 1 }):Play()
	local c = t:FindFirstChildOfClass("UIStroke")
	if c then
		TweenService:Create(c, TweenInfo.new(duree), { Transparency = 1 }):Play()
	end
end

---------------------------------------------------------------------
-- La séquence
---------------------------------------------------------------------
local termine = false

local function finir()
	if termine then
		return
	end
	termine = true
	RunService:UnbindFromRenderStep("IntroCamera")
	-- Les bandes « cinéma » s'écartent, tout s'efface
	TweenService:Create(bandeHaut, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, -0.12) }):Play()
	TweenService:Create(bandeBas, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0, 1.01) }):Play()
	TweenService:Create(noir, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	for _, t in ipairs({ titre, sousTitre, slogan }) do
		disparaitre(t, 0.5)
	end
	boutonPasser.Visible = false
	camera.CameraType = Enum.CameraType.Custom
	controles:Enable()
	joueur:SetAttribute("IntroFinie", true)
	task.delay(0.8, function()
		gui:Destroy()
	end)
end
boutonPasser.Activated:Connect(finir)

-- Sécurité : quoi qu'il arrive, l'intro se termine au bout de 12 secondes
task.delay(12, function()
	finir()
end)

local function sequence()
	-- L'intro ne se joue qu'en arrivant au lobby (pas dans les places de jeu,
	-- ni quand on revient au lobby après une partie)
	local TYPE = Config.TypeDePlace()
	local donneesVoyage = game:GetService("TeleportService"):GetLocalPlayerTeleportData()
	local retour = type(donneesVoyage) == "table" and donneesVoyage.ouvrirMenu == true
	if (TYPE ~= "Lobby" and TYPE ~= "ToutEnUn") or retour then
		finir()
		return
	end
	-- On attend le personnage et la carte
	local perso = joueur.Character or joueur.CharacterAdded:Wait()
	local racine = perso:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local carte = workspace:WaitForChild("GoldenMall", 15)
	if termine then
		return
	end
	if not carte or not racine then
		finir()
		return
	end
	controles:Disable()
	-- Charge le décor autour de la fontaine (utile si le "streaming" est activé)
	pcall(function()
		joueur:RequestStreamAroundAsync(Vector3.new(0, SOL, 0))
		joueur:RequestStreamAroundAsync(Vector3.new(0, SOL, 250))
	end)

	camera.CameraType = Enum.CameraType.Scriptable
	local debut = os.clock()
	local garage = carte:FindFirstChild("GarageVIP")
	local porteGarage = if garage then (garage:GetPivot().Position) else racine.Position
	-- On termine dehors, face à l'entrée du garage (on voit l'enseigne et l'intérieur)
	local finSurvol = Vector3.new(racine.Position.X * 0.3, SOL + 9, porteGarage.Z - 68)

	RunService:BindToRenderStep("IntroCamera", Enum.RenderPriority.Camera.Value + 2, function()
		local okImage = pcall(function()
		local t = os.clock() - debut
		if t < DUREE_FONTAINE then
			-- 1) On tourne autour de la fontaine, sous le plafond
			local a = t / DUREE_FONTAINE
			local angle = math.rad(-40 + 110 * a)
			local rayon = 44 - 8 * a
			local pos = Vector3.new(math.cos(angle) * rayon, SOL + 9 + 3 * a, math.sin(angle) * rayon)
			camera.CFrame = CFrame.lookAt(pos, Vector3.new(0, SOL + 6, 0))
		elseif t < DUREE_FONTAINE + DUREE_SURVOL then
			-- 2) On sort par l'entrée et on survole le parking jusqu'au garage
			local a = (t - DUREE_FONTAINE) / DUREE_SURVOL
			local doux = a * a * (3 - 2 * a)
			local depart = Vector3.new(0, SOL + 14, 120)
			local milieu = Vector3.new(0, SOL + 40, 200)
			local p1 = depart:Lerp(milieu, doux)
			local p2 = milieu:Lerp(finSurvol, doux)
			local pos = p1:Lerp(p2, doux)
			local regard = Vector3.new(0, SOL + 8, 175):Lerp(porteGarage + Vector3.new(0, 4, 0), doux)
			camera.CFrame = CFrame.lookAt(pos, regard)
		else
			finir()
		end
		end)
		if not okImage then
			finir() -- en cas de souci, on rend la main tout de suite
		end
	end)

	-- Les textes
	TweenService:Create(noir, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()
	task.wait(0.6)
	apparaitre(titre, 0.6)
	TweenService:Create(echelleTitre, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.wait(0.4)
	apparaitre(sousTitre, 0.5)
	task.wait(0.3)
	apparaitre(slogan, 0.5)
	task.wait(DUREE_FONTAINE - 0.2)
	if not termine then
		disparaitre(titre, 0.6)
		disparaitre(sousTitre, 0.6)
	end
end

task.spawn(function()
	local ok, erreur = pcall(sequence)
	if not ok then
		warn("[Intro] " .. tostring(erreur))
		finir()
	end
end)
