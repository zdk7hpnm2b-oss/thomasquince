--[[
	Tutoriel  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : Tutoriel

	Remplace l'ancienne cinématique d'ouverture. À la TOUTE PREMIÈRE partie, un
	tuto interactif explique comment conduire et comment marche le jeu :
	  1. Bienvenue            5. Étoiles et boost       9. Garage, pièces, menu
	  2. Accélérer / freiner  6. Sol mouillé
	  3. Tourner              7. La police du mall
	  4. Drifter              8. Les touches utiles
	Pour les étapes de conduite, il faut vraiment appuyer sur les touches (la
	touche s'allume et la barre se remplit). Sur téléphone, « SUIVANT » suffit.
	Pendant le tuto, la caméra survole le mall en arrière-plan.

	Le serveur retient que le tuto a été vu (il ne revient pas à chaque fois).
	On peut le revoir depuis le menu : bouton « 📖 TUTO ».
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local controles = require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local SOL = 1
local K = Enum.KeyCode
local TACTILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local ROUGE = Color3.fromRGB(225, 30, 45)
local FOND = Color3.fromRGB(17, 17, 21)
local CASE = Color3.fromRGB(34, 34, 40)
local OR = Color3.fromRGB(255, 205, 80)
local VERT = Color3.fromRGB(80, 230, 120)

---------------------------------------------------------------------
-- Lecture des commandes (clavier + manette)
---------------------------------------------------------------------
local function manette(): (number, number, boolean)
	local x, y, drift = 0, 0, false
	for _, etat in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		if etat.KeyCode == K.Thumbstick1 then
			x, y = etat.Position.X, etat.Position.Y
		elseif etat.KeyCode == K.ButtonR2 and etat.Position.Z > 0.3 then
			y = math.max(y, etat.Position.Z)
		elseif (etat.KeyCode == K.ButtonL2) and etat.Position.Z > 0.3 then
			drift = true
		end
	end
	return x, y, drift
end

local function enfoncee(touches: { Enum.KeyCode }): boolean
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	for _, t in ipairs(touches) do
		if UserInputService:IsKeyDown(t) then
			return true
		end
	end
	return false
end

local AVANCER = { K.W, K.Z, K.Up }
local RECULER = { K.S, K.Down }
local GAUCHE = { K.A, K.Q, K.Left }
local DROITE = { K.D, K.Right }
local DRIFT = { K.LeftShift, K.RightShift }

local function avance(): boolean
	local _, y = manette()
	return enfoncee(AVANCER) or y > 0.5
end
local function gauche(): boolean
	local x = manette()
	return enfoncee(GAUCHE) or x < -0.5
end
local function droite(): boolean
	local x = manette()
	return enfoncee(DROITE) or x > 0.5
end
local function drifte(): boolean
	local _, _, d = manette()
	return (enfoncee(DRIFT) or d) and (gauche() or droite())
end

---------------------------------------------------------------------
-- L'écran du tuto
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "TutoGoldenMall"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.Enabled = false
gui.Parent = joueur:WaitForChild("PlayerGui")

local voile = Instance.new("Frame") -- assombrit un peu le mall derrière
voile.Size = UDim2.fromScale(1, 1)
voile.BackgroundColor3 = Color3.new(0, 0, 0)
voile.BackgroundTransparency = 0.45
voile.BorderSizePixel = 0
voile.Parent = gui

local function coins(o: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end

local function texte(parent: Instance, taille: UDim2, position: UDim2, couleur: Color3, police: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = taille
	t.Position = position
	t.BackgroundTransparency = 1
	t.TextColor3 = couleur
	t.Font = police or Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = ""
	t.Parent = parent
	return t
end

local carte = Instance.new("Frame")
carte.AnchorPoint = Vector2.new(0.5, 0.5)
carte.Size = UDim2.new(0.62, 0, 0.7, 0)
carte.Position = UDim2.fromScale(0.5, 0.52)
carte.BackgroundColor3 = FOND
carte.BackgroundTransparency = 0.04
carte.ClipsDescendants = true
carte.Parent = gui
coins(carte, 10)
local tailleCarte = Instance.new("UISizeConstraint")
tailleCarte.MinSize = Vector2.new(340, 360)
tailleCarte.MaxSize = Vector2.new(760, 560)
tailleCarte.Parent = carte
local echelleCarte = Instance.new("UIScale")
echelleCarte.Parent = carte

local lisere = Instance.new("Frame")
lisere.Size = UDim2.new(1, 0, 0, 5)
lisere.BackgroundColor3 = ROUGE
lisere.BorderSizePixel = 0
lisere.Parent = carte

local etape = texte(carte, UDim2.new(0.5, 0, 0, 18), UDim2.new(0, 22, 0, 18), Color3.fromRGB(170, 170, 180), Enum.Font.GothamBold)
etape.TextXAlignment = Enum.TextXAlignment.Left

-- Les points de progression (un par étape)
local points = Instance.new("Frame")
points.AnchorPoint = Vector2.new(1, 0)
points.Size = UDim2.new(0.45, 0, 0, 10)
points.Position = UDim2.new(1, -22, 0, 22)
points.BackgroundTransparency = 1
points.Parent = carte
local dispoPoints = Instance.new("UIListLayout")
dispoPoints.FillDirection = Enum.FillDirection.Horizontal
dispoPoints.HorizontalAlignment = Enum.HorizontalAlignment.Right
dispoPoints.Padding = UDim.new(0, 6)
dispoPoints.Parent = points

local icone = texte(carte, UDim2.new(0, 84, 0, 84), UDim2.new(0, 22, 0, 52), Color3.new(1, 1, 1))
local echelleIcone = Instance.new("UIScale")
echelleIcone.Parent = icone
local titre = texte(carte, UDim2.new(1, -140, 0, 44), UDim2.new(0, 118, 0, 58), Color3.new(1, 1, 1))
titre.Font = Enum.Font.Oswald
titre.TextXAlignment = Enum.TextXAlignment.Left
local explication = texte(carte, UDim2.new(1, -140, 0, 44), UDim2.new(0, 118, 0, 102), Color3.fromRGB(215, 215, 222), Enum.Font.GothamMedium)
explication.TextXAlignment = Enum.TextXAlignment.Left
explication.TextYAlignment = Enum.TextYAlignment.Top
explication.TextWrapped = true

-- La zone centrale : touches à presser, ou petite animation
local scene = Instance.new("Frame")
scene.Size = UDim2.new(1, -44, 1, -260)
scene.Position = UDim2.new(0, 22, 0, 160)
scene.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
scene.ClipsDescendants = true
scene.Parent = carte
coins(scene, 8)

-- La barre d'objectif
local fondBarre = Instance.new("Frame")
fondBarre.Size = UDim2.new(1, -44, 0, 26)
fondBarre.Position = UDim2.new(0, 22, 1, -90)
fondBarre.BackgroundColor3 = CASE
fondBarre.Parent = carte
coins(fondBarre, 6)
local barre = Instance.new("Frame")
barre.Size = UDim2.fromScale(0, 1)
barre.BackgroundColor3 = ROUGE
barre.BorderSizePixel = 0
barre.Parent = fondBarre
coins(barre, 6)
local texteBarre = texte(fondBarre, UDim2.new(1, -16, 0.7, 0), UDim2.new(0, 8, 0.15, 0), Color3.new(1, 1, 1), Enum.Font.GothamBold)

local function boutonTexte(t: string, couleur: Color3, taille: UDim2, position: UDim2, parent: Instance?): TextButton
	local b = Instance.new("TextButton")
	b.Size = taille
	b.Position = position
	b.BackgroundColor3 = couleur
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.Text = t
	b.Parent = parent or carte
	coins(b, 6)
	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 10)
	marge.PaddingBottom = UDim.new(0, 10)
	marge.Parent = b
	local e = Instance.new("UIScale")
	e.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(e, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(e, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	return b
end

local boutonSuivant = boutonTexte("SUIVANT ▶", ROUGE, UDim2.new(0.34, 0, 0, 46), UDim2.new(0.66, -22, 1, -56))
local boutonPasser = boutonTexte("PASSER LE TUTO", CASE, UDim2.new(0.3, 0, 0, 46), UDim2.new(0, 22, 1, -56))
boutonPasser.TextColor3 = Color3.fromRGB(200, 200, 210)

---------------------------------------------------------------------
-- Petits éléments de la scène
---------------------------------------------------------------------
local elementsScene: { Instance } = {}
local animationScene: ((number) -> ())? = nil
local touchesAffichees: { { cadre: Frame, touches: () -> boolean } } = {}

local function viderScene()
	for _, e in ipairs(elementsScene) do
		e:Destroy()
	end
	elementsScene = {}
	touchesAffichees = {}
	animationScene = nil
end

-- Une rangée de touches de clavier (elles s'allument quand on appuie)
local function rangeeTouches(liste: { { texte: string, large: boolean?, test: (() -> boolean)? } }, y: number, legende: string?)
	local rangee = Instance.new("Frame")
	rangee.AnchorPoint = Vector2.new(0.5, 0)
	rangee.Size = UDim2.new(1, -20, 0, 58)
	rangee.Position = UDim2.new(0.5, 0, y, 0)
	rangee.BackgroundTransparency = 1
	rangee.Parent = scene
	table.insert(elementsScene, rangee)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 8)
	l.Parent = rangee
	for _, t in ipairs(liste) do
		local cadre = Instance.new("Frame")
		cadre.Size = UDim2.new(0, if t.large then 120 else (if #t.texte > 2 then 76 else 54), 0, 54)
		cadre.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
		cadre.Parent = rangee
		coins(cadre, 8)
		local ombre = Instance.new("UIStroke")
		ombre.Thickness = 3
		ombre.Color = Color3.fromRGB(110, 110, 120)
		ombre.Parent = cadre
		local lettre = texte(cadre, UDim2.new(1, -12, 0.62, 0), UDim2.new(0, 6, 0.19, 0), Color3.fromRGB(25, 25, 30))
		lettre.Text = t.texte
		if t.test then
			table.insert(touchesAffichees, { cadre = cadre, touches = t.test })
		end
	end
	if legende then
		local leg = texte(rangee, UDim2.new(0, 160, 0, 20), UDim2.new(), Color3.fromRGB(190, 190, 200), Enum.Font.GothamBold)
		leg.Text = legende
		leg.TextXAlignment = Enum.TextXAlignment.Left
		leg.LayoutOrder = 99
	end
end

local function legendeScene(t: string, y: number, couleur: Color3?)
	local l = texte(scene, UDim2.new(1, -30, 0, 22), UDim2.new(0, 15, y, 0), couleur or Color3.fromRGB(200, 200, 210), Enum.Font.GothamBold)
	l.Text = t
	table.insert(elementsScene, l)
	return l
end

-- Un mini kart vu du dessus (utilisé par les animations)
local function miniKart(couleur: Color3): Frame
	local k = Instance.new("Frame")
	k.AnchorPoint = Vector2.new(0.5, 0.5)
	k.Size = UDim2.fromOffset(26, 40)
	k.BackgroundColor3 = couleur
	k.ZIndex = 3
	k.Parent = scene
	coins(k, 8)
	local siege = Instance.new("Frame")
	siege.Size = UDim2.fromOffset(14, 12)
	siege.Position = UDim2.fromOffset(6, 22)
	siege.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	siege.ZIndex = 4
	siege.Parent = k
	coins(siege, 4)
	table.insert(elementsScene, k)
	return k
end

local function petitRond(couleur: Color3, taille: number, transparence: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(taille, taille)
	f.BackgroundColor3 = couleur
	f.BackgroundTransparency = transparence
	f.BorderSizePixel = 0
	f.ZIndex = 2
	f.Parent = scene
	coins(f, math.floor(taille / 2))
	table.insert(elementsScene, f)
	return f
end

---------------------------------------------------------------------
-- LES ÉTAPES
---------------------------------------------------------------------
type Etape = {
	icone: string,
	titre: string,
	texte: string,
	preparer: (() -> ())?,
	objectif: string?, -- texte de la barre
	progres: ((number) -> number)?, -- renvoie la progression 0..1 (appelée chaque image)
	bouton: string?,
}

local temps = { avance = 0, gauche = 0, droite = 0, drift = 0 }

local ETAPES: { Etape } = {
	{
		icone = "🏎️",
		titre = "BIENVENUE AU " .. string.upper(Config.NomDuJeu) .. " !",
		texte = "Le plus grand mall de " .. Config.Lieu .. " est ta piste. En 1 minute, apprends à piloter et à drifter comme un pro.",
		bouton = "C'EST PARTI ▶",
		preparer = function()
			-- Le mini kart fait le tour de la scène, avec une traînée
			local k = miniKart(ROUGE)
			local traces = {}
			for i = 1, 10 do
				traces[i] = petitRond(Color3.fromRGB(255, 120, 120), 10, 0.4 + i * 0.05)
			end
			local a = 0
			animationScene = function(dt)
				a += dt * 1.6
				local w, h = scene.AbsoluteSize.X, scene.AbsoluteSize.Y
				local function pos(angle)
					return Vector2.new(w / 2 + math.cos(angle) * w * 0.36, h / 2 + math.sin(angle) * h * 0.3)
				end
				local p = pos(a)
				k.Position = UDim2.fromOffset(p.X, p.Y)
				k.Rotation = math.deg(a) + 180 + 25
				for i, t in ipairs(traces) do
					local q = pos(a - i * 0.08)
					t.Position = UDim2.fromOffset(q.X, q.Y)
				end
			end
			legendeScene("✦ DRIFTE · GAGNE DES ÉTOILES · SÈME LA POLICE ✦", 0.82, OR)
		end,
	},
	{
		icone = "⬆️",
		titre = "ACCÉLÉRER ET FREINER",
		texte = if TACTILE then "Pousse le joystick vers le haut pour accélérer, vers le bas pour freiner et reculer."
			else "Appuie sur Z (ou W / ↑) pour accélérer. S (ou ↓) pour freiner et reculer.",
		objectif = if TACTILE then nil else "Maintiens la touche pour accélérer",
		progres = function(dt)
			if avance() then
				temps.avance += dt
			end
			return temps.avance / 1.2
		end,
		preparer = function()
			if TACTILE then
				legendeScene("🕹️  Joystick à gauche de l'écran", 0.4, Color3.new(1, 1, 1))
				return
			end
			rangeeTouches({ { texte = "Z", test = function() return enfoncee({ K.Z }) end }, { texte = "W", test = function() return enfoncee({ K.W }) end }, { texte = "↑", test = function() return enfoncee({ K.Up }) end } }, 0.12, "accélérer")
			rangeeTouches({ { texte = "S", test = function() return enfoncee({ K.S }) end }, { texte = "↓", test = function() return enfoncee({ K.Down }) end } }, 0.55, "freiner")
		end,
	},
	{
		icone = "↔️",
		titre = "TOURNER",
		texte = if TACTILE then "Joystick à gauche ou à droite pour tourner."
			else "Q (ou A / ←) pour tourner à gauche, D (ou →) pour tourner à droite.",
		objectif = if TACTILE then nil else "Tourne à gauche, puis à droite",
		progres = function(dt)
			if gauche() then
				temps.gauche += dt
			end
			if droite() then
				temps.droite += dt
			end
			return math.min(temps.gauche / 0.5, 1) * 0.5 + math.min(temps.droite / 0.5, 1) * 0.5
		end,
		preparer = function()
			if TACTILE then
				legendeScene("🕹️  ⬅  Joystick  ➡", 0.4, Color3.new(1, 1, 1))
				return
			end
			rangeeTouches({
				{ texte = "Q", test = function() return enfoncee({ K.Q, K.A }) end },
				{ texte = "←", test = function() return enfoncee({ K.Left }) end },
				{ texte = "→", test = function() return enfoncee({ K.Right }) end },
				{ texte = "D", test = function() return enfoncee({ K.D }) end },
			}, 0.3)
		end,
	},
	{
		icone = "💨",
		titre = "DRIFTER !",
		texte = if TACTILE then "En roulant, touche le bouton DRIFT et tourne : le kart glisse de côté. Plus tu glisses longtemps, plus tu marques de points !"
			else "En roulant, MAINTIENS SHIFT et tourne : le kart glisse de côté. Plus tu glisses longtemps, plus tu marques de points !",
		objectif = if TACTILE then nil else "Maintiens SHIFT + une direction",
		progres = function(dt)
			if drifte() then
				temps.drift += dt
			end
			return temps.drift / 1.2
		end,
		preparer = function()
			-- Animation : le kart dérape dans un virage, fumée et étincelles
			local k = miniKart(ROUGE)
			local fumees = {}
			for i = 1, 14 do
				fumees[i] = petitRond(Color3.fromRGB(220, 220, 230), 14 + i, 0.5 + i * 0.03)
			end
			local etincelles = {}
			for i = 1, 6 do
				etincelles[i] = petitRond(Color3.fromRGB(255, 160, 50), 5, 0)
			end
			local a = 0
			animationScene = function(dt)
				a += dt * 1.3
				local w, h = scene.AbsoluteSize.X, scene.AbsoluteSize.Y
				local function pos(angle)
					return Vector2.new(w * 0.5 + math.cos(angle) * w * 0.33, h * 0.38 + math.sin(angle) * h * 0.24)
				end
				local p = pos(a)
				k.Position = UDim2.fromOffset(p.X, p.Y)
				k.Rotation = math.deg(a) + 180 + 55 -- bien de travers : c'est un drift !
				for i, f in ipairs(fumees) do
					local q = pos(a - i * 0.06)
					f.Position = UDim2.fromOffset(q.X, q.Y)
				end
				local couleur = if (a % 6) > 4 then Color3.fromRGB(200, 90, 255) elseif (a % 6) > 2 then Color3.fromRGB(255, 150, 40) else Color3.fromRGB(90, 170, 255)
				for i, e in ipairs(etincelles) do
					local q = pos(a - 0.05) + Vector2.new(math.random(-14, 14), math.random(-14, 14))
					e.Position = UDim2.fromOffset(q.X, q.Y)
					e.BackgroundColor3 = couleur
					e.Visible = (i + math.floor(a * 20)) % 2 == 0
				end
			end
			if not TACTILE then
				local rangee = { { texte = "SHIFT", large = true, test = function() return enfoncee(DRIFT) end }, { texte = "+", }, { texte = "Q", test = gauche }, { texte = "D", test = droite } }
				rangeeTouches(rangee, 0.72)
			else
				legendeScene("Bouton DRIFT  +  🕹️", 0.8, Color3.new(1, 1, 1))
			end
		end,
	},
	{
		icone = "⭐",
		titre = "ÉTOILES ET BOOST",
		texte = ("Un drift de %d points = ⭐, %d = ⭐⭐, %d = ⭐⭐⭐. Quand le drift se termine, tes étoiles te donnent un BOOST de vitesse 🔥"):format(Config.Score.Etoiles[1], Config.Score.Etoiles[2], Config.Score.Etoiles[3]),
		bouton = "COMPRIS ▶",
		preparer = function()
			local etoiles = {}
			for i = 1, 3 do
				local e = texte(scene, UDim2.fromOffset(60, 60), UDim2.new(0.5, (i - 2) * 76 - 30, 0.18, 0), Color3.fromRGB(80, 80, 90))
				e.Text = "★"
				table.insert(elementsScene, e)
				etoiles[i] = e
			end
			local pointsTexte = legendeScene("+0", 0.55, Color3.new(1, 1, 1))
			local boost = legendeScene("", 0.75, Color3.fromRGB(255, 150, 40))
			local t = 0
			animationScene = function(dt)
				t = (t + dt) % 4.5
				local pts = math.floor(math.min(t / 3, 1) * Config.Score.Etoiles[3] * 1.1)
				pointsTexte.Text = ("+%d points"):format(pts)
				for i, e in ipairs(etoiles) do
					local allumee = pts >= Config.Score.Etoiles[i]
					e.TextColor3 = if allumee then OR else Color3.fromRGB(80, 80, 90)
				end
				boost.Text = if t > 3.1 then "🔥 BOOST ! 🔥" else ""
			end
		end,
	},
	{
		icone = "💧",
		titre = "ATTENTION, SOL GLISSANT !",
		texte = "Les flaques près des panneaux jaunes font glisser encore plus : drifte dessus pour le BONUS EAU 💧 (plus de points). Attention aux caddies et aux obstacles !",
		bouton = "SUIVANT ▶",
		preparer = function()
			local panneau = texte(scene, UDim2.fromOffset(90, 90), UDim2.new(0.5, -45, 0.12, 0), Color3.fromRGB(255, 210, 40))
			panneau.Text = "⚠"
			table.insert(elementsScene, panneau)
			legendeScene("ATTENTION · SOL GLISSANT", 0.72, Color3.fromRGB(255, 210, 40))
			local t = 0
			animationScene = function(dt)
				t += dt
				panneau.Rotation = math.sin(t * 4) * 8
			end
		end,
	},
	{
		icone = "🚓",
		titre = "LA POLICE DU MALL",
		texte = "Les agents de sécurité te poursuivent à pied… puis sautent dans leur kart ! Drifte pour les semer : un drift réussi pendant une poursuite donne un boost d'évasion.",
		bouton = "SUIVANT ▶",
		preparer = function()
			local fugitif = miniKart(ROUGE)
			local police = miniKart(Color3.fromRGB(40, 90, 255))
			local gyro = petitRond(Color3.fromRGB(255, 40, 40), 10, 0)
			gyro.ZIndex = 5
			local t = 0
			animationScene = function(dt)
				t += dt
				local w, h = scene.AbsoluteSize.X, scene.AbsoluteSize.Y
				local x = (t * 0.25 % 1)
				local xf = w * (0.1 + x * 0.9)
				fugitif.Position = UDim2.fromOffset(xf, h * 0.45 + math.sin(t * 5) * 12)
				fugitif.Rotation = 90 + math.sin(t * 5) * 25
				police.Position = UDim2.fromOffset(xf - 90, h * 0.45 + math.sin(t * 5 - 1) * 8)
				police.Rotation = 90
				gyro.Position = police.Position
				gyro.BackgroundColor3 = if math.floor(t * 6) % 2 == 0 then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(40, 90, 255)
			end
		end,
	},
	{
		icone = "⌨️",
		titre = "LES TOUCHES UTILES",
		texte = "F : prendre ton kart  ·  V : changer de caméra  ·  R : redresser le kart  ·  N : jour / nuit",
		bouton = "SUIVANT ▶",
		preparer = function()
			if TACTILE then
				legendeScene("Boutons à l'écran : 🏎️ CONDUIRE · CAM · R", 0.4, Color3.new(1, 1, 1))
				return
			end
			rangeeTouches({
				{ texte = "F", test = function() return enfoncee({ K.F }) end },
				{ texte = "V", test = function() return enfoncee({ K.V }) end },
				{ texte = "R", test = function() return enfoncee({ K.R }) end },
				{ texte = "N", test = function() return enfoncee({ K.N }) end },
			}, 0.12)
			legendeScene("conduire   ·   caméra   ·   redresser   ·   jour / nuit", 0.62)
		end,
	},
	{
		icone = "🎨",
		titre = "GARAGE, PIÈCES ET MODES",
		texte = "Chaque drift rapporte des 💰. Au GARAGE (borne violette, touche E), achète des couleurs, des peintures et des karts. Le ☰ MENU (en bas à droite) lance l'Entraînement, le jeu En ligne ou la Drift Battle !",
		bouton = "JOUER ! 🏁",
		preparer = function()
			local couleurs = { Color3.fromRGB(215, 35, 40), Color3.fromRGB(250, 205, 30), Color3.fromRGB(40, 170, 80), Color3.fromRGB(35, 105, 215), Color3.fromRGB(170, 60, 255), Color3.fromRGB(255, 70, 170) }
			local cases = {}
			for i, c in ipairs(couleurs) do
				local f = Instance.new("Frame")
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.Size = UDim2.fromOffset(50, 50)
				f.Position = UDim2.new(0.5, (i - 3.5) * 60, 0.35, 0)
				f.BackgroundColor3 = c
				f.Parent = scene
				coins(f, 6)
				table.insert(elementsScene, f)
				cases[i] = f
			end
			legendeScene("💰 drifte → achète → brille !", 0.72, OR)
			local t = 0
			animationScene = function(dt)
				t += dt
				for i, f in ipairs(cases) do
					local s = 1 + math.max(0, math.sin(t * 3 - i * 0.6)) * 0.18
					f.Size = UDim2.fromOffset(50 * s, 50 * s)
				end
			end
		end,
	},
}

for _ = 1, #ETAPES do
	local p = Instance.new("Frame")
	p.Size = UDim2.fromOffset(10, 10)
	p.BackgroundColor3 = CASE
	p.Parent = points
	coins(p, 5)
end

---------------------------------------------------------------------
-- Déroulement
---------------------------------------------------------------------
local actuelle = 0
local enCours = false
local progression = 0
local valide = false
local debutEtape = 0
local connexion: RBXScriptConnection? = nil

local function montrerEtape(n: number)
	actuelle = n
	local e = ETAPES[n]
	viderScene()
	temps = { avance = 0, gauche = 0, droite = 0, drift = 0 }
	progression = 0
	valide = e.progres == nil
	debutEtape = os.clock()
	etape.Text = ("ÉTAPE %d / %d"):format(n, #ETAPES)
	for i, p in ipairs(points:GetChildren()) do
		if p:IsA("Frame") then
			p.BackgroundColor3 = if i < n then VERT elseif i == n then ROUGE else CASE
			p.Size = if i == n then UDim2.fromOffset(26, 10) else UDim2.fromOffset(10, 10)
		end
	end
	icone.Text = e.icone
	titre.Text = e.titre
	explication.Text = e.texte
	fondBarre.Visible = e.progres ~= nil
	barre.Size = UDim2.fromScale(0, 1)
	barre.BackgroundColor3 = ROUGE
	texteBarre.Text = e.objectif or "Essaie, puis clique sur SUIVANT"
	boutonSuivant.Text = e.bouton or "SUIVANT ▶"
	boutonSuivant.BackgroundColor3 = if valide then ROUGE else CASE
	if e.preparer then
		e.preparer()
	end
	-- Petite animation d'entrée
	echelleIcone.Scale = 0.3
	TweenService:Create(echelleIcone, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	for _, t in ipairs({ titre, explication }) do
		t.TextTransparency = 1
		TweenService:Create(t, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	end
	scene.Position = UDim2.new(0, 60, 0, 160)
	TweenService:Create(scene, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Position = UDim2.new(0, 22, 0, 160) }):Play()
end

local function terminer(vu: boolean)
	if not enCours then
		return
	end
	enCours = false
	if connexion then
		connexion:Disconnect()
		connexion = nil
	end
	RunService:UnbindFromRenderStep("TutoCamera")
	if vu then
		remotes:WaitForChild("TutoTermine"):FireServer()
	end
	TweenService:Create(echelleCarte, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
	TweenService:Create(voile, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	task.delay(0.3, function()
		gui.Enabled = false
		viderScene()
	end)
	camera.CameraType = Enum.CameraType.Custom
	controles:Enable()
	joueur:SetAttribute("IntroFinie", true)
end

local function suivante()
	if not enCours then
		return
	end
	if not valide then
		texteBarre.Text = "Essaie d'abord ! (ou PASSER LE TUTO)"
		local e = Instance.new("UIScale")
		e.Parent = fondBarre
		e.Scale = 1.06
		TweenService:Create(e, TweenInfo.new(0.25), { Scale = 1 }):Play()
		task.delay(0.3, function()
			e:Destroy()
		end)
		return
	end
	if actuelle >= #ETAPES then
		terminer(true)
	else
		montrerEtape(actuelle + 1)
	end
end
boutonSuivant.Activated:Connect(suivante)
boutonPasser.Activated:Connect(function()
	terminer(true)
end)

local function lancer()
	if enCours then
		return
	end
	enCours = true
	gui.Enabled = true
	controles:Disable()
	voile.BackgroundTransparency = 0.45
	echelleCarte.Scale = 0.7
	TweenService:Create(echelleCarte, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	montrerEtape(1)

	-- En fond : la caméra survole lentement la place centrale du mall
	camera.CameraType = Enum.CameraType.Scriptable
	local angle = 0
	RunService:BindToRenderStep("TutoCamera", Enum.RenderPriority.Camera.Value + 2, function(dt)
		angle += dt * 0.08
		local pos = Vector3.new(math.cos(angle) * 46, SOL + 14, math.sin(angle) * 46)
		camera.CFrame = CFrame.lookAt(pos, Vector3.new(0, SOL + 6, 0))
	end)

	connexion = RunService.RenderStepped:Connect(function(dt)
		local e = ETAPES[actuelle]
		if not e then
			return
		end
		-- Les touches s'allument quand on appuie dessus
		for _, t in ipairs(touchesAffichees) do
			local active = t.touches()
			t.cadre.BackgroundColor3 = if active then ROUGE else Color3.fromRGB(235, 235, 240)
			local lettre = t.cadre:FindFirstChildOfClass("TextLabel")
			if lettre then
				lettre.TextColor3 = if active then Color3.new(1, 1, 1) else Color3.fromRGB(25, 25, 30)
			end
		end
		if animationScene then
			animationScene(dt)
		end
		if e.progres and not valide then
			progression = math.clamp(e.progres(dt), 0, 1)
			barre.Size = UDim2.fromScale(progression, 1)
			-- Sur téléphone (1,5 s) ou si on bloque (6 s), SUIVANT devient possible
			local tempsLibre = os.clock() - debutEtape > (if TACTILE then 1.5 else 6)
			if progression >= 1 or tempsLibre then
				valide = true
				boutonSuivant.BackgroundColor3 = ROUGE
				if progression >= 1 then
					barre.BackgroundColor3 = VERT
					texteBarre.Text = "✔ BRAVO !"
					task.delay(0.6, function()
						if enCours and ETAPES[actuelle] == e then
							suivante()
						end
					end)
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- Au démarrage : tuto seulement à la toute première visite, au lobby
---------------------------------------------------------------------
task.spawn(function()
	local TYPE = Config.TypeDePlace()
	local donneesVoyage = game:GetService("TeleportService"):GetLocalPlayerTeleportData()
	local retour = type(donneesVoyage) == "table" and donneesVoyage.ouvrirMenu == true
	if (TYPE ~= "Lobby" and TYPE ~= "ToutEnUn") or retour then
		joueur:SetAttribute("IntroFinie", true)
		return
	end
	local ok, profil = pcall(function()
		return remotes:WaitForChild("ObtenirProfil"):InvokeServer()
	end)
	if ok and type(profil) == "table" and profil.TutoFait then
		joueur:SetAttribute("IntroFinie", true)
		return
	end
	-- On attend le personnage et la carte
	local perso = joueur.Character or joueur.CharacterAdded:Wait()
	perso:WaitForChild("HumanoidRootPart", 10)
	workspace:WaitForChild("GoldenMall", 15)
	pcall(function()
		joueur:RequestStreamAroundAsync(Vector3.new(0, SOL, 0))
	end)
	local okLancer, erreur = pcall(lancer)
	if not okLancer then
		warn("[Tutoriel] " .. tostring(erreur))
		enCours = true
		terminer(false)
	end
end)

-- Revoir le tuto depuis le menu (bouton « 📖 TUTO »)
joueur:GetAttributeChangedSignal("RevoirTuto"):Connect(function()
	if joueur:GetAttribute("RevoirTuto") then
		joueur:SetAttribute("RevoirTuto", false)
		local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
		if h and h.SeatPart then
			return -- pas au volant
		end
		lancer()
	end
end)
