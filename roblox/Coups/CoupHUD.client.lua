--[[
	NEON BAY : écran du joueur pour les coups

	OÙ LE METTRE : StarterPlayer > StarterPlayerScripts > LocalScript, nommé « CoupHUD ».

	CE QU'IL AFFICHE
	- En haut à gauche : le camp (Malin ou Gardien), les étoiles, les billets,
	  le temps restant avant le changement de camp.
	- En bas : l'objectif du moment, en une phrase.
	- Une grosse flèche « ▼ » au-dessus de l'endroit où aller, visible à travers les murs.
	- Les messages du jeu (coup réussi, attrapé, nouvelle manche...).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local joueur = Players.LocalPlayer
local evenement = ReplicatedStorage:WaitForChild("CoupEvent")

local neonBay = Workspace:WaitForChild("NeonBay")
local rue = neonBay:WaitForChild("RueDesBoutiques")
local plage = neonBay:WaitForChild("Plage")
local rideauCabine = plage:WaitForChild("CabineDeguisement"):WaitForChild("Rideau")
local depot = neonBay:WaitForChild("Marais"):WaitForChild("Planque"):WaitForChild("Depot")

local COULEURS = {
	blanc = Color3.fromRGB(255, 255, 255),
	or_ = Color3.fromRGB(255, 200, 40),
	rouge = Color3.fromRGB(255, 80, 80),
	cyan = Color3.fromRGB(40, 230, 255),
	bleu = Color3.fromRGB(90, 150, 255),
	orange = Color3.fromRGB(255, 140, 40),
}
COULEURS["or"] = COULEURS.or_

---------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------
local ecran = Instance.new("ScreenGui")
ecran.Name = "CoupHUD"
ecran.ResetOnSpawn = false
ecran.Parent = joueur:WaitForChild("PlayerGui")

local function label(nom, parent, position, taille, couleur)
	local l = Instance.new("TextLabel")
	l.Name = nom
	l.Position = position
	l.Size = taille
	l.BackgroundTransparency = 1
	l.TextColor3 = couleur or COULEURS.blanc
	l.TextStrokeTransparency = 0.3
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local cadre = Instance.new("Frame")
cadre.Name = "Statut"
cadre.Position = UDim2.fromOffset(12, 70)
cadre.Size = UDim2.fromOffset(240, 130)
cadre.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
cadre.BackgroundTransparency = 0.25
cadre.Parent = ecran
local coins = Instance.new("UICorner")
coins.CornerRadius = UDim.new(0, 12)
coins.Parent = cadre

local texteCamp = label("Camp", cadre, UDim2.fromOffset(12, 6), UDim2.new(1, -24, 0, 28))
local texteEtoiles = label("Etoiles", cadre, UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 32), COULEURS.or_)
texteEtoiles.Font = Enum.Font.GothamBlack
local texteBillets = label("Billets", cadre, UDim2.fromOffset(12, 70), UDim2.new(1, -24, 0, 26), COULEURS.or_)
local texteManche = label("Manche", cadre, UDim2.fromOffset(12, 100), UDim2.new(1, -24, 0, 22), COULEURS.cyan)

local objectif = Instance.new("TextLabel")
objectif.Name = "Objectif"
objectif.AnchorPoint = Vector2.new(0.5, 1)
objectif.Position = UDim2.new(0.5, 0, 1, -100)
objectif.Size = UDim2.new(0.7, 0, 0, 40)
objectif.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
objectif.BackgroundTransparency = 0.25
objectif.TextColor3 = COULEURS.blanc
objectif.TextScaled = true
objectif.Font = Enum.Font.FredokaOne
objectif.Parent = ecran
local coinsObjectif = Instance.new("UICorner")
coinsObjectif.CornerRadius = UDim.new(0, 10)
coinsObjectif.Parent = objectif
local margeObjectif = Instance.new("UIPadding")
margeObjectif.PaddingLeft = UDim.new(0, 10)
margeObjectif.PaddingRight = UDim.new(0, 10)
margeObjectif.Parent = objectif

-- La grosse flèche, posée au-dessus de la cible
local fleche = Instance.new("BillboardGui")
fleche.Name = "Fleche"
fleche.Size = UDim2.fromOffset(90, 110)
fleche.StudsOffset = Vector3.new(0, 7, 0)
fleche.AlwaysOnTop = true
fleche.Enabled = false
fleche.Parent = ecran
local symbole = Instance.new("TextLabel")
symbole.Size = UDim2.fromScale(1, 0.7)
symbole.BackgroundTransparency = 1
symbole.Text = "▼"
symbole.TextColor3 = COULEURS.or_
symbole.TextStrokeTransparency = 0
symbole.TextScaled = true
symbole.Font = Enum.Font.GothamBlack
symbole.Parent = fleche
local distance = Instance.new("TextLabel")
distance.Position = UDim2.fromScale(0, 0.7)
distance.Size = UDim2.fromScale(1, 0.3)
distance.BackgroundTransparency = 1
distance.TextColor3 = COULEURS.blanc
distance.TextStrokeTransparency = 0
distance.TextScaled = true
distance.Font = Enum.Font.FredokaOne
distance.Parent = fleche

-- Petit rebond de la flèche
task.spawn(function()
	while true do
		TweenService:Create(fleche, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { StudsOffset = Vector3.new(0, 8, 0) }):Play()
		task.wait(0.5)
		TweenService:Create(fleche, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { StudsOffset = Vector3.new(0, 6.5, 0) }):Play()
		task.wait(0.5)
	end
end)

---------------------------------------------------------------------------
-- Messages qui apparaissent au centre de l'écran
---------------------------------------------------------------------------
local pileMessages = 0
local function afficherMessage(texte, nomCouleur)
	pileMessages = pileMessages + 1
	local decalage = (pileMessages % 3) * 0.06
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.3 + decalage)
	l.Size = UDim2.new(0.6, 0, 0, 44)
	l.BackgroundTransparency = 1
	l.TextColor3 = COULEURS[nomCouleur] or COULEURS.blanc
	l.TextStrokeTransparency = 0.1
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.Text = texte
	l.Parent = ecran
	task.delay(2.5, function()
		TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	Debris:AddItem(l, 3.2)
end

evenement.OnClientEvent:Connect(function(type, texte, couleur)
	if type == "Message" then
		afficherMessage(texte, couleur)
	end
end)

---------------------------------------------------------------------------
-- Objectif et cible de la flèche
---------------------------------------------------------------------------
local function maPosition()
	local perso = joueur.Character
	local r = perso and perso:FindFirstChild("HumanoidRootPart")
	return r and r.Position
end

local function plusProche(parts, depuis)
	local meilleur, meilleureDistance = nil, math.huge
	for _, p in ipairs(parts) do
		local d = (p.Position - depuis).Magnitude
		if d < meilleureDistance then
			meilleur, meilleureDistance = p, d
		end
	end
	return meilleur
end

local function chercherObjectif(position)
	local camp = joueur.Team and joueur.Team.Name

	if camp == "Gardiens" then
		local cibles = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if p ~= joueur and p.Team and p.Team.Name == "Malins" and (p:GetAttribute("Etoiles") or 0) > 0 and r then
				table.insert(cibles, r)
			end
		end
		if #cibles > 0 then
			return plusProche(cibles, position), "Attrape le Malin recherché : touche-le !"
		end
		return nil, "Patrouille dans la rue : les Malins avec des étoiles sont à attraper."
	end

	local etoiles = joueur:GetAttribute("Etoiles") or 0
	local butin = joueur:GetAttribute("Butin")
	if etoiles > 0 then
		return rideauCabine, "Tu es recherché ! Cours à la cabine de déguisement sur la plage."
	end
	if butin then
		return depot, "Rapporte ton " .. butin .. " à la planque, dans le marais."
	end

	local caisses = {}
	for _, boutique in ipairs(rue:GetChildren()) do
		local caisse = boutique:FindFirstChild("Caisse")
		local prompt = caisse and caisse:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt and prompt.Enabled then
			table.insert(caisses, caisse)
		end
	end
	if #caisses > 0 then
		return plusProche(caisses, position), "Fais un coup : maintiens le bouton devant une caisse."
	end
	return nil, "Les boutiques sont fermées un moment... entraîne-toi à Muscle Beach !"
end

local function formaterTemps(secondes)
	secondes = math.max(0, math.floor(secondes))
	return string.format("%d:%02d", math.floor(secondes / 60), secondes % 60)
end

while true do
	local position = maPosition()
	if position then
		local cible, texte = chercherObjectif(position)
		objectif.Text = texte
		if cible then
			fleche.Adornee = cible
			fleche.Enabled = true
			distance.Text = math.floor((cible.Position - position).Magnitude) .. " m"
		else
			fleche.Enabled = false
		end
	end

	local camp = joueur.Team and joueur.Team.Name or "?"
	if camp == "Gardiens" then
		texteCamp.Text = "GARDIEN"
		texteCamp.TextColor3 = COULEURS.bleu
	else
		texteCamp.Text = "MALIN"
		texteCamp.TextColor3 = COULEURS.orange
	end

	local etoiles = joueur:GetAttribute("Etoiles") or 0
	texteEtoiles.Text = string.rep("★", etoiles) .. string.rep("☆", 3 - etoiles)

	local stats = joueur:FindFirstChild("leaderstats")
	local billets = stats and stats:FindFirstChild("Billets")
	texteBillets.Text = "Billets : " .. (billets and billets.Value or 0)

	local fin = ReplicatedStorage:GetAttribute("FinManche")
	if fin then
		texteManche.Text = "Changement de camp : " .. formaterTemps(fin - Workspace:GetServerTimeNow())
	end

	task.wait(0.25)
end
