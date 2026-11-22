--[[
	KartController  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : KartController

	Gère tout ce que le joueur ressent quand il conduit :
	  • la conduite et le DRIFT (glisse, 360°)
	  • le SCORE de drift : plus il est long et beau, plus il rapporte (avec étoiles ★)
	  • le SOL MOUILLÉ : ça glisse énormément + éclaboussures sur l'écran
	  • la caméra 1re personne (V), jour/nuit (N), remettre le kart droit (R)

	Commandes :
	  Avancer / reculer / tourner : flèches, ZQSD (ou WASD), manette, joystick mobile
	  Drift : Maj (Shift) — gâchette R2/L2 — bouton DRIFT sur mobile
	  Descendre du kart : Espace (saut)
	Les points de drift deviennent de l'XP : en montant de niveau, on débloque
	des karts, des couleurs et des décos au GARAGE VIP.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local controles = require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

---------------------------------------------------------------------
-- INTERFACE (créée par le code, rien à dessiner)
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MallDriftHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = joueur:WaitForChild("PlayerGui")

local function label(nom: string, parent: Instance, taille: UDim2, position: UDim2, texteTaille: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = nom
	l.Size = taille
	l.Position = position
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = texteTaille == nil
	if texteTaille then
		l.TextSize = texteTaille
	end
	l.Text = ""
	local contour = Instance.new("UIStroke")
	contour.Thickness = 2
	contour.Color = Color3.fromRGB(20, 20, 30)
	contour.Parent = l
	l.Parent = parent
	return l
end

-- Écran des éclaboussures (en dessous du reste)
local ecranEau = Instance.new("Frame")
ecranEau.Name = "Eclaboussures"
ecranEau.Size = UDim2.fromScale(1, 1)
ecranEau.BackgroundTransparency = 1
ecranEau.ZIndex = 1
ecranEau.Parent = gui

local hud = Instance.new("Frame")
hud.Name = "HUD"
hud.Size = UDim2.fromScale(1, 1)
hud.BackgroundTransparency = 1
hud.ZIndex = 5
hud.Visible = false
hud.Parent = gui

-- Niveau du joueur + barre d'XP (toujours visible, en haut à gauche)
local blocNiveau = Instance.new("Frame")
blocNiveau.Name = "NiveauJoueur"
blocNiveau.Size = UDim2.new(0, 300, 0, 64)
blocNiveau.Position = UDim2.new(0, 16, 0, 56)
blocNiveau.BackgroundTransparency = 1
blocNiveau.ZIndex = 5
blocNiveau.Parent = gui
local niveauLabel = label("Niveau", blocNiveau, UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0))
niveauLabel.TextXAlignment = Enum.TextXAlignment.Left
niveauLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
niveauLabel.Text = "NIV. 1"
local fondBarre = Instance.new("Frame")
fondBarre.Size = UDim2.new(1, 0, 0, 12)
fondBarre.Position = UDim2.new(0, 0, 0, 32)
fondBarre.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
fondBarre.BackgroundTransparency = 0.3
fondBarre.Parent = blocNiveau
Instance.new("UICorner", fondBarre).CornerRadius = UDim.new(0.5, 0)
local barreXP = Instance.new("Frame")
barreXP.Size = UDim2.fromScale(0, 1)
barreXP.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
barreXP.Parent = fondBarre
Instance.new("UICorner", barreXP).CornerRadius = UDim.new(0.5, 0)
local xpLabel = label("XP", blocNiveau, UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 47))
xpLabel.TextXAlignment = Enum.TextXAlignment.Left
xpLabel.TextTransparency = 0.2

local scoreLabel = label("Score", hud, UDim2.new(0, 320, 0, 40), UDim2.new(1, -336, 0, 56))
scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
local meilleurLabel = label("Meilleur", hud, UDim2.new(0, 320, 0, 22), UDim2.new(1, -336, 0, 98))
meilleurLabel.TextXAlignment = Enum.TextXAlignment.Right
meilleurLabel.TextColor3 = Color3.fromRGB(255, 215, 80)

local vitesseLabel = label("Vitesse", hud, UDim2.new(0, 220, 0, 48), UDim2.new(0, 16, 1, -120))
vitesseLabel.TextXAlignment = Enum.TextXAlignment.Left

local aide = label("Aide", hud, UDim2.new(1, -32, 0, 18), UDim2.new(0, 16, 1, -30))
aide.TextXAlignment = Enum.TextXAlignment.Left
aide.TextTransparency = 0.25
aide.Text = "Maj : DRIFT  ·  V : caméra  ·  N : jour/nuit  ·  R : redresser  ·  Espace : descendre  ·  Garage VIP : personnaliser ton kart"

-- Le compteur de drift (au centre, en bas)
local blocDrift = Instance.new("Frame")
blocDrift.Name = "Drift"
blocDrift.AnchorPoint = Vector2.new(0.5, 1)
blocDrift.Size = UDim2.new(0, 360, 0, 130)
blocDrift.Position = UDim2.new(0.5, 0, 1, -70)
blocDrift.BackgroundTransparency = 1
blocDrift.Visible = false
blocDrift.Parent = hud
local etoilesLabel = label("Etoiles", blocDrift, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 0))
etoilesLabel.TextColor3 = Color3.fromRGB(255, 210, 40)
local pointsLabel = label("Points", blocDrift, UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0, 40))
local comboLabel = label("Combo", blocDrift, UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 98))
comboLabel.TextColor3 = Color3.fromRGB(120, 220, 255)

-- Messages qui apparaissent au milieu (« SUPER DRIFT ★★ », « 360° ! »…)
local function message(texte: string, couleur: Color3?, duree: number?)
	local m = label("Message", gui, UDim2.new(0, 600, 0, 60), UDim2.new(0.5, -300, 0.28, 0))
	m.Text = texte
	m.TextColor3 = couleur or Color3.new(1, 1, 1)
	m.ZIndex = 10
	local echelle = Instance.new("UIScale")
	echelle.Scale = 0.4
	echelle.Parent = m
	TweenService:Create(echelle, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duree or 1.4, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(m, info, { TextTransparency = 1, Position = m.Position - UDim2.fromOffset(0, 30) }):Play()
		local contour = m:FindFirstChildOfClass("UIStroke")
		if contour then
			TweenService:Create(contour, info, { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		m:Destroy()
	end)
end

---------------------------------------------------------------------
-- ÉCLABOUSSURES SUR L'ÉCRAN
---------------------------------------------------------------------
local function goutte()
	local taille = math.random(50, 170)
	local g = Instance.new("Frame")
	g.Size = UDim2.fromOffset(taille, taille)
	g.Position = UDim2.new(math.random(), -taille / 2, math.random() * 0.85, -taille / 2)
	g.BackgroundColor3 = Color3.fromRGB(190, 225, 255)
	g.BackgroundTransparency = 0.55
	g.ZIndex = 2
	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0.5, 0)
	coin.Parent = g
	local bord = Instance.new("UIStroke")
	bord.Color = Color3.new(1, 1, 1)
	bord.Thickness = 2
	bord.Transparency = 0.35
	bord.Parent = g
	-- petit reflet de lumière dans la goutte
	local reflet = Instance.new("Frame")
	reflet.Size = UDim2.fromScale(0.25, 0.25)
	reflet.Position = UDim2.fromScale(0.2, 0.18)
	reflet.BackgroundColor3 = Color3.new(1, 1, 1)
	reflet.BackgroundTransparency = 0.3
	reflet.ZIndex = 3
	local coin2 = Instance.new("UICorner")
	coin2.CornerRadius = UDim.new(0.5, 0)
	coin2.Parent = reflet
	reflet.Parent = g
	g.Parent = ecranEau

	-- la goutte coule vers le bas puis disparaît
	local duree = math.random(12, 22) / 10
	local info = TweenInfo.new(duree, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(g, info, { BackgroundTransparency = 1, Position = g.Position + UDim2.fromScale(0, 0.08) }):Play()
	TweenService:Create(bord, info, { Transparency = 1 }):Play()
	TweenService:Create(reflet, info, { BackgroundTransparency = 1 }):Play()
	task.delay(duree + 0.1, function()
		g:Destroy()
	end)
end

local function grosseEclaboussure()
	-- flash bleuté + plein de gouttes
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(170, 215, 255)
	flash.BackgroundTransparency = 0.6
	flash.ZIndex = 1
	flash.Parent = ecranEau
	TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	task.delay(0.4, function()
		flash:Destroy()
	end)
	for _ = 1, math.random(7, 11) do
		goutte()
	end
end

---------------------------------------------------------------------
-- ÉTAT DU JEU
---------------------------------------------------------------------
local kart = nil -- { modele, chassis, stats, trails, fumees, eaux, sons }
local driftAppuye = false
local driftAppuyeAvant = false
local vitesseRotation = 0
local tempsBoost = 0
local forceBoost = 1 -- puissance du boost en cours (selon les étoiles du drift)
local derniereVitesse = 0
local etaitMouille = false
local prochaineGoutte = 0
local nuit = Lighting:GetAttribute("Nuit")
if nuit == nil then
	nuit = Config.NuitParDefaut
end

local scoreTotal, meilleurDrift = 0, 0
local drift = { actif = false, points = 0, temps = 0, rotation = 0, horsDrift = 0, combo = 1, nb360 = 0 }

local parametresRayon = RaycastParams.new()
parametresRayon.FilterType = Enum.RaycastFilterType.Exclude

local function nombreEtoiles(points: number): number
	local n = 0
	for i, seuil in ipairs(Config.Score.Etoiles) do
		if points >= seuil then
			n = i
		end
	end
	return n
end

local function texteEtoiles(n: number): string
	return string.rep("★", n) .. string.rep("☆", #Config.Score.Etoiles - n)
end

local function majScore()
	scoreLabel.Text = ("SCORE  %d"):format(scoreTotal)
	meilleurLabel.Text = ("RECORD  %d"):format(meilleurDrift)
end
majScore()

-- Profil envoyé par le serveur (niveau, XP, record)
local function afficherProfil(profil, niveauGagne: number?)
	if type(profil) ~= "table" then
		return
	end
	niveauLabel.Text = ("NIV. %d"):format(profil.Niveau)
	local pleinNiveau = profil.Niveau >= Config.NiveauMax
	xpLabel.Text = if pleinNiveau then "NIVEAU MAX !" else ("%d / %d XP"):format(profil.XPDansNiveau, profil.XPRequis)
	local ratio = if pleinNiveau then 1 else math.clamp(profil.XPDansNiveau / profil.XPRequis, 0, 1)
	TweenService:Create(barreXP, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(ratio, 1) }):Play()
	meilleurDrift = math.max(meilleurDrift, profil.Record or 0)
	majScore()
	if niveauGagne then
		message(("NIVEAU %d ! 🎉"):format(niveauGagne), Color3.fromRGB(255, 215, 80), 2.5)
		task.delay(0.8, function()
			message("Nouveautés au GARAGE VIP !", Color3.fromRGB(200, 150, 255), 2)
		end)
	end
end
remotes:WaitForChild("ProfilMisAJour").OnClientEvent:Connect(afficherProfil)
task.spawn(function()
	afficherProfil(remotes:WaitForChild("ObtenirProfil"):InvokeServer())
	-- On attend la fin de l'intro cinématique avant d'afficher les conseils
	local debut = os.clock()
	while not joueur:GetAttribute("IntroFinie") and os.clock() - debut < 12 do
		task.wait(0.2)
	end
	message("Appuie sur F (ou le bouton 🏎️) pour conduire !", Color3.fromRGB(255, 215, 80), 3.5)
	task.wait(3.8)
	message("Borne de l'atelier : E = personnaliser ton kart", Color3.new(1, 1, 1), 3.5)
end)

local function vers(valeur: number, cible: number, pas: number): number
	if valeur < cible then
		return math.min(valeur + pas, cible)
	end
	return math.max(valeur - pas, cible)
end

---------------------------------------------------------------------
-- DRIFT : début / fin / score
---------------------------------------------------------------------
local function terminerDrift(reussi: boolean)
	local points = math.floor(drift.points)
	if reussi and points >= Config.Score.Minimum then
		local etoiles = nombreEtoiles(points)
		scoreTotal += points
		if points > meilleurDrift then
			meilleurDrift = points
		end
		remotes.DriftTermine:FireServer(points) -- le serveur transforme les points en XP
		local titres = { [0] = "PETIT DRIFT", "JOLI DRIFT", "SUPER DRIFT", "DRIFT DE LÉGENDE" }
		local couleurs = { [0] = Color3.new(1, 1, 1), Color3.fromRGB(150, 230, 255), Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 120, 220) }
		local titre = titres[math.min(etoiles, 3)]
		message(("%s %s  +%d"):format(titre, etoiles > 0 and texteEtoiles(etoiles) or "", points), couleurs[math.min(etoiles, 3)], 1.8)
		-- Un beau drift = un BOOST (plus il y a d'étoiles, plus il est fort)
		local reglageBoost = Config.Score.BoostEtoiles and Config.Score.BoostEtoiles[math.min(etoiles, 3)]
		if reglageBoost then
			-- La police te poursuit ? Boost d'évasion !
			local poursuivi = joueur:GetAttribute("Poursuivi") == true or joueur:GetAttribute("Role") == "Fugitif"
			local multiplicateur = if poursuivi then (Config.Score.BoostEvasion or 1.5) else 1
			tempsBoost = reglageBoost.Duree * (if poursuivi then 1.2 else 1)
			forceBoost = reglageBoost.Force * multiplicateur
			message(if poursuivi then ("🚨 BOOST D'ÉVASION %s !"):format(string.rep("★", etoiles)) else ("BOOST %s !"):format(string.rep("★", etoiles)),
				if poursuivi then Color3.fromRGB(255, 140, 60) else Color3.fromRGB(120, 255, 140), 0.9)
		end
		majScore()
	elseif not reussi and points > 0 then
		message(("OUPS ! DRIFT PERDU  -%d"):format(points), Color3.fromRGB(255, 90, 90), 1.4)
	end
	drift.actif = false
	drift.points, drift.temps, drift.rotation, drift.horsDrift, drift.combo, drift.nb360 = 0, 0, 0, 0, 1, 0
	blocDrift.Visible = false
end

---------------------------------------------------------------------
-- ENTRER / SORTIR DU KART
---------------------------------------------------------------------
local function effets(nomEffet: string): { Instance }
	local liste = {}
	for _, d in ipairs(kart.chassis:GetDescendants()) do
		if d.Name == nomEffet then
			table.insert(liste, d)
		end
	end
	return liste
end

local function creerSon(id: string, boucle: boolean): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = boucle
	s.Volume = 0.5
	s.Parent = kart.chassis
	return s
end

local function actionDrift(_, etat: Enum.UserInputState)
	driftAppuye = etat == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end

---------------------------------------------------------------------
-- CAMÉRA AUTOMATIQUE : elle se place toute seule derrière le kart
-- et tourne avec lui (plus besoin du clic droit).
-- V = alterner entre la « GoPro » (sur la poitrine du pilote, comme les
-- vidéos TikTok) et la vue « derrière le kart »
---------------------------------------------------------------------
local modeCamera = Config.Camera.VueParDefaut or "gopro" -- "gopro" ou "derriere"

-- Séquence de départ : survol de la map (~3 s), la caméra plonge derrière ton
-- kart sur la ligne de départ, puis feux 3, 2, 1, PARTEZ !
local DUREE_SURVOL = 3
local DUREE_PLONGEE = 0.9
local DUREE_ANIM_DEPART = DUREE_SURVOL + DUREE_PLONGEE
-- Les survols possibles (un au hasard à chaque départ) : de -> vers, en regardant "cible"
local SURVOLS = {
	{ nom = "LA FONTAINE", de = Vector3.new(-34, 13, -62), vers = Vector3.new(32, 9, -22), cible = Vector3.new(0, 6, 0) },
	{ nom = "L'AQUARIUM GÉANT", de = Vector3.new(-45, 10, -137), vers = Vector3.new(45, 10, -137), cible = Vector3.new(0, 9, -158) },
	{ nom = "LES BOUTIQUES", de = Vector3.new(-195, 8, 0), vers = Vector3.new(-90, 6, 0), cible = Vector3.new(-40, 4, 0) },
	{ nom = "LE FOOD COURT", de = Vector3.new(-118, 11, 30), vers = Vector3.new(-150, 8, 108), cible = Vector3.new(-136, 3, 72) },
	{ nom = "LES SOLDES", de = Vector3.new(190, 9, -8), vers = Vector3.new(95, 6, 6), cible = Vector3.new(40, 4, 0) },
}
type Depart = { debut: number, etape: number, survol: { [string]: any }, finSurvol: CFrame? }
local depart: Depart? = nil
local departsJoues: { [Instance]: boolean } = {}
local dernierRestePolice = -1

-- Les feux à l'écran (3 grosses lumières en haut au centre)
local blocFeux = Instance.new("Frame")
blocFeux.AnchorPoint = Vector2.new(0.5, 0)
blocFeux.Size = UDim2.new(0, 330, 0, 120)
blocFeux.Position = UDim2.new(0.5, 0, 0.14, 0)
blocFeux.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
blocFeux.BackgroundTransparency = 0.15
blocFeux.Visible = false
blocFeux.ZIndex = 11
blocFeux.Parent = gui
Instance.new("UICorner", blocFeux).CornerRadius = UDim.new(0, 18)
local feuxEcran = {}
for i = 1, 3 do
	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 90, 0, 90)
	f.Position = UDim2.new(0, 15 + (i - 1) * 105, 0, 15)
	f.BackgroundColor3 = Color3.fromRGB(60, 15, 15)
	f.ZIndex = 12
	f.Parent = blocFeux
	Instance.new("UICorner", f).CornerRadius = UDim.new(0.5, 0)
	feuxEcran[i] = f
end
local chiffreDepart = Instance.new("TextLabel")
chiffreDepart.AnchorPoint = Vector2.new(0.5, 0.5)
chiffreDepart.Size = UDim2.new(0, 500, 0, 130)
chiffreDepart.Position = UDim2.fromScale(0.5, 0.48)
chiffreDepart.BackgroundTransparency = 1
chiffreDepart.Font = Enum.Font.GothamBlack
chiffreDepart.TextScaled = true
chiffreDepart.TextColor3 = Color3.new(1, 1, 1)
chiffreDepart.Text = ""
chiffreDepart.ZIndex = 12
local contourChiffre = Instance.new("UIStroke")
contourChiffre.Thickness = 4
contourChiffre.Color = Color3.fromRGB(15, 15, 20)
contourChiffre.Parent = chiffreDepart
chiffreDepart.Parent = gui
local echelleChiffre = Instance.new("UIScale")
echelleChiffre.Parent = chiffreDepart

local noirDepart = Instance.new("Frame")
noirDepart.Size = UDim2.fromScale(1, 1)
noirDepart.BackgroundColor3 = Color3.new(0, 0, 0)
noirDepart.BackgroundTransparency = 1
noirDepart.ZIndex = 20
noirDepart.Parent = gui

-- Les vrais feux du portique (dans le mall), allumés seulement chez toi
local function feuxPortique(): { BasePart }
	local liste = {}
	local carte = workspace:FindFirstChild("GoldenMall")
	local ligne = carte and carte:FindFirstChild("LigneDepart")
	if ligne then
		for i = 1, 3 do
			local f = ligne:FindFirstChild("Feu" .. i)
			if f then
				table.insert(liste, f :: BasePart)
			end
		end
	end
	return liste
end

local ROUGE_FEU = Color3.fromRGB(255, 40, 40)
local VERT_FEU = Color3.fromRGB(40, 255, 90)
local ETEINT = Color3.fromRGB(60, 15, 15)
local function allumerFeux(nombreRouges: number, vert: boolean)
	local portique = feuxPortique()
	for i = 1, 3 do
		local couleur = if vert then VERT_FEU elseif i <= nombreRouges then ROUGE_FEU else ETEINT
		feuxEcran[i].BackgroundColor3 = couleur
		if portique[i] then
			portique[i].Color = couleur
		end
	end
end

local function afficherChiffre(texte: string, couleur: Color3)
	chiffreDepart.Text = texte
	chiffreDepart.TextColor3 = couleur
	chiffreDepart.TextTransparency = 0
	contourChiffre.Transparency = 0
	echelleChiffre.Scale = 1.8
	TweenService:Create(echelleChiffre, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local bandesCinema = {}
for _, haut in ipairs({ true, false }) do
	local b = Instance.new("Frame")
	b.Size = UDim2.new(1, 0, 0.11, 0)
	b.Position = if haut then UDim2.fromScale(0, -0.12) else UDim2.fromScale(0, 1.01)
	b.BackgroundColor3 = Color3.new(0, 0, 0)
	b.BorderSizePixel = 0
	b.ZIndex = 9
	b.Parent = gui
	table.insert(bandesCinema, { cadre = b, haut = haut })
end
local function afficherBandes(visible: boolean)
	for _, b in ipairs(bandesCinema) do
		local cible = if visible then (if b.haut then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 0.89))
			else (if b.haut then UDim2.fromScale(0, -0.12) else UDim2.fromScale(0, 1.01))
		TweenService:Create(b.cadre, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Position = cible }):Play()
	end
end
local directionCamera = Vector3.new(0, 0, -1)
local rayonCamera = RaycastParams.new()
rayonCamera.FilterType = Enum.RaycastFilterType.Exclude

-- En vue GoPro, on cache la tête et le buste (la caméra est dessus) mais on
-- garde les bras et les jambes visibles, comme dans les vraies vidéos.
local PARTIES_CACHEES = { Head = true, UpperTorso = true, Torso = true, HumanoidRootPart = true }
local function cacherPilote(cacher: boolean)
	local perso = joueur.Character
	if not perso then
		return
	end
	for _, p in ipairs(perso:GetDescendants()) do
		if p:IsA("BasePart") then
			local aCacher = PARTIES_CACHEES[p.Name] or p:FindFirstAncestorOfClass("Accessory") ~= nil
			p.LocalTransparencyModifier = (cacher and aCacher) and 1 or 0
		elseif p:IsA("Decal") then
			p.LocalTransparencyModifier = cacher and 1 or 0
		end
	end
end

local function mettreAJourCamera(dt: number)
	if not kart or not kart.chassis.Parent then
		return
	end
	local ch = kart.chassis
	local reglages = Config.Camera
	local avant = Vector3.new(ch.CFrame.LookVector.X, 0, ch.CFrame.LookVector.Z)
	if avant.Magnitude < 0.1 then
		return
	end
	avant = avant.Unit

	if depart and os.clock() - depart.debut < DUREE_ANIM_DEPART then
		cacherPilote(false)
		local t = os.clock() - depart.debut
		local s = depart.survol
		if t < DUREE_SURVOL then
			-- 1) Survol d'un coin de la map
			local a = t / DUREE_SURVOL
			a = a * a * (3 - 2 * a)
			local cf = CFrame.lookAt(s.de:Lerp(s.vers, a), s.cible)
			depart.finSurvol = cf
			camera.CFrame = cf
		else
			-- 2) La caméra plonge derrière ton kart, sur la ligne de départ
			local a = math.clamp((t - DUREE_SURVOL) / DUREE_PLONGEE, 0, 1)
			a = a * a * (3 - 2 * a)
			local derriere = CFrame.lookAt(ch.Position - avant * 12 + Vector3.new(0, 4.5, 0), ch.Position + avant * 8 + Vector3.new(0, 2, 0))
			camera.CFrame = (depart.finSurvol or derriere):Lerp(derriere, a)
		end
		return
	end

	if modeCamera == "gopro" then
		cacherPilote(true)
		-- GoPro fixée sur la poitrine : on voit le volant, les mains, les jambes et le sol
		local vitesseG = Vector3.new(ch.AssemblyLinearVelocity.X, 0, ch.AssemblyLinearVelocity.Z)
		local glisse = vitesseG:Dot(Vector3.new(-avant.Z, 0, avant.X)) -- vitesse sur le côté
		local inclinaison = math.clamp(-glisse * 0.006, -0.12, 0.12) -- la caméra penche dans les drifts
		local tremble = math.clamp(vitesseG.Magnitude, 0, 80) * 0.0009
		local secousse = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * tremble
		local plat = CFrame.lookAt(ch.Position, ch.Position + avant)
		local oeil = plat * CFrame.new(0, 2.9, 0.15) + secousse
		camera.CFrame = CFrame.lookAt(oeil.Position, (plat * CFrame.new(0, 0.2, -7)).Position) * CFrame.Angles(0, 0, inclinaison)
		return
	end

	-- Direction suivie : surtout l'avant du kart, un peu le sens de la glisse (on voit le drift)
	local vel = Vector3.new(ch.AssemblyLinearVelocity.X, 0, ch.AssemblyLinearVelocity.Z)
	local cible = avant
	if vel.Magnitude > 8 then
		local sens = if vel:Dot(avant) < 0 then avant else vel.Unit
		cible = (avant * (1 - reglages.SuiviGlisse) + sens * reglages.SuiviGlisse)
		if cible.Magnitude < 0.1 then
			cible = avant
		end
		cible = cible.Unit
	end
	local lissage = 1 - math.exp(-reglages.Souplesse * dt)
	local nouvelle = directionCamera:Lerp(cible, lissage)
	if nouvelle.Magnitude > 0.1 then
		directionCamera = nouvelle.Unit
	end

	local vitesse = vel.Magnitude
	local distance = reglages.Distance + math.clamp(vitesse, 0, 70) * 0.04
	local pivot = ch.Position + Vector3.new(0, 2.5, 0)
	local voulu = ch.Position - directionCamera * distance + Vector3.new(0, reglages.Hauteur, 0)
	-- Si un mur est entre le kart et la caméra, on rapproche la caméra
	rayonCamera.FilterDescendantsInstances = { kart.modele, joueur.Character }
	local obstacle = workspace:Raycast(pivot, voulu - pivot, rayonCamera)
	if obstacle and obstacle.Instance.CanCollide then
		voulu = obstacle.Position + (pivot - voulu).Unit * 1
	end
	camera.CFrame = CFrame.lookAt(voulu, ch.Position + directionCamera * 6 + Vector3.new(0, 2, 0))
end

local function demarrerCamera()
	if kart then
		local lv = kart.chassis.CFrame.LookVector
		directionCamera = Vector3.new(lv.X, 0, lv.Z).Unit
	end
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:UnbindFromRenderStep("MallDriftCamera")
	RunService:BindToRenderStep("MallDriftCamera", Enum.RenderPriority.Camera.Value + 1, mettreAJourCamera)
end

local function arreterCamera()
	RunService:UnbindFromRenderStep("MallDriftCamera")
	cacherPilote(false)
	camera.CameraType = Enum.CameraType.Custom
end

local function actionCamera(_, etat: Enum.UserInputState)
	if etat == Enum.UserInputState.Begin then
		modeCamera = if modeCamera == "derriere" then "gopro" else "derriere"
		if modeCamera == "derriere" then
			cacherPilote(false)
		end
		message(if modeCamera == "gopro" then "*CAMÉRA GOPRO* 🎥" else "*VUE ARRIÈRE* 🎥", Color3.new(1, 1, 1), 0.8)
	end
	return Enum.ContextActionResult.Sink
end

local function actionNuit(_, etat: Enum.UserInputState)
	if etat == Enum.UserInputState.Begin then
		nuit = not nuit
		Config.AppliquerAmbiance(nuit)
		message(nuit and "MODE NUIT 🌙" or "MODE JOUR ☀️", Color3.new(1, 1, 1), 1)
	end
	return Enum.ContextActionResult.Sink
end

local function actionRedresser(_, etat: Enum.UserInputState)
	if etat == Enum.UserInputState.Begin and kart then
		local ch = kart.chassis
		local regard = Vector3.new(ch.CFrame.LookVector.X, 0, ch.CFrame.LookVector.Z)
		if regard.Magnitude < 0.1 then
			regard = Vector3.new(0, 0, -1)
		end
		local pos = ch.Position + Vector3.new(0, 3, 0)
		ch.AssemblyLinearVelocity = Vector3.zero
		ch.AssemblyAngularVelocity = Vector3.zero
		ch.CFrame = CFrame.lookAt(pos, pos + regard.Unit)
	end
	return Enum.ContextActionResult.Sink
end

---------------------------------------------------------------------
-- BOUTON « CONDUIRE » : toujours visible quand on est à pied.
-- Le kart apparaît sous toi et tu es assis dedans automatiquement.
---------------------------------------------------------------------
local boutonConduire = Instance.new("TextButton")
boutonConduire.Name = "Conduire"
boutonConduire.AnchorPoint = Vector2.new(0.5, 1)
boutonConduire.Size = UDim2.new(0, 260, 0, 64)
boutonConduire.Position = UDim2.new(0.5, 0, 1, -40)
boutonConduire.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
boutonConduire.TextColor3 = Color3.fromRGB(25, 25, 30)
boutonConduire.Font = Enum.Font.GothamBlack
boutonConduire.TextScaled = true
boutonConduire.Text = "🏎️ CONDUIRE  (F)"
boutonConduire.ZIndex = 8
boutonConduire.Parent = gui
Instance.new("UICorner", boutonConduire).CornerRadius = UDim.new(0, 14)
local contourBouton = Instance.new("UIStroke")
contourBouton.Thickness = 3
contourBouton.Color = Color3.new(1, 1, 1)
contourBouton.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
contourBouton.Parent = boutonConduire
local margeBouton = Instance.new("UIPadding")
margeBouton.PaddingTop = UDim.new(0, 10)
margeBouton.PaddingBottom = UDim.new(0, 10)
margeBouton.Parent = boutonConduire

local function demanderKart()
	if kart or not joueur:GetAttribute("IntroFinie") or joueur:GetAttribute("MenuGarage") or joueur:GetAttribute("EnSalle") then
		return -- pas pendant l'intro, le menu du garage ou la page d'attente
	end
	boutonConduire.Text = "⏳ ..."
	remotes.SortirKart:FireServer()
	task.delay(1.5, function()
		boutonConduire.Text = "🏎️ CONDUIRE  (F)"
	end)
end
boutonConduire.Activated:Connect(demanderKart)

local function activerToucheConduire(actif: boolean)
	boutonConduire.Visible = actif
	if actif then
		ContextActionService:BindAction("MallDrift_Conduire", function(_, etat)
			if etat == Enum.UserInputState.Begin then
				demanderKart()
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
	else
		ContextActionService:UnbindAction("MallDrift_Conduire")
	end
end
activerToucheConduire(true)

local function sortirDuKart()
	if not kart then
		return
	end
	if drift.actif then
		terminerDrift(true)
	end
	for _, nom in ipairs({ "TracePneu", "Fumee", "Eclaboussures" }) do
		for _, e in ipairs(effets(nom)) do
			(e :: any).Enabled = false
		end
	end
	for _, s in pairs(kart.sons) do
		s:Destroy()
	end
	ContextActionService:UnbindAction("MallDrift_Drift")
	ContextActionService:UnbindAction("MallDrift_Camera")
	ContextActionService:UnbindAction("MallDrift_Nuit")
	ContextActionService:UnbindAction("MallDrift_Redresser")
	if depart then
		depart = nil
		afficherBandes(false)
		blocFeux.Visible = false
		chiffreDepart.Text = ""
	end
	arreterCamera()
	camera.FieldOfView = 70
	driftAppuye = false
	hud.Visible = false
	kart = nil
	activerToucheConduire(true)
end

local function entrerDansKart(siege: Seat)
	local modele = siege.Parent
	local typeKart = modele and modele:GetAttribute("KartType")
	if not typeKart then
		return
	end
	local chassis = modele:WaitForChild("Chassis", 3)
	if not chassis then
		return
	end
	kart = {
		modele = modele,
		chassis = chassis,
		stats = Config.Karts[typeKart],
		sons = {},
	}
	kart.align = chassis:FindFirstChildOfClass("AlignOrientation")
	normaleSol = Vector3.yAxis
	kart.trails = effets("TracePneu")
	kart.fumees = effets("Fumee")
	kart.eaux = effets("Eclaboussures")
	kart.sons.moteur = creerSon(Config.Sons.Moteur, true)
	kart.sons.drift = creerSon(Config.Sons.Drift, true)
	kart.sons.eau = creerSon(Config.Sons.Eclaboussure, false)
	if kart.sons.moteur then
		kart.sons.moteur:Play()
	end

	parametresRayon.FilterDescendantsInstances = { modele, joueur.Character }
	vitesseRotation = 0
	derniereVitesse = 0
	tempsBoost = 0

	ContextActionService:BindActionAtPriority("MallDrift_Drift", actionDrift, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)
	ContextActionService:SetTitle("MallDrift_Drift", "DRIFT")
	ContextActionService:SetPosition("MallDrift_Drift", UDim2.new(1, -170, 1, -150))
	ContextActionService:BindAction("MallDrift_Camera", actionCamera, true, Enum.KeyCode.V, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("MallDrift_Camera", "CAM")
	ContextActionService:SetPosition("MallDrift_Camera", UDim2.new(1, -230, 1, -230))
	ContextActionService:BindAction("MallDrift_Nuit", actionNuit, false, Enum.KeyCode.N)
	ContextActionService:BindAction("MallDrift_Redresser", actionRedresser, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("MallDrift_Redresser", "R")
	ContextActionService:SetPosition("MallDrift_Redresser", UDim2.new(1, -290, 1, -150))

	hud.Visible = true
	activerToucheConduire(false)
	controles:Enable() -- on s'assure que les commandes marchent au volant
	demarrerCamera()
	if modele:GetAttribute("DepartHall") and not departsJoues[modele] then
		departsJoues[modele] = true
		local survol = SURVOLS[math.random(1, #SURVOLS)]
		depart = { debut = os.clock(), etape = 0, survol = survol, finSurvol = nil }
		dernierRestePolice = -1
		hud.Visible = false
		afficherBandes(true)
		allumerFeux(0, false)
		-- Fondu depuis le noir, puis le survol de la map
		noirDepart.BackgroundTransparency = 0
		TweenService:Create(noirDepart, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		message("✦ " .. survol.nom .. " ✦", Color3.fromRGB(255, 215, 80), 2.2)
		task.delay(DUREE_SURVOL, function()
			message("★ EN PLACE SUR LA LIGNE ! ★", Color3.new(1, 1, 1), 1)
		end)
	end
	message(("%s · c'est parti !"):format(kart.stats.Nom), Color3.new(1, 1, 1), 1.5)
end

local function brancherPersonnage(perso: Model)
	local humanoide = perso:WaitForChild("Humanoid") :: Humanoid
	humanoide.Seated:Connect(function(assis: boolean, siege: BasePart?)
		if assis and siege and siege:IsA("Seat") then
			entrerDansKart(siege)
		else
			sortirDuKart()
		end
	end)
	humanoide.Died:Connect(sortirDuKart)
end

if joueur.Character then
	brancherPersonnage(joueur.Character)
end
joueur.CharacterAdded:Connect(brancherPersonnage)

---------------------------------------------------------------------
-- LA CONDUITE (exécutée à chaque image)
---------------------------------------------------------------------
-- Ce qu'il y a sous le kart : "normal", "mouille" ou nil (en l'air), + la pente du sol
-- + la pièce touchée (pour savoir si c'est un tapis roulant)
-- Lecture directe du clavier et de la manette (en plus des commandes Roblox),
-- pour que le kart réponde toujours, même si le module de commandes est coupé
local function toucheBas(...): boolean
	for _, touche in ipairs({ ... }) do
		if UserInputService:IsKeyDown(touche) then
			return true
		end
	end
	return false
end
local function lireCommandesDirectes(): (number, number)
	if UserInputService:GetFocusedTextBox() then
		return 0, 0 -- on écrit dans le chat : pas de conduite
	end
	local K = Enum.KeyCode
	local gaz = (if toucheBas(K.W, K.Z, K.Up) then 1 else 0) - (if toucheBas(K.S, K.Down) then 1 else 0)
	local volant = (if toucheBas(K.D, K.Right) then 1 else 0) - (if toucheBas(K.A, K.Q, K.Left) then 1 else 0)
	for _, etat in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		if etat.KeyCode == K.Thumbstick1 and etat.Position.Magnitude > 0.2 then
			volant = if math.abs(etat.Position.X) > math.abs(volant) then etat.Position.X else volant
			gaz = if math.abs(etat.Position.Y) > math.abs(gaz) then etat.Position.Y else gaz
		elseif etat.KeyCode == K.ButtonR2 and etat.Position.Z > 0.2 and gaz == 0 then
			gaz = etat.Position.Z
		end
	end
	return gaz, volant
end

-- Diagnostic : si le kart ne bouge pas alors que tu accélères, on t'explique pourquoi
local tempsBloque = 0
local diagnosticAffiche = false

local function surfaceSous(chassis: BasePart): (string?, Vector3, BasePart?)
	local resultat = workspace:Raycast(chassis.Position, Vector3.new(0, -3, 0), parametresRayon)
	if not resultat then
		return nil, Vector3.yAxis, nil -- en l'air
	end
	if resultat.Instance:GetAttribute("Mouille") then
		return "mouille", resultat.Normal, resultat.Instance
	end
	return "normal", resultat.Normal, resultat.Instance
end

-- La pente sous le kart (lissée) : permet de monter les rampes du 1er étage
local normaleSol = Vector3.yAxis

RunService.Heartbeat:Connect(function(dt: number)
	if not kart then
		return
	end
	local ch = kart.chassis
	if not ch.Parent then
		sortirDuKart()
		return
	end
	local s = kart.stats
	local cf = ch.CFrame

	-- Direction du kart (à plat)
	local avant = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if avant.Magnitude < 0.1 then
		return
	end
	avant = avant.Unit
	local droite = Vector3.new(-avant.Z, 0, avant.X)

	-- Le sol sous le kart (et sa pente, pour les rampes)
	local surface, normale, pieceSol = surfaceSous(ch)
	local cibleNormale = if surface and normale.Y > 0.6 then normale else Vector3.yAxis
	normaleSol = normaleSol:Lerp(cibleNormale, math.clamp(dt * 10, 0, 1)).Unit
	-- L'avant et le côté du kart, couchés le long de la pente
	local avantPente = (avant - normaleSol * avant:Dot(normaleSol)).Unit
	local droitePente = (droite - normaleSol * droite:Dot(normaleSol)).Unit
	if kart.align then
		kart.align.PrimaryAxis = normaleSol -- le kart s'incline avec la rampe
	end

	-- Vitesse actuelle découpée en "vers l'avant", "sur le côté" et "contre le sol"
	local vel = ch.AssemblyLinearVelocity
	local vAvant = vel:Dot(avantPente)
	local vCote = vel:Dot(droitePente)
	local vSol = vel:Dot(normaleSol)
	-- Dans une pente, la gravité ne freine plus le kart (il monte comme sur du plat)
	if surface and normaleSol.Y < 0.999 then
		vAvant += workspace.Gravity * avantPente.Y * dt
		vCote += workspace.Gravity * droitePente.Y * dt
	end
	local vitesse = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local rotationReelle = ch.AssemblyAngularVelocity.Y

	-- Commandes du joueur (clavier, manette ou joystick mobile)
	local mv = controles:GetMoveVector()
	local gaz = math.clamp(-mv.Z, -1, 1)
	local volant = math.clamp(mv.X, -1, 1)
	local gazDirect, volantDirect = lireCommandesDirectes()
	if math.abs(gazDirect) > math.abs(gaz) then
		gaz = gazDirect
	end
	if math.abs(volantDirect) > math.abs(volant) then
		volant = volantDirect
	end
	if depart then
		local t = os.clock() - depart.debut
		local tCompte = t - DUREE_ANIM_DEPART -- 0 = début du compte à rebours
		if tCompte >= 0 and depart.etape == 0 then
			depart.etape = 1
			afficherBandes(false)
			blocFeux.Visible = true
			allumerFeux(1, false)
			afficherChiffre("3", ROUGE_FEU)
		elseif tCompte >= 1 and depart.etape == 1 then
			depart.etape = 2
			allumerFeux(2, false)
			afficherChiffre("2", ROUGE_FEU)
		elseif tCompte >= 2 and depart.etape == 2 then
			depart.etape = 3
			allumerFeux(3, false)
			afficherChiffre("1", ROUGE_FEU)
		elseif tCompte >= 3 and depart.etape == 3 then
			depart.etape = 4
			allumerFeux(3, true)
			afficherChiffre("PARTEZ ! 🏁", VERT_FEU)
			hud.Visible = true
			controles:Enable()
			local fin = depart
			task.delay(1.2, function()
				if depart == fin then
					depart = nil
				end
				blocFeux.Visible = false
				TweenService:Create(chiffreDepart, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				TweenService:Create(contourChiffre, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				task.delay(3, function()
					allumerFeux(0, false) -- on éteint le portique
				end)
			end)
		end
		if depart and depart.etape < 4 then
			-- Avant le vert : le kart ne bouge pas
			gaz = 0
			volant = 0
			driftAppuye = false
		end
	end
	-- Mode en ligne : la police reste bloquée pendant l'avance des fugitifs
	local bloqueJusqua = kart.modele:GetAttribute("BloqueJusqua")
	if bloqueJusqua and not (depart and depart.etape < 4) then
		local reste = bloqueJusqua - workspace:GetServerTimeNow()
		if reste > 0 then
			gaz = 0
			volant = 0
			driftAppuye = false
			local secondes = math.ceil(reste)
			if secondes ~= dernierRestePolice then
				dernierRestePolice = secondes
				afficherChiffre(("🚓 DÉPART DANS %d"):format(secondes), Color3.fromRGB(90, 150, 255))
			end
		elseif dernierRestePolice ~= 0 then
			dernierRestePolice = 0
			afficherChiffre("🚓 GO ! ATTRAPE-LES !", Color3.fromRGB(90, 150, 255))
			task.delay(1.2, function()
				TweenService:Create(chiffreDepart, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				TweenService:Create(contourChiffre, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end)
		end
	end

	local auSol = surface ~= nil
	local mouille = surface == "mouille"

	tempsBoost = math.max(tempsBoost - dt, 0)

	-- 1) Accélérer / freiner
	local vMax = s.VitesseMax + (if tempsBoost > 0 then s.Boost * forceBoost else 0)
	local cible = if gaz >= 0 then gaz * vMax else gaz * s.VitesseMax * 0.5
	local taux
	if math.abs(gaz) < 0.05 then
		taux = s.Freinage * 0.25 -- roue libre
	elseif math.sign(gaz) ~= math.sign(vAvant) and math.abs(vAvant) > 1 then
		taux = s.Freinage
	else
		taux = s.Acceleration * (tempsBoost > 0 and 2 or 1)
	end
	if mouille then
		taux *= Config.Mouille.Acceleration
	end
	if auSol then
		vAvant = vers(vAvant, cible, taux * dt)
	end

	-- 2) Adhérence : on "efface" plus ou moins vite la glisse sur le côté
	local adherence = if driftAppuye then s.AdherenceDrift else s.Adherence
	-- Plus on va vite, moins les pneus accrochent : le kart part en glisse tout seul à fond
	local glisse = Config.Glisse or { PerteAdherenceAFond = 0.45, CoupDeVolant = 1.6 }
	adherence *= 1 - glisse.PerteAdherenceAFond * math.clamp(math.abs(vAvant) / s.VitesseMax, 0, 1)
	-- Coup de volant : au moment où on déclenche le drift en tournant, l'arrière décroche
	if driftAppuye and not driftAppuyeAvant and math.abs(volant) > 0.3 and math.abs(vAvant) > 12 then
		vitesseRotation += -math.sign(volant) * glisse.CoupDeVolant
		vCote -= math.sign(volant) * math.abs(vAvant) * 0.12 -- l'élan continue tout droit : le kart glisse vers l'extérieur
	end
	driftAppuyeAvant = driftAppuye
	if mouille then
		adherence *= Config.Mouille.Adherence
	end
	if auSol then
		vCote *= math.exp(-adherence * dt)
	end

	-- 3) Tourner (en drift, on tourne beaucoup plus : 360 possibles !)
	local facteur = math.clamp(math.abs(vAvant) / 12, 0, 1)
	if driftAppuye then
		facteur = math.max(facteur, 0.7) -- on peut tourner sur place en drift
	end
	local puissance = s.Rotation * (if driftAppuye then s.RotationDrift else 1)
	local sens = if vAvant < -1 then -1 else 1
	local rotationCible = -volant * puissance * facteur * sens
	vitesseRotation += (rotationCible - vitesseRotation) * math.clamp(dt * 8, 0, 1)

	local nouvelleVitesse = avantPente * vAvant + droitePente * vCote + normaleSol * vSol
	-- Tapis roulant : il t'emporte au moins à sa vitesse, dans son sens
	local sensTapis = pieceSol and pieceSol:GetAttribute("Tapis")
	if typeof(sensTapis) == "Vector3" then
		local vitesseTapis = Config.Tapis and Config.Tapis.Vitesse or 32
		local leLong = nouvelleVitesse:Dot(sensTapis)
		if leLong < vitesseTapis then
			nouvelleVitesse += sensTapis * (vitesseTapis - leLong)
		end
	end
	ch.AssemblyLinearVelocity = nouvelleVitesse
	ch.AssemblyAngularVelocity = normaleSol * vitesseRotation

	-----------------------------------------------------------------
	-- SCORE DE DRIFT
	-----------------------------------------------------------------
	local angleGlisse = math.deg(math.atan2(math.abs(vCote), math.max(math.abs(vAvant), 0.01)))
	local enDrift = auSol and vitesse > Config.Score.VitesseMin and angleGlisse > Config.Score.AngleMin

	-- Choc contre un mur pendant un drift = drift perdu
	if drift.actif and derniereVitesse - vitesse > Config.Score.SeuilChoc then
		terminerDrift(false)
		enDrift = false
	end
	derniereVitesse = vitesse

	if enDrift then
		if not drift.actif then
			drift.actif = true
			blocDrift.Visible = true
		end
		drift.horsDrift = 0
		drift.temps += dt
		drift.combo = math.min(1 + drift.temps * Config.Score.ComboParSeconde, Config.Score.ComboMax)
		-- plus l'angle est beau (jusqu'à ~60°), plus ça rapporte
		local beaute = math.clamp(angleGlisse / 45, 0.3, 1.5)
		local gain = vitesse * beaute * drift.combo * Config.Score.PointsParStud * dt
		if mouille then
			gain *= Config.Mouille.BonusPoints
		end
		drift.points += gain
	elseif drift.actif then
		drift.horsDrift += dt
		if drift.horsDrift > Config.Score.Tolerance then
			terminerDrift(true)
		end
	end

	if drift.actif then
		-- Compter les tours complets (360°)
		drift.rotation += rotationReelle * dt
		if math.abs(drift.rotation) >= 2 * math.pi then
			drift.rotation -= math.sign(drift.rotation) * 2 * math.pi
			drift.nb360 += 1
			local bonus = math.floor(Config.Score.Bonus360 * drift.combo)
			drift.points += bonus
			message(("360° !  +%d"):format(bonus), Color3.fromRGB(255, 150, 60), 1)
		end
		local pts = math.floor(drift.points)
		pointsLabel.Text = ("+%d"):format(pts)
		comboLabel.Text = ("x%.1f%s"):format(drift.combo, mouille and "  💧 BONUS EAU" or "")
		etoilesLabel.Text = texteEtoiles(nombreEtoiles(pts))
	end

	-----------------------------------------------------------------
	-- EFFETS : traces, fumée, eau, éclaboussures sur l'écran, caméra
	-----------------------------------------------------------------
	local traces = drift.actif and auSol and not mouille
	for _, t in ipairs(kart.trails) do
		t.Enabled = traces
	end
	for _, f in ipairs(kart.fumees) do
		f.Enabled = traces and vitesse > 15
	end
	local gerbes = mouille and vitesse > 8
	for _, e in ipairs(kart.eaux) do
		e.Enabled = gerbes
	end

	local maintenant = os.clock()
	if mouille and vitesse > 10 then
		if not etaitMouille then
			grosseEclaboussure()
			if kart.sons.eau then
				kart.sons.eau:Play()
			end
		elseif maintenant > prochaineGoutte then
			goutte()
			prochaineGoutte = maintenant + 0.25
		end
	end
	etaitMouille = mouille

	if kart.sons.moteur then
		kart.sons.moteur.PlaybackSpeed = 0.8 + vitesse / s.VitesseMax * 0.8
	end
	if kart.sons.drift then
		if drift.actif and not kart.sons.drift.IsPlaying then
			kart.sons.drift:Play()
		elseif not drift.actif and kart.sons.drift.IsPlaying then
			kart.sons.drift:Stop()
		end
	end

	-- Sensation de vitesse : le champ de vision s'élargit quand on va vite
	local fovBase = if modeCamera == "gopro" then Config.Camera.ChampGoPro else 70
	local fovCible = fovBase + math.clamp(vitesse, 0, 80) * (if modeCamera == "gopro" then 0.12 else 0.3) + (tempsBoost > 0 and 6 or 0)
	camera.FieldOfView += (fovCible - camera.FieldOfView) * math.clamp(dt * 5, 0, 1)

	vitesseLabel.Text = ("%d km/h"):format(math.floor(vitesse + 0.5))

	-- Diagnostic : on accélère depuis 2,5 s mais le kart ne bouge pas
	if math.abs(gaz) > 0.5 and vitesse < 1.5 and not (depart and depart.etape < 4) then
		tempsBloque += dt
	else
		tempsBloque = 0
	end
	if tempsBloque > 2.5 and not diagnosticAffiche then
		diagnosticAffiche = true
		local controleServeur = ch.ReceiveAge > 0 -- (0 = c'est bien ton ordinateur qui contrôle le kart)
		local raison = if ch.Anchored then "le kart est bloqué (ancré)"
			elseif not auSol then "le kart ne touche pas le sol"
			elseif controleServeur then "le serveur n'a pas donné le contrôle du kart"
			else "obstacle devant le kart ?"
		message("⚠ KART BLOQUÉ : " .. raison .. " · appuie sur R", Color3.fromRGB(255, 120, 80), 5)
		warn(("[Diagnostic kart] bloqué : %s (ReceiveAge=%.2f, au sol=%s, ancré=%s)"):format(raison, ch.ReceiveAge, tostring(auSol), tostring(ch.Anchored)))
		task.delay(6, function()
			diagnosticAffiche = false
		end)
	end
end)

---------------------------------------------------------------------
-- NÉONS ARC-EN-CIEL : ils changent de couleur en continu
---------------------------------------------------------------------
local kartsArcEnCiel: { { parties: { BasePart }, lumieres: { PointLight } } } = {}
local gyrosPolice: { BasePart } = {}
local prochainScan = 0

local function scannerArcEnCiel()
	kartsArcEnCiel = {}
	gyrosPolice = {}
	local candidats = {}
	local dossier = workspace:FindFirstChild("KartsJoueurs")
	if dossier then
		for _, m in ipairs(dossier:GetChildren()) do
			table.insert(candidats, m)
		end
	end
	local apercuGarage = workspace:FindFirstChild("ApercuGarage")
	if apercuGarage then
		table.insert(candidats, apercuGarage)
	end
	for _, m in ipairs(candidats) do
		if m:GetAttribute("Police") then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "GyroPolice" then
					table.insert(gyrosPolice, d)
				end
			end
		end
		if m:GetAttribute("NeonArcEnCiel") then
			local entree = { parties = {}, lumieres = {} }
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and d:GetAttribute("Peinture") == "Neon" then
					table.insert(entree.parties, d)
				elseif d:IsA("PointLight") and d.Name == "LumiereNeon" then
					table.insert(entree.lumieres, d)
				end
			end
			table.insert(kartsArcEnCiel, entree)
		end
	end
end

RunService.Heartbeat:Connect(function()
	local maintenant = os.clock()
	if maintenant > prochainScan then
		prochainScan = maintenant + 1
		scannerArcEnCiel()
	end
	-- Gyrophares police : rouge / bleu qui alternent
	local alterne = math.floor(maintenant * 5) % 2 == 0
	for i, g in ipairs(gyrosPolice) do
		local rouge = (i % 2 == 1) == alterne
		g.Color = if rouge then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(40, 90, 255)
	end
	if #kartsArcEnCiel == 0 then
		return
	end
	local couleur = Color3.fromHSV((maintenant * 0.25) % 1, 0.9, 1)
	for _, k in ipairs(kartsArcEnCiel) do
		for _, p in ipairs(k.parties) do
			p.Color = couleur
		end
		for _, l in ipairs(k.lumieres) do
			l.Color = couleur
		end
	end
end)

---------------------------------------------------------------------
-- TAPIS ROULANTS : les marches défilent (effet visuel, chez toi seulement)
---------------------------------------------------------------------
local marchesTapis: { { part: BasePart, rampe: BasePart, decalage: number } } = {}
local ESPACE_MARCHES = 4

local function preparerTapis()
	local carte = workspace:WaitForChild("GoldenMall", 30)
	local dossierRampes = carte and carte:WaitForChild("Rampes", 30)
	if not dossierRampes then
		return
	end
	local dossierMarches = Instance.new("Folder")
	dossierMarches.Name = "MarchesTapis"
	dossierMarches.Parent = workspace
	for _, rampe in ipairs(dossierRampes:GetChildren()) do
		if rampe:IsA("BasePart") and rampe:GetAttribute("Tapis") then
			local longueur = rampe:GetAttribute("Longueur") or rampe.Size.Z
			for k = 0, math.floor(longueur / ESPACE_MARCHES) - 1 do
				local m = Instance.new("Part")
				m.Name = "Marche"
				m.Size = Vector3.new(rampe.Size.X - 1.4, 0.06, 0.5)
				m.Color = Color3.fromRGB(150, 155, 165)
				m.Material = Enum.Material.Metal
				m.Anchored = true
				m.CanCollide = false
				m.CanQuery = false
				m.CanTouch = false
				m.CastShadow = false
				m.Parent = dossierMarches
				table.insert(marchesTapis, { part = m, rampe = rampe, decalage = k * ESPACE_MARCHES })
			end
		end
	end
end
task.spawn(preparerTapis)

RunService.RenderStepped:Connect(function()
	if #marchesTapis == 0 then
		return
	end
	local t = os.clock()
	local vitesse = (Config.Tapis and Config.Tapis.Vitesse or 32) * 0.5
	for _, m in ipairs(marchesTapis) do
		local r = m.rampe
		local longueur = r:GetAttribute("Longueur") or r.Size.Z
		local sens = r:GetAttribute("Tapis")
		-- Le tapis qui monte fait défiler les marches vers le haut (vers -Z de la rampe)
		local monte = typeof(sens) == "Vector3" and sens:Dot(r.CFrame.LookVector) > 0
		local d = (m.decalage + t * vitesse) % longueur
		local z = if monte then longueur / 2 - d else -longueur / 2 + d
		m.part.CFrame = r.CFrame * CFrame.new(0, r.Size.Y / 2 + 0.04, z)
	end
end)

---------------------------------------------------------------------
-- Filet de sécurité : si les commandes sont restées bloquées par erreur
-- (intro ou menu du garage), on les réactive.
task.spawn(function()
	while true do
		task.wait(1)
		-- Rattrapage : assis dans un kart, mais la conduite n'est pas active
		local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
		local siegeActuel = h and h.SeatPart
		if not kart and siegeActuel and siegeActuel:IsA("Seat") and siegeActuel.Parent and siegeActuel.Parent:GetAttribute("KartType") then
			entrerDansKart(siegeActuel)
		end
		if joueur:GetAttribute("IntroFinie") and not joueur:GetAttribute("MenuGarage") and not joueur:GetAttribute("EnSalle") then
			controles:Enable()
			if not kart and camera.CameraType == Enum.CameraType.Scriptable and not joueur:GetAttribute("CameraGarage") then
				camera.CameraType = Enum.CameraType.Custom
			end
		end
	end
end)
