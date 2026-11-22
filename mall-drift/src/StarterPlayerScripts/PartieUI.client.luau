--[[
	PartieUI  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : PartieUI

	Ce que le joueur voit du mode en ligne « Police contre Fugitifs » :
	  • la barre d'état en haut (attente, prochaine manche, temps restant, fugitifs libres)
	  • l'animation du TIRAGE AU SORT (roulette 🚓 / 🏃, puis ta carte d'équipe)
	  • le fil des arrestations, l'écran « TU ES ARRÊTÉ », l'écran de victoire
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local controles = require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")
local Partie = remotes:WaitForChild("Partie", 30)
if not Partie then
	return
end

local BLEU = Color3.fromRGB(70, 140, 255)
local ORANGE = Color3.fromRGB(255, 150, 40)
local FOND = Color3.fromRGB(15, 15, 20)

local gui = Instance.new("ScreenGui")
gui.Name = "PartieHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = joueur:WaitForChild("PlayerGui")

local function texte(parent: Instance, taille: UDim2, position: UDim2, couleur: Color3, police: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = taille
	t.Position = position
	t.BackgroundTransparency = 1
	t.TextColor3 = couleur
	t.Font = police or Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = ""
	local c = Instance.new("UIStroke")
	c.Thickness = 2
	c.Color = Color3.fromRGB(10, 10, 14)
	c.Parent = t
	t.Parent = parent
	return t
end

---------------------------------------------------------------------
-- Barre d'état (en haut au centre)
---------------------------------------------------------------------
local barre = Instance.new("Frame")
barre.AnchorPoint = Vector2.new(0.5, 0)
barre.Size = UDim2.new(0, 440, 0, 40)
barre.Position = UDim2.new(0.5, 0, 0, 8)
barre.BackgroundColor3 = FOND
barre.BackgroundTransparency = 0.25
barre.Parent = gui
Instance.new("UICorner", barre).CornerRadius = UDim.new(0, 10)
local texteBarre = texte(barre, UDim2.new(1, -20, 1, -10), UDim2.new(0, 10, 0, 5), Color3.new(1, 1, 1))

local function formatTemps(s: number): string
	return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

---------------------------------------------------------------------
-- Fil des arrestations (en bas à gauche)
---------------------------------------------------------------------
local fil = Instance.new("Frame")
fil.Size = UDim2.new(0, 380, 0, 140)
fil.Position = UDim2.new(0, 16, 1, -300)
fil.BackgroundTransparency = 1
fil.Parent = gui
local listeFil = Instance.new("UIListLayout")
listeFil.VerticalAlignment = Enum.VerticalAlignment.Bottom
listeFil.Padding = UDim.new(0, 4)
listeFil.Parent = fil

local function ajouterAuFil(message: string, couleur: Color3)
	local l = texte(fil, UDim2.new(1, 0, 0, 26), UDim2.new(), couleur, Enum.Font.GothamBold)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = message
	task.delay(6, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.55)
		l:Destroy()
	end)
end

---------------------------------------------------------------------
-- Grand écran central (tirage, arrestation, victoire)
---------------------------------------------------------------------
local carte = Instance.new("Frame")
carte.AnchorPoint = Vector2.new(0.5, 0.5)
carte.Size = UDim2.new(0, 520, 0, 260)
carte.Position = UDim2.fromScale(0.5, 0.45)
carte.BackgroundColor3 = FOND
carte.BackgroundTransparency = 0.1
carte.Visible = false
carte.Parent = gui
Instance.new("UICorner", carte).CornerRadius = UDim.new(0, 18)
local bordCarte = Instance.new("UIStroke")
bordCarte.Thickness = 4
bordCarte.Parent = carte
local echelleCarte = Instance.new("UIScale")
echelleCarte.Parent = carte
local petitTitre = texte(carte, UDim2.new(1, -30, 0, 34), UDim2.new(0, 15, 0, 18), Color3.fromRGB(200, 200, 210), Enum.Font.GothamBold)
local grandTitre = texte(carte, UDim2.new(1, -30, 0, 90), UDim2.new(0, 15, 0, 60), Color3.new(1, 1, 1))
local sousTitre = texte(carte, UDim2.new(1, -40, 0, 60), UDim2.new(0, 20, 0, 170), Color3.fromRGB(230, 230, 235), Enum.Font.GothamMedium)

local function montrerCarte(petit: string, grand: string, sous: string, couleur: Color3, duree: number?)
	petitTitre.Text = petit
	grandTitre.Text = grand
	grandTitre.TextColor3 = couleur
	sousTitre.Text = sous
	bordCarte.Color = couleur
	carte.Visible = true
	echelleCarte.Scale = 0.4
	TweenService:Create(echelleCarte, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if duree then
		local moi = grand
		task.delay(duree, function()
			if grandTitre.Text == moi then
				carte.Visible = false
			end
		end)
	end
end

---------------------------------------------------------------------
-- LE TABLEAU DE CLASSEMENT (fin de manche) : total de drift et meilleur drift
---------------------------------------------------------------------
local tableau = Instance.new("Frame")
tableau.AnchorPoint = Vector2.new(0.5, 0)
tableau.Size = UDim2.new(0, 520, 0, 300)
tableau.Position = UDim2.new(0.5, 0, 0.45, 140)
tableau.BackgroundColor3 = FOND
tableau.BackgroundTransparency = 0.1
tableau.Visible = false
tableau.ZIndex = 2
tableau.Parent = gui
Instance.new("UICorner", tableau).CornerRadius = UDim.new(0, 16)
local bordTableau = Instance.new("UIStroke")
bordTableau.Thickness = 3
bordTableau.Color = Color3.fromRGB(255, 205, 70)
bordTableau.Parent = tableau
local titreTableau = texte(tableau, UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 8), Color3.fromRGB(255, 205, 70))
local lignesTableau = Instance.new("Frame")
lignesTableau.Size = UDim2.new(1, -24, 1, -54)
lignesTableau.Position = UDim2.new(0, 12, 0, 48)
lignesTableau.BackgroundTransparency = 1
lignesTableau.Parent = tableau
local dispositionLignes = Instance.new("UIListLayout")
dispositionLignes.Padding = UDim.new(0, 4)
dispositionLignes.SortOrder = Enum.SortOrder.LayoutOrder
dispositionLignes.Parent = lignesTableau

local function montrerClassement(titre: string, classement, duree: number)
	titreTableau.Text = titre
	for _, enfant in ipairs(lignesTableau:GetChildren()) do
		if enfant:IsA("TextLabel") then
			enfant:Destroy()
		end
	end
	local medailles = { "🥇", "🥈", "🥉" }
	for i, ligne in ipairs(classement or {}) do
		if i > 8 then
			break
		end
		local l = texte(lignesTableau, UDim2.new(1, 0, 0, 26), UDim2.new(), if ligne.nom == joueur.DisplayName then Color3.fromRGB(255, 230, 120) else Color3.new(1, 1, 1), Enum.Font.GothamBold)
		l.LayoutOrder = i
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = ("%s %d. %s   ·   %d pts   ·   meilleur drift %d"):format(medailles[i] or "  ", i, ligne.nom, ligne.total, ligne.meilleur)
	end
	tableau.Visible = true
	task.delay(duree, function()
		tableau.Visible = false
	end)
end

---------------------------------------------------------------------
-- LA PAGE D'ATTENTE (avant chaque manche) : on ne roule pas, on attend
-- le tirage au sort pendant que la caméra survole le mall
---------------------------------------------------------------------
local page = Instance.new("Frame")
page.Name = "PageAttente"
page.Size = UDim2.fromScale(1, 1)
page.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
page.BackgroundTransparency = 0.35
page.Visible = false
page.ZIndex = 0
page.Parent = gui
local degradePage = Instance.new("UIGradient")
degradePage.Rotation = 90
degradePage.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
degradePage.Parent = page
local titrePage = texte(page, UDim2.new(0.8, 0, 0, 70), UDim2.new(0.1, 0, 0.12, 0), Color3.fromRGB(255, 205, 70))
titrePage.Text = "GOLDEN MALL DRIFT"
local sousTitrePage = texte(page, UDim2.new(0.8, 0, 0, 40), UDim2.new(0.1, 0, 0.12, 78), Color3.new(1, 1, 1))
sousTitrePage.Text = "🚓 POLICE  vs  FUGITIFS 🏃"
local comptePage = texte(page, UDim2.new(0.6, 0, 0, 46), UDim2.new(0.2, 0, 0.72, 0), Color3.fromRGB(255, 215, 80))
local listePage = texte(page, UDim2.new(0.7, 0, 0, 30), UDim2.new(0.15, 0, 0.8, 0), Color3.fromRGB(220, 220, 230), Enum.Font.GothamBold)
local aidePage = texte(page, UDim2.new(0.7, 0, 0, 24), UDim2.new(0.15, 0, 0.86, 0), Color3.fromRGB(180, 180, 190), Enum.Font.GothamMedium)
aidePage.Text = "Le tirage au sort décide de ton équipe. Les fugitifs partent au sud, la police au nord !"

local enSalle = false
local angleSalle = 0
local nombreBots = 0

local function majListe()
	local noms = {}
	for _, j in ipairs(Players:GetPlayers()) do
		table.insert(noms, j.DisplayName)
	end
	listePage.Text = "Joueurs : " .. table.concat(noms, ", ") .. (if nombreBots > 0 then ("  (+%d bot de test 🤖)"):format(nombreBots) else "")
end

local function surSalle()
	local doitEtreEnSalle = joueur:GetAttribute("EnSalle") == true and joueur:GetAttribute("IntroFinie") == true
	if doitEtreEnSalle == enSalle then
		return
	end
	enSalle = doitEtreEnSalle
	page.Visible = enSalle
	if enSalle then
		controles:Disable()
		camera.CameraType = Enum.CameraType.Scriptable
		majListe()
	else
		controles:Enable()
		local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
		if not (h and h.SeatPart) then
			camera.CameraType = Enum.CameraType.Custom -- (au volant, c'est la caméra du kart qui commande)
		end
	end
end
joueur:GetAttributeChangedSignal("EnSalle"):Connect(surSalle)
joueur:GetAttributeChangedSignal("IntroFinie"):Connect(surSalle)
Players.PlayerAdded:Connect(majListe)
Players.PlayerRemoving:Connect(function()
	task.defer(majListe)
end)

-- La caméra survole l'atrium du mall pendant l'attente
RunService.RenderStepped:Connect(function(dt)
	if not enSalle then
		return
	end
	angleSalle += dt * 0.15
	local pos = Vector3.new(math.cos(angleSalle) * 24, 34, math.sin(angleSalle) * 95)
	camera.CFrame = CFrame.lookAt(pos, Vector3.new(0, 8, 0))
end)

---------------------------------------------------------------------
-- LE MENU : choisir son mode de jeu
--   🏁 ENTRAÎNEMENT : drift libre, la police du mall (bots) te poursuit
--   🌐 JOUER EN LIGNE : Police contre Fugitifs avec de vrais joueurs
--   🎨 GARAGE VIP : personnaliser son kart
-- Il s'ouvre après l'intro, puis avec le bouton « ☰ MENU » (en bas à droite).
---------------------------------------------------------------------
local VIOLET = Color3.fromRGB(110, 60, 220)

local boutonMenu = Instance.new("TextButton")
boutonMenu.Name = "BoutonMenu"
boutonMenu.AnchorPoint = Vector2.new(1, 1)
boutonMenu.Size = UDim2.new(0, 190, 0, 54)
boutonMenu.Position = UDim2.new(1, -20, 1, -40)
boutonMenu.Font = Enum.Font.GothamBlack
boutonMenu.TextScaled = true
boutonMenu.TextColor3 = Color3.new(1, 1, 1)
boutonMenu.BackgroundColor3 = VIOLET
boutonMenu.Text = "☰ MENU"
boutonMenu.ZIndex = 5
boutonMenu.Parent = gui
Instance.new("UICorner", boutonMenu).CornerRadius = UDim.new(0, 14)
local bordMenu = Instance.new("UIStroke")
bordMenu.Thickness = 3
bordMenu.Color = Color3.new(1, 1, 1)
bordMenu.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bordMenu.Parent = boutonMenu
local margeMenu = Instance.new("UIPadding")
margeMenu.PaddingTop = UDim.new(0, 10)
margeMenu.PaddingBottom = UDim.new(0, 10)
margeMenu.Parent = boutonMenu

local fondMenu = Instance.new("Frame")
fondMenu.Name = "Menu"
fondMenu.Size = UDim2.fromScale(1, 1)
fondMenu.BackgroundColor3 = Color3.fromRGB(5, 5, 10)
fondMenu.BackgroundTransparency = 0.35
fondMenu.Visible = false
fondMenu.ZIndex = 20
fondMenu.Parent = gui
local titreMenu = texte(fondMenu, UDim2.new(0.8, 0, 0, 60), UDim2.new(0.1, 0, 0.1, 0), Color3.fromRGB(255, 205, 70))
titreMenu.Text = "GOLDEN MALL DRIFT"
titreMenu.ZIndex = 21
local sousTitreMenu = texte(fondMenu, UDim2.new(0.8, 0, 0, 30), UDim2.new(0.1, 0, 0.1, 64), Color3.new(1, 1, 1), Enum.Font.GothamBold)
sousTitreMenu.Text = "Choisis ton mode de jeu"
sousTitreMenu.ZIndex = 21

local rangeeCartes = Instance.new("Frame")
rangeeCartes.AnchorPoint = Vector2.new(0.5, 0.5)
rangeeCartes.Size = UDim2.new(0.9, 0, 0, 250)
rangeeCartes.Position = UDim2.fromScale(0.5, 0.55)
rangeeCartes.BackgroundTransparency = 1
rangeeCartes.ZIndex = 21
rangeeCartes.Parent = fondMenu
local dispositionCartes = Instance.new("UIListLayout")
dispositionCartes.FillDirection = Enum.FillDirection.Horizontal
dispositionCartes.HorizontalAlignment = Enum.HorizontalAlignment.Center
dispositionCartes.Padding = UDim.new(0, 18)
dispositionCartes.Parent = rangeeCartes

local function carteMode(icone: string, titre: string, description: string, couleur: Color3): (TextButton, TextLabel, TextLabel)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 230, 1, 0)
	b.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	b.Text = ""
	b.AutoButtonColor = true
	b.ZIndex = 22
	b.Parent = rangeeCartes
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 18)
	local bord = Instance.new("UIStroke")
	bord.Thickness = 4
	bord.Color = couleur
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = b
	local i = texte(b, UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 0, 14), Color3.new(1, 1, 1))
	i.Text = icone
	i.ZIndex = 23
	local t = texte(b, UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 92), couleur)
	t.Text = titre
	t.ZIndex = 23
	local d = texte(b, UDim2.new(1, -24, 0, 90), UDim2.new(0, 12, 0, 140), Color3.fromRGB(210, 210, 220), Enum.Font.GothamMedium)
	d.Text = description
	d.ZIndex = 23
	return b, t, d
end

local carteEntrainement = carteMode("🏁", "ENTRAÎNEMENT", "Roule librement et travaille tes drifts. La police du mall (des bots) te poursuit !", Color3.fromRGB(80, 220, 120))
local carteEnLigne, titreEnLigne, descEnLigne = carteMode("🌐", "JOUER EN LIGNE", "Police contre Fugitifs avec de vrais joueurs. Tirage au sort des équipes !", Color3.fromRGB(90, 150, 255))
local carteBattle, titreBattle, descBattle = carteMode("🔥", "DRIFT BATTLE", "1 minute, pas de police : fais le plus de points de drift ! Seul, c'est un défi.", Color3.fromRGB(255, 90, 170))
local carteGarage = carteMode("🎨", "GARAGE VIP", "Personnalise ton kart : couleurs, néons, autocollants…", Color3.fromRGB(200, 140, 255))

local boutonFermerMenu = Instance.new("TextButton")
boutonFermerMenu.AnchorPoint = Vector2.new(1, 0)
boutonFermerMenu.Size = UDim2.new(0, 54, 0, 54)
boutonFermerMenu.Position = UDim2.new(1, -24, 0, 60)
boutonFermerMenu.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
boutonFermerMenu.TextColor3 = Color3.new(1, 1, 1)
boutonFermerMenu.Font = Enum.Font.GothamBlack
boutonFermerMenu.TextScaled = true
boutonFermerMenu.Text = "✕"
boutonFermerMenu.ZIndex = 22
boutonFermerMenu.Parent = fondMenu
Instance.new("UICorner", boutonFermerMenu).CornerRadius = UDim.new(0, 12)

local function majMenu()
	local enManche = joueur:GetAttribute("Role") ~= nil
	local prete = joueur:GetAttribute("Pret") == true
	local preteBattle = joueur:GetAttribute("PretBattle") == true
	titreBattle.Text = if preteBattle then "QUITTER LA FILE" else "DRIFT BATTLE"
	descBattle.Text = if preteBattle
		then "Tu es dans la file du Drift Battle. Clique pour la quitter."
		else "1 minute, pas de police : fais le plus de points de drift ! Seul, c'est un défi."
	boutonMenu.Visible = not enManche and joueur:GetAttribute("IntroFinie") == true and not (joueur:GetAttribute("EnSalle") == true)
	if enManche then
		fondMenu.Visible = false
	end
	titreEnLigne.Text = if prete then "QUITTER LA FILE" else "JOUER EN LIGNE"
	descEnLigne.Text = if prete
		then "Tu es dans la file d'attente de Police contre Fugitifs. Clique pour la quitter."
		else "Police contre Fugitifs avec de vrais joueurs. Tirage au sort des équipes !"
	boutonMenu.Text = if prete or preteBattle then "☰ MENU · ✅ EN FILE" else "☰ MENU"
	boutonMenu.Size = UDim2.new(0, if prete or preteBattle then 300 else 190, 0, 54)
end
for _, nom in ipairs({ "Pret", "PretBattle", "Role", "IntroFinie", "EnSalle" }) do
	joueur:GetAttributeChangedSignal(nom):Connect(majMenu)
end
majMenu()

local function ouvrirMenu(ouvert: boolean)
	fondMenu.Visible = ouvert
	majMenu()
end
boutonMenu.Activated:Connect(function()
	ouvrirMenu(not fondMenu.Visible)
end)
boutonFermerMenu.Activated:Connect(function()
	ouvrirMenu(false)
end)
carteEntrainement.Activated:Connect(function()
	ouvrirMenu(false)
	if joueur:GetAttribute("Pret") then
		Partie:FireServer({ type = "pret", valeur = false })
	end
	if joueur:GetAttribute("PretBattle") then
		Partie:FireServer({ type = "pretBattle", valeur = false })
	end
	-- On part directement sur la ligne de départ (survol + 3, 2, 1, PARTEZ)
	remotes:WaitForChild("SortirKart"):FireServer()
end)
carteEnLigne.Activated:Connect(function()
	ouvrirMenu(false)
	local prete = joueur:GetAttribute("Pret") == true
	Partie:FireServer({ type = "pret", valeur = not prete })
	ajouterAuFil(if prete then "Tu as quitté la file d'attente." else "🌐 Tu es dans la file pour Police contre Fugitifs !", Color3.fromRGB(90, 150, 255))
end)
carteBattle.Activated:Connect(function()
	ouvrirMenu(false)
	local prete = joueur:GetAttribute("PretBattle") == true
	Partie:FireServer({ type = "pretBattle", valeur = not prete })
	ajouterAuFil(if prete then "Tu as quitté la file du Drift Battle." else "🔥 Tu es dans la file du Drift Battle !", Color3.fromRGB(255, 90, 170))
end)
carteGarage.Activated:Connect(function()
	ouvrirMenu(false)
	Partie:FireServer({ type = "garage" })
end)

-- Le menu s'ouvre tout seul à la fin de l'intro (la première fois)
task.spawn(function()
	while not joueur:GetAttribute("IntroFinie") do
		task.wait(0.3)
	end
	task.wait(0.5)
	if joueur:GetAttribute("Role") == nil then
		ouvrirMenu(true)
	end
end)

---------------------------------------------------------------------
-- Messages du serveur
---------------------------------------------------------------------
Partie.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	if info.type == "etat" then
		if info.etat == "attente" then
			texteBarre.Text = if joueur:GetAttribute("Pret")
				then ("✅ Prêt ! En attente de joueurs (%d/%d prêts)"):format(info.joueurs or 0, info.min or 2)
				elseif joueur:GetAttribute("PretBattle") then "🔥 Drift Battle : ça commence dans un instant…"
				else ("🏁 ENTRAÎNEMENT · Police vs Fugitifs : %d/%d dans la file · ☰ MENU pour jouer en ligne"):format(info.joueurs or 0, info.min or 2)
			texteBarre.TextColor3 = Color3.fromRGB(220, 220, 230)
		elseif info.etat == "intermission" then
			nombreBots = info.bots or 0
			comptePage.Text = if info.mode == "battle" then ("🔥 Départ dans %d s"):format(info.temps or 0) else ("🎲 Tirage au sort dans %d s"):format(info.temps or 0)
			majListe()
			local enBattle = info.mode == "battle"
			sousTitrePage.Text = if enBattle then "🔥 DRIFT BATTLE 🔥" else "🚓 POLICE  vs  FUGITIFS 🏃"
			aidePage.Text = if enBattle then "1 minute pour faire le plus de points de drift. Les plus longs drifts rapportent le plus !"
				else "Le tirage au sort décide de ton équipe. Les fugitifs partent au sud, la police au nord !"
			texteBarre.Text = if joueur:GetAttribute("Pret") or joueur:GetAttribute("PretBattle")
				then (if enBattle then ("🔥 DRIFT BATTLE · départ dans %d s"):format(info.temps or 0) else ("🚓 POLICE vs FUGITIFS 🏃 · tirage au sort dans %d s"):format(info.temps or 0))
				else ("🌐 Une partie en ligne commence dans %d s · ☰ MENU > JOUER EN LIGNE pour la rejoindre"):format(info.temps or 0)
				.. (if (info.bots or 0) > 0 then " · 🤖 + bot de test" else "")
			texteBarre.TextColor3 = Color3.fromRGB(255, 215, 80)
		elseif info.etat == "battle" then
			texteBarre.Text = ("🔥 %s   ·   %de / %d   ·   %d pts   ·   1er : %s (%d)"):format(formatTemps(info.temps or 0), info.monRang or 1, info.nb or 1, info.monScore or 0, info.premier or "", info.scorePremier or 0)
			texteBarre.TextColor3 = Color3.fromRGB(255, 120, 190)
		elseif info.etat == "manche" then
			texteBarre.Text = ("⏱ %s   ·   🏃 %d/%d fugitifs libres"):format(formatTemps(info.temps or 0), info.restants or 0, info.total or 0)
			texteBarre.TextColor3 = if joueur:GetAttribute("Role") == "Police" then BLEU else ORANGE
		end
	elseif info.type == "tirage" then
		-- La roulette : 🚓 / 🏃 qui défilent, puis ton équipe
		task.spawn(function()
			local d = 0.06
			for i = 1, 22 do
				local police = i % 2 == 0
				montrerCarte("TIRAGE AU SORT...", if police then "🚓 POLICE" else "🏃 FUGITIF", "", if police then BLEU else ORANGE)
				echelleCarte.Scale = 1
				task.wait(d)
				d *= 1.12
			end
			if info.equipe == "Police" then
				montrerCarte(("TU ES POLICIER ! (%d policiers contre %d fugitifs)"):format(info.nbPolice or 0, info.nbFugitifs or 0), "🚓 POLICE",
					"Attrape TOUS les fugitifs avant la fin du temps ! Fonce sur leur kart pour les arrêter.", BLEU, 4)
			else
				montrerCarte(("TU ES FUGITIF ! (%d fugitifs contre %d policiers)"):format(info.nbFugitifs or 0, info.nbPolice or 0), "🏃 FUGITIF",
					"Échappe à la police jusqu'à la fin du temps ! Ne te laisse pas coller par un kart de police.", ORANGE, 4)
			end
		end)
	elseif info.type == "battle" then
		montrerCarte(("🔥 DRIFT BATTLE · %d joueur%s"):format(info.nb or 1, if (info.nb or 1) > 1 then "s" else ""), "🔥 DRIFT BATTLE",
			("%d secondes pour faire le plus de points de drift. Enchaîne les longs drifts et les 360 !"):format(info.duree or 60),
			Color3.fromRGB(255, 90, 170), 3.5)
	elseif info.type == "finBattle" then
		local premier = info.classement and info.classement[1]
		montrerCarte("🏁 FIN DU DRIFT BATTLE", if premier then ("🏆 %s GAGNE !"):format(string.upper(premier.nom)) else "FIN !",
			if premier then ("%d points de drift · meilleur drift %d"):format(premier.total, premier.meilleur) else "", Color3.fromRGB(255, 90, 170), 6.5)
		montrerClassement("🏆 CLASSEMENT DU DRIFT BATTLE", info.classement, 6.5)
	elseif info.type == "info" then
		ajouterAuFil(info.texte or "", Color3.fromRGB(255, 215, 80))
	elseif info.type == "arrestation" then
		ajouterAuFil(("🚔 %s a arrêté %s !"):format(info.policier or "?", info.fugitif or "?"), BLEU)
	elseif info.type == "arrete" then
		montrerCarte("🚨 ARRÊTÉ PAR " .. string.upper(info.par or "LA POLICE") .. " 🚨", "TU ES ARRÊTÉ !",
			"Tu regardes la fin de la manche depuis le garage. Courage à ton équipe !", Color3.fromRGB(255, 70, 70), 4)
	elseif info.type == "fin" then
		local police = info.gagnant == "Police"
		local monRole = joueur:GetAttribute("Role")
		local gagne = (police and monRole == "Police") or (not police and monRole == "Fugitif")
		montrerCarte(
			if gagne then ("🏆 VICTOIRE ! +%d XP"):format(info.xp or 0) else "Dommage... la prochaine sera la bonne !",
			if police then "🚓 LA POLICE GAGNE !" else "🏃 LES FUGITIFS GAGNENT !",
			if police then "Tous les fugitifs ont été arrêtés." else "Au moins un fugitif a échappé à la police !",
			if police then BLEU else ORANGE,
			5.5
		)
		if info.classement and #info.classement > 0 then
			montrerClassement(if info.roi then ("👑 ROI DU DRIFT : %s"):format(info.roi) else "🏆 CLASSEMENT DES DRIFTS", info.classement, 5.5)
		end
	end
end)
