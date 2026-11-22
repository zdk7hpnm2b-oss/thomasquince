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
-- Transitions de caméra (aller vers le plateau / revenir derrière le joueur)
local debutTransition = 0
local camDepart = CFrame.new()
local transitionRetour = false
local DUREE_TRANSITION = 0.9

local function adoucir(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function cameraDerriereJoueur(): CFrame?
	local perso = joueur.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not racine then
		return nil
	end
	local regard = racine.CFrame.LookVector
	return CFrame.lookAt(racine.Position - regard * 12 + Vector3.new(0, 5, 0), racine.Position + Vector3.new(0, 2, 0))
end
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
	-- Caméra de showroom : le kart apparaît à droite du menu
	local cfShowroom = CFrame.lookAt(plateau.Position + Vector3.new(-17, 7, 4), plateau.Position + Vector3.new(0, 1.5, -4))
	if menuOuvert then
		-- La caméra glisse en douceur jusqu'au plateau
		camera.CFrame = camDepart:Lerp(cfShowroom, adoucir((os.clock() - debutTransition) / DUREE_TRANSITION))
	elseif transitionRetour then
		-- Si le joueur vient de monter dans son kart, c'est la caméra du kart qui commande
		local humanoide = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
		if humanoide and humanoide.SeatPart then
			transitionRetour = false
			return
		end
		-- ...puis revient en douceur derrière le joueur
		local a = adoucir((os.clock() - debutTransition) / 0.7)
		local cfFin = cameraDerriereJoueur() or cfShowroom
		camera.CFrame = cfShowroom:Lerp(cfFin, a)
		if a >= 1 then
			transitionRetour = false
			camera.CameraType = Enum.CameraType.Custom
		end
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
	sousTitre.Text = ("Niveau %d  ·  💰 %d pièces  ·  drifte pour en gagner !"):format(niveau(), profil and profil.Pieces or 0)
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
-- Ce que le joueur a acheté
local function possede(liste: string, nom: string): boolean
	local p = profil and profil.Possessions
	return p ~= nil and type(p[liste]) == "table" and p[liste][nom] == true
end

-- Acheter une couleur avec des pièces (2 clics : le 1er demande confirmation)
local achatEnAttente: string? = nil
local function acheterCouleur(c): boolean
	if achatEnAttente ~= c.Nom then
		achatEnAttente = c.Nom
		afficherStatut(("Acheter « %s » pour %d 💰 ? Clique encore pour confirmer"):format(c.Nom, c.Prix), Color3.fromRGB(255, 220, 90))
		task.delay(4, function()
			if achatEnAttente == c.Nom then
				achatEnAttente = nil
			end
		end)
		return false
	end
	achatEnAttente = nil
	local resultat = remotes:WaitForChild("Acheter"):InvokeServer({ type = "couleur", nom = c.Nom })
	if type(resultat) == "table" then
		if resultat.profil then
			profil = resultat.profil
		end
		afficherStatut(resultat.message or "", if resultat.ok then Color3.fromRGB(140, 255, 160) else Color3.fromRGB(255, 140, 140))
		return resultat.ok == true
	end
	return false
end

local function choixCouleur(titreSection: string, champ: string, liste: { any }?)
	local entete = section(titreSection)
	local g = grille(Vector2.new(40, 40))
	for i, c in ipairs(liste or Config.Couleurs) do
		local b = Instance.new("TextButton")
		b.LayoutOrder = i
		b.BackgroundColor3 = c.Couleur
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = ""
		coins(b, 20)
		local trait = contour(b, Color3.new(1, 1, 1), 0)
		if c.Nom == "Aucun" then
			b.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
		elseif c.Nom == "Arc-en-ciel" then
			local degrade = Instance.new("UIGradient")
			degrade.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(60, 255, 100)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 120, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 220)),
			})
			degrade.Parent = b
		end
		b.Parent = g
		local payante = (c.Prix or 0) > 0
		table.insert(miseAJour, function()
			local bloque = c.Niveau > niveau()
			local aAcheter = payante and not possede("Couleurs", c.Nom)
			b.Text = if bloque then "🔒" elseif aAcheter then (tostring(c.Prix) .. "💰") elseif c.Nom == "Aucun" then "∅" else ""
			b.BackgroundTransparency = if bloque then 0.55 elseif aAcheter then 0.25 else 0
			trait.Thickness = if persoEdite[champ] == c.Nom and not (champ == "Carrosserie" and persoEdite.Premium) then 3 else 0
		end)
		b.Activated:Connect(function()
			if verrouille(c.Niveau) then
				return
			end
			if payante and not possede("Couleurs", c.Nom) and not acheterCouleur(c) then
				rafraichir()
				return
			end
			persoEdite[champ] = c.Nom
			if champ == "Carrosserie" then
				persoEdite.Premium = nil -- une couleur normale remplace la peinture premium
			end
			rafraichir()
		end)
	end
	table.insert(miseAJour, function()
		entete.Text = ("%s  ·  %s"):format(titreSection, persoEdite[champ])
	end)
end

choixCouleur("🎨  CARROSSERIE", "Carrosserie")

-- 2 bis) LES PEINTURES PREMIUM (Robux)
local MarketplaceService = game:GetService("MarketplaceService")
local entetePremium = section("💎  PEINTURES PREMIUM")
local grillePremium = grille(Vector2.new(40, 40))
for i, pp in ipairs(Config.PeinturesPremium or {}) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = i
	b.BackgroundColor3 = pp.Couleur
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	coins(b, 8)
	local trait = contour(b, OR, 0)
	if pp.ArcEnCiel then
		local degrade = Instance.new("UIGradient")
		degrade.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(60, 255, 100)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 120, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 220)),
		})
		degrade.Parent = b
	end
	b.Parent = grillePremium
	table.insert(miseAJour, function()
		b.Text = if possede("Premium", pp.Nom) then "" else "R$"
		trait.Thickness = if persoEdite.Premium == pp.Nom then 3 else 0
	end)
	b.Activated:Connect(function()
		if possede("Premium", pp.Nom) then
			persoEdite.Premium = if persoEdite.Premium == pp.Nom then nil else pp.Nom
			rafraichir()
		elseif (pp.ProduitId or 0) ~= 0 then
			MarketplaceService:PromptProductPurchase(joueur, pp.ProduitId) -- achat Roblox
		else
			-- Pas encore configuré : gratuit dans Studio pour tester
			local resultat = remotes:WaitForChild("Acheter"):InvokeServer({ type = "test", nom = pp.Nom })
			if type(resultat) == "table" then
				if resultat.profil then
					profil = resultat.profil
					persoEdite.Premium = pp.Nom
				end
				afficherStatut(resultat.message or "", if resultat.ok then Color3.fromRGB(140, 255, 160) else Color3.fromRGB(255, 140, 140))
			end
			rafraichir()
		end
	end)
end
table.insert(miseAJour, function()
	entetePremium.Text = "💎  PEINTURES PREMIUM" .. (if persoEdite.Premium then ("  ·  " .. persoEdite.Premium) else "  ·  " .. (Config.PeinturesPremium[1] and Config.PeinturesPremium[1].PrixAffiche or "") .. " et +")
end)

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

choixCouleur("💡  NÉONS SOUS LE KART", "Neon", Config.Neons)
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
	camDepart = camera.CFrame
	debutTransition = os.clock()
	transitionRetour = false
	menuOuvert = true
	joueur:SetAttribute("MenuGarage", true)
	controles:Disable()
	camera.CameraType = Enum.CameraType.Scriptable
	gui.Enabled = true
	statut.Text = ""
	-- Le panneau arrive en glissant depuis la gauche
	panneau.Position = UDim2.new(0, -440, 0, 20)
	TweenService:Create(panneau, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 20, 0, 20) }):Play()
	rafraichir()
end

local function fermer(sansTransition: boolean?)
	if not menuOuvert then
		return
	end
	menuOuvert = false
	joueur:SetAttribute("MenuGarage", false)
	gui.Enabled = false
	controles:Enable()
	if sansTransition then
		camera.CameraType = Enum.CameraType.Custom
	else
		transitionRetour = true
		debutTransition = os.clock()
		joueur:SetAttribute("CameraGarage", true)
		task.delay(0.8, function()
			joueur:SetAttribute("CameraGarage", false)
		end)
	end
	if profil then
		majApercu(profil.Perso) -- on remet le kart enregistré sur le plateau
	end
end

boutonFermer.Activated:Connect(function()
	fermer(false)
end)

boutonEnregistrer.Activated:Connect(function()
	remotes.Personnaliser:FireServer(persoEdite)
	afficherStatut("✔ Kart enregistré !", Color3.fromRGB(140, 255, 160))
end)

boutonSortir.Activated:Connect(function()
	remotes.Personnaliser:FireServer(persoEdite)
	fermer(true) -- la cinématique de départ prend le relais
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
joueur.CharacterAdded:Connect(function()
	fermer(true)
end)

---------------------------------------------------------------------
-- BANNIÈRE « GARAGE VIP » quand on entre dans le garage
-- (mêmes limites que le bâtiment construit par MallDriftServer)
---------------------------------------------------------------------
local GARAGE_X, GARAGE_Z1, GARAGE_Z2 = 90, 250, 330
local banniere = Instance.new("ScreenGui")
banniere.Name = "BanniereGarage"
banniere.ResetOnSpawn = false
banniere.IgnoreGuiInset = true
banniere.DisplayOrder = 5
banniere.Parent = joueur:WaitForChild("PlayerGui")

local function montrerBanniere()
	local cadre = Instance.new("Frame")
	cadre.AnchorPoint = Vector2.new(0.5, 0.5)
	cadre.Size = UDim2.new(0, 520, 0, 110)
	cadre.Position = UDim2.fromScale(0.5, 0.3)
	cadre.BackgroundColor3 = FOND
	cadre.BackgroundTransparency = 0.15
	cadre.Parent = banniere
	coins(cadre, 14)
	local trait = contour(cadre, Color3.fromRGB(190, 120, 255), 3)
	local t1 = Instance.new("TextLabel")
	t1.Size = UDim2.new(1, -20, 0, 56)
	t1.Position = UDim2.new(0, 10, 0, 8)
	t1.BackgroundTransparency = 1
	t1.Font = Enum.Font.GothamBlack
	t1.TextScaled = true
	t1.TextColor3 = OR
	t1.Text = "★ GARAGE VIP ★"
	t1.Parent = cadre
	local t2 = Instance.new("TextLabel")
	t2.Size = UDim2.new(1, -20, 0, 28)
	t2.Position = UDim2.new(0, 10, 0, 70)
	t2.BackgroundTransparency = 1
	t2.Font = Enum.Font.GothamBold
	t2.TextScaled = true
	t2.TextColor3 = Color3.fromRGB(220, 220, 230)
	t2.Text = "Borne violette : E = personnaliser  ·  F = prendre ton kart"
	t2.Parent = cadre
	local echelle = Instance.new("UIScale")
	echelle.Scale = 0.2
	echelle.Parent = cadre
	TweenService:Create(echelle, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.6, function()
		local info = TweenInfo.new(0.5)
		TweenService:Create(cadre, info, { BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.24) }):Play()
		TweenService:Create(t1, info, { TextTransparency = 1 }):Play()
		TweenService:Create(t2, info, { TextTransparency = 1 }):Play()
		TweenService:Create(trait, info, { Transparency = 1 }):Play()
		task.wait(0.55)
		cadre:Destroy()
	end)
end

task.spawn(function()
	local dedans = false
	while true do
		task.wait(0.3)
		local perso = joueur.Character
		local racine = perso and perso:FindFirstChild("HumanoidRootPart") :: BasePart?
		if racine and joueur:GetAttribute("IntroFinie") then
			local p = racine.Position
			local maintenantDedans = math.abs(p.X) < GARAGE_X and p.Z > GARAGE_Z1 and p.Z < GARAGE_Z2
			if maintenantDedans and not dedans then
				montrerBanniere()
			end
			dedans = maintenantDedans
		end
	end
end)
