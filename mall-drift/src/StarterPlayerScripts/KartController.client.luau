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
local TYPE_PLACE = Config.TypeDePlace() -- rôle de cette place (lobby, entraînement…)

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
	l.Font = Enum.Font.FredokaOne
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

-- Lignes de vitesse sur les bords de l'écran (quand on va vite / en boost)
local lignesVitesse = Instance.new("Frame")
lignesVitesse.Name = "LignesVitesse"
lignesVitesse.Size = UDim2.fromScale(1, 1)
lignesVitesse.BackgroundTransparency = 1
lignesVitesse.ZIndex = 1
lignesVitesse.Parent = gui
local lignes = {}
do
	local alea = Random.new(7)
	for i = 1, 28 do
		local angle = (i / 28) * math.pi * 2 + alea:NextNumber(-0.08, 0.08)
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.BackgroundColor3 = Color3.new(1, 1, 1)
		l.BorderSizePixel = 0
		l.Rotation = math.deg(angle)
		l.BackgroundTransparency = 1
		l.Parent = lignesVitesse
		local degradeLigne = Instance.new("UIGradient")
		degradeLigne.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		degradeLigne.Parent = l
		table.insert(lignes, { cadre = l, angle = angle, phase = alea:NextNumber(0, 1), vitesse = alea:NextNumber(1.5, 3) })
	end
end
local function majLignesVitesse(force: number, dt: number)
	lignesVitesse.Visible = force > 0.02
	if not lignesVitesse.Visible then
		return
	end
	for _, l in ipairs(lignes) do
		l.phase = (l.phase + dt * l.vitesse * (0.6 + force)) % 1
		local rayon = 0.42 + l.phase * 0.35
		local cadre = l.cadre
		cadre.Position = UDim2.fromScale(0.5 + math.cos(l.angle) * rayon * 0.75, 0.5 + math.sin(l.angle) * rayon)
		cadre.Size = UDim2.new(0, 60 + 160 * force, 0, 2)
		cadre.BackgroundTransparency = 1 - force * 0.55 * math.sin(l.phase * math.pi)
	end
end

-- Flash orange au déclenchement du boost
local flashBoost = Instance.new("Frame")
flashBoost.Name = "FlashBoost"
flashBoost.Size = UDim2.fromScale(1, 1)
flashBoost.BackgroundColor3 = Color3.fromRGB(255, 180, 80)
flashBoost.BackgroundTransparency = 1
flashBoost.BorderSizePixel = 0
flashBoost.ZIndex = 2
flashBoost.Parent = gui

-- Flou de vitesse (léger, surtout pendant le boost)
local flouVitesse = Instance.new("BlurEffect")
flouVitesse.Name = "FlouVitesse"
flouVitesse.Size = 0
flouVitesse.Parent = camera

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
-- Les pièces 💰 (la monnaie du jeu)
local piecesLabel = label("Pieces", blocNiveau, UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 68))
piecesLabel.TextXAlignment = Enum.TextXAlignment.Left
piecesLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
piecesLabel.Text = "💰 0"

local scoreLabel = label("Score", hud, UDim2.new(0, 250, 0, 40), UDim2.new(1, -266, 0, 56)) -- (étroit : ne touche pas le chrono)
scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
local meilleurLabel = label("Meilleur", hud, UDim2.new(0, 250, 0, 22), UDim2.new(1, -266, 0, 98))
meilleurLabel.TextXAlignment = Enum.TextXAlignment.Right
meilleurLabel.TextColor3 = Color3.fromRGB(255, 215, 80)

local vitesseLabel = label("Vitesse", hud, UDim2.new(0, 220, 0, 48), UDim2.new(0, 16, 1, -120))
vitesseLabel.TextXAlignment = Enum.TextXAlignment.Left

local aide = label("Aide", hud, UDim2.new(1, -32, 0, 18), UDim2.new(0, 16, 1, -30))
aide.TextXAlignment = Enum.TextXAlignment.Left
aide.TextTransparency = 0.25
aide.Text = "Maj : drift  ·  V : caméra  ·  R : redresser  ·  P : photo  ·  MENU en haut à droite"

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
local emplacementsMessages: { [number]: TextLabel } = {} -- 3 lignes, l'une sous l'autre
local function message(texte: string, couleur: Color3?, duree: number?)
	-- Première ligne libre ; si les 3 sont prises, la 1re est remplacée : jamais deux textes l'un sur l'autre
	local ligne = nil
	for i = 1, 3 do
		local occupe = emplacementsMessages[i]
		if not (occupe and occupe.Parent) then
			ligne = i
			break
		end
	end
	if not ligne then
		ligne = 1
		emplacementsMessages[1]:Destroy()
	end
	local m = label("Message", gui, UDim2.new(0, 600, 0, 46), UDim2.new(0.5, -300, 0.3, (ligne - 1) * 50)) -- (sous les feux et la carte du tuto)
	emplacementsMessages[ligne] = m
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
local poussee = 0 -- vitesse ajoutée d'un coup quand le boost se déclenche
local volantLisse = 0 -- le volant monte en douceur (au clavier, sinon le kart braque d'un coup)
local driftSens = 0 -- sens du drift en cours (-1 / 1), verrouillé jusqu'à la fin du drift
local driftDebut = 0 -- moment où le drift a commencé (pour une entrée progressive)
local secousseImpact = 0 -- secousse de caméra (choc, boost), qui retombe toute seule
local vitessePrecCam = 0
local accelLisse = 0
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
	local avant = tonumber((piecesLabel.Text:gsub("[^%d]", ""))) or 0
	piecesLabel.Text = ("💰 %d"):format(profil.Pieces or 0)
	if (profil.Pieces or 0) > avant then
		-- petite animation quand on gagne des pièces
		local echelle = piecesLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		echelle.Parent = piecesLabel
		echelle.Scale = 1.3
		TweenService:Create(echelle, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
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
	-- (au lobby, c'est le menu qui accueille le joueur : pas de conseils en plus)
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
		-- BOOST PROGRESSIF : plus le drift est puissant, plus le boost est long et fort
		local bp = Config.Score.BoostProgressif or {}
		local puissance = math.clamp(points / Config.Score.Etoiles[3], 0.05, bp.PuissanceMax or 2)
		local reglageBoost = {
			Duree = (bp.DureeMin or 0.5) + (bp.DureeParPuissance or 1.9) * puissance,
			Force = (bp.ForceMin or 0.4) + (bp.ForceParPuissance or 1) * puissance,
		}
		if reglageBoost then
			-- La police te poursuit ? Boost d'évasion !
			local poursuivi = joueur:GetAttribute("Poursuivi") == true or joueur:GetAttribute("Role") == "Fugitif"
			local multiplicateur = if poursuivi then (Config.Score.BoostEvasion or 1.5) else 1
			tempsBoost = reglageBoost.Duree * (if poursuivi then 1.2 else 1)
			poussee = (bp.PousseeMin or 4) + (bp.PousseeParPuissance or 10) * puissance -- (coup de pied, selon la puissance)
			-- Flammes et lumière plus grosses avec un boost puissant
			local taille = 0.6 + 0.6 * puissance
			for _, f in ipairs(kart.flammes or {}) do
				(f :: ParticleEmitter).Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, taille), NumberSequenceKeypoint.new(1, 0.1) })
			end
			for _, l in ipairs(kart.lumieresBoost or {}) do
				(l :: PointLight).Brightness = 2 + 2 * puissance
			end
			secousseImpact = math.max(secousseImpact, 0.2 + 0.2 * puissance) -- (secousse selon la puissance)
			-- FLASH : l'écran s'illumine d'un coup, puis s'efface
			flashBoost.BackgroundTransparency = math.clamp(0.88 - 0.1 * puissance, 0.68, 0.88)
			TweenService:Create(flashBoost, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
			flouVitesse.Size = 6 + 3 * puissance -- (coup de flou, qui retombe tout seul)
			camera.FieldOfView += 3 + 3 * puissance -- (le champ de vision « claque »)
			joueur:SetAttribute("TutoBoost", os.clock()) -- (pour le tuto)
			forceBoost = reglageBoost.Force * multiplicateur
			message(if poursuivi then ("🚨 BOOST D'ÉVASION x%.1f !"):format(forceBoost) else ("BOOST x%.1f %s"):format(forceBoost, string.rep("🔥", math.clamp(math.ceil(puissance * 1.5), 1, 3))),
				if poursuivi then Color3.fromRGB(255, 140, 60) else Color3.fromRGB(120, 255, 140), 0.9)
		end
		majScore()
	elseif not reussi and points > 0 then
		message(("OUPS ! DRIFT PERDU  -%d"):format(points), Color3.fromRGB(255, 90, 90), 1.4)
	end
	drift.actif = false
	drift.points, drift.temps, drift.rotation, drift.horsDrift, drift.combo, drift.nb360 = 0, 0, 0, 0, 1, 0
	blocDrift.Visible = false
	joueur:SetAttribute("TutoDriftPoints", 0)
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
type Depart = { debut: number, etape: number, survol: { [string]: any }, finSurvol: CFrame?, court: boolean }
local depart: Depart? = nil
local departsJoues: { [Instance]: boolean } = {}
local dernierRestePolice = -1

-- Les feux à l'écran (3 grosses lumières en haut au centre)
local blocFeux = Instance.new("Frame")
blocFeux.AnchorPoint = Vector2.new(0.5, 0)
blocFeux.Size = UDim2.new(0, 330, 0, 120)
blocFeux.Position = UDim2.new(0.5, 0, 0.135, 0) -- (sous les barres du haut et les cœurs)
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
chiffreDepart.Font = Enum.Font.FredokaOne
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

	if depart and not depart.court and os.clock() - depart.debut < DUREE_ANIM_DEPART then
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
	-- Recul à l'accélération / rapprochement au freinage (lissé)
	local accel = (vitesse - vitessePrecCam) / math.max(dt, 1 / 240)
	vitessePrecCam = vitesse
	accelLisse += (math.clamp(accel, -60, 60) - accelLisse) * math.clamp(dt * 3, 0, 1)
	local distance = reglages.Distance + math.clamp(vitesse, 0, 70) * 0.03 + math.clamp(accelLisse * (reglages.ReculAcceleration or 0.03), -1, 1.5)
	local pivot = ch.Position + Vector3.new(0, 2.5, 0)
	-- (hauteur fixe : on voit bien la piste devant, même à pleine vitesse)
	local hauteur = reglages.Hauteur
	local voulu = ch.Position - directionCamera * distance + Vector3.new(0, hauteur, 0)
	-- Si un mur est entre le kart et la caméra, on rapproche la caméra
	rayonCamera.FilterDescendantsInstances = { kart.modele, joueur.Character }
	local obstacle = workspace:Raycast(pivot, voulu - pivot, rayonCamera)
	if obstacle and obstacle.Instance.CanCollide then
		voulu = obstacle.Position + (pivot - voulu).Unit * 1
	end
	-- Réalisme : la caméra penche un peu dans les drifts et tremble pendant le boost
	local glisseCam = vel:Dot(Vector3.new(-directionCamera.Z, 0, directionCamera.X))
	local roulis = math.clamp(-glisseCam * (reglages.RoulisDrift or 0.005), -0.12, 0.12)
	-- Tremblements : un peu à pleine vitesse, plus au boost, beaucoup aux chocs
	secousseImpact = math.max(secousseImpact - dt * 1.8, 0)
	local force = math.clamp((vitesse - 40) / 30, 0, 1) * (reglages.TremblementVitesse or 0.05)
		+ (if tempsBoost > 0 then (reglages.TremblementBoost or 0.3) else 0)
		+ secousseImpact * 0.9
	local secousse = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * force
	camera.CFrame = CFrame.lookAt(voulu + secousse, ch.Position + directionCamera * 6 + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, roulis)
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
boutonConduire.Font = Enum.Font.FredokaOne
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

-- Le bouton CONDUIRE n'apparaît jamais par-dessus le menu (ni le garage)
local function menuAffiche(): boolean
	local hudPartie = joueur.PlayerGui:FindFirstChild("PartieHUD")
	local menu = hudPartie and hudPartie:FindFirstChild("Menu")
	return (menu ~= nil and (menu :: GuiObject).Visible) or joueur:GetAttribute("MenuGarage") == true
end
local function demanderKart()
	if kart or not joueur:GetAttribute("IntroFinie") or joueur:GetAttribute("MenuGarage") or joueur:GetAttribute("EnSalle") or menuAffiche() then
		return -- pas pendant l'intro, le menu du garage ou la page d'attente
	end
	boutonConduire.Text = "⏳ ..."
	remotes.SortirKart:FireServer()
	task.delay(1.5, function()
		boutonConduire.Text = "🏎️ CONDUIRE  (F)"
	end)
end
boutonConduire.Activated:Connect(demanderKart)

local conduireDisponible = false
task.spawn(function()
	while true do
		task.wait(0.2)
		boutonConduire.Visible = conduireDisponible and not menuAffiche()
	end
end)
local function activerToucheConduire(actif: boolean)
	if TYPE_PLACE == "Lobby" then
		actif = false -- dans le lobby, on choisit son mode dans le menu (pas de kart)
	end
	conduireDisponible = actif
	boutonConduire.Visible = actif and not menuAffiche()
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
	for _, nom in ipairs({ "TracePneu", "Fumee", "Eclaboussures", "Etincelles", "FlammeBoost", "LumiereBoost" }) do
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
	majLignesVitesse(0, 0)
	flouVitesse.Size = 0
	driftSens = 0
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
	local ecranVolant = modele:FindFirstChild("EcranVolant")
	local tableau = ecranVolant and ecranVolant:FindFirstChild("Tableau")
	kart.tableau = tableau and tableau:FindFirstChildOfClass("Frame")
	kart.etincelles = effets("Etincelles")
	kart.flammes = effets("FlammeBoost")
	kart.lumieresBoost = effets("LumiereBoost")
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
		local court = modele:GetAttribute("DepartCourt") == true -- Drift Battle : juste 3, 2, 1
		depart = { debut = os.clock(), etape = 0, survol = survol, finSurvol = nil, court = court }
		dernierRestePolice = -1
		hud.Visible = false
		afficherBandes(true)
		allumerFeux(0, false)
		-- Fondu depuis le noir, puis le survol de la map
		noirDepart.BackgroundTransparency = 0
		TweenService:Create(noirDepart, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		if not court then
			message("✦ " .. survol.nom .. " ✦", Color3.fromRGB(255, 215, 80), 2.2)
			task.delay(DUREE_SURVOL, function()
				message("★ EN PLACE SUR LA LIGNE ! ★", Color3.new(1, 1, 1), 1)
			end)
		end
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
	-- Volant progressif : on braque vite, on revient au centre un peu plus vite encore
	local vitesseVolant = if math.abs(volant) > math.abs(volantLisse) then 9 else 12
	volantLisse += (volant - volantLisse) * math.clamp(dt * vitesseVolant, 0, 1)
	if depart then
		local t = os.clock() - depart.debut
		-- (départ court du Drift Battle : pas de survol, feux plus rapides)
		local pas = if depart.court then 0.7 else 1
		-- (départ court : on laisse 1 s au titre « DRIFT BATTLE », le kart est déjà sur la ligne)
		local tCompte = (t - (if depart.court then 1.1 else DUREE_ANIM_DEPART)) / pas -- 0 = début du compte à rebours
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
	-- Power slide : en drift avec l'accélérateur, le kart garde presque toute sa vitesse
	if driftAppuye and gaz > 0.3 then
		cible = math.max(cible, vMax * 0.92)
	end
	local taux
	if math.abs(gaz) < 0.05 then
		taux = s.Freinage * 0.25 -- roue libre
	elseif math.sign(gaz) ~= math.sign(vAvant) and math.abs(vAvant) > 1 then
		taux = s.Freinage
	else
		-- Départ nerveux, qui s'adoucit près de la vitesse max (plus de sensations)
		local ratio = math.clamp(math.abs(vAvant) / math.max(vMax, 1), 0, 1)
		local accBoost = (Config.Score.BoostProgressif and Config.Score.BoostProgressif.AccelerationBoost) or 2.5
		taux = s.Acceleration * (1.5 - 0.8 * ratio) * (if tempsBoost > 0 then accBoost else 1)
	end
	-- Coup de pied du boost : une vraie poussée au moment où il se déclenche
	if poussee > 0 and auSol then
		vAvant += poussee
		poussee = 0
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
	-- Le drift démarre dès qu'on tient SHIFT en tournant (même si SHIFT était appuyé avant)
	if driftAppuye and driftSens == 0 and math.abs(volant) > 0.25 and math.abs(vAvant) > 12 then
		driftSens = math.sign(volant)
		driftDebut = os.clock()
		vitesseRotation += -driftSens * glisse.CoupDeVolant -- l'arrière décroche (en douceur)
	end
	if not driftAppuye or math.abs(vAvant) < 6 then
		driftSens = 0
	end
	driftAppuyeAvant = driftAppuye
	if mouille then
		adherence *= Config.Mouille.Adherence
	end
	if auSol and driftSens ~= 0 then
		-- DRIFT ARCADE : le kart rejoint un angle de glisse cible (toujours le même ressenti)
		local intention = math.clamp(volantLisse * driftSens, -1, 1) -- 1 = on braque dans le virage, -1 = contre-braquage
		local angle = (glisse.AngleDrift or 32) + (glisse.AngleVolant or 16) * intention + (if mouille then (glisse.AngleMouille or 10) else 0)
		-- Entrée progressive : l'angle monte de 40 % à 100 % pendant les premiers instants du drift
		local entree = math.clamp(0.4 + 0.6 * (os.clock() - driftDebut) / (glisse.EntreeDrift or 0.5), 0.4, 1)
		angle *= entree
		local cibleCote = -driftSens * math.abs(vAvant) * math.tan(math.rad(math.clamp(angle, 8, 65)))
		vCote += (cibleCote - vCote) * math.clamp(dt * (glisse.RapiditeDrift or 5), 0, 1)
	elseif auSol then
		vCote *= math.exp(-adherence * dt)
	end

	-- 3) Tourner (en drift, on tourne beaucoup plus : 360 possibles !)
	local facteur = math.clamp(math.abs(vAvant) / 12, 0, 1)
	if driftAppuye then
		facteur = math.max(facteur, 0.7) -- on peut tourner sur place en drift
	end
	local puissance = s.Rotation * (if driftAppuye then s.RotationDrift else 1)
	-- Stabilité : à pleine vitesse (hors drift), on braque un peu moins
	if not driftAppuye then
		puissance *= 1 - 0.3 * math.clamp(math.abs(vAvant) / s.VitesseMax, 0, 1)
	end
	local sens = if vAvant < -1 then -1 else 1
	local rotationCible = -volantLisse * puissance * facteur * sens
	if driftSens ~= 0 then
		-- En drift : le kart tourne toujours dans le sens du drift (arc régulier),
		-- plus serré si on braque, plus large si on contre-braque
		local intention = math.clamp(volantLisse * driftSens, -1, 1)
		rotationCible = -driftSens * puissance * facteur * sens * (0.75 + 0.45 * intention)
	end
	vitesseRotation += (rotationCible - vitesseRotation) * math.clamp(dt * 10, 0, 1)

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

	-- Choc : la caméra tremble selon la violence du choc
	if derniereVitesse - vitesse > Config.Score.SeuilChoc * 0.6 then
		-- Petit rebond vers l'arrière au lieu de rester collé au mur
		if auSol and math.abs(gaz) > 0.2 then
			ch.AssemblyLinearVelocity = ch.AssemblyLinearVelocity - avant * math.clamp((derniereVitesse - vitesse) * 0.25, 3, 10)
		end
		secousseImpact = math.max(secousseImpact, math.clamp((derniereVitesse - vitesse) / 30, 0.3, 1))
	end
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
		joueur:SetAttribute("TutoDriftPoints", pts) -- (pour le tuto)
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
	-- Étincelles : bleues, puis orange (2 étoiles), puis violettes (3 étoiles)
	local etoilesDrift = if drift.actif then nombreEtoiles(math.floor(drift.points)) else 0
	local couleurEtincelles = if etoilesDrift >= 3 then Color3.fromRGB(200, 90, 255)
		elseif etoilesDrift >= 2 then Color3.fromRGB(255, 150, 40)
		else Color3.fromRGB(90, 170, 255)
	for _, e in ipairs(kart.etincelles) do
		e.Enabled = drift.actif and auSol and vitesse > 20
		e.Color = ColorSequence.new(couleurEtincelles)
	end
	for _, f in ipairs(kart.flammes) do
		f.Enabled = tempsBoost > 0
	end
	for _, l in ipairs(kart.lumieresBoost) do
		l.Enabled = tempsBoost > 0
	end
	majLignesVitesse(math.clamp((vitesse - 45) / 40, 0, 0.7) + (if tempsBoost > 0 then 0.4 else 0), dt)
	local flouVoulu = if tempsBoost > 0 then 5 elseif vitesse > 60 then 1.5 else 0
	if workspace:GetAttribute("GraphismesLegers") or joueur:GetAttribute("GraphismesLegers") then
		flouVoulu = 0
	end
	flouVitesse.Size += (flouVoulu - flouVitesse.Size) * math.clamp(dt * 6, 0, 1)

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
	local fovCible = fovBase + math.clamp(vitesse, 0, 80) * (if modeCamera == "gopro" then 0.12 else 0.3) + (if tempsBoost > 0 then (Config.Camera.ChampBoost or 14) * math.clamp(forceBoost / 1.4, 0.5, 1.6) else 0)
	-- Le champ de vision s'ouvre VITE (effet « coup de boost ») et se referme doucement
	local vitesseFov = if fovCible > camera.FieldOfView then 9 else 3
	camera.FieldOfView += (fovCible - camera.FieldOfView) * math.clamp(dt * vitesseFov, 0, 1)

	vitesseLabel.Text = ("%d km/h"):format(math.floor(vitesse + 0.5))

	-- L'écran digital du volant (bien visible en caméra GoPro, touche V)
	local ecran = kart.tableau
	if ecran then
		local ratio = math.clamp(vitesse / s.VitesseMax, 0, 1.4)
		local regime = 1500 + ratio * 6300 + (if drift.actif then 600 else 0) + math.random(-40, 40)
		local lVitesse = ecran:FindFirstChild("Vitesse") :: TextLabel?
		local lRegime = ecran:FindFirstChild("Regime") :: TextLabel?
		local lPiste = ecran:FindFirstChild("Piste") :: TextLabel?
		local lEtat = ecran:FindFirstChild("Etat") :: TextLabel?
		local barreR = ecran:FindFirstChild("BarreRegime")
		local rempli = barreR and barreR:FindFirstChild("Remplissage") :: Frame?
		if lVitesse then
			lVitesse.Text = ("%03d"):format(math.floor(vitesse + 0.5))
		end
		if lRegime then
			lRegime.Text = ("%d TR/MIN"):format(math.floor(regime / 100) * 100)
		end
		if lPiste then
			lPiste.Text = if mouille then "MOUILLÉ" else "SEC"
			lPiste.TextColor3 = if mouille then Color3.fromRGB(90, 190, 255) else Color3.fromRGB(255, 200, 60)
		end
		if lEtat then
			lEtat.Text = if tempsBoost > 0 then "BOOST !" elseif drift.actif then ("DRIFT x%.1f"):format(drift.combo) else ""
			lEtat.TextColor3 = if tempsBoost > 0 then Color3.fromRGB(255, 150, 40) else Color3.fromRGB(120, 255, 140)
		end
		if rempli then
			local r = math.clamp((regime - 1500) / 7000, 0, 1)
			rempli.Size = UDim2.fromScale(r, 1)
			rempli.BackgroundColor3 = if r > 0.85 then Color3.fromRGB(255, 60, 60) elseif r > 0.6 then Color3.fromRGB(255, 190, 50) else Color3.fromRGB(90, 200, 255)
		end
	end

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
local kartsArcEnCiel: { { parties: { BasePart }, lumieres: { PointLight }, pastel: boolean? } } = {}
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
	-- Les karts exposés dans le garage (dont le kart exclusif) et son socle lumineux
	local carteMall = workspace:FindFirstChild("GoldenMall")
	local garageVIP = carteMall and carteMall:FindFirstChild("GarageVIP")
	if garageVIP then
		local socles = { parties = {}, lumieres = {} }
		for _, m in ipairs(garageVIP:GetChildren()) do
			if m:IsA("Model") and string.sub(m.Name, 1, 8) == "Vitrine_" then
				table.insert(candidats, m)
			elseif m:IsA("BasePart") and m:GetAttribute("ArcEnCiel") then
				table.insert(socles.parties, m)
				for _, l in ipairs(m:GetChildren()) do
					if l:IsA("PointLight") then
						table.insert(socles.lumieres, l)
					end
				end
			end
		end
		if #socles.parties > 0 then
			table.insert(kartsArcEnCiel, socles)
		end
	end
	for _, m in ipairs(candidats) do
		if m:GetAttribute("Police") then
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and d.Name == "GyroPolice" then
					table.insert(gyrosPolice, d)
				end
			end
		end
		if m:GetAttribute("CarrosserieArcEnCiel") then
			local entree = { parties = {}, lumieres = {}, pastel = m:GetAttribute("ArcEnCielPastel") == true }
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("BasePart") and d:GetAttribute("Peinture") == "Carrosserie" then
					table.insert(entree.parties, d)
				end
			end
			table.insert(kartsArcEnCiel, entree)
		end
		-- Pièces décoratives toujours arc-en-ciel (ailes du kart exclusif...)
		local deco = { parties = {}, lumieres = {}, pastel = true }
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("ArcEnCiel") then
				table.insert(deco.parties, d)
			end
		end
		if #deco.parties > 0 then
			table.insert(kartsArcEnCiel, deco)
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
	-- Une « vague » de couleurs qui parcourt le kart (chaque pièce est un peu décalée)
	local teinte = maintenant * 0.25
	for _, k in ipairs(kartsArcEnCiel) do
		local saturation = if k.pastel then 0.5 else 0.9
		for i, p in ipairs(k.parties) do
			p.Color = Color3.fromHSV((teinte + i * 0.06) % 1, saturation, 1)
		end
		local couleur = Color3.fromHSV(teinte % 1, 0.9, 1)
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

---------------------------------------------------------------------
-- LES MAINS SUR LE VOLANT : chaque pilote (toi et les autres joueurs)
-- tend les bras vers le volant de son kart (personnages R15)
---------------------------------------------------------------------
local POSE_EPAULE_DROITE = CFrame.Angles(math.rad(72), 0, math.rad(-12))
local POSE_EPAULE_GAUCHE = CFrame.Angles(math.rad(72), 0, math.rad(12))
local POSE_COUDE = CFrame.Angles(math.rad(22), 0, 0)

RunService.Stepped:Connect(function()
	local dossier = workspace:FindFirstChild("KartsJoueurs")
	if not dossier then
		return
	end
	for _, k in ipairs(dossier:GetChildren()) do
		local siege = k:FindFirstChild("Siege") :: Seat?
		local pilote = siege and siege.Occupant and siege.Occupant.Parent
		if pilote then
			local brasD = pilote:FindFirstChild("RightUpperArm")
			local brasG = pilote:FindFirstChild("LeftUpperArm")
			local avantD = pilote:FindFirstChild("RightLowerArm")
			local avantG = pilote:FindFirstChild("LeftLowerArm")
			local epauleD = brasD and brasD:FindFirstChild("RightShoulder") :: Motor6D?
			local epauleG = brasG and brasG:FindFirstChild("LeftShoulder") :: Motor6D?
			local coudeD = avantD and avantD:FindFirstChild("RightElbow") :: Motor6D?
			local coudeG = avantG and avantG:FindFirstChild("LeftElbow") :: Motor6D?
			if epauleD then
				epauleD.Transform = POSE_EPAULE_DROITE
			end
			if epauleG then
				epauleG.Transform = POSE_EPAULE_GAUCHE
			end
			if coudeD then
				coudeD.Transform = POSE_COUDE
			end
			if coudeG then
				coudeG.Transform = POSE_COUDE
			end
		end
	end
end)
