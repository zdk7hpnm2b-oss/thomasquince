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
	-- Caméra de showroom : le kart apparaît à gauche du menu (le panneau est à droite)
	local cfShowroom = CFrame.lookAt(plateau.Position + Vector3.new(-16, 6, 4), plateau.Position + Vector3.new(2, 1.5, 4))
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
-- INTERFACE  (style « atelier de course » : panneau sombre à droite,
-- liseré rouge, onglets, cases de couleur avec leur prix)
---------------------------------------------------------------------
local OR = Color3.fromRGB(255, 205, 80)
local FOND = Color3.fromRGB(17, 17, 21)
local ROUGE = Color3.fromRGB(225, 30, 45)
local ROUGE_SOMBRE = Color3.fromRGB(120, 22, 32)
local CASE = Color3.fromRGB(32, 32, 38)
local GRIS_TEXTE = Color3.fromRGB(170, 170, 180)
local VIOLET = Color3.fromRGB(190, 110, 255)

local gui = Instance.new("ScreenGui")
gui.Name = "GarageVIP"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Enabled = false
gui.Parent = joueur:WaitForChild("PlayerGui")

local function coins(objet: GuiObject, rayon: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, rayon or 6)
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

local function etiquette(parent: Instance, texte: string, taille: UDim2, position: UDim2, couleur: Color3, police: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = taille
	l.Position = position
	l.BackgroundTransparency = 1
	l.Font = police or Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = couleur
	l.Text = texte
	l.Parent = parent
	return l
end

-- Animations : la case grossit au survol et « rebondit » quand on clique
local function animer(b: GuiButton)
	local echelle = Instance.new("UIScale")
	echelle.Parent = b
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad)
	b.MouseEnter:Connect(function()
		TweenService:Create(echelle, info, { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(echelle, info, { Scale = 1 }):Play()
	end)
	b.Activated:Connect(function()
		echelle.Scale = 0.9
		TweenService:Create(echelle, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

local function bouton(parent: Instance, texte: string, couleur: Color3, taille: UDim2, position: UDim2?): TextButton
	local b = Instance.new("TextButton")
	b.Size = taille
	if position then
		b.Position = position
	end
	b.BackgroundColor3 = couleur
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.Text = texte
	b.AutoButtonColor = true
	coins(b)
	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 9)
	marge.PaddingBottom = UDim.new(0, 9)
	marge.PaddingLeft = UDim.new(0, 8)
	marge.PaddingRight = UDim.new(0, 8)
	marge.Parent = b
	b.Parent = parent
	animer(b)
	return b
end

-- Le panneau (à droite de l'écran, le kart tourne à gauche)
local panneau = Instance.new("Frame")
panneau.Name = "Panneau"
panneau.AnchorPoint = Vector2.new(1, 0.5)
panneau.Size = UDim2.new(0.34, 0, 0.92, 0)
panneau.Position = UDim2.new(1, -24, 0.5, 0)
panneau.BackgroundColor3 = FOND
panneau.BackgroundTransparency = 0.04
panneau.ClipsDescendants = true
panneau.Parent = gui
coins(panneau, 8)
contour(panneau, Color3.fromRGB(45, 45, 52), 1)
local tailleMax = Instance.new("UISizeConstraint")
tailleMax.MinSize = Vector2.new(330, 420)
tailleMax.MaxSize = Vector2.new(470, 880)
tailleMax.Parent = panneau
-- Liseré rouge en haut (avec un reflet qui passe)
local lisere = Instance.new("Frame")
lisere.Size = UDim2.new(1, 0, 0, 5)
lisere.BackgroundColor3 = ROUGE
lisere.BorderSizePixel = 0
lisere.Parent = panneau
local refletLisere = Instance.new("UIGradient")
refletLisere.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, ROUGE),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 150)),
	ColorSequenceKeypoint.new(1, ROUGE),
})
refletLisere.Parent = lisere
task.spawn(function()
	while true do
		refletLisere.Offset = Vector2.new(-1, 0)
		local t = TweenService:Create(refletLisere, TweenInfo.new(1.6, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) })
		t:Play()
		task.wait(3.2)
	end
end)

etiquette(panneau, "Garage", UDim2.new(0.5, 0, 0, 16), UDim2.new(0, 18, 0, 16), GRIS_TEXTE, Enum.Font.GothamMedium)
local titre = etiquette(panneau, "PERSONNALISER", UDim2.new(1, -90, 0, 40), UDim2.new(0, 18, 0, 32), Color3.new(1, 1, 1))
titre.FontFace = Font.fromEnum(Enum.Font.FredokaOne) -- gras italique, style course
local sousTitre = etiquette(panneau, "", UDim2.new(0.6, 0, 0, 18), UDim2.new(0, 18, 0, 76), Color3.fromRGB(230, 230, 235))
local soldePieces = etiquette(panneau, "💰 0", UDim2.new(0.35, 0, 0, 18), UDim2.new(0.65, -18, 0, 76), OR)
soldePieces.TextXAlignment = Enum.TextXAlignment.Right
local sousTitreNiveau = sousTitre -- (compatibilité)

local boutonFermer = bouton(panneau, "X", Color3.fromRGB(32, 32, 38), UDim2.new(0, 42, 0, 42), UDim2.new(1, -58, 0, 18))
boutonFermer.TextColor3 = Color3.fromRGB(220, 220, 225)

local statut = Instance.new("TextLabel") -- (ligne d'info, placée en bas)

local function afficherStatut(texte: string, couleur: Color3?)
	statut.Text = texte
	statut.TextColor3 = couleur or Color3.fromRGB(255, 160, 160)
	statut.TextTransparency = 1
	TweenService:Create(statut, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
end

---------------------------------------------------------------------
-- Les « slots » : un onglet par modèle de kart (comme SLOT 1, 2, 3...)
---------------------------------------------------------------------
local miseAJour: { () -> () } = {}

local function possede(liste: string, nom: string): boolean
	local p = profil and profil.Possessions
	return p ~= nil and type(p[liste]) == "table" and p[liste][nom] == true
end

local MarketplaceService = game:GetService("MarketplaceService")
-- Achat en Robux (ou gratuit dans Studio tant que le produit n'est pas configuré)
local function acheterRobux(produitId: number?, nomTest: string, quandOk: (() -> ())?)
	if (produitId or 0) ~= 0 then
		MarketplaceService:PromptProductPurchase(joueur, produitId :: number)
		return
	end
	local resultat = remotes:WaitForChild("Acheter"):InvokeServer({ type = "test", nom = nomTest })
	if type(resultat) == "table" then
		if resultat.profil then
			profil = resultat.profil
			if quandOk then
				quandOk()
			end
		end
		afficherStatut(resultat.message or "", if resultat.ok then Color3.fromRGB(140, 255, 160) else Color3.fromRGB(255, 140, 140))
	end
end

local rangeeSlots = Instance.new("Frame")
rangeeSlots.Size = UDim2.new(1, -32, 0, 50)
rangeeSlots.Position = UDim2.new(0, 16, 0, 104)
rangeeSlots.BackgroundTransparency = 1
rangeeSlots.Parent = panneau
local dispoSlots = Instance.new("UIListLayout")
dispoSlots.FillDirection = Enum.FillDirection.Horizontal
dispoSlots.Padding = UDim.new(0, 5)
dispoSlots.SortOrder = Enum.SortOrder.LayoutOrder
dispoSlots.Parent = rangeeSlots

local kartsTries = {}
for id, k in pairs(Config.Karts) do
	table.insert(kartsTries, { id = id, k = k })
end
table.sort(kartsTries, function(a, b)
	return a.k.Ordre < b.k.Ordre
end)
local largeurSlot = 1 / #kartsTries

local rafraichir: () -> ()
for i, e in ipairs(kartsTries) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = i
	b.Size = UDim2.new(largeurSlot, -5, 1, 0)
	b.BackgroundColor3 = CASE
	b.Text = ""
	b.AutoButtonColor = true
	b.Parent = rangeeSlots
	coins(b, 5)
	animer(b)
	local nomSlot = etiquette(b, "", UDim2.new(1, -8, 0.48, 0), UDim2.new(0, 4, 0.08, 0), Color3.new(1, 1, 1))
	nomSlot.TextXAlignment = Enum.TextXAlignment.Center
	local infoSlot = etiquette(b, "", UDim2.new(1, -8, 0.3, 0), UDim2.new(0, 4, 0.58, 0), GRIS_TEXTE, Enum.Font.FredokaOne)
	infoSlot.TextXAlignment = Enum.TextXAlignment.Center
	local souligne = Instance.new("Frame")
	souligne.AnchorPoint = Vector2.new(0, 1)
	souligne.Size = UDim2.new(1, 0, 0, 3)
	souligne.Position = UDim2.new(0, 0, 1, 0)
	souligne.BackgroundColor3 = ROUGE
	souligne.BorderSizePixel = 0
	souligne.Parent = b
	local bordExclusif: UIStroke? = nil
	if e.k.Exclusif then
		-- Le kart exclusif : cadre arc-en-ciel qui tourne
		bordExclusif = contour(b, Color3.new(1, 1, 1), 2)
		local degrade = Instance.new("UIGradient")
		degrade.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 200)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(120, 200, 255)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 230, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 200)),
		})
		degrade.Parent = bordExclusif
		task.spawn(function()
			while b.Parent do
				degrade.Rotation = (degrade.Rotation + 4) % 360
				task.wait(0.03)
			end
		end)
	end
	table.insert(miseAJour, function()
		local bloqueNiveau = e.k.Niveau > niveau()
		local aAcheter = e.k.Exclusif and not possede("Karts", e.id)
		nomSlot.Text = if e.k.Exclusif then "🦄 " .. string.upper(e.k.Nom) else string.upper(e.k.Nom)
		infoSlot.Text = if aAcheter then "🔒 " .. (e.k.PrixAffiche or "R$")
			elseif bloqueNiveau then ("🔒 NIV %d"):format(e.k.Niveau)
			elseif e.id == (profil and profil.Perso and profil.Perso.Kart) then "ACTUEL"
			else ("%d km/h"):format(e.k.VitesseMax)
		infoSlot.TextColor3 = if aAcheter then Color3.fromRGB(255, 200, 90) elseif bloqueNiveau then Color3.fromRGB(255, 120, 120) else GRIS_TEXTE
		local actif = persoEdite.Kart == e.id
		souligne.Visible = actif
		b.BackgroundColor3 = if actif then Color3.fromRGB(44, 30, 36) else CASE
	end)
	b.Activated:Connect(function()
		if e.k.Exclusif and not possede("Karts", e.id) and persoEdite.Kart ~= e.id then
			-- 1er clic : on ESSAIE le kart exclusif (aperçu sur le plateau)
			persoEdite.Kart = e.id
			afficherStatut(("👀 Aperçu %s · reclique pour l'acheter (%s)"):format(e.k.Nom, e.k.PrixAffiche or "R$"), VIOLET)
			rafraichir()
			return
		end
		if e.k.Exclusif and not possede("Karts", e.id) then
			afficherStatut(("🦄 %s : %s"):format(e.k.Nom, e.k.Description), VIOLET)
			acheterRobux(e.k.ProduitId, e.id, function()
				persoEdite.Kart = e.id
			end)
			rafraichir()
			return
		end
		if e.k.Niveau > niveau() then
			afficherStatut(("🔒 %s : débloqué au niveau %d (continue à drifter !)"):format(e.k.Nom, e.k.Niveau))
			return
		end
		persoEdite.Kart = e.id
		afficherStatut(("%s · %s"):format(e.k.Nom, e.k.Description), Color3.fromRGB(220, 220, 230))
		rafraichir()
	end)
end

---------------------------------------------------------------------
-- Onglets : PEINTURE / FINITIONS / DÉCO, et sous-onglets de la peinture
---------------------------------------------------------------------
local function rangeeOnglets(y: number, hauteur: number, noms: { string }, sombre: boolean?): ({ TextButton }, Frame)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -32, 0, hauteur)
	f.Position = UDim2.new(0, 16, 0, y)
	f.BackgroundTransparency = 1
	f.Parent = panneau
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.Parent = f
	local boutons = {}
	for i, nom in ipairs(noms) do
		local b = bouton(f, nom, CASE, UDim2.new(1 / #noms, -6, 1, 0))
		b.LayoutOrder = i
		b.TextColor3 = Color3.fromRGB(225, 225, 230)
		if sombre then
			b.Font = Enum.Font.FredokaOne
		end
		boutons[i] = b
	end
	return boutons, f
end

local ongletsPrincipaux = rangeeOnglets(162, 42, { "PEINTURE", "FINITIONS", "DÉCO" })
local sousOnglets, rangeeSous = rangeeOnglets(212, 32, { "CARROSSERIE", "JANTES", "SIÈGE", "BANDES" }, true)
local ongletActif, sousOngletActif = 1, 1

-- La zone qui défile (une page par onglet)
local zone = Instance.new("ScrollingFrame")
zone.Size = UDim2.new(1, -24, 1, -250 - 128)
zone.Position = UDim2.new(0, 12, 0, 252)
zone.BackgroundTransparency = 1
zone.BorderSizePixel = 0
zone.ScrollBarThickness = 5
zone.ScrollBarImageColor3 = ROUGE
zone.CanvasSize = UDim2.new()
zone.AutomaticCanvasSize = Enum.AutomaticSize.Y
zone.Parent = panneau

local function page(): Frame
	local p = Instance.new("Frame")
	p.Size = UDim2.new(1, -8, 0, 0)
	p.Position = UDim2.new(0, 4, 0, 0)
	p.AutomaticSize = Enum.AutomaticSize.Y
	p.BackgroundTransparency = 1
	p.Visible = false
	p.Parent = zone
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = p
	return p
end

local ordre = 0
local function suivant(): number
	ordre += 1
	return ordre
end

local function section(parent: Instance, nom: string, couleur: Color3?): TextLabel
	local l = etiquette(parent, nom, UDim2.new(1, 0, 0, 18), UDim2.new(), couleur or Color3.fromRGB(205, 205, 212), Enum.Font.FredokaOne)
	l.LayoutOrder = suivant()
	return l
end

local function grille(parent: Instance, taille: Vector2): Frame
	local f = Instance.new("Frame")
	f.LayoutOrder = suivant()
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundTransparency = 1
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(taille.X, taille.Y)
	g.CellPadding = UDim2.fromOffset(7, 7)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	f.Parent = parent
	return f
end

local DEGRADE_ARC_EN_CIEL = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(60, 255, 100)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 120, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 220)),
})
local DEGRADE_PASTEL = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 230)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 220, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 170)),
})

-- Une case de couleur, avec sa pastille de prix en bas (comme sur la photo)
local function caseCouleur(parent: Instance, ordreCase: number, couleur: Color3): (TextButton, TextLabel, UIStroke)
	local b = Instance.new("TextButton")
	b.LayoutOrder = ordreCase
	b.BackgroundColor3 = couleur
	b.Text = ""
	b.AutoButtonColor = true
	coins(b, 6)
	local trait = contour(b, Color3.new(1, 1, 1), 0)
	-- Petit reflet en haut de la case
	local brillance = Instance.new("Frame")
	brillance.Size = UDim2.new(1, -6, 0.32, 0)
	brillance.Position = UDim2.new(0, 3, 0, 3)
	brillance.BackgroundColor3 = Color3.new(1, 1, 1)
	brillance.BackgroundTransparency = 0.82
	brillance.BorderSizePixel = 0
	brillance.Parent = b
	coins(brillance, 4)
	local prix = Instance.new("TextLabel")
	prix.AnchorPoint = Vector2.new(0.5, 1)
	prix.Size = UDim2.new(0.86, 0, 0.3, 0)
	prix.Position = UDim2.new(0.5, 0, 1, -4)
	prix.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
	prix.BackgroundTransparency = 0.25
	prix.Font = Enum.Font.FredokaOne
	prix.TextScaled = true
	prix.TextColor3 = Color3.new(1, 1, 1)
	prix.Text = ""
	prix.Parent = b
	coins(prix, 4)
	b.Parent = parent
	animer(b)
	return b, prix, trait
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

local function grilleCouleurs(parent: Instance, champ: string, liste: { any }?)
	local g = grille(parent, Vector2.new(58, 58))
	for i, c in ipairs(liste or Config.Couleurs) do
		local b, prix, trait = caseCouleur(g, i, c.Couleur)
		if c.Nom == "Aucun" then
			b.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
		elseif c.Nom == "Arc-en-ciel" then
			local degrade = Instance.new("UIGradient")
			degrade.Color = DEGRADE_ARC_EN_CIEL
			degrade.Parent = b
		end
		local payante = (c.Prix or 0) > 0
		table.insert(miseAJour, function()
			local bloque = (c.Niveau or 1) > niveau()
			local aAcheter = payante and not possede("Couleurs", c.Nom)
			prix.Text = if bloque then ("🔒 NIV %d"):format(c.Niveau) elseif aAcheter then (tostring(c.Prix) .. " 💰") elseif c.Nom == "Aucun" then "AUCUN" else ""
			prix.Visible = prix.Text ~= ""
			local choisi = persoEdite[champ] == c.Nom and not (champ == "Carrosserie" and persoEdite.Premium)
			trait.Thickness = if choisi then 3 else 0
			b.BackgroundTransparency = if bloque then 0.5 else 0
		end)
		b.Activated:Connect(function()
			if (c.Niveau or 1) > niveau() then
				afficherStatut(("🔒 Débloqué au niveau %d (continue à drifter !)"):format(c.Niveau))
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
			afficherStatut(c.Nom, Color3.fromRGB(220, 220, 230))
			rafraichir()
		end)
	end
end

-- Les peintures Robux (premium, puis exclusives)
local function grillePremium(parent: Instance, exclusives: boolean)
	local g = grille(parent, Vector2.new(58, 58))
	for i, pp in ipairs(Config.PeinturesPremium or {}) do
		if (pp.Exclusive == true) ~= exclusives then
			continue
		end
		local b, prix, trait = caseCouleur(g, i, pp.Couleur)
		if pp.ArcEnCiel then
			local degrade = Instance.new("UIGradient")
			degrade.Color = if pp.Pastel then DEGRADE_PASTEL else DEGRADE_ARC_EN_CIEL
			degrade.Rotation = 35
			degrade.Parent = b
		elseif pp.Materiau == Enum.Material.Foil or pp.Materiau == Enum.Material.Ice or pp.Materiau == Enum.Material.Glass then
			local degrade = Instance.new("UIGradient") -- effet métal / glace / galaxie
			degrade.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, pp.Couleur:Lerp(Color3.new(1, 1, 1), 0.6)),
				ColorSequenceKeypoint.new(0.5, pp.Couleur),
				ColorSequenceKeypoint.new(1, pp.Couleur:Lerp(Color3.new(0, 0, 0), 0.4)),
			})
			degrade.Rotation = 45
			degrade.Parent = b
		end
		local bordCouleur = contour(b, if exclusives then VIOLET else OR, 1)
		table.insert(miseAJour, function()
			local achete = possede("Premium", pp.Nom)
			prix.Text = if achete then "" else "R$"
			prix.TextColor3 = if exclusives then Color3.fromRGB(230, 190, 255) else Color3.fromRGB(120, 255, 140)
			prix.Visible = not achete
			local choisi = persoEdite.Premium == pp.Nom
			trait.Thickness = if choisi then 3 else 0
			bordCouleur.Thickness = if choisi then 0 else 1
		end)
		b.Activated:Connect(function()
			if possede("Premium", pp.Nom) then
				persoEdite.Premium = if persoEdite.Premium == pp.Nom then nil else pp.Nom
				afficherStatut(pp.Nom, Color3.fromRGB(220, 220, 230))
				rafraichir()
				return
			end
			if persoEdite.Premium ~= pp.Nom then
				-- 1er clic : on ESSAIE la peinture sur le kart (aperçu)
				persoEdite.Premium = pp.Nom
				afficherStatut(("👀 Aperçu %s · reclique pour l'acheter (%s)"):format(pp.Nom, pp.PrixAffiche or "R$"), if exclusives then VIOLET else OR)
				rafraichir()
				return
			end
			afficherStatut(("%s %s · %s"):format(if exclusives then "✦" else "💎", pp.Nom, pp.PrixAffiche or "R$"), if exclusives then VIOLET else OR)
			acheterRobux(pp.ProduitId, pp.Nom, function()
				persoEdite.Premium = pp.Nom
			end)
			rafraichir()
		end)
	end
end

-- PAGE PEINTURE (un contenu par sous-onglet)
local pagesPeinture = {}
for i, champ in ipairs({ "Carrosserie", "Jantes", "Siege", "Bandes" }) do
	local p = page()
	section(p, "COULEURS")
	grilleCouleurs(p, champ)
	if champ == "Carrosserie" then
		section(p, "PEINTURE PREMIUM", OR)
		grillePremium(p, false)
		section(p, "✦ COULEURS EXCLUSIVES", VIOLET)
		grillePremium(p, true)
	elseif champ == "Bandes" then
		local b = bouton(p, "", CASE, UDim2.new(1, 0, 0, 38))
		b.LayoutOrder = 0 -- (en haut de la page)
		table.insert(miseAJour, function()
			b.Text = if persoEdite.BandesActives then "BANDES DE COURSE : OUI ✔" else "BANDES DE COURSE : NON ✕"
			b.BackgroundColor3 = if persoEdite.BandesActives then ROUGE_SOMBRE else CASE
		end)
		b.Activated:Connect(function()
			persoEdite.BandesActives = not persoEdite.BandesActives
			rafraichir()
		end)
	end
	pagesPeinture[i] = p
end

-- PAGE FINITIONS
local pageFinitions = page()
section(pageFinitions, "FINITION DE LA PEINTURE")
local grilleFinition = grille(pageFinitions, Vector2.new(124, 44))
for i, f in ipairs(Config.Finitions) do
	local b = bouton(grilleFinition, f.Nom, CASE, UDim2.new())
	b.LayoutOrder = i
	local trait = contour(b, ROUGE, 0)
	table.insert(miseAJour, function()
		local bloque = f.Niveau > niveau()
		b.Text = if bloque then ("🔒 %s · NIV %d"):format(f.Nom, f.Niveau) else f.Nom
		b.BackgroundTransparency = if bloque then 0.5 else 0
		b.BackgroundColor3 = if persoEdite.Finition == f.Nom then ROUGE_SOMBRE else CASE
		trait.Thickness = if persoEdite.Finition == f.Nom then 2 else 0
	end)
	b.Activated:Connect(function()
		if f.Niveau > niveau() then
			afficherStatut(("🔒 Débloqué au niveau %d (continue à drifter !)"):format(f.Niveau))
			return
		end
		persoEdite.Finition = f.Nom
		afficherStatut("Finition : " .. f.Nom, Color3.fromRGB(220, 220, 230))
		rafraichir()
	end)
end
local noteFinition = etiquette(pageFinitions, "(Une peinture premium a sa propre finition.)", UDim2.new(1, 0, 0, 14), UDim2.new(), GRIS_TEXTE, Enum.Font.GothamMedium)
noteFinition.LayoutOrder = suivant()

-- PAGE DÉCO : néons, autocollant, numéro
local pageDeco = page()
section(pageDeco, "NÉONS SOUS LE KART")
grilleCouleurs(pageDeco, "Neon", Config.Neons)
section(pageDeco, "🌈 TRAÎNÉES (derrière ton kart)", VIOLET)
local grilleTrainees = grille(pageDeco, Vector2.new(58, 58))
for i, t in ipairs(Config.Trainees or {}) do
	local b, prix, trait = caseCouleur(grilleTrainees, i, Color3.fromRGB(45, 45, 58))
	if t.Couleurs then
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		local degrade = Instance.new("UIGradient")
		degrade.Color = t.Couleurs
		degrade.Rotation = 45
		degrade.Parent = b
	end
	local icone = etiquette(b, t.Icone or "", UDim2.new(0.6, 0, 0.45, 0), UDim2.new(0.2, 0, 0.08, 0), Color3.new(1, 1, 1))
	icone.TextXAlignment = Enum.TextXAlignment.Center
	local offre = Config.OffreTrainee(t.Nom)
	table.insert(miseAJour, function()
		local achetee = t.Nom == "Aucune" or possede("Trainees", t.Nom)
		prix.Text = if achetee then (if t.Nom == "Aucune" then "AUCUNE" else "") else (offre and offre.PrixAffiche or "R$")
		prix.Visible = prix.Text ~= ""
		trait.Thickness = if (persoEdite.Trainee or "Aucune") == t.Nom then 3 else 0
	end)
	b.Activated:Connect(function()
		if t.Nom == "Aucune" or possede("Trainees", t.Nom) then
			persoEdite.Trainee = t.Nom
			afficherStatut("Traînée : " .. t.Nom, Color3.fromRGB(220, 220, 230))
			rafraichir()
			return
		end
		if not offre then
			afficherStatut("Gagne-la à la 🎡 ROUE DU JOUR !", VIOLET)
			return
		end
		afficherStatut(("%s %s · %s"):format(t.Icone or "", offre.Nom, offre.PrixAffiche), VIOLET)
		acheterRobux(offre.ProduitId, offre.Id, function()
			persoEdite.Trainee = t.Nom
		end)
		rafraichir()
	end)
end
section(pageDeco, "AUTOCOLLANT")
local grilleAutocollant = grille(pageDeco, Vector2.new(58, 58))
for i, a in ipairs(Config.Autocollants) do
	local b = bouton(grilleAutocollant, a.Texte ~= "" and a.Texte or "∅", CASE, UDim2.new())
	b.LayoutOrder = i
	local trait = contour(b, Color3.new(1, 1, 1), 0)
	table.insert(miseAJour, function()
		local bloque = a.Niveau > niveau()
		b.Text = if bloque then "🔒" else (a.Texte ~= "" and a.Texte or "∅")
		b.BackgroundTransparency = if bloque then 0.5 else 0
		trait.Thickness = if persoEdite.Autocollant == a.Nom then 3 else 0
	end)
	b.Activated:Connect(function()
		if a.Niveau > niveau() then
			afficherStatut(("🔒 Débloqué au niveau %d (continue à drifter !)"):format(a.Niveau))
			return
		end
		persoEdite.Autocollant = a.Nom
		rafraichir()
	end)
end
section(pageDeco, "NUMÉRO")
local ligneNumero = Instance.new("Frame")
ligneNumero.LayoutOrder = suivant()
ligneNumero.Size = UDim2.new(1, 0, 0, 44)
ligneNumero.BackgroundTransparency = 1
ligneNumero.Parent = pageDeco
local moins = bouton(ligneNumero, "−", CASE, UDim2.new(0, 54, 1, 0), UDim2.new(0, 0, 0, 0))
local plus = bouton(ligneNumero, "+", CASE, UDim2.new(0, 54, 1, 0), UDim2.new(0, 160, 0, 0))
local valeurNumero = etiquette(ligneNumero, "", UDim2.new(0, 90, 1, 0), UDim2.new(0, 62, 0, 0), Color3.new(1, 1, 1))
valeurNumero.TextXAlignment = Enum.TextXAlignment.Center
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

-- Affichage des onglets
local function majOnglets()
	for i, b in ipairs(ongletsPrincipaux) do
		b.BackgroundColor3 = if i == ongletActif then ROUGE else CASE
	end
	for i, b in ipairs(sousOnglets) do
		b.BackgroundColor3 = if i == sousOngletActif then ROUGE_SOMBRE else CASE
	end
	rangeeSous.Visible = ongletActif == 1
	for i, p in ipairs(pagesPeinture) do
		p.Visible = ongletActif == 1 and i == sousOngletActif
	end
	pageFinitions.Visible = ongletActif == 2
	pageDeco.Visible = ongletActif == 3
	-- sans sous-onglets, la zone remonte un peu
	zone.Position = UDim2.new(0, 12, 0, if ongletActif == 1 then 252 else 214)
	zone.Size = UDim2.new(1, -24, 1, if ongletActif == 1 then -378 else -340)
	zone.CanvasPosition = Vector2.zero
end
for i, b in ipairs(ongletsPrincipaux) do
	b.Activated:Connect(function()
		ongletActif = i
		majOnglets()
	end)
end
for i, b in ipairs(sousOnglets) do
	b.Activated:Connect(function()
		sousOngletActif = i
		majOnglets()
	end)
end
majOnglets()

-- Ligne d'info + boutons du bas (RÉINITIALISER / ENREGISTRER / SORTIR)
local barreStatut = Instance.new("Frame")
barreStatut.Size = UDim2.new(1, -32, 0, 38)
barreStatut.Position = UDim2.new(0, 16, 1, -120)
barreStatut.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
barreStatut.Parent = panneau
coins(barreStatut, 5)
statut.Size = UDim2.new(1, -24, 0.56, 0)
statut.Position = UDim2.new(0, 12, 0.22, 0)
statut.BackgroundTransparency = 1
statut.Font = Enum.Font.FredokaOne
statut.TextScaled = true
statut.TextXAlignment = Enum.TextXAlignment.Left
statut.TextColor3 = Color3.fromRGB(220, 220, 230)
statut.Parent = barreStatut

local boutonReinit = bouton(panneau, "RÉINIT.", Color3.fromRGB(32, 32, 38), UDim2.new(0.26, -8, 0, 52), UDim2.new(0, 16, 1, -70))
local boutonEnregistrer = bouton(panneau, "ENREGISTRER", ROUGE_SOMBRE, UDim2.new(0.37, -8, 0, 52), UDim2.new(0.26, 14, 1, -70))
local boutonSortir = bouton(panneau, "ROULER 🏁", ROUGE, UDim2.new(0.37, -14, 0, 52), UDim2.new(0.63, 12, 1, -70))
contour(boutonEnregistrer, ROUGE, 1)

boutonReinit.Activated:Connect(function()
	persoEdite = table.clone(profil and profil.Perso or Config.PersoParDefaut)
	afficherStatut("Retour au look enregistré", Color3.fromRGB(220, 220, 230))
	rafraichir()
end)

rafraichir = function()
	for _, f in ipairs(miseAJour) do
		f()
	end
	local k = Config.Karts[persoEdite.Kart]
	sousTitre.Text = string.upper(k and k.Nom or "") .. ("  ·  NIV %d"):format(niveau())
	soldePieces.Text = ("💰 %d"):format(profil and profil.Pieces or 0)
	if menuOuvert then
		majApercu(persoEdite)
	end
end
local _ = sousTitreNiveau

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
	local k = Config.Karts[persoEdite.Kart]
	statut.Text = ("%s · look actuel"):format(k and k.Nom or "Kart")
	statut.TextColor3 = Color3.fromRGB(220, 220, 230)
	-- Le panneau arrive en glissant depuis la droite
	panneau.Position = UDim2.new(1, 480, 0.5, 0)
	TweenService:Create(panneau, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(1, -24, 0.5, 0) }):Play()
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
	joueur:SetAttribute("RetourMenu", true) -- on revient au menu
end)

-- Bouton GARAGE du menu : on ouvre la personnalisation directement
joueur:GetAttributeChangedSignal("OuvrirGarage"):Connect(function()
	if joueur:GetAttribute("OuvrirGarage") then
		joueur:SetAttribute("OuvrirGarage", false)
		task.wait(0.05)
		ouvrir()
	end
end)

-- Ce qui n'est qu'un ESSAI (pas encore acheté) n'est pas enregistré
local function retirerEssais(): boolean
	local retire = false
	if persoEdite.Premium and not possede("Premium", persoEdite.Premium) then
		persoEdite.Premium = nil
		retire = true
	end
	local k = Config.Karts[persoEdite.Kart]
	if k and k.Exclusif and not possede("Karts", persoEdite.Kart) then
		persoEdite.Kart = (profil and profil.Perso and profil.Perso.Kart) or "Basique"
		retire = true
	end
	if persoEdite.Trainee and persoEdite.Trainee ~= "Aucune" and not possede("Trainees", persoEdite.Trainee) then
		persoEdite.Trainee = "Aucune"
		retire = true
	end
	return retire
end

boutonEnregistrer.Activated:Connect(function()
	if retirerEssais() then
		rafraichir()
		afficherStatut("(Les objets en aperçu non achetés ont été retirés)", Color3.fromRGB(255, 200, 90))
		task.wait(1.2)
	end
	remotes.Personnaliser:FireServer(persoEdite)
	afficherStatut("✔ Kart enregistré !", Color3.fromRGB(140, 255, 160))
end)

boutonSortir.Activated:Connect(function()
	retirerEssais()
	remotes.Personnaliser:FireServer(persoEdite)
	fermer(true) -- la cinématique de départ prend le relais
	task.wait(0.35) -- laisse le serveur enregistrer avant de sortir le kart
	if Config.TypeDePlace() == "Lobby" then
		joueur:SetAttribute("ModeDemande", "Entrainement") -- au lobby : direction l'entraînement
	else
		remotes.SortirKart:FireServer()
	end
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
	t1.Font = Enum.Font.FredokaOne
	t1.TextScaled = true
	t1.TextColor3 = OR
	t1.Text = "★ GARAGE VIP ★"
	t1.Parent = cadre
	local t2 = Instance.new("TextLabel")
	t2.Size = UDim2.new(1, -20, 0, 28)
	t2.Position = UDim2.new(0, 10, 0, 70)
	t2.BackgroundTransparency = 1
	t2.Font = Enum.Font.FredokaOne
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
			local hud = joueur.PlayerGui:FindFirstChild("PartieHUD")
			local menuDuJeu = hud and hud:FindFirstChild("Menu")
			local menuOuvertAilleurs = (menuDuJeu and (menuDuJeu :: Frame).Visible) or menuOuvert or joueur:GetAttribute("EnTuto")
			if maintenantDedans and not dedans and not menuOuvertAilleurs then
				montrerBanniere()
			end
			dedans = maintenantDedans
		end
	end
end)
