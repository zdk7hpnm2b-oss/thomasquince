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
local TeleportService = game:GetService("TeleportService")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local controles = require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")
local Partie = remotes:WaitForChild("Partie", 30)
local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local TYPE = Config.TypeDePlace() -- "ToutEnUn", "Lobby", "Entrainement", "PoliceFugitifs", "DriftBattle"…
local Voyage = remotes:WaitForChild("Voyage", 10) -- (matchmaking entre les places)
local EN_LOBBY = TYPE == "Lobby"
local DANS_UNE_PLACE_DE_JEU = TYPE ~= "Lobby" and TYPE ~= "ToutEnUn"
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
-- L'ÉCRAN DE CHARGEMENT (voyage entre le lobby et les places de jeu)
---------------------------------------------------------------------
local function creerEcranChargement(parent: Instance): (Frame, TextLabel)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
	f.ZIndex = 100
	f.Parent = parent
	local t1 = Instance.new("TextLabel")
	t1.AnchorPoint = Vector2.new(0.5, 0.5)
	t1.Size = UDim2.new(0.8, 0, 0, 70)
	t1.Position = UDim2.fromScale(0.5, 0.42)
	t1.BackgroundTransparency = 1
	t1.Font = Enum.Font.GothamBlack
	t1.TextScaled = true
	t1.TextColor3 = Color3.fromRGB(255, 205, 70)
	t1.Text = "GOLDEN MALL DRIFT"
	t1.ZIndex = 101
	t1.Parent = f
	local t2 = Instance.new("TextLabel")
	t2.AnchorPoint = Vector2.new(0.5, 0.5)
	t2.Size = UDim2.new(0.7, 0, 0, 36)
	t2.Position = UDim2.fromScale(0.5, 0.54)
	t2.BackgroundTransparency = 1
	t2.Font = Enum.Font.GothamBold
	t2.TextScaled = true
	t2.TextColor3 = Color3.new(1, 1, 1)
	t2.Text = "Chargement…"
	t2.ZIndex = 101
	t2.Parent = f
	return f, t2
end
local ecranVoyage, texteVoyage = creerEcranChargement(gui)
ecranVoyage.Visible = false
-- (le même écran reste affiché pendant la téléportation)
local guiTeleport = Instance.new("ScreenGui")
guiTeleport.Name = "ChargementVoyage"
guiTeleport.IgnoreGuiInset = true
creerEcranChargement(guiTeleport)
pcall(function()
	TeleportService:SetTeleportGui(guiTeleport)
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
fondMenu.BackgroundTransparency = 0
fondMenu.Visible = false
fondMenu.ZIndex = 20
fondMenu.Parent = gui
-- Dégradé : sombre à gauche (sous les boutons), transparent à droite (on voit la carte)
local degradeMenu = Instance.new("UIGradient")
degradeMenu.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.15),
	NumberSequenceKeypoint.new(0.42, 0.55),
	NumberSequenceKeypoint.new(0.7, 1),
	NumberSequenceKeypoint.new(1, 1),
})
degradeMenu.Parent = fondMenu

local colonne = Instance.new("Frame")
colonne.Name = "Colonne"
colonne.Size = UDim2.new(0, 470, 1, 0)
colonne.Position = UDim2.new(0, 46, 0, 0)
colonne.BackgroundTransparency = 1
colonne.ZIndex = 21
colonne.Parent = fondMenu

local bienvenue = texte(colonne, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0.17, 0), Color3.fromRGB(220, 220, 230), Enum.Font.GothamBold)
bienvenue.Text = "BIENVENUE AU"
bienvenue.TextXAlignment = Enum.TextXAlignment.Left
bienvenue.ZIndex = 22
local titreMenu = texte(colonne, UDim2.new(1, 0, 0, 64), UDim2.new(0, 0, 0.17, 24), Color3.new(1, 1, 1))
titreMenu.Text = string.upper(Config.NomDuJeu)
titreMenu.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic) -- gras italique, style course
titreMenu.TextXAlignment = Enum.TextXAlignment.Left
titreMenu.ZIndex = 22
local sousTitreMenu = texte(colonne, UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0.17, 90), Color3.fromRGB(255, 205, 70), Enum.Font.GothamBold)
sousTitreMenu.Text = "✦ " .. Config.Lieu .. " ✦"
sousTitreMenu.TextXAlignment = Enum.TextXAlignment.Left
sousTitreMenu.ZIndex = 22

local listeBoutons = Instance.new("Frame")
listeBoutons.Size = UDim2.new(1, 0, 0, 420)
listeBoutons.Position = UDim2.new(0, 0, 0.17, 130)
listeBoutons.BackgroundTransparency = 1
listeBoutons.ZIndex = 21
listeBoutons.Parent = colonne
local dispositionBoutons = Instance.new("UIListLayout")
dispositionBoutons.Padding = UDim.new(0, 10)
dispositionBoutons.SortOrder = Enum.SortOrder.LayoutOrder
dispositionBoutons.Parent = listeBoutons

local boutonsMenu = {} -- (pour l'animation d'arrivée)
local ROUGE_MENU = Color3.fromRGB(215, 35, 40)

-- Un grand bouton du menu : icône + titre + description + flèche
local function carteMode(icone: string, titre: string, description: string, couleur: Color3, principal: boolean?): (TextButton, TextLabel, TextLabel)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 64)
	b.LayoutOrder = #boutonsMenu + 1
	b.BackgroundColor3 = if principal then ROUGE_MENU else Color3.fromRGB(22, 22, 28)
	b.BackgroundTransparency = if principal then 0 else 0.1
	b.Text = ""
	b.AutoButtonColor = false
	b.ZIndex = 22
	b.Parent = listeBoutons
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	local bord = Instance.new("UIStroke")
	bord.Thickness = 2
	bord.Color = if principal then Color3.fromRGB(255, 120, 120) else couleur
	bord.Transparency = if principal then 0 else 0.5
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = b
	local i = texte(b, UDim2.new(0, 50, 0, 44), UDim2.new(0, 14, 0, 10), Color3.new(1, 1, 1))
	i.Text = icone
	i.ZIndex = 23
	local t = texte(b, UDim2.new(1, -120, 0, 26), UDim2.new(0, 76, 0, 9), Color3.new(1, 1, 1))
	t.Text = titre
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 23
	local d = texte(b, UDim2.new(1, -120, 0, 18), UDim2.new(0, 76, 0, 38), Color3.fromRGB(200, 200, 210), Enum.Font.GothamMedium)
	d.Text = description
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.ZIndex = 23
	local fleche = texte(b, UDim2.new(0, 30, 0, 30), UDim2.new(1, -44, 0, 17), Color3.new(1, 1, 1))
	fleche.Text = if principal then "»" else "›"
	fleche.ZIndex = 23
	-- Reflet qui balaie le bouton principal
	if principal then
		local reflet = Instance.new("UIGradient")
		reflet.Color = ColorSequence.new(Color3.new(1, 1, 1))
		reflet.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0),
			NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(1, 0),
		})
		reflet.Rotation = 20
		reflet.Parent = b
		task.spawn(function()
			while b.Parent do
				reflet.Offset = Vector2.new(-1, 0)
				TweenService:Create(reflet, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) }):Play()
				task.wait(3)
			end
		end)
	end
	-- Survol : le bouton s'avance et s'éclaire
	local echelle = Instance.new("UIScale")
	echelle.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(echelle, TweenInfo.new(0.15), { Scale = 1.04 }):Play()
		TweenService:Create(bord, TweenInfo.new(0.15), { Transparency = 0 }):Play()
		TweenService:Create(fleche, TweenInfo.new(0.15), { Position = UDim2.new(1, -36, 0, 17) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(echelle, TweenInfo.new(0.15), { Scale = 1 }):Play()
		TweenService:Create(bord, TweenInfo.new(0.15), { Transparency = if principal then 0 else 0.5 }):Play()
		TweenService:Create(fleche, TweenInfo.new(0.15), { Position = UDim2.new(1, -44, 0, 17) }):Play()
	end)
	table.insert(boutonsMenu, b)
	return b, t, d
end

local carteGarage = carteMode("🔧", "GARAGE", "Personnalise ton kart : couleurs, peintures, néons…", ROUGE_MENU, true)
local carteEntrainement = carteMode("🏁", "ENTRAÎNEMENT", "Drift libre, la police du mall te poursuit", Color3.fromRGB(80, 220, 120))
local carteEnLigne, titreEnLigne, descEnLigne = carteMode("🌐", "JOUER EN LIGNE", "Police contre Fugitifs avec de vrais joueurs", Color3.fromRGB(90, 150, 255))
local carteBattle = carteMode("🔥", "DRIFT BATTLE", "Défi solo : 1 minute pour le meilleur score", Color3.fromRGB(255, 90, 170))
local carteMagasin = carteMode("🛒", "MAGASIN", "Pièces, peintures premium et packs", Color3.fromRGB(255, 205, 70))
local carteLobby = carteMode("🏠", "RETOUR AU LOBBY", "Change de mode ou personnalise ton kart", Color3.fromRGB(255, 205, 70), true)
-- Dans une place de jeu (entraînement, partie, défi) : « retour au lobby » + magasin
carteLobby.Visible = DANS_UNE_PLACE_DE_JEU
for _, carteJeu in ipairs({ carteEntrainement, carteEnLigne, carteBattle, carteGarage }) do
	carteJeu.Visible = not DANS_UNE_PLACE_DE_JEU
end

-- La carte promo (Pack de démarrage)
local offrePromo = nil
for _, offre in ipairs(Config.Boutique or {}) do
	if offre.Promo and not offrePromo then
		offrePromo = offre -- (la 1re offre « Promo » : le kart exclusif)
	end
end
local cartePromo = Instance.new("TextButton")
cartePromo.Size = UDim2.new(0.8, 0, 0, 62)
cartePromo.LayoutOrder = 99
cartePromo.BackgroundColor3 = Color3.fromRGB(25, 20, 10)
cartePromo.Text = ""
cartePromo.ZIndex = 22
cartePromo.Visible = offrePromo ~= nil
cartePromo.Parent = listeBoutons
Instance.new("UICorner", cartePromo).CornerRadius = UDim.new(0, 12)
local bordPromo = Instance.new("UIStroke")
bordPromo.Thickness = 3
bordPromo.Color = Color3.fromRGB(255, 205, 40)
bordPromo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bordPromo.Parent = cartePromo
local textePromo = texte(cartePromo, UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 0, 6), Color3.new(1, 1, 1))
textePromo.Text = offrePromo and offrePromo.Nom or ""
textePromo.TextXAlignment = Enum.TextXAlignment.Left
textePromo.ZIndex = 23
local prixPromo = texte(cartePromo, UDim2.new(1, -24, 0, 20), UDim2.new(0, 12, 0, 36), Color3.fromRGB(120, 255, 140), Enum.Font.GothamBold)
prixPromo.Text = offrePromo and (offrePromo.PrixAffiche .. "  ·  " .. offrePromo.Description) or ""
prixPromo.TextXAlignment = Enum.TextXAlignment.Left
prixPromo.ZIndex = 23
task.spawn(function() -- le cadre doré « respire »
	while cartePromo.Parent do
		TweenService:Create(bordPromo, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Transparency = 0.6 }):Play()
		task.wait(0.8)
		TweenService:Create(bordPromo, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Transparency = 0 }):Play()
		task.wait(0.8)
	end
end)

local piecesMenu = texte(colonne, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0.17, 560), Color3.fromRGB(255, 220, 90), Enum.Font.GothamBold)
piecesMenu.TextXAlignment = Enum.TextXAlignment.Left
piecesMenu.ZIndex = 22
piecesMenu.Text = "💰 0 pièces"
remotes:WaitForChild("ProfilMisAJour").OnClientEvent:Connect(function(profil)
	if type(profil) == "table" then
		piecesMenu.Text = ("💰 %d pièces  ·  Niveau %d"):format(profil.Pieces or 0, profil.Niveau or 1)
	end
end)
task.spawn(function()
	local profil = remotes:WaitForChild("ObtenirProfil"):InvokeServer()
	if type(profil) == "table" then
		piecesMenu.Text = ("💰 %d pièces  ·  Niveau %d"):format(profil.Pieces or 0, profil.Niveau or 1)
	end
end)

local boutonFermerMenu = Instance.new("TextButton")
boutonFermerMenu.AnchorPoint = Vector2.new(1, 0)
boutonFermerMenu.Size = UDim2.new(0, 54, 0, 54)
boutonFermerMenu.Position = UDim2.new(1, -24, 0, 60)
boutonFermerMenu.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
boutonFermerMenu.TextColor3 = Color3.new(1, 1, 1)
boutonFermerMenu.Font = Enum.Font.GothamBlack
boutonFermerMenu.TextScaled = true
boutonFermerMenu.Text = "✕"
boutonFermerMenu.ZIndex = 22
boutonFermerMenu.Parent = fondMenu
Instance.new("UICorner", boutonFermerMenu).CornerRadius = UDim.new(0, 12)

---------------------------------------------------------------------
-- LE MAGASIN : packs de pièces et Pack de démarrage (Robux)
---------------------------------------------------------------------
local MarketplaceService = game:GetService("MarketplaceService")
local panneauMagasin = Instance.new("Frame")
panneauMagasin.AnchorPoint = Vector2.new(0.5, 0.5)
panneauMagasin.Size = UDim2.new(0, 520, 0, 460)
panneauMagasin.Position = UDim2.fromScale(0.62, 0.5)
panneauMagasin.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
panneauMagasin.Visible = false
panneauMagasin.ZIndex = 30
panneauMagasin.Parent = fondMenu
Instance.new("UICorner", panneauMagasin).CornerRadius = UDim.new(0, 16)
local bordMagasin = Instance.new("UIStroke")
bordMagasin.Thickness = 3
bordMagasin.Color = Color3.fromRGB(255, 205, 70)
bordMagasin.Parent = panneauMagasin
local titreMagasin = texte(panneauMagasin, UDim2.new(1, -30, 0, 34), UDim2.new(0, 15, 0, 14), Color3.fromRGB(255, 205, 70))
titreMagasin.Text = "🛒 MAGASIN"
titreMagasin.ZIndex = 31
local listeMagasin = Instance.new("Frame")
listeMagasin.Size = UDim2.new(1, -30, 1, -70)
listeMagasin.Position = UDim2.new(0, 15, 0, 58)
listeMagasin.BackgroundTransparency = 1
listeMagasin.ZIndex = 31
listeMagasin.Parent = panneauMagasin
local dispoMagasin = Instance.new("UIListLayout")
dispoMagasin.Padding = UDim.new(0, 10)
dispoMagasin.Parent = listeMagasin
for _, offre in ipairs(Config.Boutique or {}) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 80)
	b.BackgroundColor3 = if offre.Promo then Color3.fromRGB(40, 30, 10) else Color3.fromRGB(28, 28, 36)
	b.Text = ""
	b.ZIndex = 32
	b.Parent = listeMagasin
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	local bord = Instance.new("UIStroke")
	bord.Thickness = 2
	bord.Color = if offre.Promo then Color3.fromRGB(255, 205, 40) else Color3.fromRGB(80, 80, 95)
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = b
	local n = texte(b, UDim2.new(0.68, 0, 0, 30), UDim2.new(0, 14, 0, 10), Color3.new(1, 1, 1))
	n.Text = offre.Nom
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.ZIndex = 33
	local dsc = texte(b, UDim2.new(0.68, 0, 0, 22), UDim2.new(0, 14, 0, 46), Color3.fromRGB(200, 200, 210), Enum.Font.GothamMedium)
	dsc.Text = offre.Description
	dsc.TextXAlignment = Enum.TextXAlignment.Left
	dsc.ZIndex = 33
	local prix = Instance.new("TextLabel")
	prix.AnchorPoint = Vector2.new(1, 0.5)
	prix.Size = UDim2.new(0, 130, 0, 46)
	prix.Position = UDim2.new(1, -12, 0.5, 0)
	prix.BackgroundColor3 = Color3.fromRGB(40, 150, 80)
	prix.TextColor3 = Color3.new(1, 1, 1)
	prix.Font = Enum.Font.GothamBlack
	prix.TextScaled = true
	prix.Text = offre.PrixAffiche
	prix.ZIndex = 33
	prix.Parent = b
	Instance.new("UICorner", prix).CornerRadius = UDim.new(0, 10)
	-- Le vrai prix Roblox, si le produit est configuré
	if (offre.ProduitId or 0) ~= 0 then
		task.spawn(function()
			local ok, infos = pcall(function()
				return MarketplaceService:GetProductInfo(offre.ProduitId, Enum.InfoType.Product)
			end)
			if ok and infos and infos.PriceInRobux then
				prix.Text = "R$ " .. tostring(infos.PriceInRobux)
			end
		end)
	end
	b.Activated:Connect(function()
		if (offre.ProduitId or 0) ~= 0 then
			MarketplaceService:PromptProductPurchase(joueur, offre.ProduitId)
		else
			local resultat = remotes:WaitForChild("Acheter"):InvokeServer({ type = "test", nom = offre.Id })
			if type(resultat) == "table" then
				ajouterAuFil(resultat.message or "", if resultat.ok then Color3.fromRGB(140, 255, 160) else Color3.fromRGB(255, 140, 140))
			end
		end
	end)
end
local fermerMagasin = Instance.new("TextButton")
fermerMagasin.AnchorPoint = Vector2.new(1, 0)
fermerMagasin.Size = UDim2.new(0, 40, 0, 40)
fermerMagasin.Position = UDim2.new(1, -12, 0, 12)
fermerMagasin.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
fermerMagasin.TextColor3 = Color3.new(1, 1, 1)
fermerMagasin.Font = Enum.Font.GothamBlack
fermerMagasin.TextScaled = true
fermerMagasin.Text = "✕"
fermerMagasin.ZIndex = 33
fermerMagasin.Parent = panneauMagasin
Instance.new("UICorner", fermerMagasin).CornerRadius = UDim.new(0, 10)
fermerMagasin.Activated:Connect(function()
	panneauMagasin.Visible = false
end)
local function ouvrirMagasin()
	panneauMagasin.Visible = true
	local e = panneauMagasin:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	e.Parent = panneauMagasin
	e.Scale = 0.6
	TweenService:Create(e, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end
carteMagasin.Activated:Connect(ouvrirMagasin)

-- Bouton « 📖 TUTO » (en haut à droite) : revoir le tuto de pilotage
local boutonTuto = Instance.new("TextButton")
boutonTuto.AnchorPoint = Vector2.new(1, 0)
boutonTuto.Size = UDim2.new(0, 150, 0, 54)
boutonTuto.Position = UDim2.new(1, -90, 0, 60)
boutonTuto.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
boutonTuto.TextColor3 = Color3.new(1, 1, 1)
boutonTuto.Font = Enum.Font.GothamBlack
boutonTuto.TextScaled = true
boutonTuto.Text = "📖 TUTO"
boutonTuto.ZIndex = 22
boutonTuto.Parent = fondMenu
Instance.new("UICorner", boutonTuto).CornerRadius = UDim.new(0, 12)
local margeTuto = Instance.new("UIPadding")
margeTuto.PaddingTop = UDim.new(0, 12)
margeTuto.PaddingBottom = UDim.new(0, 12)
margeTuto.Parent = boutonTuto
cartePromo.Activated:Connect(ouvrirMagasin)

-- EN FOND DU MENU : la partie EN DIRECT. La caméra suit un kart qui roule
-- (un autre joueur, un bot ou la police en poursuite) et change de pilote
-- toutes les 8 secondes. Si personne ne roule : elle survole le mall.
local angleMenu = 0
local cameraMenu = false
local cibleDirect: BasePart? = nil
local nomDirect = ""
local prochainChangement = 0
local cfCamera: CFrame? = nil

local badgeDirect = Instance.new("TextLabel")
badgeDirect.AnchorPoint = Vector2.new(1, 0)
badgeDirect.Size = UDim2.new(0, 320, 0, 36)
badgeDirect.Position = UDim2.new(1, -96, 0, 68)
badgeDirect.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
badgeDirect.BackgroundTransparency = 0.2
badgeDirect.TextColor3 = Color3.new(1, 1, 1)
badgeDirect.Font = Enum.Font.GothamBlack
badgeDirect.TextScaled = true
badgeDirect.Visible = false
badgeDirect.ZIndex = 22
badgeDirect.Parent = fondMenu
Instance.new("UICorner", badgeDirect).CornerRadius = UDim.new(0, 10)
local margeBadge = Instance.new("UIPadding")
margeBadge.PaddingTop = UDim.new(0, 6)
margeBadge.PaddingBottom = UDim.new(0, 6)
margeBadge.Parent = badgeDirect

-- Les karts qui roulent en ce moment : { pièce à suivre, nom }
local function kartsEnJeu(): { { BasePart | string } }
	local liste = {}
	local dossier = workspace:FindFirstChild("KartsJoueurs")
	if dossier then
		for _, k in ipairs(dossier:GetChildren()) do
			local siege = k:FindFirstChild("Siege") :: Seat?
			local chassis = (k :: Model).PrimaryPart
			local pilote = siege and siege.Occupant and Players:GetPlayerFromCharacter(siege.Occupant.Parent)
			if chassis and pilote and pilote ~= joueur then
				table.insert(liste, { chassis, pilote.DisplayName })
			end
		end
	end
	local bots = workspace:FindFirstChild("BotsManche")
	if bots then
		for _, b in ipairs(bots:GetChildren()) do
			local racine = b:FindFirstChild("HumanoidRootPart") :: BasePart?
			if racine then
				table.insert(liste, { racine, "🤖 " .. b.Name })
			end
		end
	end
	local police = workspace:FindFirstChild("Securite")
	if police then
		for _, g in ipairs(police:GetChildren()) do
			local racine = g:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- (seulement les policiers en poursuite, dans leur kart de police)
			if racine and g:FindFirstChild("KartPolice") then
				table.insert(liste, { racine, "🚓 Police du mall" })
			end
		end
	end
	return liste
end

RunService.RenderStepped:Connect(function(dt)
	if not cameraMenu then
		badgeDirect.Visible = false
		return
	end
	local maintenant = os.clock()
	if not cibleDirect or not cibleDirect.Parent or maintenant > prochainChangement then
		local liste = kartsEnJeu()
		if #liste > 0 then
			local choix = liste[math.random(1, #liste)]
			cibleDirect = choix[1] :: BasePart
			nomDirect = choix[2] :: string
		else
			cibleDirect = nil
		end
		prochainChangement = maintenant + 8
	end

	local voulu: CFrame
	if cibleDirect and cibleDirect.Parent then
		-- Caméra de télé : derrière et au-dessus du kart, qui le suit en douceur
		local avant = Vector3.new(cibleDirect.CFrame.LookVector.X, 0, cibleDirect.CFrame.LookVector.Z)
		if avant.Magnitude < 0.1 then
			avant = Vector3.new(0, 0, -1)
		end
		avant = avant.Unit
		local pos = cibleDirect.Position - avant * 16 + Vector3.new(0, 7, 0)
		voulu = CFrame.lookAt(pos, cibleDirect.Position + avant * 6 + Vector3.new(0, 1.5, 0))
		badgeDirect.Text = "🔴 EN DIRECT · " .. nomDirect
		badgeDirect.Visible = true
	else
		-- Personne ne roule : survol du mall
		angleMenu += dt * 0.06
		local centre = Vector3.new(0, 10, -20)
		local pos = centre + Vector3.new(math.cos(angleMenu) * 26, 22 + math.sin(angleMenu * 2) * 3, math.sin(angleMenu) * 110)
		voulu = CFrame.lookAt(pos, centre + Vector3.new(math.sin(angleMenu) * 30, -4, -math.cos(angleMenu) * 40))
		badgeDirect.Visible = false
	end
	cfCamera = if cfCamera then cfCamera:Lerp(voulu, math.clamp(dt * 3, 0, 1)) else voulu
	camera.CFrame = cfCamera :: CFrame
end)

local function majMenu()
	local enManche = joueur:GetAttribute("Role") ~= nil
	local prete = joueur:GetAttribute("Pret") == true
	local preteBattle = false
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
for _, nom in ipairs({ "Pret", "Role", "IntroFinie", "EnSalle" }) do
	joueur:GetAttributeChangedSignal(nom):Connect(majMenu)
end
majMenu()

local function ouvrirMenu(ouvert: boolean)
	local dejaOuvert = fondMenu.Visible
	fondMenu.Visible = ouvert
	panneauMagasin.Visible = false
	majMenu()
	local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	local auVolant = h and h.SeatPart ~= nil
	if ouvert and not dejaOuvert then
		-- La caméra montre la carte (sauf si on est au volant)
		if not auVolant and not joueur:GetAttribute("EnSalle") then
			cameraMenu = true
			cfCamera = nil -- (on repart d'une caméra neuve)
			prochainChangement = 0
			camera.CameraType = Enum.CameraType.Scriptable
		end
		-- Les boutons arrivent en glissant, l'un après l'autre
		for i, b in ipairs(boutonsMenu) do
			local e = b:FindFirstChildOfClass("UIScale")
			b.Position = UDim2.new(-0.6, 0, 0, 0)
			if e then
				e.Scale = 0.9
			end
			task.delay(i * 0.06, function()
				if e then
					TweenService:Create(e, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				end
			end)
		end
		titreMenu.TextTransparency = 1
		TweenService:Create(titreMenu, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	elseif not ouvert and cameraMenu then
		cameraMenu = false
		if not auVolant then
			camera.CameraType = Enum.CameraType.Custom
		end
	end
end
boutonMenu.Activated:Connect(function()
	ouvrirMenu(not fondMenu.Visible)
end)
boutonFermerMenu.Activated:Connect(function()
	ouvrirMenu(false)
end)
carteLobby.Activated:Connect(function()
	ouvrirMenu(false)
	if Voyage then
		Voyage:FireServer({ mode = "Lobby" })
	end
end)
carteEntrainement.Activated:Connect(function()
	ouvrirMenu(false)
	if EN_LOBBY and Voyage then
		Voyage:FireServer({ mode = "Entrainement" }) -- direction la place Entraînement
		return
	end
	if joueur:GetAttribute("Pret") then
		Partie:FireServer({ type = "pret", valeur = false })
	end
	-- On part directement sur la ligne de départ (survol + 3, 2, 1, PARTEZ)
	remotes:WaitForChild("SortirKart"):FireServer()
end)
carteEnLigne.Activated:Connect(function()
	ouvrirMenu(false)
	local prete = joueur:GetAttribute("Pret") == true
	if EN_LOBBY and Voyage then
		Voyage:FireServer({ mode = "PoliceFugitifs" }) -- file d'attente du matchmaking
	else
		Partie:FireServer({ type = "pret", valeur = not prete })
	end
	ajouterAuFil(if prete then "Tu as quitté la file d'attente." else "🌐 Tu es dans la file pour Police contre Fugitifs !", Color3.fromRGB(90, 150, 255))
end)
carteBattle.Activated:Connect(function()
	ouvrirMenu(false)
	if EN_LOBBY and Voyage then
		Voyage:FireServer({ mode = "DriftBattle" }) -- direction la place Drift Battle
	else
		Partie:FireServer({ type = "battle" }) -- le défi démarre tout de suite
	end
end)
carteGarage.Activated:Connect(function()
	ouvrirMenu(false)
	Partie:FireServer({ type = "garage" })
end)

-- (En arrivant, on visite le garage : le menu s'ouvre avec le bouton « ☰ MENU »)

if Voyage then
	Voyage.OnClientEvent:Connect(function(info)
		if type(info) ~= "table" then
			return
		end
		if info.type == "file" and EN_LOBBY then
			texteBarre.Text = if joueur:GetAttribute("Pret")
				then ("🌐 Dans la file Police vs Fugitifs : %d/%d joueurs… la partie arrive !"):format(info.n or 0, info.min or 2)
				else ("🏠 LOBBY · Police vs Fugitifs : %d joueur(s) dans la file · ☰ MENU pour jouer"):format(info.n or 0)
			texteBarre.TextColor3 = Color3.fromRGB(220, 220, 230)
		elseif info.type == "depart" then
			texteVoyage.Text = info.texte or "Chargement…"
			ecranVoyage.Visible = true
			task.delay(15, function()
				ecranVoyage.Visible = false -- (au cas où le voyage échoue)
			end)
		elseif info.type == "erreur" then
			ecranVoyage.Visible = false
			ajouterAuFil("⚠ " .. (info.texte or "Erreur de voyage"), Color3.fromRGB(255, 100, 100))
		end
	end)
end

-- Retour au lobby après une partie : le menu s'ouvre directement
task.spawn(function()
	local donnees = TeleportService:GetLocalPlayerTeleportData()
	if EN_LOBBY and type(donnees) == "table" and donnees.ouvrirMenu then
		while not joueur:GetAttribute("IntroFinie") do
			task.wait(0.3)
		end
		task.wait(0.5)
		ouvrirMenu(true)
	end
end)

---------------------------------------------------------------------
-- LE CLASSEMENT MONDIAL DU DRIFT BATTLE : top 3 + ta place directement
---------------------------------------------------------------------
local panneauMondial = Instance.new("Frame")
panneauMondial.AnchorPoint = Vector2.new(0.5, 0.5)
panneauMondial.Size = UDim2.new(0, 480, 0, 400)
panneauMondial.Position = UDim2.fromScale(0.5, 0.5)
panneauMondial.BackgroundColor3 = FOND
panneauMondial.BackgroundTransparency = 0.05
panneauMondial.Visible = false
panneauMondial.ZIndex = 40
panneauMondial.Parent = gui
Instance.new("UICorner", panneauMondial).CornerRadius = UDim.new(0, 18)
local bordMondial = Instance.new("UIStroke")
bordMondial.Thickness = 4
bordMondial.Color = Color3.fromRGB(255, 205, 70)
bordMondial.Parent = panneauMondial
local titreMondial = texte(panneauMondial, UDim2.new(1, -30, 0, 30), UDim2.new(0, 15, 0, 12), Color3.fromRGB(255, 205, 70))
titreMondial.Text = "🏆 CLASSEMENT MONDIAL · DRIFT BATTLE"
titreMondial.ZIndex = 41
local maPlace = texte(panneauMondial, UDim2.new(1, -30, 0, 48), UDim2.new(0, 15, 0, 46), Color3.new(1, 1, 1))
maPlace.ZIndex = 41
local lignesMondial = Instance.new("Frame")
lignesMondial.Size = UDim2.new(1, -30, 0, 250)
lignesMondial.Position = UDim2.new(0, 15, 0, 100)
lignesMondial.BackgroundTransparency = 1
lignesMondial.ZIndex = 41
lignesMondial.Parent = panneauMondial
local listeMondial = Instance.new("UIListLayout")
listeMondial.Padding = UDim.new(0, 3)
listeMondial.SortOrder = Enum.SortOrder.LayoutOrder
listeMondial.Parent = lignesMondial
local boutonOK = Instance.new("TextButton")
boutonOK.AnchorPoint = Vector2.new(0.5, 1)
boutonOK.Size = UDim2.new(0, 160, 0, 40)
boutonOK.Position = UDim2.new(0.5, 0, 1, -12)
boutonOK.BackgroundColor3 = Color3.fromRGB(110, 60, 220)
boutonOK.TextColor3 = Color3.new(1, 1, 1)
boutonOK.Font = Enum.Font.GothamBlack
boutonOK.TextScaled = true
boutonOK.Text = "OK"
boutonOK.ZIndex = 42
boutonOK.Parent = panneauMondial
Instance.new("UICorner", boutonOK).CornerRadius = UDim.new(0, 10)
boutonOK.Activated:Connect(function()
	panneauMondial.Visible = false
end)

local function ligneMondial(ordre: number, txt: string, couleur: Color3)
	local l = texte(lignesMondial, UDim2.new(1, 0, 0, 26), UDim2.new(), couleur, Enum.Font.GothamBold)
	l.LayoutOrder = ordre
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = txt
	l.ZIndex = 42
end

local function montrerClassementMondial(info)
	for _, enfant in ipairs(lignesMondial:GetChildren()) do
		if enfant:IsA("TextLabel") then
			enfant:Destroy()
		end
	end
	maPlace.Text = ("Tu es %de ! · ton record : %d pts"):format(info.rang or 1, info.record or 0)
	local medailles = { "🥇", "🥈", "🥉" }
	local ordre = 0
	local dejaMontre = {}
	for _, l in ipairs(info.top or {}) do
		ordre += 1
		dejaMontre[l.rang] = true
		local estMoi = l.rang == info.rang
		ligneMondial(ordre, ("%s %d. %s — %d pts"):format(medailles[l.rang] or "", l.rang, l.nom, l.score),
			if estMoi then Color3.fromRGB(255, 230, 120) else Color3.new(1, 1, 1))
	end
	local premierAutour = info.autour and info.autour[1]
	if premierAutour and premierAutour.rang > 4 then
		ordre += 1
		ligneMondial(ordre, "          · · ·", Color3.fromRGB(150, 150, 160))
	end
	for _, l in ipairs(info.autour or {}) do
		if not dejaMontre[l.rang] then
			ordre += 1
			ligneMondial(ordre, ("%s%d. %s — %d pts"):format(if l.moi then "👉 " else "     ", l.rang, l.nom, l.score),
				if l.moi then Color3.fromRGB(255, 230, 120) else Color3.fromRGB(210, 210, 220))
		end
	end
	panneauMondial.Visible = true
end

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
			texteBarre.Text = if joueur:GetAttribute("Pret")
				then (if enBattle then ("🔥 DRIFT BATTLE · départ dans %d s"):format(info.temps or 0) else ("🚓 POLICE vs FUGITIFS 🏃 · tirage au sort dans %d s"):format(info.temps or 0))
				else ("🌐 Une partie en ligne commence dans %d s · ☰ MENU > JOUER EN LIGNE pour la rejoindre"):format(info.temps or 0)
				.. (if (info.bots or 0) > 0 then " · 🤖 + bot de test" else "")
			texteBarre.TextColor3 = Color3.fromRGB(255, 215, 80)
		elseif info.etat == "battle" then
			texteBarre.Text = ("🔥 DRIFT BATTLE · %s   ·   %d pts   ·   record %d"):format(formatTemps(info.temps or 0), info.monScore or 0, info.record or 0)
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
		-- Le petit titre de 2 secondes
		montrerCarte("DÉFI SOLO", "🔥 DRIFT BATTLE",
			("%d secondes pour faire le plus de points de drift !"):format(info.duree or 60),
			Color3.fromRGB(255, 90, 170), 2)
	elseif info.type == "finBattle" then
		montrerCarte(if info.nouveauRecord then "🏆 NOUVEAU RECORD !" else ("Ton record : %d pts"):format(info.record or 0),
			("🔥 %d POINTS"):format(info.total or 0),
			("Meilleur drift : %d"):format(info.meilleur or 0),
			if info.nouveauRecord then Color3.fromRGB(255, 205, 70) else Color3.fromRGB(255, 90, 170), 3)
		task.delay(3, function()
			if not DANS_UNE_PLACE_DE_JEU then
				ouvrirMenu(true) -- retour direct au menu
			end
		end)
	elseif info.type == "classementMondial" then
		task.delay(3, function()
			montrerClassementMondial(info)
		end)
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

boutonTuto.Activated:Connect(function()
	ouvrirMenu(false)
	joueur:SetAttribute("RevoirTuto", true) -- le script Tutoriel s'en occupe
end)
