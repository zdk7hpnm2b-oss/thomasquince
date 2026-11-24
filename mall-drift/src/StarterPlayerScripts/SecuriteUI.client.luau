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
barre.Font = Enum.Font.FredokaOne
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
	l.Font = Enum.Font.FredokaOne
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

---------------------------------------------------------------------
-- 💓 TENSION : quand un policier se rapproche, le cœur bat de plus en plus vite
-- (contour rouge qui pulse en « boum-boum », + « !! » au centre)
---------------------------------------------------------------------
local camera = workspace.CurrentCamera
local vignette = {}
for _, info in ipairs({
	{ UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0), 90 },
	{ UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0.78), -90 },
	{ UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0 },
	{ UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0.84, 0), 180 },
}) do
	local f = Instance.new("Frame")
	f.Size = info[1]
	f.Position = info[2]
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(200, 0, 20)
	f.BackgroundTransparency = 1
	f.ZIndex = 2
	f.Parent = gui
	local d = Instance.new("UIGradient") -- rouge au bord, transparent vers le centre
	d.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	d.Rotation = info[3]
	d.Parent = f
	table.insert(vignette, f)
end
local alerteProche = Instance.new("TextLabel")
alerteProche.AnchorPoint = Vector2.new(0.5, 0.5)
alerteProche.Size = UDim2.fromOffset(90, 70)
alerteProche.Position = UDim2.fromScale(0.5, 0.2)
alerteProche.BackgroundTransparency = 1
alerteProche.Font = Enum.Font.FredokaOne
alerteProche.TextScaled = true
alerteProche.TextColor3 = Color3.fromRGB(255, 60, 60)
alerteProche.Text = "!!"
alerteProche.Visible = false
alerteProche.ZIndex = 3
alerteProche.Parent = gui
local contourProche = Instance.new("UIStroke")
contourProche.Thickness = 3
contourProche.Color = Color3.new(1, 1, 1)
contourProche.Parent = alerteProche
local echelleProche = Instance.new("UIScale")
echelleProche.Parent = alerteProche

local function maPosition(): Vector3?
	local perso = joueur.Character
	local h = perso and perso:FindFirstChildOfClass("Humanoid")
	local siege = h and h.SeatPart
	if siege then
		return siege.Position
	end
	local racine = perso and perso:FindFirstChild("HumanoidRootPart") :: BasePart?
	return racine and racine.Position or nil
end

-- Distance du policier le plus proche (police du mall en kart, ou police en ligne)
local function policierLePlusProche(moi: Vector3): number
	local meilleur = math.huge
	local monRole = joueur:GetAttribute("Role")
	if monRole == "Police" or monRole == "Battle" or monRole == "Chrono" then
		return meilleur
	end
	local securite = workspace:FindFirstChild("Securite")
	if securite and monRole == nil then
		for _, g in ipairs(securite:GetChildren()) do
			local racine = g:FindFirstChild("HumanoidRootPart") :: BasePart?
			if racine and g:FindFirstChild("KartPolice", true) then
				meilleur = math.min(meilleur, (racine.Position - moi).Magnitude)
			end
		end
	end
	if monRole == "Fugitif" then
		for _, nom in ipairs({ "KartsJoueurs", "BotsManche" }) do
			local dossier = workspace:FindFirstChild(nom)
			if dossier then
				for _, m in ipairs(dossier:GetChildren()) do
					if m:IsA("Model") and m:GetAttribute("Role") == "Police" then
						local p = m:GetPivot().Position
						meilleur = math.min(meilleur, (p - moi).Magnitude)
					end
				end
			end
		end
	end
	return meilleur
end

local phaseCoeur = 0
local prochaineVerif = 0
local tension = 0 -- 0 = calme, 1 = le policier est collé à toi
RunService.RenderStepped:Connect(function(dt)
	local maintenant = os.clock()
	if maintenant > prochaineVerif then
		prochaineVerif = maintenant + 0.2
		local moi = maPosition()
		local d = if moi then policierLePlusProche(moi) else math.huge
		tension = math.clamp((45 - d) / (45 - 8), 0, 1)
	end
	if tension <= 0 then
		for _, f in ipairs(vignette) do
			f.BackgroundTransparency = 1
		end
		alerteProche.Visible = false
		return
	end
	-- Le cœur bat de 80 à 190 battements par minute selon la proximité
	local bpm = 80 + 110 * tension
	phaseCoeur = (phaseCoeur + dt * bpm / 60) % 1
	-- « boum-boum » : deux pulsations rapprochées à chaque battement
	local pulse = math.max(math.exp(-((phaseCoeur - 0.05) ^ 2) / 0.002), 0.7 * math.exp(-((phaseCoeur - 0.22) ^ 2) / 0.002))
	for _, f in ipairs(vignette) do
		f.BackgroundTransparency = 1 - (0.25 + 0.55 * pulse) * tension
	end
	alerteProche.Visible = tension > 0.45
	echelleProche.Scale = 1 + 0.35 * pulse
end)

---------------------------------------------------------------------
-- 🚔 L'ARRESTATION : gyrophares en rafale, caméra qui se jette sur toi,
-- barreaux de prison qui tombent et tampon « ATTRAPÉ ! » qui s'écrase
---------------------------------------------------------------------
local stroboscope = Instance.new("Frame")
stroboscope.Size = UDim2.fromScale(1, 1)
stroboscope.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
stroboscope.BackgroundTransparency = 1
stroboscope.BorderSizePixel = 0
stroboscope.ZIndex = 6
stroboscope.Parent = gui
local barreaux = {}
for i = 1, 9 do
	local b = Instance.new("Frame")
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Size = UDim2.new(0, 26, 1, 0)
	b.Position = UDim2.new(i / 10, 0, 0, 0)
	b.BackgroundColor3 = Color3.fromRGB(40, 42, 48)
	b.BorderSizePixel = 0
	b.Visible = false
	b.ZIndex = 7
	b.Parent = gui
	local reflet = Instance.new("UIGradient")
	reflet.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 62, 70)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(170, 175, 185)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 42, 48)),
	})
	reflet.Parent = b
	table.insert(barreaux, b)
end
local tampon = Instance.new("TextLabel")
tampon.AnchorPoint = Vector2.new(0.5, 0.5)
tampon.Size = UDim2.new(0.7, 0, 0, 120)
tampon.Position = UDim2.fromScale(0.5, 0.42)
tampon.BackgroundTransparency = 1
tampon.Font = Enum.Font.FredokaOne
tampon.TextScaled = true
tampon.TextColor3 = Color3.fromRGB(255, 50, 50)
tampon.Text = "🚔 ATTRAPÉ !"
tampon.Visible = false
tampon.ZIndex = 8
tampon.Parent = gui
local contourTampon = Instance.new("UIStroke")
contourTampon.Thickness = 6
contourTampon.Color = Color3.new(1, 1, 1)
contourTampon.Parent = tampon
local echelleTampon = Instance.new("UIScale")
echelleTampon.Parent = tampon
local sousTampon = Instance.new("TextLabel")
sousTampon.AnchorPoint = Vector2.new(0.5, 0)
sousTampon.Size = UDim2.new(0.6, 0, 0, 40)
sousTampon.Position = UDim2.fromScale(0.5, 0.53)
sousTampon.BackgroundTransparency = 1
sousTampon.Font = Enum.Font.FredokaOne
sousTampon.TextScaled = true
sousTampon.TextColor3 = Color3.new(1, 1, 1)
sousTampon.Visible = false
sousTampon.ZIndex = 8
sousTampon.Parent = gui
local contourSous = Instance.new("UIStroke")
contourSous.Thickness = 3
contourSous.Parent = sousTampon

local enArrestation = false
local function animationArrestation(parQui: string?, avecFondu: boolean)
	if enArrestation then
		return
	end
	enArrestation = true
	local debut = os.clock()
	-- 1) Caméra : elle se jette sur toi (zoom brutal) et tremble
	local champAvant = camera.FieldOfView
	RunService:BindToRenderStep("CameraArrestation", Enum.RenderPriority.Camera.Value + 30, function()
		local t = os.clock() - debut
		if t > 1.6 then
			return
		end
		local force = math.max(0, 1 - t / 1.6)
		camera.FieldOfView = champAvant - 25 * math.min(t / 0.25, 1) * (0.5 + 0.5 * force)
		local secousse = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * 0.9 * force
		camera.CFrame = camera.CFrame * CFrame.new(secousse) * CFrame.Angles(0, 0, (math.random() - 0.5) * 0.06 * force)
	end)
	-- 2) Gyrophares en rafale (rouge / bleu sur tout l'écran)
	task.spawn(function()
		for i = 1, 12 do
			stroboscope.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(40, 90, 255) else Color3.fromRGB(255, 40, 40)
			stroboscope.BackgroundTransparency = 0.45
			task.wait(0.06)
			stroboscope.BackgroundTransparency = 0.85
			task.wait(0.04)
		end
		stroboscope.BackgroundTransparency = 1
	end)
	-- 3) Les barreaux de prison tombent et rebondissent
	for i, b in ipairs(barreaux) do
		b.Visible = true
		b.Position = UDim2.new(i / 10, 0, 0, 0)
		task.delay(0.15 + i * 0.025, function()
			TweenService:Create(b, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { Position = UDim2.new(i / 10, 0, 1, 0) }):Play()
		end)
	end
	-- 4) Le tampon « ATTRAPÉ ! » s'écrase (de très gros à normal, un peu penché)
	task.delay(0.35, function()
		tampon.Visible = true
		tampon.TextTransparency = 0
		contourTampon.Transparency = 0
		tampon.Rotation = -14
		echelleTampon.Scale = 3.2
		TweenService:Create(echelleTampon, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 }):Play()
		TweenService:Create(tampon, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rotation = -8 }):Play()
		sousTampon.Text = if parQui then ("par %s"):format(parQui) else "La sécurité du mall t'a eu…"
		task.wait(0.25)
		sousTampon.Visible = true
	end)
	-- 5) Fin : fondu au noir (retour au garage) ou on laisse la place à l'écran suivant
	-- (le serveur ramène au garage 2,2 s après l'arrestation : l'écran est noir avant)
	task.delay(if avecFondu then 1.7 else 1.9, function()
		if avecFondu then
			TweenService:Create(noir, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
			task.wait(0.4)
		end
		RunService:UnbindFromRenderStep("CameraArrestation")
		camera.FieldOfView = champAvant
		tampon.Visible = false
		sousTampon.Visible = false
		for _, b in ipairs(barreaux) do
			b.Visible = false
		end
		if avecFondu then
			task.wait(1)
			TweenService:Create(noir, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		end
		enArrestation = false
	end)
end

-- Mode en ligne : PartieUI demande l'animation (vie perdue / plus de vies)
joueur:GetAttributeChangedSignal("AnimArrestation"):Connect(function()
	local valeur = joueur:GetAttribute("AnimArrestation")
	if type(valeur) == "string" and valeur ~= "" then
		local parQui = string.match(valeur, "^(.-)|")
		animationArrestation(parQui, false)
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
		animationArrestation(nil, true) -- (gyrophares, barreaux, tampon, puis fondu au noir)
	end
end)
