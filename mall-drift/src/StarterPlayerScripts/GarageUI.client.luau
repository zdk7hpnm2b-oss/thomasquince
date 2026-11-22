--[[
	GarageUI  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : GarageUI

	Le menu du GARAGE VIP :
	  • ton kart tourne sur le plateau (on le voit sous tous les angles)
	  • choisir le modèle de kart, la couleur de carrosserie, la finition
	    (brillant, mat, métallisé, nacré, chrome), les jantes, le siège,
	    les bandes de course, l'autocollant et le numéro
	  • ce qui n'est pas encore débloqué affiche un cadenas 🔒 + le niveau requis
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local KartBuilder = require(ReplicatedStorage:WaitForChild("KartBuilder"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local controles = require(joueur:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local profil = nil -- infos envoyées par le serveur (niveau, XP, kart enregistré)
local persoEdite = table.clone(Config.PersoParDefaut) -- ce que le joueur est en train de modifier
local menuOuvert = false

local function niveau(): number
	return profil and profil.Niveau or 1
end

---------------------------------------------------------------------
-- LE KART SUR LE PLATEAU TOURNANT (visible seulement par toi)
---------------------------------------------------------------------
local apercu: Model? = nil
local typeApercu: string? = nil
local angleApercu = 0

local function trouverPlateau(): BasePart?
	local carte = workspace:FindFirstChild("GoldenMall")
	local garage = carte and carte:FindFirstChild("GarageVIP")
	return garage and garage:FindFirstChild("PlateauTournant") :: BasePart?
end

local function majApercu(perso)
	local plateau = trouverPlateau()
	if not plateau then
		return
	end
	if apercu and typeApercu ~= perso.Kart then
		apercu:Destroy()
		apercu = nil
	end
	if not apercu then
		apercu = KartBuilder.Construire(perso, CFrame.new(plateau.Position + Vector3.new(0, 1.1, 0)), true)
		apercu.Name = "ApercuGarage"
		apercu.Parent = workspace
		typeApercu = perso.Kart
	else
		KartBuilder.Peindre(apercu, perso)
	end
end

RunService.RenderStepped:Connect(function(dt: number)
	local plateau = trouverPlateau()
	if not plateau then
		return
	end
	if not apercu and profil then
		majApercu(if menuOuvert then persoEdite else profil.Perso)
	end
	if apercu then
		angleApercu += dt * (if menuOuvert then 0.5 else 0.3)
		apercu:PivotTo(CFrame.new(plateau.Position + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, angleApercu, 0))
	end
	if menuOuvert then
		-- Caméra de showroom : le kart apparaît à droite du menu
		local cible = plateau.Position + Vector3.new(0, 1.5, -4)
		camera.CFrame = CFrame.lookAt(plateau.Position + Vector3.new(-17, 7, 4), cible)
	end
end)

---------------------------------------------------------------------
-- INTERFACE
---------------------------------------------------------------------
local OR = Color3.fromRGB(255, 205, 80)
local FOND = Color3.fromRGB(14, 14, 20)

local gui = Instance.new("ScreenGui")
gui.Name = "GarageVIP"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Enabled = false
gui.Parent = joueur:WaitForChild("PlayerGui")

local function coins(objet: GuiObject, rayon: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, rayon or 8)
	c.Parent = objet
end

local function contour(objet: GuiObject, couleur: Color3, epaisseur: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = couleur
	s.Thickness = epaisseur
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = objet
	return s
end

local function bouton(parent: Instance, texte: string, couleur: Color3, taille: UDim2, position: UDim2?): TextButton
	local b = Instance.new("TextButton")
	b.Size = taille
	if position then
		b.Position = position
	end
	b.BackgroundColor3 = couleur
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.Text = texte
	b.AutoButtonColor = true
	coins(b)
	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 6)
	marge.PaddingBottom = UDim.new(0, 6)
	marge.PaddingLeft = UDim.new(0, 6)
	marge.PaddingRight = UDim.new(0, 6)
	marge.Parent = b
	b.Parent = parent
	return b
end

local panneau = Instance.new("Frame")
panneau.Name = "Panneau"
panneau.Size = UDim2.new(0, 400, 1, -40)
panneau.Position = UDim2.new(0, 20, 0, 20)
panneau.BackgroundColor3 = FOND
panneau.BackgroundTransparency = 0.08
panneau.Parent = gui
coins(panneau, 14)
contour(panneau, OR, 2)
local tailleMax = Instance.new("UISizeConstraint")
tailleMax.MaxSize = Vector2.new(400, 900)
tailleMax.Parent = panneau

local titre = Instance.new("TextLabel")
titre.Size = UDim2.new(1, -70, 0, 40)
titre.Position = UDim2.new(0, 16, 0, 12)
titre.BackgroundTransparency = 1
titre.Font = Enum.Font.GothamBlack
titre.TextScaled = true
titre.TextXAlignment = Enum.TextXAlignment.Left
titre.TextColor3 = OR
titre.Text = "★ GARAGE VIP"
titre.Parent = panneau

local sousTitre = Instance.new("TextLabel")
sousTitre.Size = UDim2.new(1, -32, 0, 18)
sousTitre.Position = UDim2.new(0, 16, 0, 54)
sousTitre.BackgroundTransparency = 1
sousTitre.Font = Enum.Font.Gotham
sousTitre.TextScaled = true
sousTitre.TextXAlignment = Enum.TextXAlignment.Left
sousTitre.TextColor3 = Color3.fromRGB(200, 200, 210)
sousTitre.Parent = panneau

local boutonFermer = bouton(panneau, "✕", Color3.fromRGB(60, 60, 70), UDim2.new(0, 40, 0, 40), UDim2.new(1, -52, 0, 12))

local liste = Instance.new("ScrollingFrame")
liste.Size = UDim2.new(1, -24, 1, -200)
liste.Position = UDim2.new(0, 12, 0, 84)
liste.BackgroundTransparency = 1
liste.BorderSizePixel = 0
liste.ScrollBarThickness = 6
liste.ScrollBarImageColor3 = OR
liste.CanvasSize = UDim2.new()
liste.AutomaticCanvasSize = Enum.AutomaticSize.Y
liste.Parent = panneau
local disposition = Instance.new("UIListLayout")
disposition.Padding = UDim.new(0, 8)
disposition.SortOrder = Enum.SortOrder.LayoutOrder
disposition.Parent = liste

local statut = Instance.new("TextLabel")
statut.Size = UDim2.new(1, -24, 0, 20)
statut.Position = UDim2.new(0, 12, 1, -108)
statut.BackgroundTransparency = 1
statut.Font = Enum.Font.GothamBold
statut.TextScaled = true
statut.TextColor3 = Color3.fromRGB(255, 160, 160)
statut.Text = ""
statut.Parent = panneau

local boutonEnregistrer = bouton(panneau, "ENREGISTRER", Color3.fromRGB(40, 150, 80), UDim2.new(0.5, -18, 0, 50), UDim2.new(0, 12, 1, -80))
local boutonSortir = bouton(panneau, "SORTIR MON KART 🏁", Color3.fromRGB(200, 140, 20), UDim2.new(0.5, -18, 0, 50), UDim2.new(0.5, 6, 1, -80))

local function afficherStatut(texte: string, couleur: Color3?)
	statut.Text = texte
	statut.TextColor3 = couleur or Color3.fromRGB(255, 160, 160)
	statut.TextTransparency = 0
	task.delay(2.5, function()
		if statut.Text == texte then
			TweenService:Create(statut, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end

---------------------------------------------------------------------
-- Contenu du menu (les boutons se mettent à jour à chaque changement)
---------------------------------------------------------------------
local miseAJour: { () -> () } = {}
local ordre = 0

local function suivant(): number
	ordre += 1
	return ordre
end

local function rafraichir()
	for _, f in ipairs(miseAJour) do
		f()
	end
	sousTitre.Text = ("Niveau %d · drifte pour débloquer plus de styles !"):format(niveau())
	if menuOuvert then
		majApercu(persoEdite)
	end
end

local function verrouille(niveauRequis: number): boolean
	if niveauRequis > niveau() then
		afficherStatut(("🔒 Débloqué au niveau %d (continue à drifter !)"):format(niveauRequis))
		return true
	end
	return false
end

local function section(nom: string): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = suivant()
	l.Size = UDim2.new(1, -10, 0, 24)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = OR
	l.Text = nom
	l.Parent = liste
	return l
end

local function grille(taille: Vector2): Frame
	local f = Instance.new("Frame")
	f.LayoutOrder = suivant()
	f.Size = UDim2.new(1, -10, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 1
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(taille.X, taille.Y)
	g.CellPadding = UDim2.fromOffset(6, 6)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	f.Parent = liste
	return f
end

-- 1) LE MODÈLE DE KART
section("🏎️  MODÈLE")
local kartsTries = {}
for id, k in pairs(Config.Karts) do
	table.insert(kartsTries, { id = id, k = k })
end
table.sort(kartsTries, function(a, b)
	return a.k.Ordre < b.k.Ordre
end)
for _, e in ipairs(kartsTries) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = suivant()
	b.Size = UDim2.new(1, -10, 0, 58)
	b.BackgroundColor3 = Color3.fromRGB(32, 32, 42)
	b.Text = ""
	b.AutoButtonColor = true
	coins(b)
	local trait = contour(b, OR, 0)
	local nom = Instance.new("TextLabel")
	nom.Size = UDim2.new(1, -20, 0, 24)
	nom.Position = UDim2.new(0, 10, 0, 6)
	nom.BackgroundTransparency = 1
	nom.Font = Enum.Font.GothamBlack
	nom.TextScaled = true
	nom.TextXAlignment = Enum.TextXAlignment.Left
	nom.TextColor3 = Color3.new(1, 1, 1)
	nom.Parent = b
	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1, -20, 0, 18)
	desc.Position = UDim2.new(0, 10, 0, 33)
	desc.BackgroundTransparency = 1
	desc.Font = Enum.Font.Gotham
	desc.TextScaled = true
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextColor3 = Color3.fromRGB(190, 190, 200)
	desc.Parent = b
	b.Parent = liste

	table.insert(miseAJour, function()
		local bloque = e.k.Niveau > niveau()
		nom.Text = (bloque and "🔒 " or "") .. e.k.Nom .. ("   ·   %d km/h"):format(e.k.VitesseMax)
		desc.Text = if bloque then ("Débloqué au niveau %d"):format(e.k.Niveau) else e.k.Description
		b.BackgroundTransparency = bloque and 0.5 or 0
		trait.Thickness = persoEdite.Kart == e.id and 3 or 0
	end)
	b.Activated:Connect(function()
		if not verrouille(e.k.Niveau) then
			persoEdite.Kart = e.id
			rafraichir()
		end
	end)
end

-- 2) LES COULEURS (carrosserie, jantes, siège, bandes)
local function choixCouleur(titreSection: string, champ: string)
	local entete = section(titreSection)
	local g = grille(Vector2.new(40, 40))
	for i, c in ipairs(Config.Couleurs) do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.BackgroundColor3 = c.Couleur
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = ""
		coins(b, 20)
		local trait = contour(b, Color3.new(1, 1, 1), 0)
		b.Parent = g
		table.insert(miseAJour, function()
			local bloque = c.Niveau > niveau()
			b.Text = bloque and "🔒" or ""
			b.BackgroundTransparency = bloque and 0.55 or 0
			trait.Thickness = persoEdite[champ] == c.Nom and 3 or 0
		end)
		b.Activated:Connect(function()
			if not verrouille(c.Niveau) then
				persoEdite[champ] = c.Nom
				rafraichir()
			end
		end)
	end
	table.insert(miseAJour, function()
		entete.Text = ("%s  ·  %s"):format(titreSection, persoEdite[champ])
	end)
end

choixCouleur("🎨  CARROSSERIE", "Carrosserie")

-- 3) LA FINITION
local enteteFinition = section("✨  FINITION")
local grilleFinition = grille(Vector2.new(112, 34))
for i, f in ipairs(Config.Finitions) do
	local b = bouton(grilleFinition, f.Nom, Color3.fromRGB(45, 45, 58), UDim2.new())
	b.LayoutOrder = i
	local trait = contour(b, OR, 0)
	table.insert(miseAJour, function()
		local bloque = f.Niveau > niveau()
		b.Text = (bloque and "🔒 " or "") .. f.Nom
		b.BackgroundTransparency = bloque and 0.5 or 0
		trait.Thickness = persoEdite.Finition == f.Nom and 3 or 0
	end)
	b.Activated:Connect(function()
		if not verrouille(f.Niveau) then
			persoEdite.Finition = f.Nom
			rafraichir()
		end
	end)
end
table.insert(miseAJour, function()
	enteteFinition.Text = "✨  FINITION  ·  " .. persoEdite.Finition
end)

choixCouleur("🛞  JANTES", "Jantes")
choixCouleur("💺  SIÈGE", "Siege")

-- 4) LES BANDES DE COURSE
section("🏁  BANDES DE COURSE")
local boutonBandes = bouton(liste, "", Color3.fromRGB(45, 45, 58), UDim2.new(1, -10, 0, 36))
boutonBandes.LayoutOrder = suivant()
table.insert(miseAJour, function()
	boutonBandes.Text = persoEdite.BandesActives and "Bandes : OUI ✔" or "Bandes : NON ✕"
end)
boutonBandes.Activated:Connect(function()
	persoEdite.BandesActives = not persoEdite.BandesActives
	rafraichir()
end)
choixCouleur("     Couleur des bandes", "Bandes")

-- 5) L'AUTOCOLLANT
local enteteAutocollant = section("⭐  AUTOCOLLANT")
local grilleAutocollant = grille(Vector2.new(46, 46))
for i, a in ipairs(Config.Autocollants) do
	local b = bouton(grilleAutocollant, a.Texte ~= "" and a.Texte or "∅", Color3.fromRGB(45, 45, 58), UDim2.new())
	b.LayoutOrder = i
	local trait = contour(b, OR, 0)
	table.insert(miseAJour, function()
		local bloque = a.Niveau > niveau()
		b.Text = bloque and "🔒" or (a.Texte ~= "" and a.Texte or "∅")
		b.BackgroundTransparency = bloque and 0.5 or 0
		trait.Thickness = persoEdite.Autocollant == a.Nom and 3 or 0
	end)
	b.Activated:Connect(function()
		if not verrouille(a.Niveau) then
			persoEdite.Autocollant = a.Nom
			rafraichir()
		end
	end)
end
table.insert(miseAJour, function()
	enteteAutocollant.Text = "⭐  AUTOCOLLANT  ·  " .. persoEdite.Autocollant
end)

-- 6) LE NUMÉRO
section("#️⃣  NUMÉRO")
local ligneNumero = Instance.new("Frame")
ligneNumero.LayoutOrder = suivant()
ligneNumero.Size = UDim2.new(1, -10, 0, 40)
ligneNumero.BackgroundTransparency = 1
ligneNumero.Parent = liste
local moins = bouton(ligneNumero, "−", Color3.fromRGB(45, 45, 58), UDim2.new(0, 50, 1, 0), UDim2.new(0, 0, 0, 0))
local plus = bouton(ligneNumero, "+", Color3.fromRGB(45, 45, 58), UDim2.new(0, 50, 1, 0), UDim2.new(0, 160, 0, 0))
local valeurNumero = Instance.new("TextLabel")
valeurNumero.Size = UDim2.new(0, 90, 1, 0)
valeurNumero.Position = UDim2.new(0, 60, 0, 0)
valeurNumero.BackgroundTransparency = 1
valeurNumero.Font = Enum.Font.GothamBlack
valeurNumero.TextScaled = true
valeurNumero.TextColor3 = Color3.new(1, 1, 1)
valeurNumero.Parent = ligneNumero
table.insert(miseAJour, function()
	valeurNumero.Text = tostring(persoEdite.Numero)
end)
moins.Activated:Connect(function()
	persoEdite.Numero = (persoEdite.Numero - 1) % 100
	rafraichir()
end)
plus.Activated:Connect(function()
	persoEdite.Numero = (persoEdite.Numero + 1) % 100
	rafraichir()
end)

-- Un peu d'espace en bas de la liste
local espace = Instance.new("Frame")
espace.LayoutOrder = suivant()
espace.Size = UDim2.new(1, 0, 0, 10)
espace.BackgroundTransparency = 1
espace.Parent = liste

---------------------------------------------------------------------
-- OUVRIR / FERMER / ENREGISTRER
---------------------------------------------------------------------
local function ouvrir()
	if menuOuvert then
		return
	end
	if not profil then
		profil = remotes:WaitForChild("ObtenirProfil"):InvokeServer()
	end
	persoEdite = table.clone(profil and profil.Perso or Config.PersoParDefaut)
	menuOuvert = true
	controles:Disable()
	camera.CameraType = Enum.CameraType.Scriptable
	gui.Enabled = true
	statut.Text = ""
	rafraichir()
end

local function fermer()
	if not menuOuvert then
		return
	end
	menuOuvert = false
	gui.Enabled = false
	controles:Enable()
	camera.CameraType = Enum.CameraType.Custom
	if profil then
		majApercu(profil.Perso) -- on remet le kart enregistré sur le plateau
	end
end

boutonFermer.Activated:Connect(fermer)

boutonEnregistrer.Activated:Connect(function()
	remotes.Personnaliser:FireServer(persoEdite)
	afficherStatut("✔ Kart enregistré !", Color3.fromRGB(140, 255, 160))
end)

boutonSortir.Activated:Connect(function()
	remotes.Personnaliser:FireServer(persoEdite)
	fermer()
	task.wait(0.35) -- laisse le serveur enregistrer avant de sortir le kart
	remotes.SortirKart:FireServer()
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "PromptGarage" then
		ouvrir()
	end
end)

remotes:WaitForChild("ProfilMisAJour").OnClientEvent:Connect(function(nouveauProfil)
	if type(nouveauProfil) ~= "table" then
		return
	end
	profil = nouveauProfil
	if menuOuvert then
		rafraichir() -- de nouveaux éléments ont peut-être été débloqués
	else
		persoEdite = table.clone(profil.Perso)
		majApercu(profil.Perso)
	end
end)

task.spawn(function()
	local p = remotes:WaitForChild("ObtenirProfil"):InvokeServer()
	if type(p) == "table" and not profil then
		profil = p
		majApercu(p.Perso)
	end
end)

-- Si le joueur meurt / réapparaît avec le menu ouvert, on le ferme proprement
joueur.CharacterAdded:Connect(fermer)
