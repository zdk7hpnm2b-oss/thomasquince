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
	t.Font = police or Enum.Font.FredokaOne
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
	local l = texte(fil, UDim2.new(1, 0, 0, 26), UDim2.new(), couleur, Enum.Font.FredokaOne)
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
local petitTitre = texte(carte, UDim2.new(1, -30, 0, 34), UDim2.new(0, 15, 0, 18), Color3.fromRGB(200, 200, 210), Enum.Font.FredokaOne)
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
		local l = texte(lignesTableau, UDim2.new(1, 0, 0, 26), UDim2.new(), if ligne.nom == joueur.DisplayName then Color3.fromRGB(255, 230, 120) else Color3.new(1, 1, 1), Enum.Font.FredokaOne)
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
local listePage = texte(page, UDim2.new(0.7, 0, 0, 30), UDim2.new(0.15, 0, 0.8, 0), Color3.fromRGB(220, 220, 230), Enum.Font.FredokaOne)
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
	t1.Font = Enum.Font.FredokaOne
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
	t2.Font = Enum.Font.FredokaOne
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
boutonMenu.AnchorPoint = Vector2.new(1, 0) -- en haut à droite, sous le score (en bas, il y a les boutons tactiles)
boutonMenu.Size = UDim2.new(0, 170, 0, 46)
boutonMenu.Position = UDim2.new(1, -16, 0, 128)
boutonMenu.Font = Enum.Font.FredokaOne
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
	echelleColonne.Scale = math.clamp(camera.ViewportSize.Y / 920, 0.5, 1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterColonne)
ajusterColonne()

local POLICE_COURSE = Font.fromEnum(Enum.Font.FredokaOne)
local ROUGE_MENU = Color3.fromRGB(225, 30, 45)

-- Le titre : GOLDEN MALL en blanc, DRIFT en rouge
local titreMenu = texte(colonne, UDim2.new(1, 0, 0, 72), UDim2.new(0, 0, 0.1, 0), Color3.new(1, 1, 1))
titreMenu.RichText = true
titreMenu.Text = 'GOLDEN MALL <font color="#E11E2D">DRIFT</font>'
titreMenu.FontFace = POLICE_COURSE
titreMenu.TextXAlignment = Enum.TextXAlignment.Left
titreMenu.ZIndex = 22
local slogan = texte(colonne, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0.1, 82), Color3.new(1, 1, 1))
slogan.Text = ""
slogan.Visible = false
slogan.FontFace = POLICE_COURSE
slogan.TextXAlignment = Enum.TextXAlignment.Left
slogan.ZIndex = 22
local sousTitreMenu = texte(colonne, UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0.1, 80), Color3.fromRGB(215, 215, 222), Enum.Font.GothamMedium)
sousTitreMenu.Text = "Le plus grand mall de " .. Config.Lieu
sousTitreMenu.TextXAlignment = Enum.TextXAlignment.Left
sousTitreMenu.ZIndex = 22

local listeBoutons = Instance.new("Frame")
listeBoutons.Size = UDim2.new(1, 0, 0, 0)
listeBoutons.AutomaticSize = Enum.AutomaticSize.Y
listeBoutons.Position = UDim2.new(0, 0, 0.1, 124)
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
	-- Relief : un bord épais en bas, plus foncé (comme un vrai bouton de jeu)
	local relief = Instance.new("Frame")
	relief.AnchorPoint = Vector2.new(0, 1)
	relief.Size = UDim2.new(1, 0, 0, 5)
	relief.Position = UDim2.new(0, 0, 1, 0)
	relief.BackgroundColor3 = if principal then Color3.fromRGB(140, 10, 25) else couleur:Lerp(Color3.new(0, 0, 0), 0.35)
	relief.BorderSizePixel = 0
	relief.ZIndex = 23
	relief.Parent = b
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
	-- Pastille d'icône bien colorée (style bonbon : dégradé clair → vif, contour blanc)
	local pastille = Instance.new("Frame")
	pastille.Size = UDim2.fromOffset(if petit then 38 else 44, if petit then 38 else 44)
	pastille.Position = UDim2.new(0, 12, 0.5, if petit then -19 else -22)
	pastille.BackgroundColor3 = Color3.new(1, 1, 1)
	pastille.Visible = not principal
	pastille.ZIndex = 23
	pastille.Parent = b
	Instance.new("UICorner", pastille).CornerRadius = UDim.new(0, 10)
	local degradePastille = Instance.new("UIGradient")
	degradePastille.Color = ColorSequence.new(couleur:Lerp(Color3.new(1, 1, 1), 0.35), couleur:Lerp(Color3.new(0, 0, 0), 0.15))
	degradePastille.Rotation = 90
	degradePastille.Parent = pastille
	local contourPastille = Instance.new("UIStroke")
	contourPastille.Color = Color3.new(1, 1, 1)
	contourPastille.Transparency = 0.55
	contourPastille.Thickness = 2
	contourPastille.Parent = pastille
	local i = texte(pastille, UDim2.new(1, -12, 1, -12), UDim2.fromOffset(6, 6), Color3.new(1, 1, 1))
	i.Text = icone
	i.ZIndex = 24
	-- Vraie icône (image) si elle est réglée dans Config.Icones
	local image = Config.ImageIcone(icone)
	if image then
		i.Visible = false
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(1, -12, 1, -12)
		img.Position = UDim2.fromOffset(6, 6)
		img.BackgroundTransparency = 1
		img.Image = image
		img.ZIndex = 24
		img.Parent = pastille
	end
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
local carteJouer, _, descJouer = carteMode("", "JOUER", "Choisis ton mode", ROUGE_MENU, true)
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
local carteEntrainement = carteMode("🏁", "ENTRAÎNEMENT", "Drift libre", Color3.fromRGB(40, 220, 110), false, listeModes, true)
local carteEnLigne, titreEnLigne, descEnLigne = carteMode("🌐", "EN LIGNE", "Police contre Fugitifs", Color3.fromRGB(50, 140, 255), false, listeModes, true)
local carteBattle = carteMode("🔥", "DRIFT BATTLE", "1 minute, meilleur score", Color3.fromRGB(255, 60, 130), false, listeModes, true)
local HAUTEUR_MODES = 3 * 54 + 2 * 6 + 2
local modesOuverts = false
local function ouvrirModes(ouvert: boolean)
	modesOuverts = ouvert
	TweenService:Create(listeModes, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { Size = UDim2.new(1, -24, 0, if ouvert then HAUTEUR_MODES else 0) }):Play()
	descJouer.Text = if ouvert then "Choisis ton mode" else "Choisis ton mode"
end
carteJouer.Activated:Connect(function()
	ouvrirModes(not modesOuverts)
end)

local carteLobby = carteMode("", "RETOUR AU LOBBY", "Change de mode ou personnalise ton kart", ROUGE_MENU, true)
-- GARAGE, ROUE, MAGASIN, TUTO : une grille 2 x 2 de grosses tuiles colorées
-- (une grande icône + un mot : moins chargé, plus attirant, comme les jeux Roblox populaires)
local grilleTuiles = Instance.new("Frame")
ordreMenu += 1
grilleTuiles.LayoutOrder = ordreMenu
grilleTuiles.Size = UDim2.new(1, 0, 0, 0)
grilleTuiles.AutomaticSize = Enum.AutomaticSize.Y
grilleTuiles.BackgroundTransparency = 1
grilleTuiles.ZIndex = 21
grilleTuiles.Parent = listeBoutons
local dispositionTuiles = Instance.new("UIGridLayout")
dispositionTuiles.CellSize = UDim2.new(0.5, -6, 0, 118)
dispositionTuiles.CellPadding = UDim2.fromOffset(12, 12)
dispositionTuiles.SortOrder = Enum.SortOrder.LayoutOrder
dispositionTuiles.Parent = grilleTuiles
local function tuile(ordre: number, icone: string, titre: string, couleur: Color3): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = ordre
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = 22
	b.Parent = grilleTuiles
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 14)
	local degrade = Instance.new("UIGradient") -- couleur vive, style bonbon
	degrade.Color = ColorSequence.new(couleur:Lerp(Color3.new(1, 1, 1), 0.3), couleur:Lerp(Color3.new(0, 0, 0), 0.1))
	degrade.Rotation = 90
	degrade.Parent = b
	local bord = Instance.new("UIStroke")
	bord.Color = Color3.new(1, 1, 1)
	bord.Thickness = 3
	bord.Transparency = 0.35
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = b
	-- Relief en bas (bouton « épais »)
	local relief = Instance.new("Frame")
	relief.AnchorPoint = Vector2.new(0, 1)
	relief.Size = UDim2.new(1, 0, 0, 7)
	relief.Position = UDim2.new(0, 0, 1, 0)
	relief.BackgroundColor3 = couleur:Lerp(Color3.new(0, 0, 0), 0.45)
	relief.BorderSizePixel = 0
	relief.ZIndex = 23
	relief.Parent = b
	Instance.new("UICorner", relief).CornerRadius = UDim.new(0, 14)
	-- Grande icône au centre
	local image = Config.ImageIcone(icone)
	if image then
		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Size = UDim2.fromOffset(56, 56)
		img.Position = UDim2.new(0.5, 0, 0, 12)
		img.BackgroundTransparency = 1
		img.Image = image
		img.ZIndex = 24
		img.Parent = b
	else
		local i = texte(b, UDim2.fromOffset(60, 56), UDim2.new(0.5, -30, 0, 12), Color3.new(1, 1, 1))
		i.Text = icone
		i.ZIndex = 24
	end
	local t = texte(b, UDim2.new(1, -16, 0, 30), UDim2.new(0, 8, 1, -44), Color3.new(1, 1, 1))
	t.Text = titre
	t.FontFace = POLICE_COURSE
	t.ZIndex = 24
	-- Survol : la tuile grossit et penche un peu
	local echelle = Instance.new("UIScale")
	echelle.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(echelle, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
		TweenService:Create(b, TweenInfo.new(0.15), { Rotation = -2 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(echelle, TweenInfo.new(0.15), { Scale = 1 }):Play()
		TweenService:Create(b, TweenInfo.new(0.15), { Rotation = 0 }):Play()
	end)
	table.insert(boutonsMenu, b)
	return b
end
local carteGarage = tuile(1, "🔧", "GARAGE", Color3.fromRGB(255, 130, 20))
local carteRoue = tuile(2, "🎡", "ROUE", Color3.fromRGB(255, 185, 0))
local carteMagasin = tuile(3, "🛒", "MAGASIN", Color3.fromRGB(240, 50, 200))
local carteTuto = tuile(4, "📖", "TUTO", Color3.fromRGB(0, 190, 230))
-- Dans une place de jeu (entraînement, partie, défi) : « retour au lobby » à la place de JOUER
-- (le menu d'accueil est le même partout : JOUER marche aussi depuis un mode de jeu)
carteLobby.Visible = false

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
etiquettePromo.Font = Enum.Font.FredokaOne
etiquettePromo.TextScaled = true
etiquettePromo.Text = "EXCLUSIF"
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
local piecesMenu = texte(fondMenu, UDim2.new(0, 300, 0, 26), UDim2.new(1, -400, 0, 74), Color3.fromRGB(255, 220, 90), Enum.Font.FredokaOne)
piecesMenu.TextXAlignment = Enum.TextXAlignment.Right
piecesMenu.ZIndex = 22
piecesMenu.Text = "💰 0 pièces"


local boutonFermerMenu = Instance.new("TextButton")
boutonFermerMenu.AnchorPoint = Vector2.new(1, 0)
boutonFermerMenu.Size = UDim2.new(0, 54, 0, 54)
boutonFermerMenu.Position = UDim2.new(1, -24, 0, 60)
boutonFermerMenu.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
boutonFermerMenu.TextColor3 = Color3.new(1, 1, 1)
boutonFermerMenu.Font = Enum.Font.FredokaOne
boutonFermerMenu.TextScaled = true
boutonFermerMenu.Text = "✕"
boutonFermerMenu.ZIndex = 22
boutonFermerMenu.Parent = fondMenu
Instance.new("UICorner", boutonFermerMenu).CornerRadius = UDim.new(0, 12)

-- LA COLONNE DE DROITE : tout est rangé dedans, l'un sous l'autre (rien ne se chevauche) :
--   [💰 pièces · niveau] [✕]   puis 🔴 EN DIRECT, les cadeaux (script Cadeaux), l'offre exclusive
local colonneDroite = Instance.new("Frame")
colonneDroite.Name = "ColonneDroite"
colonneDroite.AnchorPoint = Vector2.new(1, 0)
colonneDroite.Size = UDim2.new(0, 300, 0, 0)
colonneDroite.AutomaticSize = Enum.AutomaticSize.Y
colonneDroite.Position = UDim2.new(1, -30, 0, 50)
colonneDroite.BackgroundTransparency = 1
colonneDroite.ZIndex = 21
colonneDroite.Parent = fondMenu
local dispoDroite = Instance.new("UIListLayout")
dispoDroite.Padding = UDim.new(0, 10)
dispoDroite.SortOrder = Enum.SortOrder.LayoutOrder
dispoDroite.HorizontalAlignment = Enum.HorizontalAlignment.Right
dispoDroite.Parent = colonneDroite
local echelleDroite = Instance.new("UIScale")
echelleDroite.Parent = colonneDroite
local function ajusterDroite()
	-- (même taille que la colonne de gauche ; plus petit sur téléphone)
	echelleDroite.Scale = math.clamp(camera.ViewportSize.Y / 920, 0.5, 1)
	echelleColonne.Scale = echelleDroite.Scale
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(ajusterDroite)
ajusterDroite()
-- Ligne du haut : pièces + bouton fermer
local ligneHaut = Instance.new("Frame")
ligneHaut.LayoutOrder = 1
ligneHaut.Size = UDim2.new(1, 0, 0, 50)
ligneHaut.BackgroundTransparency = 1
ligneHaut.ZIndex = 21
ligneHaut.Parent = colonneDroite
piecesMenu.Parent = ligneHaut
piecesMenu.AnchorPoint = Vector2.new(0, 0.5)
piecesMenu.Size = UDim2.new(1, -64, 0, 24)
piecesMenu.Position = UDim2.new(0, 0, 0.5, 0)
boutonFermerMenu.Parent = ligneHaut
boutonFermerMenu.AnchorPoint = Vector2.new(1, 0)
boutonFermerMenu.Size = UDim2.new(0, 50, 0, 50)
boutonFermerMenu.Position = UDim2.new(1, 0, 0, 0)
-- L'offre exclusive, tout en bas de la colonne
cartePromo.Parent = colonneDroite
cartePromo.LayoutOrder = 4
cartePromo.AnchorPoint = Vector2.new(0, 0)
cartePromo.Size = UDim2.new(1, 0, 0, 150)
textePromo.Size = UDim2.new(1, -34, 0, 28)
prixPromo.Size = UDim2.new(1, -34, 0, 22)
prixPromo.Position = UDim2.new(0, 22, 0, 76)
boutonVoirPromo.AnchorPoint = Vector2.new(1, 1)
boutonVoirPromo.Size = UDim2.new(0, 130, 0, 42)
boutonVoirPromo.Position = UDim2.new(1, -12, 1, -12)

---------------------------------------------------------------------
-- LE MAGASIN (Robux) : onglets Offres / Traînées / Roue / Pièces
---------------------------------------------------------------------
local MarketplaceService = game:GetService("MarketplaceService")
local profilMenu: any = nil -- (le profil, pour savoir ce qui est déjà acheté)
local majMagasin: { () -> () } = {}

-- Une PAGE ENTIÈRE (magasin, roue…) : fond animé, grand titre, arrivée en glissant.
-- (largeur / hauteur ne servent plus : la page prend tout l'écran)
local flouPages = Instance.new("BlurEffect")
flouPages.Name = "FlouPages"
flouPages.Size = 0
flouPages.Parent = camera
local pagesListe: { Frame } = {}
-- Le flou n'est là que si le menu est ouvert ET qu'une page y est affichée
local function majFlouPages()
	local ouverte = false
	for _, page in ipairs(pagesListe) do
		if page.Visible then
			ouverte = true
		end
	end
	TweenService:Create(flouPages, TweenInfo.new(0.35), { Size = if ouverte and fondMenu.Visible then 14 else 0 }):Play()
end
fondMenu:GetPropertyChangedSignal("Visible"):Connect(majFlouPages)
local function fenetre(nom: string, titreFenetre: string, _largeur: number, _hauteur: number, couleurBord: Color3): (Frame, TextLabel)
	local f = Instance.new("Frame")
	f.Name = nom
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromScale(1, 1)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.03
	f.Visible = false
	f.ZIndex = 30
	f.Parent = fondMenu
	local degradeFond = Instance.new("UIGradient")
	degradeFond.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 14)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(16, 14, 20)),
		ColorSequenceKeypoint.new(1, couleurBord:Lerp(Color3.new(0, 0, 0), 0.72)),
	})
	degradeFond.Rotation = 25
	degradeFond.Parent = f
	-- Décor : grand titre en filigrane + traits lumineux qui défilent en diagonale
	local filigrane = Instance.new("TextLabel")
	filigrane.AnchorPoint = Vector2.new(1, 1)
	filigrane.Size = UDim2.new(0.9, 0, 0.32, 0)
	filigrane.Position = UDim2.new(1, 40, 1, 30)
	filigrane.BackgroundTransparency = 1
	filigrane.Text = string.upper((titreFenetre:gsub("^[^%w]+ ", "")))
	filigrane.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	filigrane.TextScaled = true
	filigrane.TextColor3 = Color3.new(1, 1, 1)
	filigrane.TextTransparency = 0.95
	filigrane.TextXAlignment = Enum.TextXAlignment.Right
	filigrane.ZIndex = 30
	filigrane.Parent = f
	local traits = {}
	for k = 1, 7 do
		local t = Instance.new("Frame")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Size = UDim2.new(0, 6 + (k % 3) * 4, 2.2, 0)
		t.Rotation = 28
		t.BackgroundColor3 = if k % 2 == 0 then couleurBord else Color3.new(1, 1, 1)
		t.BackgroundTransparency = 0.9
		t.BorderSizePixel = 0
		t.ZIndex = 30
		t.Parent = f
		traits[k] = { cadre = t, x = k / 7, vitesse = 0.04 + (k % 4) * 0.015 }
	end
	task.spawn(function()
		while f.Parent do
			if f.Visible then
				for _, t in ipairs(traits) do
					t.x = (t.x + t.vitesse * 0.03) % 1.4
					t.cadre.Position = UDim2.new(t.x - 0.2, 0, 0.5, 0)
				end
			end
			task.wait(0.03)
		end
	end)
	-- Le contenu est dans une zone centrée (marges autour)
	local marges = Instance.new("UIPadding")
	marges.PaddingLeft = UDim.new(0.07, 0)
	marges.PaddingRight = UDim.new(0.07, 0)
	marges.PaddingTop = UDim.new(0, 40)
	marges.PaddingBottom = UDim.new(0, 30)
	marges.Parent = f
	-- Barre de couleur sous le titre
	local soulignement = Instance.new("Frame")
	soulignement.Name = "Soulignement"
	soulignement.Size = UDim2.new(0, 140, 0, 5)
	soulignement.Position = UDim2.new(0, 20, 0, 62)
	soulignement.BackgroundColor3 = couleurBord
	soulignement.BorderSizePixel = 0
	soulignement.ZIndex = 31
	soulignement.Parent = f
	local t = texte(f, UDim2.new(1, -220, 0, 50), UDim2.new(0, 20, 0, 6), Color3.new(1, 1, 1))
	t.Text = titreFenetre
	t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 31
	local fermer = Instance.new("TextButton")
	fermer.AnchorPoint = Vector2.new(1, 0)
	fermer.Size = UDim2.new(0, 150, 0, 46)
	fermer.Position = UDim2.new(1, -10, 0, 8)
	fermer.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
	fermer.TextColor3 = Color3.new(1, 1, 1)
	fermer.Font = Enum.Font.FredokaOne
	fermer.TextScaled = true
	fermer.Text = "← RETOUR"
	fermer.ZIndex = 33
	fermer.Parent = f
	Instance.new("UICorner", fermer).CornerRadius = UDim.new(0, 6)
	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 12)
	marge.PaddingBottom = UDim.new(0, 12)
	marge.Parent = fermer
	fermer.Activated:Connect(function()
		f.Visible = false
	end)
	-- Flou de l'arrière-plan tant qu'une page est ouverte
	table.insert(pagesListe, f)
	f:GetPropertyChangedSignal("Visible"):Connect(majFlouPages)
	return f, t
end

-- Arrivée de la page : elle glisse depuis la droite, un éclair de couleur la balaie,
-- le titre et la barre arrivent juste après
local function apparaitre(f: Frame)
	for _, autre in ipairs(pagesListe) do
		if autre ~= f and not (f.Name == "Apercu" and autre.Name == "Magasin") then
			autre.Visible = false -- (une seule page à la fois)
		end
	end
	local pageCadeaux = fondMenu:FindFirstChild("PageCadeaux")
	if pageCadeaux and pageCadeaux:IsA("GuiObject") then
		pageCadeaux.Visible = false
	end
	f.Visible = true
	f.Position = UDim2.fromScale(1.5, 0.5)
	TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	local eclair = Instance.new("Frame")
	eclair.AnchorPoint = Vector2.new(0.5, 0.5)
	eclair.Size = UDim2.new(0, 160, 3, 0)
	eclair.Position = UDim2.fromScale(-0.2, 0.5)
	eclair.Rotation = 20
	eclair.BackgroundColor3 = Color3.new(1, 1, 1)
	eclair.BackgroundTransparency = 0.75
	eclair.BorderSizePixel = 0
	eclair.ZIndex = 60
	eclair.Parent = f
	local tw = TweenService:Create(eclair, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(1.3, 0.5), BackgroundTransparency = 1 })
	task.delay(0.25, function()
		tw:Play()
	end)
	tw.Completed:Connect(function()
		eclair:Destroy()
	end)
	local soulignement = f:FindFirstChild("Soulignement") :: Frame?
	if soulignement then
		soulignement.Size = UDim2.new(0, 0, 0, 5)
		TweenService:Create(soulignement, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 140, 0, 5) }):Play()
	end
end

local panneauMagasin = fenetre("Magasin", "MAGASIN", 560, 520, Color3.fromRGB(225, 30, 45))
local soldeMagasin = texte(panneauMagasin, UDim2.new(0, 220, 0, 28), UDim2.new(1, -400, 0, 16), Color3.fromRGB(255, 220, 90), Enum.Font.FredokaOne)
soldeMagasin.TextXAlignment = Enum.TextXAlignment.Right
soldeMagasin.ZIndex = 31

-- Onglets
local ongletsMagasin = Instance.new("Frame")
ongletsMagasin.Size = UDim2.new(1, -40, 0, 48)
ongletsMagasin.Position = UDim2.new(0, 20, 0, 86)
ongletsMagasin.BackgroundTransparency = 1
ongletsMagasin.ZIndex = 31
ongletsMagasin.Parent = panneauMagasin
local dispoOnglets = Instance.new("UIListLayout")
dispoOnglets.FillDirection = Enum.FillDirection.Horizontal
dispoOnglets.Padding = UDim.new(0, 6)
dispoOnglets.Parent = ongletsMagasin

local listeMagasin = Instance.new("ScrollingFrame")
listeMagasin.Size = UDim2.new(1, -30, 1, -156)
listeMagasin.Position = UDim2.new(0, 20, 0, 150)
listeMagasin.BackgroundTransparency = 1
listeMagasin.BorderSizePixel = 0
listeMagasin.ScrollBarThickness = 5
listeMagasin.ScrollBarImageColor3 = Color3.fromRGB(225, 30, 45)
listeMagasin.AutomaticCanvasSize = Enum.AutomaticSize.Y
listeMagasin.CanvasSize = UDim2.new()
listeMagasin.ZIndex = 31
listeMagasin.Parent = panneauMagasin
local dispoMagasin = Instance.new("UIGridLayout") -- 2 colonnes de grandes cartes
dispoMagasin.CellSize = UDim2.new(0.5, -10, 0, 132)
dispoMagasin.CellPadding = UDim2.fromOffset(12, 12)
dispoMagasin.SortOrder = Enum.SortOrder.LayoutOrder
dispoMagasin.Parent = listeMagasin

local function dejaAchete(offre): boolean
	local p = profilMenu and profilMenu.Possessions
	if not p then
		return false
	end
	if offre.Kart then
		return p.Karts ~= nil and p.Karts[offre.Kart] == true
	end
	if offre.Categorie == "Traînées" and offre.Trainee then
		return p.Trainees ~= nil and p.Trainees[offre.Trainee] == true
	end
	return offre.Unique == true and p.Produits ~= nil and p.Produits[offre.Id] == true
end

local ouvrirApercu: (any) -> () -- (définie plus bas : la page d'aperçu)
local function acheterOffre(offre)
	if dejaAchete(offre) then
		ajouterAuFil("✔ Tu l'as déjà !", Color3.fromRGB(140, 255, 160))
		return
	end
	if (offre.ProduitId or 0) ~= 0 then
		MarketplaceService:PromptProductPurchase(joueur, offre.ProduitId)
	else
		local resultat = remotes:WaitForChild("Acheter"):InvokeServer({ type = "test", nom = offre.Id })
		if type(resultat) == "table" then
			if resultat.profil then
				profilMenu = resultat.profil
				for _, f in ipairs(majMagasin) do
					f()
				end
			end
			ajouterAuFil(resultat.message or "", if resultat.ok then Color3.fromRGB(140, 255, 160) else Color3.fromRGB(255, 140, 140))
		end
	end
end

local cartesParCategorie: { [string]: { GuiObject } } = {}
for ordre, offre in ipairs(Config.Boutique or {}) do
	local grande = offre.Promo == true
	local b = Instance.new("TextButton")
	b.LayoutOrder = ordre
	b.Size = UDim2.new(1, -8, 0, if grande then 110 else 78)
	b.BackgroundColor3 = if grande then Color3.fromRGB(40, 22, 50) else Color3.fromRGB(26, 26, 32)
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = 32
	b.Parent = listeMagasin
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	local bord = Instance.new("UIStroke")
	bord.Thickness = if grande then 2 else 1
	bord.Color = if grande then Color3.fromRGB(255, 140, 230) else Color3.fromRGB(60, 60, 72)
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = b
	if grande then
		local degradeBord = Instance.new("UIGradient")
		degradeBord.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 90)),
		})
		degradeBord.Parent = bord
		task.spawn(function()
			while b.Parent do
				degradeBord.Rotation = (degradeBord.Rotation + 3) % 360
				task.wait(0.03)
			end
		end)
	end
	-- Aperçu de la traînée : un dégradé de ses couleurs
	local trainee = offre.Trainee and Config.Trainee(offre.Trainee)
	if offre.Categorie == "Traînées" and trainee and trainee.Couleurs then
		local apercu = Instance.new("Frame")
		apercu.Size = UDim2.new(0, 60, 0, 60)
		apercu.Position = UDim2.new(0, 10, 0.5, -30)
		apercu.BackgroundColor3 = Color3.new(1, 1, 1)
		apercu.ZIndex = 33
		apercu.Parent = b
		Instance.new("UICorner", apercu).CornerRadius = UDim.new(0, 6)
		local d = Instance.new("UIGradient")
		d.Color = trainee.Couleurs
		d.Rotation = 45
		d.Parent = apercu
		local ic = texte(apercu, UDim2.new(1, -16, 1, -16), UDim2.new(0, 8, 0, 8), Color3.new(1, 1, 1))
		ic.Text = trainee.Icone or ""
		ic.ZIndex = 34
	end
	local gauche = if offre.Categorie == "Traînées" then 82 else 16
	local n = texte(b, UDim2.new(1, -gauche - 160, 0, if grande then 34 else 26), UDim2.new(0, gauche, 0, if grande then 16 else 12), Color3.new(1, 1, 1))
	n.Text = offre.Nom
	n.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.ZIndex = 33
	local dsc = texte(b, UDim2.new(1, -gauche - 160, 0, if grande then 40 else 30), UDim2.new(0, gauche, 0, if grande then 56 else 42), Color3.fromRGB(200, 200, 210), Enum.Font.GothamMedium)
	dsc.Text = offre.Description
	dsc.TextWrapped = true
	dsc.TextXAlignment = Enum.TextXAlignment.Left
	dsc.TextYAlignment = Enum.TextYAlignment.Top
	dsc.ZIndex = 33
	local prix = Instance.new("TextLabel")
	prix.AnchorPoint = Vector2.new(1, 0.5)
	prix.Size = UDim2.new(0, 130, 0, 46)
	prix.Position = UDim2.new(1, -12, 0.5, 0)
	prix.BackgroundColor3 = Color3.fromRGB(225, 30, 45)
	prix.TextColor3 = Color3.new(1, 1, 1)
	prix.Font = Enum.Font.FredokaOne
	prix.TextScaled = true
	prix.Text = offre.PrixAffiche
	prix.ZIndex = 33
	prix.Parent = b
	Instance.new("UICorner", prix).CornerRadius = UDim.new(0, 6)
	local margePrix = Instance.new("UIPadding")
	margePrix.PaddingTop = UDim.new(0, 10)
	margePrix.PaddingBottom = UDim.new(0, 10)
	margePrix.Parent = prix
	local vraiPrix = offre.PrixAffiche
	if (offre.ProduitId or 0) ~= 0 then
		task.spawn(function()
			local ok, infos = pcall(function()
				return MarketplaceService:GetProductInfo(offre.ProduitId, Enum.InfoType.Product)
			end)
			if ok and infos and infos.PriceInRobux then
				vraiPrix = "R$ " .. tostring(infos.PriceInRobux)
				prix.Text = vraiPrix
			end
		end)
	end
	table.insert(majMagasin, function()
		local achete = dejaAchete(offre)
		prix.Text = if achete then "✔ ACHETÉ" else vraiPrix
		prix.BackgroundColor3 = if achete then Color3.fromRGB(40, 140, 70) else Color3.fromRGB(225, 30, 45)
	end)
	local echelle = Instance.new("UIScale")
	echelle.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(echelle, TweenInfo.new(0.12), { Scale = 1.02 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(echelle, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		ouvrirApercu(offre) -- d'abord l'aperçu, puis le bouton ACHETER
	end)
	local cat = offre.Categorie or "Offres"
	cartesParCategorie[cat] = cartesParCategorie[cat] or {}
	table.insert(cartesParCategorie[cat], b)
end

local boutonsOnglets: { [string]: TextButton } = {}
local function montrerCategorie(cat: string)
	for c, cartes in pairs(cartesParCategorie) do
		for _, carte in ipairs(cartes) do
			carte.Visible = c == cat
		end
	end
	for c, bouton in pairs(boutonsOnglets) do
		bouton.BackgroundColor3 = if c == cat then Color3.fromRGB(225, 30, 45) else Color3.fromRGB(34, 34, 40)
	end
	listeMagasin.CanvasPosition = Vector2.zero
end
local ICONES_CATEGORIES = { Offres = "OFFRES", ["Traînées"] = "TRAÎNÉES", Roue = "ROUE", ["Pièces"] = "PIÈCES" }
for i, cat in ipairs(Config.CategoriesBoutique or {}) do
	local o = Instance.new("TextButton")
	o.LayoutOrder = i
	o.Size = UDim2.new(1 / #Config.CategoriesBoutique, -6, 1, 0)
	o.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
	o.TextColor3 = Color3.new(1, 1, 1)
	o.Font = Enum.Font.FredokaOne
	o.TextScaled = true
	o.Text = ICONES_CATEGORIES[cat] or cat
	o.ZIndex = 32
	o.Parent = ongletsMagasin
	Instance.new("UICorner", o).CornerRadius = UDim.new(0, 5)
	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 9)
	marge.PaddingBottom = UDim.new(0, 9)
	marge.Parent = o
	boutonsOnglets[cat] = o
	o.Activated:Connect(function()
		montrerCategorie(cat)
	end)
end
montrerCategorie("Offres")

local function majProfilMenu(p)
	if type(p) ~= "table" then
		return
	end
	profilMenu = p
	soldeMagasin.Text = ("💰 %d"):format(p.Pieces or 0)
	for _, f in ipairs(majMagasin) do
		f()
	end
end

local function ouvrirMagasin(categorie: string?)
	montrerCategorie(categorie or "Offres")
	apparaitre(panneauMagasin)
end

-- 👀 APERÇU AVANT D'ACHETER : on clique sur une offre → page avec ton kart équipé
-- de l'objet, qui tourne en 3D, et le gros bouton ACHETER.
do
	local KartBuilderApercu = require(ReplicatedStorage:WaitForChild("KartBuilder"))
	local pageApercu = fenetre("Apercu", "APERÇU", 0, 0, Color3.fromRGB(225, 30, 45))
	pageApercu.ZIndex = 35

	-- La scène 3D (à gauche)
	local scene = Instance.new("ViewportFrame")
	scene.Size = UDim2.new(0.58, 0, 1, -100)
	scene.Position = UDim2.new(0, 10, 0, 90)
	scene.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	scene.BackgroundTransparency = 0.2
	scene.Ambient = Color3.fromRGB(150, 150, 160)
	scene.LightColor = Color3.fromRGB(255, 245, 230)
	scene.LightDirection = Vector3.new(-1, -1.5, -0.6)
	scene.ZIndex = 32
	scene.Parent = pageApercu
	Instance.new("UICorner", scene).CornerRadius = UDim.new(0, 8)
	local degradeScene = Instance.new("UIGradient")
	degradeScene.Color = ColorSequence.new(Color3.fromRGB(70, 70, 90), Color3.fromRGB(20, 20, 28))
	degradeScene.Rotation = 90
	degradeScene.Parent = scene
	local cameraScene = Instance.new("Camera")
	cameraScene.FieldOfView = 40
	cameraScene.Parent = scene
	scene.CurrentCamera = cameraScene
	-- Ruban de couleur de la traînée (les traînées 3D ne s'affichent pas dans un aperçu)
	local ruban = Instance.new("Frame")
	ruban.AnchorPoint = Vector2.new(0, 0.5)
	ruban.Size = UDim2.new(0.55, 0, 0, 34)
	ruban.Position = UDim2.new(0, 10, 0.62, 0)
	ruban.BackgroundColor3 = Color3.new(1, 1, 1)
	ruban.Visible = false
	ruban.ZIndex = 31
	ruban.Parent = pageApercu
	Instance.new("UICorner", ruban).CornerRadius = UDim.new(0, 17)
	local degradeRuban = Instance.new("UIGradient")
	degradeRuban.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) })
	degradeRuban.Parent = ruban
	local degradeRubanCouleur = Instance.new("UIGradient")
	degradeRubanCouleur.Parent = ruban
	-- Grosse icône pour ce qui n'est pas un objet sur le kart (pièces, tours, VIP)
	local grosseIcone = Instance.new("TextLabel")
	grosseIcone.AnchorPoint = Vector2.new(0.5, 0.5)
	grosseIcone.Size = UDim2.fromScale(0.5, 0.5)
	grosseIcone.Position = UDim2.fromScale(0.5, 0.5)
	grosseIcone.BackgroundTransparency = 1
	grosseIcone.TextScaled = true
	grosseIcone.Font = Enum.Font.FredokaOne
	grosseIcone.Visible = false
	grosseIcone.ZIndex = 33
	grosseIcone.Parent = scene

	-- Les infos (à droite)
	local nomApercu = texte(pageApercu, UDim2.new(0.38, 0, 0, 50), UDim2.new(0.62, 0, 0, 100), Color3.new(1, 1, 1))
	nomApercu.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	nomApercu.TextXAlignment = Enum.TextXAlignment.Left
	nomApercu.ZIndex = 32
	local descApercu = texte(pageApercu, UDim2.new(0.38, 0, 0, 90), UDim2.new(0.62, 0, 0, 160), Color3.fromRGB(215, 215, 222), Enum.Font.GothamMedium)
	descApercu.TextWrapped = true
	descApercu.TextXAlignment = Enum.TextXAlignment.Left
	descApercu.TextYAlignment = Enum.TextYAlignment.Top
	descApercu.ZIndex = 32
	local boutonAcheter = Instance.new("TextButton")
	boutonAcheter.Size = UDim2.new(0.38, 0, 0, 74)
	boutonAcheter.Position = UDim2.new(0.62, 0, 0, 280)
	boutonAcheter.BackgroundColor3 = Color3.fromRGB(225, 30, 45)
	boutonAcheter.TextColor3 = Color3.new(1, 1, 1)
	boutonAcheter.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	boutonAcheter.TextScaled = true
	boutonAcheter.ZIndex = 33
	boutonAcheter.Parent = pageApercu
	Instance.new("UICorner", boutonAcheter).CornerRadius = UDim.new(0, 8)
	local margeAcheter = Instance.new("UIPadding")
	margeAcheter.PaddingTop = UDim.new(0, 16)
	margeAcheter.PaddingBottom = UDim.new(0, 16)
	margeAcheter.Parent = boutonAcheter
	local reflet = Instance.new("UIGradient")
	reflet.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0),
		NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(1, 0),
	})
	reflet.Rotation = 20
	reflet.Parent = boutonAcheter

	local kartApercu: Model? = nil
	local offreAffichee = nil
	local angle = 0
	local arcEnCiel = false

	local function majBouton()
		if not offreAffichee then
			return
		end
		local achete = dejaAchete(offreAffichee)
		boutonAcheter.Text = if achete then "✔ DÉJÀ À TOI" else ("ACHETER · %s"):format(offreAffichee.PrixAffiche or "R$")
		boutonAcheter.BackgroundColor3 = if achete then Color3.fromRGB(40, 140, 70) else Color3.fromRGB(225, 30, 45)
	end
	table.insert(majMagasin, majBouton)

	ouvrirApercu = function(offre)
		offreAffichee = offre
		if kartApercu then
			kartApercu:Destroy()
			kartApercu = nil
		end
		nomApercu.Text = offre.Nom
		descApercu.Text = offre.Description or ""
		majBouton()
		-- Le kart du joueur, équipé de l'objet
		local perso = table.clone(profilMenu and profilMenu.Perso or Config.PersoParDefaut)
		local surLeKart = false
		if offre.Kart then
			perso.Kart = offre.Kart
			perso.Premium = nil
			surLeKart = true
		end
		local premium = offre.Premium or (offre.Premiums and offre.Premiums[1])
		if premium then
			perso.Premium = premium
			surLeKart = true
		end
		local trainee = offre.Trainee and Config.Trainee(offre.Trainee)
		ruban.Visible = trainee ~= nil and trainee.Couleurs ~= nil
		if trainee and trainee.Couleurs then
			degradeRubanCouleur.Color = trainee.Couleurs
			surLeKart = true
		end
		grosseIcone.Visible = not surLeKart
		if surLeKart then
			kartApercu = KartBuilderApercu.Construire(perso, CFrame.new(), true)
			kartApercu.Parent = scene
			local pp = premium and Config.PeinturePremium(premium)
			arcEnCiel = perso.Kart == "Galaxie" or (pp ~= nil and pp.ArcEnCiel == true)
		else
			grosseIcone.Text = if offre.Tours then "🎡" elseif offre.Id == "PassVIP" then "👑" else "💰"
		end
		apparaitre(pageApercu)
	end

	boutonAcheter.Activated:Connect(function()
		if offreAffichee then
			acheterOffre(offreAffichee)
			majBouton()
		end
	end)

	-- Le kart tourne lentement (et l'arc-en-ciel s'anime)
	RunService.RenderStepped:Connect(function(dt)
		if not pageApercu.Visible then
			return
		end
		angle += dt * 0.6
		reflet.Offset = Vector2.new((angle * 0.5) % 2 - 1, 0)
		local k = kartApercu
		if k then
			k:PivotTo(CFrame.Angles(0, angle, 0))
			cameraScene.CFrame = CFrame.lookAt(Vector3.new(0, 4.5, 13), Vector3.new(0, 0.8, 0))
			if arcEnCiel then
				for i, d in ipairs(k:GetDescendants()) do
					if d:IsA("BasePart") and (d:GetAttribute("Peinture") == "Carrosserie" or d:GetAttribute("ArcEnCiel")) then
						d.Color = Color3.fromHSV((os.clock() * 0.25 + i * 0.03) % 1, 0.85, 1)
					end
				end
			end
		else
			grosseIcone.Rotation = math.sin(angle * 2) * 8
		end
	end)
end

local ouvrirMenu: (boolean) -> () -- (définie plus bas)
do
---------------------------------------------------------------------
-- 🎡 LA ROUE DU JOUR
---------------------------------------------------------------------
local panneauRoue = fenetre("RoueDuJour", "ROUE DU JOUR", 560, 600, Color3.fromRGB(255, 200, 40))
do -- (bloc de la roue : ses variables restent ici)
local TAILLE_ROUE = 430
local N = #Config.Roue
local ANGLE = 360 / N

local cadreRoue = Instance.new("Frame") -- l'anneau doré autour
cadreRoue.AnchorPoint = Vector2.new(0.5, 0.5)
cadreRoue.Size = UDim2.fromOffset(TAILLE_ROUE + 24, TAILLE_ROUE + 24)
cadreRoue.Position = UDim2.new(0.3, 0, 0.55, 0) -- (la roue à gauche, les infos à droite)
cadreRoue.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
cadreRoue.ZIndex = 31
cadreRoue.Parent = panneauRoue
Instance.new("UICorner", cadreRoue).CornerRadius = UDim.new(0.5, 0)
local degradeAnneau = Instance.new("UIGradient")
degradeAnneau.Color = ColorSequence.new(Color3.fromRGB(255, 235, 150), Color3.fromRGB(200, 130, 20))
degradeAnneau.Rotation = 45
degradeAnneau.Parent = cadreRoue
-- Les petites ampoules qui clignotent autour
local ampoules = {}
for i = 1, 24 do
	local a = math.rad(i * 15)
	local amp = Instance.new("Frame")
	amp.AnchorPoint = Vector2.new(0.5, 0.5)
	amp.Size = UDim2.fromOffset(9, 9)
	amp.Position = UDim2.new(0.5, math.sin(a) * (TAILLE_ROUE / 2 + 6), 0.5, -math.cos(a) * (TAILLE_ROUE / 2 + 6))
	amp.BackgroundColor3 = Color3.new(1, 1, 1)
	amp.ZIndex = 33
	amp.Parent = cadreRoue
	Instance.new("UICorner", amp).CornerRadius = UDim.new(0.5, 0)
	ampoules[i] = amp
end

-- La roue elle-même (CanvasGroup : découpée en rond, et elle peut tourner)
local roue = Instance.new("CanvasGroup")
roue.AnchorPoint = Vector2.new(0.5, 0.5)
roue.Size = UDim2.fromOffset(TAILLE_ROUE, TAILLE_ROUE)
roue.Position = UDim2.fromScale(0.5, 0.5)
roue.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
roue.ZIndex = 32
roue.Parent = cadreRoue
Instance.new("UICorner", roue).CornerRadius = UDim.new(0.5, 0)
local largeurPart = 2 * (TAILLE_ROUE / 2) * math.tan(math.rad(ANGLE / 2)) + 6
for i, case in ipairs(Config.Roue) do
	-- Chaque part : un support qui tourne autour du centre de la roue
	local support = Instance.new("Frame")
	support.Size = UDim2.fromScale(1, 1)
	support.BackgroundTransparency = 1
	support.Rotation = (i - 1) * ANGLE
	support.ZIndex = 32 + i
	support.Parent = roue
	local part = Instance.new("Frame")
	part.AnchorPoint = Vector2.new(0.5, 0)
	part.Size = UDim2.new(0, largeurPart, 0.5, 0)
	part.Position = UDim2.fromScale(0.5, 0)
	part.BackgroundColor3 = case.Couleur
	part.BorderSizePixel = 0
	part.ZIndex = 32 + i
	part.Parent = support
	local reflet = Instance.new("UIGradient")
	reflet.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	reflet.Rotation = 90
	reflet.Parent = part
	local nom = Instance.new("TextLabel")
	nom.AnchorPoint = Vector2.new(0.5, 0)
	nom.Size = UDim2.new(0, 116, 0, 26)
	nom.Position = UDim2.new(0.5, 0, 0, 36)
	nom.BackgroundTransparency = 1
	nom.TextColor3 = Color3.new(1, 1, 1)
	nom.Font = Enum.Font.FredokaOne
	nom.TextScaled = true
	nom.Text = case.Nom
	nom.ZIndex = 50
	nom.Parent = support
	local contourNom = Instance.new("UIStroke")
	contourNom.Thickness = 2
	contourNom.Color = Color3.fromRGB(20, 20, 26)
	contourNom.Parent = nom
	-- Séparation dorée entre deux parts
	local supportTrait = Instance.new("Frame")
	supportTrait.Size = UDim2.fromScale(1, 1)
	supportTrait.BackgroundTransparency = 1
	supportTrait.Rotation = (i - 1) * ANGLE + ANGLE / 2
	supportTrait.ZIndex = 45
	supportTrait.Parent = roue
	local trait = Instance.new("Frame")
	trait.AnchorPoint = Vector2.new(0.5, 0)
	trait.Size = UDim2.new(0, 3, 0.5, 0)
	trait.Position = UDim2.fromScale(0.5, 0)
	trait.BackgroundColor3 = Color3.fromRGB(255, 215, 90)
	trait.BorderSizePixel = 0
	trait.ZIndex = 45
	trait.Parent = supportTrait
end
-- Le centre (bouton TOURNER)
local boutonTourner = Instance.new("TextButton")
boutonTourner.AnchorPoint = Vector2.new(0.5, 0.5)
boutonTourner.Size = UDim2.fromOffset(130, 130)
boutonTourner.Position = UDim2.fromScale(0.5, 0.5)
boutonTourner.BackgroundColor3 = Color3.fromRGB(225, 30, 45)
boutonTourner.TextColor3 = Color3.new(1, 1, 1)
boutonTourner.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
boutonTourner.TextScaled = true
boutonTourner.Text = "TOURNER"
boutonTourner.ZIndex = 60
boutonTourner.Parent = cadreRoue
Instance.new("UICorner", boutonTourner).CornerRadius = UDim.new(0.5, 0)
local bordCentre = Instance.new("UIStroke")
bordCentre.Thickness = 5
bordCentre.Color = Color3.fromRGB(255, 215, 90)
bordCentre.Parent = boutonTourner
local margeCentre = Instance.new("UIPadding")
margeCentre.PaddingTop = UDim.new(0, 46)
margeCentre.PaddingBottom = UDim.new(0, 46)
margeCentre.PaddingLeft = UDim.new(0, 10)
margeCentre.PaddingRight = UDim.new(0, 10)
margeCentre.Parent = boutonTourner
local echelleCentre = Instance.new("UIScale")
echelleCentre.Parent = boutonTourner
-- La flèche en haut
local fleche = Instance.new("TextLabel")
fleche.AnchorPoint = Vector2.new(0.5, 0)
fleche.Size = UDim2.fromOffset(50, 50)
fleche.Position = UDim2.new(0.5, 0, 0, -34)
fleche.BackgroundTransparency = 1
fleche.TextColor3 = Color3.fromRGB(255, 255, 255)
fleche.Font = Enum.Font.FredokaOne
fleche.TextScaled = true
fleche.Text = "▼"
fleche.ZIndex = 70
fleche.Parent = cadreRoue
local contourFleche = Instance.new("UIStroke")
contourFleche.Thickness = 3
contourFleche.Color = Color3.fromRGB(225, 30, 45)
contourFleche.Parent = fleche

local infoRoue = texte(panneauRoue, UDim2.new(0.42, 0, 0, 34), UDim2.new(0.58, 0, 0.3, 0), Color3.new(1, 1, 1), Enum.Font.FredokaOne)
infoRoue.ZIndex = 31
local resultatRoue = texte(panneauRoue, UDim2.new(0.42, 0, 0, 60), UDim2.new(0.58, 0, 0.3, 48), Color3.fromRGB(255, 215, 80))
resultatRoue.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
resultatRoue.ZIndex = 31
-- Les chances de chaque cadeau (obligatoire sur Roblox pour les tours achetés)
local totalPoids = 0
for _, case in ipairs(Config.Roue) do
	totalPoids += case.Poids
end
local morceaux = {}
for _, case in ipairs(Config.Roue) do
	table.insert(morceaux, ("%s %s%%"):format(case.Nom, string.format("%.1f", case.Poids / totalPoids * 100):gsub("%.0$", "")))
end
local chances = texte(panneauRoue, UDim2.new(0.42, 0, 0, 80), UDim2.new(0.58, 0, 0.3, 230), Color3.fromRGB(150, 150, 160), Enum.Font.GothamMedium)
chances.Text = "Chances : " .. table.concat(morceaux, " · ")
chances.TextWrapped = true
chances.ZIndex = 31
local boutonAcheterTours = Instance.new("TextButton")
boutonAcheterTours.AnchorPoint = Vector2.new(0, 0)
boutonAcheterTours.Size = UDim2.new(0, 320, 0, 52)
boutonAcheterTours.Position = UDim2.new(0.58, 0, 0.3, 130)
boutonAcheterTours.BackgroundColor3 = Color3.fromRGB(225, 30, 45)
boutonAcheterTours.TextColor3 = Color3.new(1, 1, 1)
boutonAcheterTours.Font = Enum.Font.FredokaOne
boutonAcheterTours.TextScaled = true
boutonAcheterTours.Text = "🛒 Acheter des tours en plus"
boutonAcheterTours.ZIndex = 31
boutonAcheterTours.Parent = panneauRoue
Instance.new("UICorner", boutonAcheterTours).CornerRadius = UDim.new(0, 6)
local margeTours = Instance.new("UIPadding")
margeTours.PaddingTop = UDim.new(0, 12)
margeTours.PaddingBottom = UDim.new(0, 12)
margeTours.Parent = boutonAcheterTours
boutonAcheterTours.Activated:Connect(function()
	panneauRoue.Visible = false
	ouvrirMagasin("Roue")
end)

local function toursDisponibles(): number
	if not profilMenu then
		return 0
	end
	return (profilMenu.ToursGratuitsRestants or 0) + (profilMenu.ToursRoue or 0)
end

local enRotation = false
local function majRoue()
	local gratuits = profilMenu and profilMenu.ToursGratuitsRestants or 0
	local achetes = profilMenu and profilMenu.ToursRoue or 0
	if gratuits > 0 then
		infoRoue.Text = ("🎁 %d tour%s GRATUIT aujourd'hui%s"):format(gratuits, if gratuits > 1 then "s" else "", if achetes > 0 then (" + %d acheté(s)"):format(achetes) else "")
	elseif achetes > 0 then
		infoRoue.Text = ("🎡 %d tour(s) en réserve"):format(achetes)
	else
		local reste = profilMenu and profilMenu.ProchainTourGratuit or 0
		infoRoue.Text = ("⏳ Prochain tour gratuit dans %dh %02dmin"):format(reste // 3600, (reste % 3600) // 60)
	end
	boutonTourner.BackgroundColor3 = if toursDisponibles() > 0 and not enRotation then Color3.fromRGB(225, 30, 45) else Color3.fromRGB(70, 70, 78)
end
table.insert(majMagasin, majRoue)

local RoueDuJour = remotes:WaitForChild("RoueDuJour")
boutonTourner.Activated:Connect(function()
	if enRotation then
		return
	end
	if toursDisponibles() <= 0 then
		resultatRoue.Text = "Plus de tour : reviens demain ou achète des tours !"
		return
	end
	enRotation = true
	resultatRoue.Text = ""
	majRoue()
	local r = RoueDuJour:InvokeServer("lancer")
	if type(r) ~= "table" or not r.ok or not r.indice then
		enRotation = false
		resultatRoue.Text = (type(r) == "table" and r.message) or "Oups, réessaie !"
		majRoue()
		return
	end
	-- La roue tourne plusieurs fois puis s'arrête sur la bonne case, sous la flèche
	local depart = roue.Rotation % 360
	local arrivee = -((r.indice - 1) * ANGLE) + math.random(-12, 12) * ANGLE / 40
	local delta = (arrivee - depart) % 360
	roue.Rotation = depart
	local tween = TweenService:Create(roue, TweenInfo.new(5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = depart + 360 * 6 + delta })
	tween:Play()
	tween.Completed:Wait()
	enRotation = false
	profilMenu = r.profil or profilMenu
	resultatRoue.Text = "🎉 " .. (r.message or "")
	local e = Instance.new("UIScale")
	e.Scale = 0.3
	e.Parent = resultatRoue
	TweenService:Create(e, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(0.6, function()
		e:Destroy()
	end)
	majProfilMenu(profilMenu)
end)

-- Animations : ampoules qui clignotent, bouton qui « respire »
task.spawn(function()
	local t = 0
	while true do
		t += 1
		if panneauRoue.Visible then
			for i, amp in ipairs(ampoules) do
				local allumee = (i + t) % 2 == 0
				amp.BackgroundColor3 = if allumee then Color3.new(1, 1, 1) else Color3.fromRGB(255, 120, 60)
			end
			if not enRotation and toursDisponibles() > 0 then
				echelleCentre.Scale = 1
				TweenService:Create(echelleCentre, TweenInfo.new(0.25), { Scale = 1.08 }):Play()
			end
		end
		task.wait(if enRotation then 0.1 else 0.35)
	end
end)

local function ouvrirRoue()
	panneauMagasin.Visible = false
	apparaitre(panneauRoue)
	resultatRoue.Text = ""
	task.spawn(function()
		local r = RoueDuJour:InvokeServer("etat")
		if type(r) == "table" and r.profil then
			majProfilMenu(r.profil)
		end
	end)
	majRoue()
end

remotes:WaitForChild("ProfilMisAJour").OnClientEvent:Connect(majProfilMenu)
task.spawn(function()
	majProfilMenu(remotes:WaitForChild("ObtenirProfil"):InvokeServer())
end)

-- Pastille rouge « ! » sur la carte ROUE quand un tour gratuit attend
local pastilleRoue = Instance.new("TextLabel")
pastilleRoue.AnchorPoint = Vector2.new(0.5, 0.5)
pastilleRoue.Size = UDim2.fromOffset(22, 22)
pastilleRoue.Position = UDim2.new(1, -14, 0, 14) -- (en haut à droite de la tuile ROUE)
pastilleRoue.BackgroundColor3 = Color3.fromRGB(235, 40, 50)
pastilleRoue.TextColor3 = Color3.new(1, 1, 1)
pastilleRoue.Font = Enum.Font.FredokaOne
pastilleRoue.TextScaled = true
pastilleRoue.Text = "!"
pastilleRoue.ZIndex = 26
pastilleRoue.Visible = false
pastilleRoue.Parent = carteRoue
Instance.new("UICorner", pastilleRoue).CornerRadius = UDim.new(0.5, 0)
table.insert(majMagasin, function()
	pastilleRoue.Visible = profilMenu ~= nil and (profilMenu.ToursGratuitsRestants or 0) > 0
	piecesMenu.Text = ("%s💰 %d pièces  ·  Niveau %d"):format(if profilMenu and profilMenu.VIP then "👑 VIP  ·  " else "", profilMenu and profilMenu.Pieces or 0, profilMenu and profilMenu.Niveau or 1)
end)
carteRoue.Activated:Connect(ouvrirRoue)
carteMagasin.Activated:Connect(function()
	panneauRoue.Visible = false
	ouvrirMagasin("Offres")
end)
end -- (fin du bloc de la roue)

cartePromo.Activated:Connect(function()
	ouvrirMagasin("Offres")
end)

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
badgeDirect.LayoutOrder = 2 -- (dans la colonne de droite, sous les pièces)
badgeDirect.Size = UDim2.new(1, 0, 0, 36)
badgeDirect.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
badgeDirect.BackgroundTransparency = 0.2
badgeDirect.TextColor3 = Color3.new(1, 1, 1)
badgeDirect.Font = Enum.Font.FredokaOne
badgeDirect.TextScaled = true
badgeDirect.Visible = false
badgeDirect.ZIndex = 22
badgeDirect.Parent = colonneDroite
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
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable -- (au cas où un autre script l'a remise)
	end
	camera.CFrame = cfCamera :: CFrame
end)

local function majMenu()
	local enManche = joueur:GetAttribute("Role") ~= nil
	local prete = joueur:GetAttribute("Pret") == true
	local preteBattle = false
	boutonMenu.Visible = not enManche and joueur:GetAttribute("IntroFinie") == true and not (joueur:GetAttribute("EnSalle") == true) and not joueur:GetAttribute("MenuGarage") and not fondMenu.Visible
	if enManche then
		fondMenu.Visible = false
	end
	titreEnLigne.Text = if prete then "QUITTER LA FILE" else "EN LIGNE"
	descEnLigne.Text = if prete
		then "Dans la file… (clique pour quitter)"
		else "Police contre Fugitifs"
	boutonMenu.Text = if prete or preteBattle then "☰ MENU · ✅ EN FILE" else "☰ MENU"
	boutonMenu.Size = UDim2.new(0, if prete or preteBattle then 260 else 170, 0, 46)
end
for _, nom in ipairs({ "Pret", "Role", "IntroFinie", "EnSalle", "MenuGarage" }) do
	joueur:GetAttributeChangedSignal(nom):Connect(majMenu)
end
majMenu()

ouvrirMenu = function(ouvert: boolean)
	local dejaOuvert = fondMenu.Visible
	fondMenu.Visible = ouvert
	barre.Visible = not ouvert -- (la barre d'état du haut passerait par-dessus le menu)
	for _, page in ipairs(pagesListe) do
		page.Visible = false -- (magasin, roue, aperçu…)
	end
	local pageCadeaux = fondMenu:FindFirstChild("PageCadeaux")
	if pageCadeaux and pageCadeaux:IsA("GuiObject") then
		pageCadeaux.Visible = false
	end
	panneauMagasin.Visible = false
	panneauRoue.Visible = false
	majMenu()
	local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	local auVolant = h and h.SeatPart ~= nil
	if ouvert and not dejaOuvert and auVolant and joueur:GetAttribute("Role") == nil then
		-- Après un mode de jeu : retour à l'accueil, on descend du kart pour voir les autres jouer
		Partie:FireServer({ type = "garage" })
		auVolant = false
	end
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
	if (EN_LOBBY or (DANS_UNE_PLACE_DE_JEU and TYPE ~= "Entrainement")) and Voyage then
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
	if (EN_LOBBY or DANS_UNE_PLACE_DE_JEU) and Voyage then
		Voyage:FireServer({ mode = "PoliceFugitifs" }) -- file d'attente du matchmaking (au lobby)
	else
		Partie:FireServer({ type = "pret", valeur = not prete })
	end
	ajouterAuFil(if prete then "Tu as quitté la file d'attente." else "🌐 Tu es dans la file pour Police contre Fugitifs !", Color3.fromRGB(90, 150, 255))
end)
carteBattle.Activated:Connect(function()
	ouvrirMenu(false)
	if (EN_LOBBY or (DANS_UNE_PLACE_DE_JEU and TYPE ~= "DriftBattle")) and Voyage then
		Voyage:FireServer({ mode = "DriftBattle" }) -- direction la place Drift Battle
	else
		Partie:FireServer({ type = "battle" }) -- le défi démarre tout de suite
	end
end)
carteGarage.Activated:Connect(function()
	-- On va DIRECTEMENT à la personnalisation : ton kart en face, les options à droite
	ouvrirMenu(false)
	joueur:SetAttribute("OuvrirGarage", true) -- (le script GarageUI s'en occupe)
end)
-- Quand on ferme le garage : retour au menu
joueur:GetAttributeChangedSignal("RetourMenu"):Connect(function()
	if joueur:GetAttribute("RetourMenu") then
		joueur:SetAttribute("RetourMenu", false)
		task.wait(0.6)
		ouvrirMenu(true)
	end
end)
-- « ROULER » depuis le garage du lobby : direction l'entraînement
joueur:GetAttributeChangedSignal("ModeDemande"):Connect(function()
	local mode = joueur:GetAttribute("ModeDemande")
	if mode then
		joueur:SetAttribute("ModeDemande", nil)
		if EN_LOBBY and Voyage then
			Voyage:FireServer({ mode = mode })
		end
	end
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
	if EN_LOBBY or TYPE == "ToutEnUn" then -- (dans les modes de jeu : bouton ☰ MENU)
		-- Le menu s'affiche TOUT DE SUITE (on ne voit jamais le lobby ni le garage avant)
		ouvrirMenu(true)
		local donnees = TeleportService:GetLocalPlayerTeleportData()
		if EN_LOBBY and type(donnees) == "table" and donnees.fileAuto and Voyage and not joueur:GetAttribute("Pret") then
			Voyage:FireServer({ mode = "PoliceFugitifs" }) -- (demandé depuis un autre mode)
			ajouterAuFil("🌐 Tu es dans la file pour Police contre Fugitifs !", Color3.fromRGB(90, 150, 255))
		end
	end
end)

end -- (bloc : garde le nombre de variables du script sous la limite de Roblox)
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
boutonOK.Font = Enum.Font.FredokaOne
boutonOK.TextScaled = true
boutonOK.Text = "OK"
boutonOK.ZIndex = 42
boutonOK.Parent = panneauMondial
Instance.new("UICorner", boutonOK).CornerRadius = UDim.new(0, 10)
boutonOK.Activated:Connect(function()
	panneauMondial.Visible = false
end)

local function ligneMondial(ordre: number, txt: string, couleur: Color3)
	local l = texte(lignesMondial, UDim2.new(1, 0, 0, 26), UDim2.new(), couleur, Enum.Font.FredokaOne)
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
do
---------------------------------------------------------------------
-- ❤️ LES VIES (Police contre Fugitifs) + le choix RÉAPPARAÎTRE / ⚡ VENGEANCE
---------------------------------------------------------------------
local POLICE_GRAS = Font.fromEnum(Enum.Font.FredokaOne)
local MarketplaceVies = game:GetService("MarketplaceService")

-- Les cœurs en haut de l'écran pendant la manche
local coeurs = Instance.new("TextLabel")
coeurs.AnchorPoint = Vector2.new(0.5, 0)
coeurs.Size = UDim2.new(0, 220, 0, 40)
coeurs.Position = UDim2.new(0.5, 0, 0, 54) -- (sous la barre d'état du haut)
coeurs.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
coeurs.BackgroundTransparency = 0.3
coeurs.TextColor3 = Color3.new(1, 1, 1)
coeurs.Font = Enum.Font.FredokaOne
coeurs.TextScaled = true
coeurs.Visible = false
coeurs.ZIndex = 6
coeurs.Parent = gui
Instance.new("UICorner", coeurs).CornerRadius = UDim.new(0, 8)
local margeCoeurs = Instance.new("UIPadding")
margeCoeurs.PaddingTop = UDim.new(0, 6)
margeCoeurs.PaddingBottom = UDim.new(0, 6)
margeCoeurs.Parent = coeurs
local echelleCoeurs = Instance.new("UIScale")
echelleCoeurs.Parent = coeurs
local viesAffichees = -1
local function majCoeurs()
	local vies = joueur:GetAttribute("Vies")
	coeurs.Visible = type(vies) == "number" and joueur:GetAttribute("Role") ~= nil
	if type(vies) ~= "number" then
		viesAffichees = -1
		return
	end
	local total = (Config.Partie and Config.Partie.Vies) or 3
	coeurs.Text = string.rep("❤️", vies) .. string.rep("🖤", math.max(total - vies, 0))
	if viesAffichees ~= -1 and vies < viesAffichees then
		echelleCoeurs.Scale = 1.5 -- une vie en moins : les cœurs « tremblent »
		TweenService:Create(echelleCoeurs, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
	end
	viesAffichees = vies
end
joueur:GetAttributeChangedSignal("Vies"):Connect(majCoeurs)
joueur:GetAttributeChangedSignal("Role"):Connect(majCoeurs)

-- L'écran du choix
local ecranChoix = Instance.new("Frame")
ecranChoix.Size = UDim2.fromScale(1, 1)
ecranChoix.BackgroundColor3 = Color3.fromRGB(40, 0, 5)
ecranChoix.BackgroundTransparency = 0.35
ecranChoix.Visible = false
ecranChoix.ZIndex = 45
ecranChoix.Parent = gui
local titreChoix = texte(ecranChoix, UDim2.new(0.8, 0, 0, 64), UDim2.new(0.1, 0, 0.18, 0), Color3.new(1, 1, 1))
titreChoix.FontFace = POLICE_GRAS
titreChoix.ZIndex = 46
local sousChoix = texte(ecranChoix, UDim2.new(0.8, 0, 0, 30), UDim2.new(0.1, 0, 0.18, 72), Color3.fromRGB(255, 200, 200), Enum.Font.FredokaOne)
sousChoix.ZIndex = 46
local coeursChoix = texte(ecranChoix, UDim2.new(0.4, 0, 0, 44), UDim2.new(0.3, 0, 0.18, 112), Color3.new(1, 1, 1))
coeursChoix.ZIndex = 46

local function grosBouton(icone: string, titre: string, sous: string, couleur: Color3, x: number): (TextButton, TextLabel)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Size = UDim2.new(0, 300, 0, 170)
	b.Position = UDim2.new(0.5, x, 0.45, 0)
	b.BackgroundColor3 = couleur
	b.Text = ""
	b.AutoButtonColor = false
	b.ZIndex = 46
	b.Parent = ecranChoix
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local bord = Instance.new("UIStroke")
	bord.Thickness = 3
	bord.Color = Color3.new(1, 1, 1)
	bord.Transparency = 0.4
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = b
	local i = texte(b, UDim2.new(1, 0, 0, 62), UDim2.new(0, 0, 0, 12), Color3.new(1, 1, 1))
	i.Text = icone
	i.ZIndex = 47
	local t = texte(b, UDim2.new(1, -20, 0, 36), UDim2.new(0, 10, 0, 80), Color3.new(1, 1, 1))
	t.Text = titre
	t.FontFace = POLICE_GRAS
	t.ZIndex = 47
	local s = texte(b, UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 122), Color3.fromRGB(240, 240, 245), Enum.Font.FredokaOne)
	s.Text = sous
	s.TextWrapped = true
	s.ZIndex = 47
	local e = Instance.new("UIScale")
	e.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(e, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(e, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	return b, s
end
local boutonReapparaitre, sousReapparaitre = grosBouton("🔄", "RÉAPPARAÎTRE", "Gratuit", Color3.fromRGB(40, 150, 80), -170)
local boutonVengeance, sousVengeance = grosBouton("⚡", "VENGEANCE", "", Color3.fromRGB(200, 20, 40), 170)
-- L'éclair de la vengeance « pulse » pour attirer l'œil
local degradeVengeance = Instance.new("UIGradient")
degradeVengeance.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 120)),
})
degradeVengeance.Rotation = 30
degradeVengeance.Parent = boutonVengeance

local choixEnCours = 0
local produitVengeance = 0
local function fermerChoix()
	choixEnCours += 1
	ecranChoix.Visible = false
end
local function montrerChoix(info)
	choixEnCours += 1
	local numero = choixEnCours
	produitVengeance = info.produit or 0
	local total = (Config.Partie and Config.Partie.Vies) or 3
	titreChoix.Text = "💥 " .. string.upper(info.par or "?") .. " T'A EU !"
	coeursChoix.Text = string.rep("❤️", info.vies or 0) .. string.rep("🖤", math.max(total - (info.vies or 0), 0))
	sousVengeance.Text = ("%s · %s perd une vie !"):format(info.prix or "R$", info.par or "?")
	ecranChoix.Visible = true
	ecranChoix.BackgroundTransparency = 1
	TweenService:Create(ecranChoix, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
	task.spawn(function()
		local reste = info.delai or 12
		while reste > 0 and numero == choixEnCours do
			sousChoix.Text = ("Il te reste %d vie%s · choisis (%d s)"):format(info.vies or 0, if (info.vies or 0) > 1 then "s" else "", reste)
			sousReapparaitre.Text = ("Gratuit · retour en piste")
			degradeVengeance.Offset = Vector2.new(if reste % 2 == 0 then -0.3 else 0.3, 0)
			task.wait(1)
			reste -= 1
		end
		if numero == choixEnCours then
			fermerChoix() -- (le serveur nous fait revenir tout seul)
		end
	end)
end
boutonReapparaitre.Activated:Connect(function()
	fermerChoix()
	Partie:FireServer({ type = "reapparaitre" })
end)
boutonVengeance.Activated:Connect(function()
	if produitVengeance ~= 0 then
		MarketplaceVies:PromptProductPurchase(joueur, produitVengeance) -- le serveur applique la vengeance après le paiement
	else
		fermerChoix()
		Partie:FireServer({ type = "vengeance" }) -- (test gratuit dans Studio)
	end
end)
-- Si l'achat de la vengeance est confirmé, l'écran se ferme quand on revient en piste

---------------------------------------------------------------------
-- 📡 RADAR de la police + 👀 MODE SPECTATEUR quand on est éliminé
---------------------------------------------------------------------
local function modelesManche(): { Model }
	local liste = {}
	for _, nomDossier in ipairs({ "KartsJoueurs", "BotsManche" }) do
		local dossier = workspace:FindFirstChild(nomDossier)
		if dossier then
			for _, m in ipairs(dossier:GetChildren()) do
				if m:IsA("Model") and m:GetAttribute("Role") and m:GetAttribute("Proprietaire") ~= joueur.UserId then
					table.insert(liste, m)
				end
			end
		end
	end
	return liste
end

local function radar(duree: number)
	local monRole = joueur:GetAttribute("Role")
	if monRole == "Fugitif" then
		ajouterAuFil("📡 Le radar de la police vous a repérés ! Bouge !", ORANGE)
		return
	end
	if monRole ~= "Police" then
		return
	end
	ajouterAuFil("📡 RADAR : les fugitifs sont visibles à travers les murs !", BLEU)
	for _, m in ipairs(modelesManche()) do
		if m:GetAttribute("Role") == "Fugitif" then
			local h = Instance.new("Highlight")
			h.FillColor = Color3.fromRGB(255, 140, 30)
			h.FillTransparency = 0.35
			h.OutlineColor = Color3.new(1, 1, 1)
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = m
			game:GetService("Debris"):AddItem(h, duree)
		end
	end
end

-- Le mode spectateur : on suit les joueurs encore en jeu, ◀ ▶ pour changer
local spectateur = false
local cibleSpectateur = 1
local cfSpectateur: CFrame? = nil
local barreSpectateur = Instance.new("Frame")
barreSpectateur.AnchorPoint = Vector2.new(0.5, 1)
barreSpectateur.Size = UDim2.new(0, 460, 0, 56)
barreSpectateur.Position = UDim2.new(0.5, 0, 1, -24)
barreSpectateur.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
barreSpectateur.BackgroundTransparency = 0.2
barreSpectateur.Visible = false
barreSpectateur.ZIndex = 8
barreSpectateur.Parent = gui
Instance.new("UICorner", barreSpectateur).CornerRadius = UDim.new(0, 10)
local nomSpectateur = texte(barreSpectateur, UDim2.new(1, -130, 0, 30), UDim2.new(0, 65, 0, 13), Color3.new(1, 1, 1))
nomSpectateur.ZIndex = 9
local function flecheSpectateur(t: string, x: number, sens: number)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(48, 44)
	b.Position = UDim2.new(x, if x == 0 then 6 else -54, 0, 6)
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 22
	b.Text = t
	b.ZIndex = 9
	b.Parent = barreSpectateur
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	b.Activated:Connect(function()
		cibleSpectateur += sens
	end)
end
flecheSpectateur("◀", 0, -1)
flecheSpectateur("▶", 1, 1)

local function arreterSpectateur()
	if spectateur then
		spectateur = false
		barreSpectateur.Visible = false
		camera.CameraType = Enum.CameraType.Custom
	end
end
RunService.RenderStepped:Connect(function(dt)
	if not spectateur then
		return
	end
	local liste = modelesManche()
	if #liste == 0 then
		nomSpectateur.Text = "👀 SPECTATEUR · en attente…"
		return
	end
	cibleSpectateur = (cibleSpectateur - 1) % #liste + 1
	local m = liste[cibleSpectateur]
	local support = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not support then
		return
	end
	local proprio = m:GetAttribute("Proprietaire")
	local pilote = proprio and Players:GetPlayerByUserId(proprio)
	nomSpectateur.Text = ("👀 %s %s"):format(if m:GetAttribute("Role") == "Police" then "🚓" else "🏃", if pilote then pilote.DisplayName else m.Name)
	local avant = Vector3.new(support.CFrame.LookVector.X, 0, support.CFrame.LookVector.Z)
	avant = if avant.Magnitude > 0.1 then avant.Unit else Vector3.new(0, 0, -1)
	local voulu = CFrame.lookAt(support.Position - avant * 16 + Vector3.new(0, 7, 0), support.Position + avant * 6)
	cfSpectateur = if cfSpectateur then cfSpectateur:Lerp(voulu, math.clamp(dt * 4, 0, 1)) else voulu
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cfSpectateur :: CFrame
end)
local function demarrerSpectateur()
	spectateur = true
	cfSpectateur = nil
	barreSpectateur.Visible = true
end

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
	elseif info.type == "perdu" then
		montrerChoix(info)
	elseif info.type == "reapparu" then
		fermerChoix()
	elseif info.type == "vengeance" then
		ajouterAuFil(("⚡ VENGEANCE ! %s se venge de %s !"):format(info.par or "?", info.cible or "?"), Color3.fromRGB(255, 90, 90))
	elseif info.type == "radar" then
		radar(info.duree or 3)
	elseif info.type == "arrete" then
		fermerChoix()
		task.delay(4.2, demarrerSpectateur) -- (après la carte « PLUS DE VIES »)
		montrerCarte("💀 ÉLIMINÉ PAR " .. string.upper(info.par or "LA POLICE"), "PLUS DE VIES !",
			"Tu regardes la fin de la manche depuis le garage. Courage à ton équipe !", Color3.fromRGB(255, 70, 70), 4)
	elseif info.type == "fin" then
		arreterSpectateur()
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

end -- (bloc : garde le nombre de variables du script sous la limite de Roblox)