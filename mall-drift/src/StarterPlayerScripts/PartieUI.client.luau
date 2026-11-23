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

-- (la colonne rétrécit un peu sur les petits écrans)
local echelleColonne = Instance.new("UIScale")
echelleColonne.Parent = colonne
local function ajusterColonne()
	echelleColonne.Scale = math.clamp(camera.ViewportSize.Y / 920, 0.62, 1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterColonne)
ajusterColonne()

local POLICE_COURSE = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local ROUGE_MENU = Color3.fromRGB(225, 30, 45)

-- Le titre : GOLDEN MALL en blanc, DRIFT en rouge
local titreMenu = texte(colonne, UDim2.new(1, 0, 0, 72), UDim2.new(0, 0, 0.1, 0), Color3.new(1, 1, 1))
titreMenu.RichText = true
titreMenu.Text = 'GOLDEN MALL <font color="#E11E2D">DRIFT</font>'
titreMenu.FontFace = POLICE_COURSE
titreMenu.TextXAlignment = Enum.TextXAlignment.Left
titreMenu.ZIndex = 22
local slogan = texte(colonne, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0.1, 82), Color3.new(1, 1, 1))
slogan.Text = "Vitesse. Drift. Évasion."
slogan.FontFace = POLICE_COURSE
slogan.TextXAlignment = Enum.TextXAlignment.Left
slogan.ZIndex = 22
local sousTitreMenu = texte(colonne, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0.1, 112), Color3.fromRGB(215, 215, 222), Enum.Font.GothamMedium)
sousTitreMenu.Text = "Drifte dans le plus grand mall de " .. Config.Lieu .. " et sème la police."
sousTitreMenu.TextXAlignment = Enum.TextXAlignment.Left
sousTitreMenu.ZIndex = 22

local listeBoutons = Instance.new("Frame")
listeBoutons.Size = UDim2.new(1, 0, 0, 0)
listeBoutons.AutomaticSize = Enum.AutomaticSize.Y
listeBoutons.Position = UDim2.new(0, 0, 0.1, 152)
listeBoutons.BackgroundTransparency = 1
listeBoutons.ZIndex = 21
listeBoutons.Parent = colonne
local dispositionBoutons = Instance.new("UIListLayout")
dispositionBoutons.Padding = UDim.new(0, 8)
dispositionBoutons.SortOrder = Enum.SortOrder.LayoutOrder
dispositionBoutons.Parent = listeBoutons

local boutonsMenu = {} -- (pour l'animation d'arrivée)
local ordreMenu = 0

-- Une carte du menu : icône + titre + description + flèche.
-- principal = le gros bouton rouge (JOUER) ; petit = les modes sous JOUER
local function carteMode(icone: string, titre: string, description: string, couleur: Color3, principal: boolean?, parent: Instance?, petit: boolean?): (TextButton, TextLabel, TextLabel)
	local hauteur = if principal then 96 elseif petit then 54 else 64
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, hauteur)
	ordreMenu += 1
	b.LayoutOrder = ordreMenu
	b.BackgroundColor3 = if principal then ROUGE_MENU elseif petit then Color3.fromRGB(32, 30, 36) else Color3.fromRGB(20, 20, 24)
	b.BackgroundTransparency = if principal then 0 else 0.08
	b.Text = ""
	b.AutoButtonColor = false
	b.ZIndex = 22
	b.Parent = parent or listeBoutons
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
	local bord = Instance.new("UIStroke")
	bord.Thickness = 1
	bord.Color = if principal then Color3.fromRGB(255, 110, 120) else Color3.fromRGB(60, 60, 70)
	bord.Transparency = if principal then 0.3 else 0.4
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = b
	-- Petite barre de couleur à gauche (couleur du mode)
	if not principal then
		local barre = Instance.new("Frame")
		barre.Size = UDim2.new(0, 3, 1, -16)
		barre.Position = UDim2.new(0, 0, 0, 8)
		barre.BackgroundColor3 = couleur
		barre.BorderSizePixel = 0
		barre.ZIndex = 23
		barre.Parent = b
	end
	local decalage = if principal then 26 else 64
	local i = texte(b, UDim2.new(0, 36, 0, 36), UDim2.new(0, 16, 0.5, -18), Color3.new(1, 1, 1))
	i.Text = icone
	i.ZIndex = 23
	i.Visible = not principal
	local t = texte(b, UDim2.new(1, -decalage - 70, 0, if principal then 40 else 24), UDim2.new(0, decalage, 0, if principal then 14 else 9), Color3.new(1, 1, 1))
	t.Text = titre
	t.FontFace = POLICE_COURSE
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 23
	local d = texte(b, UDim2.new(1, -decalage - 70, 0, if principal then 18 else 16), UDim2.new(0, decalage, 0, if principal then 62 else 36), Color3.fromRGB(220, 220, 228), Enum.Font.GothamMedium)
	d.Text = description
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.ZIndex = 23
	local fleche = texte(b, UDim2.new(0, if principal then 48 else 24, 0, if principal then 48 else 24), UDim2.new(1, if principal then -74 else -40, 0.5, if principal then -24 else -12), Color3.new(1, 1, 1))
	fleche.Text = if principal then "»" else "›"
	fleche.ZIndex = 23
	-- Reflet qui balaie le gros bouton rouge
	if principal then
		local reflet = Instance.new("UIGradient")
		reflet.Color = ColorSequence.new(Color3.new(1, 1, 1))
		reflet.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0),
			NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(1, 0),
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
	-- Survol : la carte s'éclaire et la flèche avance
	local echelle = Instance.new("UIScale")
	echelle.Parent = b
	local couleurFond = b.BackgroundColor3
	local positionFleche = fleche.Position
	b.MouseEnter:Connect(function()
		TweenService:Create(echelle, TweenInfo.new(0.15), { Scale = 1.03 }):Play()
		TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = if principal then Color3.fromRGB(245, 50, 65) else Color3.fromRGB(40, 40, 48) }):Play()
		TweenService:Create(fleche, TweenInfo.new(0.15), { Position = positionFleche + UDim2.fromOffset(8, 0) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(echelle, TweenInfo.new(0.15), { Scale = 1 }):Play()
		TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = couleurFond }):Play()
		TweenService:Create(fleche, TweenInfo.new(0.15), { Position = positionFleche }):Play()
	end)
	if not petit then
		table.insert(boutonsMenu, b)
	end
	return b, t, d
end

-- JOUER : ouvre / ferme la liste des 3 modes juste en dessous
local carteJouer, _, descJouer = carteMode("", "JOUER", "Choisis ton mode : entraînement, en ligne ou Drift Battle", ROUGE_MENU, true)
local listeModes = Instance.new("Frame")
ordreMenu += 1
listeModes.LayoutOrder = ordreMenu
listeModes.Size = UDim2.new(1, -24, 0, 0)
listeModes.BackgroundTransparency = 1
listeModes.ClipsDescendants = true
listeModes.ZIndex = 21
listeModes.Parent = listeBoutons
local margeModes = Instance.new("UIPadding")
margeModes.PaddingLeft = UDim.new(0, 24)
margeModes.Parent = listeModes
local dispoModes = Instance.new("UIListLayout")
dispoModes.Padding = UDim.new(0, 6)
dispoModes.SortOrder = Enum.SortOrder.LayoutOrder
dispoModes.Parent = listeModes
local carteEntrainement = carteMode("🏁", "ENTRAÎNEMENT", "Drift libre, la police du mall te poursuit", Color3.fromRGB(80, 220, 120), false, listeModes, true)
local carteEnLigne, titreEnLigne, descEnLigne = carteMode("🌐", "JOUER EN LIGNE", "Police contre Fugitifs avec de vrais joueurs", Color3.fromRGB(90, 150, 255), false, listeModes, true)
local carteBattle = carteMode("🔥", "DRIFT BATTLE", "Défi solo : 1 minute pour le meilleur score", Color3.fromRGB(255, 90, 170), false, listeModes, true)
local HAUTEUR_MODES = 3 * 54 + 2 * 6 + 2
local modesOuverts = false
local function ouvrirModes(ouvert: boolean)
	modesOuverts = ouvert
	TweenService:Create(listeModes, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Size = UDim2.new(1, -24, 0, if ouvert then HAUTEUR_MODES else 0) }):Play()
	descJouer.Text = if ouvert then "▼ Choisis ton mode ci-dessous" else "Choisis ton mode : entraînement, en ligne ou Drift Battle"
end
carteJouer.Activated:Connect(function()
	ouvrirModes(not modesOuverts)
end)

local carteLobby = carteMode("", "RETOUR AU LOBBY", "Change de mode ou personnalise ton kart", ROUGE_MENU, true)
local carteGarage = carteMode("🔧", "GARAGE", "Personnalise ton kart : couleurs, peintures, néons…", Color3.fromRGB(255, 205, 70))
local carteMagasin = carteMode("🛒", "MAGASIN", "Pièces, peintures premium et kart exclusif", Color3.fromRGB(255, 205, 70))
local carteTuto = carteMode("📖", "TUTO", "Apprends à drifter en 3 étapes, sur la piste", Color3.fromRGB(150, 200, 255))
-- Dans une place de jeu (entraînement, partie, défi) : « retour au lobby » à la place de JOUER
carteLobby.Visible = DANS_UNE_PLACE_DE_JEU
for _, carteJeu in ipairs({ carteJouer, listeModes, carteGarage } :: { GuiObject }) do
	carteJeu.Visible = not DANS_UNE_PLACE_DE_JEU
end

-- En bas à droite : l'offre du moment (le kart exclusif)
local offrePromo = nil
for _, offre in ipairs(Config.Boutique or {}) do
	if offre.Promo and not offrePromo then
		offrePromo = offre -- (la 1re offre « Promo » : le kart exclusif)
	end
end
local cartePromo = Instance.new("TextButton")
cartePromo.AnchorPoint = Vector2.new(1, 1)
cartePromo.Size = UDim2.new(0, 430, 0, 120)
cartePromo.Position = UDim2.new(1, -40, 1, -40)
cartePromo.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
cartePromo.BackgroundTransparency = 0.05
cartePromo.AutoButtonColor = false
cartePromo.Text = ""
cartePromo.ZIndex = 22
cartePromo.Visible = offrePromo ~= nil
cartePromo.Parent = fondMenu
Instance.new("UICorner", cartePromo).CornerRadius = UDim.new(0, 4)
local bordPromo = Instance.new("UIStroke")
bordPromo.Thickness = 2
bordPromo.Color = Color3.fromRGB(255, 120, 230)
bordPromo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
bordPromo.Parent = cartePromo
local degradeBordPromo = Instance.new("UIGradient") -- contour arc-en-ciel qui tourne
degradeBordPromo.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 200)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(120, 200, 255)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 230, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 200)),
})
degradeBordPromo.Parent = bordPromo
local barrePromo = Instance.new("Frame")
barrePromo.Size = UDim2.new(0, 5, 1, 0)
barrePromo.BackgroundColor3 = ROUGE_MENU
barrePromo.BorderSizePixel = 0
barrePromo.ZIndex = 23
barrePromo.Parent = cartePromo
local etiquettePromo = Instance.new("TextLabel")
etiquettePromo.Size = UDim2.new(0, 150, 0, 22)
etiquettePromo.Position = UDim2.new(0, 22, 0, 14)
etiquettePromo.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
etiquettePromo.TextColor3 = Color3.new(1, 1, 1)
etiquettePromo.Font = Enum.Font.GothamBold
etiquettePromo.TextScaled = true
etiquettePromo.Text = "✦ ÉDITION EXCLUSIVE"
etiquettePromo.ZIndex = 23
etiquettePromo.Parent = cartePromo
Instance.new("UICorner", etiquettePromo).CornerRadius = UDim.new(0, 4)
local textePromo = texte(cartePromo, UDim2.new(1, -190, 0, 30), UDim2.new(0, 22, 0, 44), Color3.new(1, 1, 1))
textePromo.Text = offrePromo and offrePromo.Nom or ""
textePromo.FontFace = POLICE_COURSE
textePromo.TextXAlignment = Enum.TextXAlignment.Left
textePromo.ZIndex = 23
local prixPromo = texte(cartePromo, UDim2.new(1, -190, 0, 30), UDim2.new(0, 22, 0, 78), Color3.fromRGB(210, 210, 220), Enum.Font.GothamMedium)
prixPromo.Text = offrePromo and offrePromo.Description or ""
prixPromo.TextXAlignment = Enum.TextXAlignment.Left
prixPromo.TextYAlignment = Enum.TextYAlignment.Top
prixPromo.TextWrapped = true
prixPromo.ZIndex = 23
local boutonVoirPromo = Instance.new("TextLabel")
boutonVoirPromo.AnchorPoint = Vector2.new(1, 0.5)
boutonVoirPromo.Size = UDim2.new(0, 140, 0, 50)
boutonVoirPromo.Position = UDim2.new(1, -16, 0.5, 0)
boutonVoirPromo.BackgroundColor3 = ROUGE_MENU
boutonVoirPromo.TextColor3 = Color3.new(1, 1, 1)
boutonVoirPromo.FontFace = POLICE_COURSE
boutonVoirPromo.TextScaled = true
boutonVoirPromo.Text = offrePromo and offrePromo.PrixAffiche or "VOIR"
boutonVoirPromo.ZIndex = 23
boutonVoirPromo.Parent = cartePromo
Instance.new("UICorner", boutonVoirPromo).CornerRadius = UDim.new(0, 4)
local margeVoir = Instance.new("UIPadding")
margeVoir.PaddingTop = UDim.new(0, 12)
margeVoir.PaddingBottom = UDim.new(0, 12)
margeVoir.Parent = boutonVoirPromo
task.spawn(function()
	while cartePromo.Parent do
		degradeBordPromo.Rotation = (degradeBordPromo.Rotation + 3) % 360
		task.wait(0.03)
	end
end)

-- En haut à droite : pièces et niveau
local piecesMenu = texte(fondMenu, UDim2.new(0, 300, 0, 26), UDim2.new(1, -400, 0, 74), Color3.fromRGB(255, 220, 90), Enum.Font.GothamBold)
piecesMenu.TextXAlignment = Enum.TextXAlignment.Right
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
badgeDirect.Position = UDim2.new(1, -96, 0, 110)
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

-- KARTS DE DÉMO : quand personne ne roule sur ce serveur (au lobby, il n'y a pas
-- de karts), quelques karts (visibles seulement par toi) font le tour du mall
-- en driftant dans les virages, pour que le fond du menu soit toujours vivant.
local KartBuilder = require(ReplicatedStorage:WaitForChild("KartBuilder"))
local CIRCUIT_DEMO = { -- la boucle : allées nord et sud, allées transversales
	Vector3.new(-173, 0, -137), Vector3.new(173, 0, -137), Vector3.new(173, 0, 137), Vector3.new(-173, 0, 137),
}
local RAYON_VIRAGE = 22
local pointsDemo: { Vector3 } = {}
do
	-- Rectangle aux coins arrondis, découpé en petits segments
	local n = #CIRCUIT_DEMO
	for k = 1, n do
		local avant = CIRCUIT_DEMO[(k - 2) % n + 1]
		local coin = CIRCUIT_DEMO[k]
		local apres = CIRCUIT_DEMO[k % n + 1]
		local entree = coin + (avant - coin).Unit * RAYON_VIRAGE
		local sortie = coin + (apres - coin).Unit * RAYON_VIRAGE
		for t = 0, 1, 0.125 do
			local a = entree:Lerp(coin, t)
			local b = coin:Lerp(sortie, t)
			table.insert(pointsDemo, a:Lerp(b, t))
		end
	end
end
local longueursDemo = {}
local LONGUEUR_DEMO = 0
for k = 1, #pointsDemo do
	longueursDemo[k] = LONGUEUR_DEMO
	LONGUEUR_DEMO += (pointsDemo[k % #pointsDemo + 1] - pointsDemo[k]).Magnitude
end
local function surCircuit(distance: number): (Vector3, Vector3, number)
	distance %= LONGUEUR_DEMO
	local k = 1
	while k < #pointsDemo and longueursDemo[k + 1] <= distance do
		k += 1
	end
	local a, b = pointsDemo[k], pointsDemo[k % #pointsDemo + 1]
	local seg = (b - a).Magnitude
	local t = if seg > 0 then (distance - longueursDemo[k]) / seg else 0
	local suivant = pointsDemo[(k + 1) % #pointsDemo + 1]
	local courbure = (b - a).Unit:Cross((suivant - b).Unit).Y -- (≠ 0 dans les virages)
	return a:Lerp(b, t), (b - a).Unit, courbure
end

local dossierDemo: Folder? = nil
local kartsDemo: { { modele: Model, decalage: number, vitesse: number, angle: number, fumee: ParticleEmitter } } = {}
local COULEURS_DEMO = { { "Rouge", "Rose" }, { "Bleu", "Cyan" }, { "Jaune", "Vert" }, { "Violet", "Violet" }, { "Orange", "Rouge" }, { "Blanc", "Bleu" } }

local function creerKartsDemo()
	if dossierDemo then
		return
	end
	local dossier = Instance.new("Folder")
	dossier.Name = "KartsDemoMenu"
	dossier.Parent = workspace
	dossierDemo = dossier
	for i, couleurs in ipairs(COULEURS_DEMO) do
		local perso = table.clone(Config.PersoParDefaut)
		perso.Carrosserie = couleurs[1]
		perso.Neon = couleurs[2]
		perso.Finition = "Métallisé"
		perso.Numero = math.random(1, 99)
		local m = KartBuilder.Construire(perso, CFrame.new(0, -50, 0), true)
		-- Un petit pilote avec son casque
		local base = (m.PrimaryPart :: BasePart).CFrame
		local function morceau(nom: string, taille: Vector3, decal: CFrame, couleur: Color3, sphere: boolean?)
			local p = Instance.new("Part")
			p.Name = nom
			p.Size = taille
			p.CFrame = base * decal
			p.Color = couleur
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			if sphere then
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			end
			p.Parent = m
		end
		local couleurKart = (Config.Couleur(couleurs[1]) or Config.Couleurs[1]).Couleur
		morceau("CorpsPilote", Vector3.new(1.7, 1.6, 0.9), CFrame.new(0, 1.65, 1.35), Color3.fromRGB(30, 30, 36))
		morceau("CasquePilote", Vector3.new(1.35, 1.35, 1.4), CFrame.new(0, 3.05, 1.25), couleurKart, true)
		morceau("Visiere", Vector3.new(1, 0.45, 0.5), CFrame.new(0, 3.05, 0.72), Color3.fromRGB(20, 25, 35), true)
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local fumee = Instance.new("ParticleEmitter")
		fumee.Color = ColorSequence.new(Color3.fromRGB(225, 225, 230))
		fumee.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.5) })
		fumee.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		fumee.Lifetime = NumberRange.new(0.6, 1)
		fumee.Speed = NumberRange.new(1, 3)
		fumee.Rate = 40
		fumee.Enabled = false
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, -0.3, 2.8)
		att.Parent = m.PrimaryPart
		fumee.Parent = att
		m.Parent = dossier
		table.insert(kartsDemo, { modele = m, decalage = (i - 1) * 26 + math.random(0, 8), vitesse = 46 + math.random(-4, 4), angle = 0, fumee = fumee })
	end
end

local function retirerKartsDemo()
	if dossierDemo then
		dossierDemo:Destroy()
		dossierDemo = nil
	end
	kartsDemo = {}
end

local tempsDemo = 0
local function animerKartsDemo(dt: number)
	tempsDemo += dt
	for _, k in ipairs(kartsDemo) do
		k.decalage += k.vitesse * dt
		local pos, direction, courbure = surCircuit(k.decalage)
		-- Dans les virages, le kart part en glisse (de travers) et fume
		local cible = if math.abs(courbure) > 0.05 then -math.sign(courbure) * math.rad(38) else 0
		k.angle += (cible - k.angle) * math.clamp(dt * 4, 0, 1)
		k.fumee.Enabled = math.abs(k.angle) > 0.2
		local cf = CFrame.lookAt(pos + Vector3.new(0, 2.1, 0), pos + Vector3.new(0, 2.1, 0) + direction) * CFrame.Angles(0, k.angle, 0)
		k.modele:PivotTo(cf)
	end
end

-- LA CAMÉRA DU MENU : elle tourne en continu autour de l'action. Elle suit
-- un vrai kart en jeu s'il y en a (🔴 EN DIRECT), sinon le peloton de démo.
local pointVise: Vector3? = nil
RunService.RenderStepped:Connect(function(dt)
	if not cameraMenu then
		badgeDirect.Visible = false
		if dossierDemo then
			retirerKartsDemo()
		end
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
		prochainChangement = maintenant + 10
	end

	local cible: Vector3
	if cibleDirect and cibleDirect.Parent then
		if dossierDemo then
			retirerKartsDemo()
		end
		cible = cibleDirect.Position
		badgeDirect.Text = "🔴 EN DIRECT · " .. nomDirect
		badgeDirect.Visible = true
	else
		creerKartsDemo()
		animerKartsDemo(dt)
		local premier = kartsDemo[1]
		cible = if premier then premier.modele:GetPivot().Position else Vector3.new(0, 5, 0)
		badgeDirect.Visible = false
	end
	pointVise = if pointVise then pointVise:Lerp(cible, math.clamp(dt * 2.5, 0, 1)) else cible
	-- Orbite qui tourne tout le temps, assez haute pour voir les karts et le mall
	angleMenu += dt * 0.16
	local centre = pointVise :: Vector3
	local pos = centre + Vector3.new(math.cos(angleMenu) * 30, 14 + math.sin(angleMenu * 0.7) * 3, math.sin(angleMenu) * 30)
	local voulu = CFrame.lookAt(pos, centre + Vector3.new(0, 1.5, 0))
	cfCamera = if cfCamera then cfCamera:Lerp(voulu, math.clamp(dt * 4, 0, 1)) else voulu
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
			pointVise = nil
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
		ouvrirModes(false)
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

-- Dès qu'on arrive dans le jeu (et au retour d'une partie) : le menu s'ouvre
-- directement, avec la partie qui se joue en fond
task.spawn(function()
	if EN_LOBBY or TYPE == "ToutEnUn" then
		while not joueur:GetAttribute("IntroFinie") do
			task.wait(0.2)
		end
		local perso = joueur.Character or joueur.CharacterAdded:Wait()
		perso:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.3)
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

carteTuto.Activated:Connect(function()
	ouvrirMenu(false)
	joueur:SetAttribute("RevoirTuto", true) -- le script Tutoriel s'en occupe
end)
