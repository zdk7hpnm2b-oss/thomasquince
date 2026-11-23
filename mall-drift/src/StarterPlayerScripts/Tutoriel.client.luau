--[[
	Tutoriel  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : Tutoriel

	Le tuto se fait DIRECTEMENT SUR LA PISTE, au volant, en 3 étapes :
	  1. ACCÉLÈRE ET TOURNE   (rouler un peu)
	  2. DRIFTE !             (un drift qui atteint ⭐)
	  3. BOOST !              (relâche le drift : les étoiles donnent un boost)
	Il se lance depuis le bouton « 📖 TUTO » du menu : le serveur donne un kart sur la ligne de départ
	(3, 2, 1) et une petite carte en haut de l'écran guide le joueur : les touches
	s'allument quand on appuie, la barre se remplit, ✔ et confettis à chaque étape.
	Au lobby, on revient au garage à la fin.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")

local joueur = Players.LocalPlayer
local K = Enum.KeyCode
local TACTILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local ROUGE = Color3.fromRGB(225, 30, 45)
local VERT = Color3.fromRGB(70, 230, 120)
local OR = Color3.fromRGB(255, 205, 80)
local POLICE_TITRE = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

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

---------------------------------------------------------------------
-- L'interface : une carte en haut de l'écran (ne cache pas la piste)
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "TutoGoldenMall"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.Enabled = false
gui.Parent = joueur:WaitForChild("PlayerGui")

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
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = ""
	t.Parent = parent
	return t
end

local carte = Instance.new("Frame")
carte.AnchorPoint = Vector2.new(0.5, 0)
carte.Size = UDim2.new(0.9, 0, 0, 150)
carte.Position = UDim2.new(0.5, 0, 0, 70)
carte.BackgroundColor3 = Color3.new(1, 1, 1)
carte.BackgroundTransparency = 0.1
carte.Parent = gui
coins(carte, 12)
local tailleMax = Instance.new("UISizeConstraint")
tailleMax.MaxSize = Vector2.new(540, 150)
tailleMax.Parent = carte
local degradeCarte = Instance.new("UIGradient") -- verre fumé
degradeCarte.Color = ColorSequence.new(Color3.fromRGB(42, 42, 52), Color3.fromRGB(10, 10, 14))
degradeCarte.Rotation = 90
degradeCarte.Parent = carte
local bordCarte = Instance.new("UIStroke")
bordCarte.Color = Color3.new(1, 1, 1)
bordCarte.Transparency = 0.85
bordCarte.Thickness = 1
bordCarte.Parent = carte
local echelleCarte = Instance.new("UIScale")
echelleCarte.Parent = carte

-- Bande rouge à gauche (elle « respire »)
local bande = Instance.new("Frame")
bande.Size = UDim2.new(0, 6, 1, -24)
bande.Position = UDim2.new(0, 12, 0, 12)
bande.BackgroundColor3 = ROUGE
bande.BorderSizePixel = 0
bande.Parent = carte
coins(bande, 3)

-- Pastilles des 3 étapes (en haut à droite)
local pastilles = {}
for i = 1, 3 do
	local p = Instance.new("TextLabel")
	p.Size = UDim2.fromOffset(26, 26)
	p.Position = UDim2.new(1, -18 - (4 - i) * 32, 0, 14)
	p.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	p.TextColor3 = Color3.new(1, 1, 1)
	p.Font = Enum.Font.GothamBlack
	p.TextScaled = true
	p.Text = tostring(i)
	p.Parent = carte
	coins(p, 13)
	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 5)
	marge.PaddingBottom = UDim.new(0, 5)
	marge.Parent = p
	pastilles[i] = p
end

local surtitre = texte(carte, UDim2.new(0.6, 0, 0, 16), UDim2.new(0, 30, 0, 14), Color3.fromRGB(255, 120, 130), Enum.Font.GothamBold)
local titre = texte(carte, UDim2.new(1, -150, 0, 38), UDim2.new(0, 30, 0, 32), Color3.new(1, 1, 1))
titre.FontFace = POLICE_TITRE
local consigne = texte(carte, UDim2.new(1, -60, 0, 18), UDim2.new(0, 30, 0, 74), Color3.fromRGB(205, 205, 215), Enum.Font.GothamMedium)

-- Les touches (elles s'allument quand on appuie)
local rangeeTouches = Instance.new("Frame")
rangeeTouches.AnchorPoint = Vector2.new(1, 0)
rangeeTouches.Size = UDim2.new(0.45, 0, 0, 32)
rangeeTouches.Position = UDim2.new(1, -18, 0, 102)
rangeeTouches.BackgroundTransparency = 1
rangeeTouches.Parent = carte
local dispoTouches = Instance.new("UIListLayout")
dispoTouches.FillDirection = Enum.FillDirection.Horizontal
dispoTouches.HorizontalAlignment = Enum.HorizontalAlignment.Right
dispoTouches.Padding = UDim.new(0, 5)
dispoTouches.Parent = rangeeTouches

-- La barre de progression (avec un reflet qui défile)
local fondBarre = Instance.new("Frame")
fondBarre.Size = UDim2.new(0.5, -30, 0, 10)
fondBarre.Position = UDim2.new(0, 30, 0, 106)
fondBarre.BackgroundColor3 = Color3.fromRGB(45, 45, 54)
fondBarre.BorderSizePixel = 0
fondBarre.Parent = carte
coins(fondBarre, 5)
local barre = Instance.new("Frame")
barre.Size = UDim2.fromScale(0, 1)
barre.BackgroundColor3 = ROUGE
barre.BorderSizePixel = 0
barre.Parent = fondBarre
coins(barre, 5)
local lueur = Instance.new("UIGradient")
lueur.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0),
	NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(1, 0),
})
lueur.Parent = barre
local pourcentage = texte(carte, UDim2.new(0, 60, 0, 14), UDim2.new(0, 30, 0, 122), Color3.fromRGB(170, 170, 180), Enum.Font.GothamBold)

local boutonPasser = Instance.new("TextButton")
boutonPasser.AnchorPoint = Vector2.new(1, 1)
boutonPasser.Size = UDim2.new(0, 120, 0, 16)
boutonPasser.Position = UDim2.new(0.5, 0, 1, -12)
boutonPasser.BackgroundTransparency = 1
boutonPasser.TextColor3 = Color3.fromRGB(150, 150, 160)
boutonPasser.Font = Enum.Font.GothamBold
boutonPasser.TextScaled = true
boutonPasser.TextXAlignment = Enum.TextXAlignment.Right
boutonPasser.Text = "Passer le tuto ✕"
boutonPasser.Parent = carte

-- Grand message au centre (✔ BIEN JOUÉ, TU ES PRÊT…)
local grandMessage = Instance.new("TextLabel")
grandMessage.AnchorPoint = Vector2.new(0.5, 0.5)
grandMessage.Size = UDim2.new(0.7, 0, 0, 70)
grandMessage.Position = UDim2.fromScale(0.5, 0.42)
grandMessage.BackgroundTransparency = 1
grandMessage.FontFace = POLICE_TITRE
grandMessage.TextScaled = true
grandMessage.TextColor3 = VERT
grandMessage.TextTransparency = 1
grandMessage.Parent = gui
local contourMessage = Instance.new("UIStroke")
contourMessage.Thickness = 4
contourMessage.Color = Color3.fromRGB(10, 20, 12)
contourMessage.Transparency = 1
contourMessage.Parent = grandMessage
local echelleMessage = Instance.new("UIScale")
echelleMessage.Parent = grandMessage

local function montrerGrandMessage(t: string, couleur: Color3, duree: number)
	grandMessage.Text = t
	grandMessage.TextColor3 = couleur
	grandMessage.TextTransparency = 0
	contourMessage.Transparency = 0
	echelleMessage.Scale = 0.4
	TweenService:Create(echelleMessage, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duree, function()
		if grandMessage.Text == t then
			TweenService:Create(grandMessage, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(contourMessage, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
end

-- Confettis qui jaillissent de la carte
local function confettis()
	local couleurs = { ROUGE, OR, VERT, Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 90, 200) }
	local centre = carte.AbsolutePosition + carte.AbsoluteSize / 2
	for i = 1, 26 do
		local c = Instance.new("Frame")
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Size = UDim2.fromOffset(math.random(6, 11), math.random(10, 16))
		c.Position = UDim2.fromOffset(centre.X, centre.Y)
		c.BackgroundColor3 = couleurs[(i % #couleurs) + 1]
		c.BorderSizePixel = 0
		c.Rotation = math.random(0, 360)
		c.ZIndex = 10
		c.Parent = gui
		local angle = math.rad(math.random(0, 360))
		local loin = math.random(120, 300)
		local fin = UDim2.fromOffset(centre.X + math.cos(angle) * loin, centre.Y + math.sin(angle) * loin * 0.6 + 120)
		local info = TweenInfo.new(math.random(70, 110) / 100, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(c, info, { Position = fin, Rotation = c.Rotation + math.random(-360, 360), BackgroundTransparency = 1 }):Play()
		task.delay(1.2, function()
			c:Destroy()
		end)
	end
end

---------------------------------------------------------------------
-- Les touches affichées pour chaque étape
---------------------------------------------------------------------
type Touche = { t: string, test: (() -> boolean)? }
local touchesAffichees: { { cadre: Frame, lettre: TextLabel, test: () -> boolean } } = {}

local function afficherTouches(liste: { Touche })
	for _, e in ipairs(rangeeTouches:GetChildren()) do
		if e:IsA("GuiObject") then
			e:Destroy()
		end
	end
	touchesAffichees = {}
	for i, k in ipairs(liste) do
		local cadre = Instance.new("Frame")
		cadre.LayoutOrder = i
		cadre.Size = UDim2.new(0, if #k.t > 2 then 64 else 32, 1, 0)
		cadre.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
		cadre.BackgroundTransparency = if k.test then 0 else 1
		cadre.Parent = rangeeTouches
		coins(cadre, 6)
		if k.test then
			local ombre = Instance.new("UIStroke")
			ombre.Thickness = 2
			ombre.Color = Color3.fromRGB(120, 120, 130)
			ombre.Parent = cadre
		end
		local lettre = texte(cadre, UDim2.new(1, -8, 0.6, 0), UDim2.new(0, 4, 0.2, 0), if k.test then Color3.fromRGB(25, 25, 30) else Color3.new(1, 1, 1))
		lettre.TextXAlignment = Enum.TextXAlignment.Center
		lettre.Text = k.t
		local test = k.test
		if test then
			table.insert(touchesAffichees, { cadre = cadre, lettre = lettre, test = test })
		end
	end
end

local AVANCER = { K.W, K.Z, K.Up }
local GAUCHE = { K.A, K.Q, K.Left }
local DROITE = { K.D, K.Right }
local DRIFT = { K.LeftShift, K.RightShift }

---------------------------------------------------------------------
-- Les 3 étapes
---------------------------------------------------------------------
local function chassisDuKart(): BasePart?
	local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	local siege = h and h.SeatPart
	local modele = siege and siege.Parent
	return modele and modele:FindFirstChild("Chassis") :: BasePart?
end

local distance = 0
local dernierePosition: Vector3? = nil
local debutEtape = 0
local etoile1 = Config.Score.Etoiles[1]

type Etape = { titre: string, consigne: string, touches: { Touche }, progres: () -> number }
local ETAPES: { Etape } = {
	{
		titre = "ACCÉLÈRE ET TOURNE",
		consigne = if TACTILE then "Joystick : vers le haut pour accélérer, à gauche / à droite pour tourner"
			else "Z pour accélérer (S pour freiner), Q et D pour tourner",
		touches = if TACTILE then {} else {
			{ t = "Z", test = function() return enfoncee(AVANCER) end },
			{ t = "Q", test = function() return enfoncee(GAUCHE) end },
			{ t = "D", test = function() return enfoncee(DROITE) end },
		},
		progres = function()
			local ch = chassisDuKart()
			if ch then
				local p = ch.Position
				if dernierePosition then
					distance += math.min((p - dernierePosition).Magnitude, 10)
				end
				dernierePosition = p
			end
			return distance / 160
		end,
	},
	{
		titre = "DRIFTE !",
		consigne = (if TACTILE then "Bouton DRIFT + tourne" else "Maintiens SHIFT en tournant") .. (" : atteins %d points ⭐"):format(etoile1),
		touches = if TACTILE then {} else {
			{ t = "SHIFT", test = function() return enfoncee(DRIFT) end },
			{ t = "+" },
			{ t = "Q", test = function() return enfoncee(GAUCHE) end },
			{ t = "D", test = function() return enfoncee(DROITE) end },
		},
		progres = function()
			return (joueur:GetAttribute("TutoDriftPoints") or 0) / etoile1
		end,
	},
	{
		titre = "BOOST ! 🔥",
		consigne = "Lâche le drift : tes étoiles se transforment en BOOST de vitesse",
		touches = if TACTILE then {} else { { t = "SHIFT", test = function() return enfoncee(DRIFT) end } },
		progres = function()
			local b = joueur:GetAttribute("TutoBoost")
			return if type(b) == "number" and b > debutEtape then 1 else 0
		end,
	},
}

local enCours = false
local actuelle = 0
local connexion: RBXScriptConnection? = nil
local etapeValidee = false

local function montrerEtape(n: number)
	actuelle = n
	etapeValidee = false
	-- (le drift qui valide l'étape 2 continue souvent jusqu'au boost : on garde ce boost-là)
	debutEtape = os.clock() - 1.5
	local e = ETAPES[n]
	surtitre.Text = ("TUTO  ·  ÉTAPE %d / 3"):format(n)
	titre.Text = e.titre
	consigne.Text = e.consigne
	afficherTouches(e.touches)
	barre.Size = UDim2.fromScale(0, 1)
	barre.BackgroundColor3 = ROUGE
	for i, p in ipairs(pastilles) do
		p.BackgroundColor3 = if i < n then VERT elseif i == n then ROUGE else Color3.fromRGB(40, 40, 48)
		p.Text = if i < n then "✔" else tostring(i)
	end
	titre.Position = UDim2.new(0, 60, 0, 32)
	titre.TextTransparency = 1
	TweenService:Create(titre, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Position = UDim2.new(0, 30, 0, 32), TextTransparency = 0 }):Play()
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
	if vu then
		local astuce = if Config.TypeDePlace() == "Lobby" then "☰ MENU (en bas à droite) pour lancer une partie" else "Gagne des 💰 et personnalise ton kart au GARAGE !"
		surtitre.Text = "TUTO TERMINÉ"
		titre.Text = "TU ES PRÊT ! 🏁"
		consigne.Text = astuce
		afficherTouches({})
		montrerGrandMessage("TU ES PRÊT ! 🏁", OR, 2.2)
		task.wait(3)
	end
	TweenService:Create(echelleCarte, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
	task.wait(0.3)
	gui.Enabled = false
	remotes:WaitForChild("TutoTermine"):FireServer()
end

local function etapeReussie()
	etapeValidee = true
	barre.BackgroundColor3 = VERT
	barre.Size = UDim2.fromScale(1, 1)
	pourcentage.Text = "100 %"
	pastilles[actuelle].BackgroundColor3 = VERT
	pastilles[actuelle].Text = "✔"
	confettis()
	echelleCarte.Scale = 1.08 -- la carte « saute » de joie
	TweenService:Create(echelleCarte, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local bravo = ({ "BIEN JOUÉ !", "SUPER DRIFT !", "BOOST ! 🔥" })[actuelle] or "BRAVO !"
	montrerGrandMessage("✔ " .. bravo, VERT, 1.1)
	task.delay(1.3, function()
		if not enCours then
			return
		end
		if actuelle >= #ETAPES then
			terminer(true)
		else
			montrerEtape(actuelle + 1)
		end
	end)
end

boutonPasser.Activated:Connect(function()
	task.spawn(terminer, false)
end)

local function lancer()
	if enCours then
		return
	end
	enCours = true
	distance = 0
	dernierePosition = nil
	joueur:SetAttribute("TutoDriftPoints", 0)
	joueur:SetAttribute("TutoBoost", 0)
	remotes:WaitForChild("DebutTuto"):FireServer() -- le serveur donne un kart sur la ligne de départ
	local debut = os.clock()
	while enCours and not chassisDuKart() and os.clock() - debut < 8 do
		task.wait(0.2)
	end
	if not enCours then
		return
	end
	if not chassisDuKart() then
		warn("[Tutoriel] pas de kart reçu : tuto annulé")
		enCours = false
		remotes:WaitForChild("TutoTermine"):FireServer()
		return
	end
	task.wait(3.6) -- on laisse le 3, 2, 1 se faire
	if not enCours then
		return
	end
	gui.Enabled = true
	echelleCarte.Scale = 0.3
	carte.Position = UDim2.new(0.5, 0, 0, 30)
	TweenService:Create(echelleCarte, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(carte, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 0, 70) }):Play()
	montrerEtape(1)

	local temps = 0
	local horsDuKart = 0
	connexion = RunService.RenderStepped:Connect(function(dt)
		temps += dt
		for _, t in ipairs(touchesAffichees) do
			local active = t.test()
			t.cadre.BackgroundColor3 = if active then ROUGE else Color3.fromRGB(235, 235, 240)
			t.lettre.TextColor3 = if active then Color3.new(1, 1, 1) else Color3.fromRGB(25, 25, 30)
		end
		bande.BackgroundTransparency = 0.15 + math.sin(temps * 4) * 0.15
		lueur.Offset = Vector2.new((temps * 0.8) % 2 - 1, 0)
		local e = ETAPES[actuelle]
		if e and not etapeValidee then
			local p = math.clamp(e.progres(), 0, 1)
			barre.Size = barre.Size:Lerp(UDim2.fromScale(p, 1), math.clamp(dt * 10, 0, 1))
			pourcentage.Text = ("%d %%"):format(math.floor(p * 100))
			if p >= 1 then
				etapeReussie()
			end
		end
		-- Descendu du kart pendant plus de 2 s : le tuto s'arrête
		horsDuKart = if chassisDuKart() then 0 else horsDuKart + dt
		if horsDuKart > 2 then
			task.spawn(terminer, false)
		end
	end)
end

---------------------------------------------------------------------
-- Au démarrage : pas de tuto automatique, c'est le MENU qui s'ouvre.
-- Le tuto se lance seulement avec le bouton « 📖 TUTO » du menu.
---------------------------------------------------------------------
joueur:SetAttribute("IntroFinie", true) -- (les autres scripts attendent ce signal)

-- Refaire le tuto depuis le menu (bouton « 📖 TUTO »)
joueur:GetAttributeChangedSignal("RevoirTuto"):Connect(function()
	if joueur:GetAttribute("RevoirTuto") then
		joueur:SetAttribute("RevoirTuto", false)
		task.spawn(lancer)
	end
end)
