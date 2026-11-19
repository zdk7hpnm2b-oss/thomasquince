--[[
	NEON BAY : générateur de la carte de départ (3 zones)

	COMMENT L'UTILISER
	1. Ouvre une nouvelle place dans Roblox Studio (modèle « Baseplate » ou vide).
	2. Si tu as une Baseplate, supprime-la (la carte a son propre sol).
	3. Menu « View » > « Command Bar » (barre de commande en bas).
	4. Copie TOUT ce fichier, colle-le dans la barre de commande, appuie sur Entrée.
	5. La carte apparaît dans Workspace > NeonBay. Ctrl+Z pour annuler si besoin.

	Tu peux relancer le script autant de fois que tu veux : il efface l'ancienne
	carte NeonBay avant de reconstruire.

	CE QUI EST CRÉÉ
	- La plage (Ocean Strip) : point de départ des Malins, écran géant,
	  cabine de déguisement, palmiers, mer, et Muscle Beach (5 appareils de muscu).
	- La rue des boutiques (Little Mango) : 3 boutiques avec une caisse
	  (« Faire le coup », 5 secondes), affiches « Recherché », poste des Gardiens.
	- Le marais (Gator Swamp) : eau, îlots, roseaux, planque du duo,
	  hydroglisseurs, alligators, Gus du marais.
	- Les équipes « Malins » et « Gardiens », un éclairage de coucher de soleil.

	Les objets importants ont un nom fixe (Caisse, CabineDeguisement, Planque,
	EcranGeant, AffichesRecherche...) : les scripts de gameplay s'en serviront.
	Les personnages (vendeurs, Gus, Don Flamingo, alligators) sont des
	silhouettes simples à remplacer par des modèles de la Toolbox.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Teams = game:GetService("Teams")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

pcall(function() ChangeHistoryService:SetWaypoint("Avant Neon Bay") end)

---------------------------------------------------------------------------
-- Couleurs
---------------------------------------------------------------------------
local C = {
	route = Color3.fromRGB(45, 45, 52),
	trottoir = Color3.fromRGB(200, 195, 185),
	herbe = Color3.fromRGB(110, 170, 80),
	sable = Color3.fromRGB(240, 220, 165),
	ligne = Color3.fromRGB(255, 210, 60),
	rose = Color3.fromRGB(255, 70, 170),
	cyan = Color3.fromRGB(40, 230, 255),
	violet = Color3.fromRGB(150, 80, 255),
	orange = Color3.fromRGB(255, 140, 40),
	menthe = Color3.fromRGB(120, 235, 190),
	bleuGardien = Color3.fromRGB(40, 110, 220),
	bois = Color3.fromRGB(140, 95, 60),
	tronc = Color3.fromRGB(120, 85, 50),
	feuille = Color3.fromRGB(50, 160, 70),
	alligator = Color3.fromRGB(70, 110, 50),
	blanc = Color3.fromRGB(255, 255, 255),
	noir = Color3.fromRGB(15, 15, 20),
}

---------------------------------------------------------------------------
-- Dossiers (on efface l'ancienne carte si elle existe)
---------------------------------------------------------------------------
local ancien = Workspace:FindFirstChild("NeonBay")
if ancien then ancien:Destroy() end

local racine = Instance.new("Folder")
racine.Name = "NeonBay"
racine.Parent = Workspace

local function dossier(nom, parent)
	local f = Instance.new("Folder")
	f.Name = nom
	f.Parent = parent or racine
	return f
end

local dSol = dossier("Sol")
local dPlage = dossier("Plage")
local dRue = dossier("RueDesBoutiques")
local dMarais = dossier("Marais")
local dDecor = dossier("Decor")
local dAffiches = dossier("AffichesRecherche", dRue)

---------------------------------------------------------------------------
-- Outils de construction
---------------------------------------------------------------------------

-- Crée une Part ancrée. props : Name, Size, CFrame, Color, Material, Shape...
local function bloc(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function modele(nom, parent)
	local m = Instance.new("Model")
	m.Name = nom
	m.Parent = parent
	return m
end

-- Texte affiché sur une face d'une Part
local function texteSurFace(part, face, texte, couleurTexte, couleurFond)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = couleurFond or C.noir
	label.BackgroundTransparency = couleurFond and 0 or 1
	label.TextColor3 = couleurTexte or C.blanc
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = texte
	label.Parent = gui
	return label
end

-- Étiquette flottante au-dessus d'un objet
local function etiquette(adornee, texte, couleur)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 50)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	bb.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = couleur or C.blanc
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = texte
	label.Parent = bb
	return bb
end

-- Bouton d'action (le « bouton unique » du jeu : E sur PC, bouton sur mobile)
local function bouton(part, action, objet, duree)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objet
	prompt.HoldDuration = duree or 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

-- Palmier simple : tronc + 6 feuilles + noix de coco
local function palmier(x, y, z, hauteur)
	hauteur = hauteur or 18
	local m = modele("Palmier", dDecor)
	bloc(m, {
		Name = "Tronc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(hauteur, 1.6, 1.6),
		CFrame = CFrame.new(x, y + hauteur / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.tronc,
		Material = Enum.Material.Wood,
	})
	local haut = CFrame.new(x, y + hauteur, z)
	for i = 1, 6 do
		local angle = math.rad(i * 60)
		bloc(m, {
			Name = "Feuille",
			Size = Vector3.new(3, 0.4, 9),
			CFrame = haut * CFrame.Angles(0, angle, 0) * CFrame.new(0, -1, -4) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = C.feuille,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	for i = 1, 3 do
		local angle = math.rad(i * 120)
		bloc(m, {
			Name = "NoixDeCoco",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.3, 1.3, 1.3),
			CFrame = haut * CFrame.Angles(0, angle, 0) * CFrame.new(0, -1.2, -1),
			Color = C.tronc,
			CanCollide = false,
		})
	end
	return m
end

-- Lampadaire néon
local function lampadaire(x, z, couleur)
	local m = modele("Lampadaire", dDecor)
	bloc(m, {
		Name = "Poteau",
		Size = Vector3.new(0.8, 14, 0.8),
		CFrame = CFrame.new(x, 7, z),
		Color = C.noir,
		Material = Enum.Material.Metal,
	})
	local lampe = bloc(m, {
		Name = "Lampe",
		Size = Vector3.new(2.5, 1, 2.5),
		CFrame = CFrame.new(x, 14.5, z),
		Color = couleur,
		Material = Enum.Material.Neon,
	})
	local lumiere = Instance.new("PointLight")
	lumiere.Color = couleur
	lumiere.Range = 22
	lumiere.Brightness = 2
	lumiere.Parent = lampe
	return m
end

-- Silhouette de personnage (à remplacer par un modèle de la Toolbox)
local function silhouette(nom, parent, cf, couleur, texte)
	local m = modele(nom, parent)
	local corps = bloc(m, {
		Name = "Corps",
		Size = Vector3.new(2, 3, 1.2),
		CFrame = cf * CFrame.new(0, 2.5, 0),
		Color = couleur,
	})
	bloc(m, {
		Name = "Tete",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = cf * CFrame.new(0, 4.9, 0),
		Color = Color3.fromRGB(255, 205, 160),
	})
	bloc(m, {
		Name = "Jambes",
		Size = Vector3.new(2, 1, 1.2),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = C.noir,
	})
	m.PrimaryPart = corps
	etiquette(corps, texte or nom, C.blanc)
	return m
end

--[[
	Bâtiment générique. La porte est sur la face avant (+Z local).
	cf : position et orientation au niveau du sol, au centre du bâtiment.
]]
local function batiment(nom, parent, cf, largeur, profondeur, hauteur, couleurMur, couleurNeon, enseigne)
	local m = modele(nom, parent)
	local w, d, h = largeur, profondeur, hauteur
	local porte = 10
	local cote = (w - porte) / 2

	local function piece(n, taille, pos, props)
		local p = {
			Name = n,
			Size = taille,
			CFrame = cf * CFrame.new(pos),
			Color = couleurMur,
			Material = Enum.Material.Concrete,
		}
		if props then
			for k, v in pairs(props) do p[k] = v end
		end
		return bloc(m, p)
	end

	piece("Sol", Vector3.new(w, 0.4, d), Vector3.new(0, 0.2, 0), { Color = C.trottoir, Material = Enum.Material.Marble })
	piece("MurArriere", Vector3.new(w, h, 1), Vector3.new(0, h / 2, -d / 2 + 0.5))
	piece("MurGauche", Vector3.new(1, h, d), Vector3.new(-w / 2 + 0.5, h / 2, 0))
	piece("MurDroit", Vector3.new(1, h, d), Vector3.new(w / 2 - 0.5, h / 2, 0))
	piece("FacadeGauche", Vector3.new(cote, h, 1), Vector3.new(-w / 2 + cote / 2, h / 2, d / 2 - 0.5))
	piece("FacadeDroite", Vector3.new(cote, h, 1), Vector3.new(w / 2 - cote / 2, h / 2, d / 2 - 0.5))
	piece("DessusPorte", Vector3.new(porte, h - 9, 1), Vector3.new(0, 9 + (h - 9) / 2, d / 2 - 0.5))
	piece("Toit", Vector3.new(w + 2, 1, d + 2), Vector3.new(0, h + 0.5, 0), { Color = C.noir })

	-- Bande néon le long de la façade
	piece("BandeNeon", Vector3.new(w, 0.6, 0.6), Vector3.new(0, h - 0.5, d / 2 + 0.3), {
		Color = couleurNeon,
		Material = Enum.Material.Neon,
	})

	-- Lumière intérieure
	local plafond = piece("Plafonnier", Vector3.new(4, 0.4, 4), Vector3.new(0, h - 0.4, 0), {
		Color = C.blanc,
		Material = Enum.Material.Neon,
	})
	local lumiere = Instance.new("PointLight")
	lumiere.Range = math.max(w, d)
	lumiere.Brightness = 1.5
	lumiere.Parent = plafond

	-- Enseigne au-dessus de la porte
	if enseigne then
		local panneau = piece("Enseigne", Vector3.new(w * 0.75, 5, 1), Vector3.new(0, h + 3.5, d / 2 - 0.5), {
			Color = C.noir,
			Material = Enum.Material.SmoothPlastic,
		})
		texteSurFace(panneau, Enum.NormalId.Back, enseigne, couleurNeon)
	end

	return m
end

---------------------------------------------------------------------------
-- 1. SOL, ROUTE, MER
--    Axe X : plage (x < -110), rue (-110 à 110), marais (x > 110)
--    Axe Z : route au centre (z = 0), mer au sud (z > 160)
---------------------------------------------------------------------------
bloc(dSol, {
	Name = "SolVille",
	Size = Vector3.new(460, 2, 400),
	CFrame = CFrame.new(-120, -1, -40),
	Color = C.herbe,
	Material = Enum.Material.Grass,
})

bloc(dSol, {
	Name = "Route",
	Size = Vector3.new(460, 0.2, 30),
	CFrame = CFrame.new(-120, 0.1, 0),
	Color = C.route,
	Material = Enum.Material.Asphalt,
})

-- Pointillés jaunes au milieu de la route
for x = -340, 100, 16 do
	bloc(dSol, {
		Name = "Ligne",
		Size = Vector3.new(8, 0.05, 0.6),
		CFrame = CFrame.new(x, 0.23, 0),
		Color = C.ligne,
		CanCollide = false,
	})
end

for _, z in ipairs({ -20, 20 }) do
	bloc(dSol, {
		Name = "Trottoir",
		Size = Vector3.new(460, 0.6, 10),
		CFrame = CFrame.new(-120, 0.3, z),
		Color = C.trottoir,
		Material = Enum.Material.Concrete,
	})
end

-- Mer (eau de terrain, on peut y nager et y mettre des bateaux)
local terrain = Workspace.Terrain
terrain:FillBlock(CFrame.new(0, -14, 260), Vector3.new(720, 4, 200), Enum.Material.Sand)
terrain:FillBlock(CFrame.new(0, -6, 260), Vector3.new(720, 12, 200), Enum.Material.Water)

---------------------------------------------------------------------------
-- 2. LA PLAGE (Ocean Strip)
---------------------------------------------------------------------------
bloc(dPlage, {
	Name = "Sable",
	Size = Vector3.new(240, 0.3, 135),
	CFrame = CFrame.new(-230, 0.15, 92.5),
	Color = C.sable,
	Material = Enum.Material.Sand,
})

-- Point de départ des Malins
local spawnMalins = Instance.new("SpawnLocation")
spawnMalins.Name = "DepartMalins"
spawnMalins.Anchored = true
spawnMalins.Size = Vector3.new(12, 1, 12)
spawnMalins.CFrame = CFrame.new(-230, 0.5, 45)
spawnMalins.Color = C.orange
spawnMalins.Material = Enum.Material.Neon
spawnMalins.Neutral = false
spawnMalins.TeamColor = BrickColor.new("Deep orange")
spawnMalins.Duration = 0
spawnMalins.Parent = dPlage

-- Écran géant (montre le meilleur exploit du serveur)
local ecran = modele("EcranGeant", dPlage)
for _, dx in ipairs({ -26, 26 }) do
	bloc(ecran, {
		Name = "Pilier",
		Size = Vector3.new(2, 14, 2),
		CFrame = CFrame.new(-230 + dx, 7, 150),
		Color = C.noir,
		Material = Enum.Material.Metal,
	})
end
local dalle = bloc(ecran, {
	Name = "Ecran",
	Size = Vector3.new(60, 28, 2),
	CFrame = CFrame.new(-230, 28, 150),
	Color = C.noir,
})
local guiEcran = Instance.new("SurfaceGui")
guiEcran.Name = "Affichage"
guiEcran.Face = Enum.NormalId.Front
guiEcran.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
guiEcran.PixelsPerStud = 20
guiEcran.Parent = dalle
local titre = Instance.new("TextLabel")
titre.Name = "Titre"
titre.Size = UDim2.fromScale(1, 0.3)
titre.BackgroundColor3 = C.rose
titre.TextColor3 = C.blanc
titre.TextScaled = true
titre.Font = Enum.Font.FredokaOne
titre.Text = "NEON BAY TV"
titre.Parent = guiEcran
local exploit = Instance.new("TextLabel")
exploit.Name = "TexteExploit"
exploit.Position = UDim2.fromScale(0, 0.3)
exploit.Size = UDim2.fromScale(1, 0.7)
exploit.BackgroundColor3 = C.noir
exploit.TextColor3 = C.cyan
exploit.TextScaled = true
exploit.Font = Enum.Font.FredokaOne
exploit.Text = "Meilleur exploit : en attente du premier coup..."
exploit.Parent = guiEcran

-- Cabine de déguisement (efface les étoiles)
local cabine = modele("CabineDeguisement", dPlage)
local baseCabine = CFrame.new(-150, 0, 50) * CFrame.Angles(0, math.pi, 0) -- ouverture vers la route
bloc(cabine, { Name = "Arriere", Size = Vector3.new(8, 10, 1), CFrame = baseCabine * CFrame.new(0, 5, -3.5), Color = C.menthe })
bloc(cabine, { Name = "Gauche", Size = Vector3.new(1, 10, 8), CFrame = baseCabine * CFrame.new(-3.5, 5, 0), Color = C.menthe })
bloc(cabine, { Name = "Droite", Size = Vector3.new(1, 10, 8), CFrame = baseCabine * CFrame.new(3.5, 5, 0), Color = C.menthe })
bloc(cabine, { Name = "Toit", Size = Vector3.new(9, 1, 9), CFrame = baseCabine * CFrame.new(0, 10.5, 0), Color = C.rose, Material = Enum.Material.Neon })
local rideau = bloc(cabine, {
	Name = "Rideau",
	Size = Vector3.new(6, 9, 0.3),
	CFrame = baseCabine * CFrame.new(0, 4.5, 3.3),
	Color = C.violet,
	Material = Enum.Material.Fabric,
	CanCollide = false,
})
local panneauCabine = bloc(cabine, {
	Name = "Panneau",
	Size = Vector3.new(8, 2.5, 0.5),
	CFrame = baseCabine * CFrame.new(0, 12.5, 3.5),
	Color = C.noir,
})
texteSurFace(panneauCabine, Enum.NormalId.Back, "DÉGUISEMENT", C.rose)
bouton(rideau, "Se déguiser", "Cabine", 1)
cabine.PrimaryPart = rideau

-- Palmiers et parasols sur la plage
for i = 0, 5 do
	palmier(-330 + i * 40, 0.3, 30 + (i % 2) * 6)
	palmier(-320 + i * 40, 0.3, 120 + (i % 3) * 5, 22)
end
local couleursParasol = { C.rose, C.cyan, C.orange, C.violet }
for i = 1, 8 do
	local x = -330 + i * 25
	local z = 85 + (i % 2) * 15
	bloc(dDecor, { Name = "MatParasol", Size = Vector3.new(0.4, 8, 0.4), CFrame = CFrame.new(x, 4.3, z), Color = C.blanc })
	bloc(dDecor, {
		Name = "Parasol",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 9, 9),
		CFrame = CFrame.new(x, 8.3, z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = couleursParasol[(i % #couleursParasol) + 1],
		CanCollide = false,
	})
end

---------------------------------------------------------------------------
-- 3. LA RUE DES BOUTIQUES (Little Mango)
---------------------------------------------------------------------------
local boutiques = {
	{ nom = "CandyMango", enseigne = "CANDY MANGO", x = -60, mur = Color3.fromRGB(255, 190, 90), neon = C.rose },
	{ nom = "GatorMart", enseigne = "GATOR MART", x = 0, mur = Color3.fromRGB(120, 210, 160), neon = C.cyan },
	{ nom = "NeonDonuts", enseigne = "NEON DONUTS", x = 60, mur = Color3.fromRGB(190, 150, 255), neon = C.orange },
}

for _, b in ipairs(boutiques) do
	local cf = CFrame.new(b.x, 0, -45)
	local m = batiment(b.nom, dRue, cf, 40, 30, 20, b.mur, b.neon, b.enseigne)
	m:SetAttribute("Boutique", true)

	-- La caisse : on reste 5 secondes pour faire le coup
	local caisse = bloc(m, {
		Name = "Caisse",
		Size = Vector3.new(10, 4, 3),
		CFrame = cf * CFrame.new(0, 2, -5),
		Color = b.neon,
		Material = Enum.Material.SmoothPlastic,
	})
	caisse:SetAttribute("Boutique", b.nom)
	bouton(caisse, "Faire le coup", b.enseigne, 5)

	-- Étagères de bonbons (décor)
	for i = -1, 1 do
		bloc(m, {
			Name = "Etagere",
			Size = Vector3.new(8, 6, 2),
			CFrame = cf * CFrame.new(i * 12, 3, -12),
			Color = b.mur:Lerp(C.blanc, 0.4),
		})
	end

	silhouette("Vendeur", m, cf * CFrame.new(0, 0, -8.5), b.mur, "Vendeur")
end

-- Affiches « Recherché » le long du trottoir (vides au départ)
for i, x in ipairs({ -90, -30, 30, 90 }) do
	local affiche = modele("Affiche" .. i, dAffiches)
	bloc(affiche, {
		Name = "Poteau",
		Size = Vector3.new(0.6, 10, 0.6),
		CFrame = CFrame.new(x, 5, -24),
		Color = C.noir,
		Material = Enum.Material.Metal,
	})
	local panneau = bloc(affiche, {
		Name = "Panneau",
		Size = Vector3.new(6, 8, 0.4),
		CFrame = CFrame.new(x, 9, -23.5),
		Color = Color3.fromRGB(245, 225, 180),
	})
	affiche.PrimaryPart = panneau

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Affichage"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = panneau

	local haut = Instance.new("TextLabel")
	haut.Name = "Titre"
	haut.Size = UDim2.fromScale(1, 0.2)
	haut.BackgroundTransparency = 1
	haut.TextColor3 = Color3.fromRGB(200, 30, 30)
	haut.TextScaled = true
	haut.Font = Enum.Font.FredokaOne
	haut.Text = "RECHERCHÉ"
	haut.Parent = gui

	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.Position = UDim2.fromScale(0.1, 0.22)
	photo.Size = UDim2.fromScale(0.8, 0.55)
	photo.BackgroundColor3 = Color3.fromRGB(210, 190, 150)
	photo.Image = ""
	photo.Parent = gui

	local nom = Instance.new("TextLabel")
	nom.Name = "Nom"
	nom.Position = UDim2.fromScale(0, 0.8)
	nom.Size = UDim2.fromScale(1, 0.2)
	nom.BackgroundTransparency = 1
	nom.TextColor3 = C.noir
	nom.TextScaled = true
	nom.Font = Enum.Font.FredokaOne
	nom.Text = "???"
	nom.Parent = gui
end

-- Poste des Gardiens (côté sud de la route, porte vers la route)
local poste = batiment("PosteDesGardiens", dRue, CFrame.new(0, 0, 50) * CFrame.Angles(0, math.pi, 0),
	50, 30, 18, Color3.fromRGB(220, 230, 245), C.bleuGardien, "POSTE DES GARDIENS")

local spawnGardiens = Instance.new("SpawnLocation")
spawnGardiens.Name = "DepartGardiens"
spawnGardiens.Anchored = true
spawnGardiens.Size = Vector3.new(10, 1, 10)
spawnGardiens.CFrame = CFrame.new(0, 0.9, 50)
spawnGardiens.Color = C.bleuGardien
spawnGardiens.Material = Enum.Material.Neon
spawnGardiens.Neutral = false
spawnGardiens.TeamColor = BrickColor.new("Bright blue")
spawnGardiens.Duration = 0
spawnGardiens.Parent = poste

-- Palmiers et lampadaires le long de la rue
for x = -100, 60, 40 do
	palmier(x + 20, 0.6, -17, 16)
	palmier(x, 0.6, 17, 16)
end
for x = -335, 100, 30 do
	lampadaire(x, -16, C.rose)
	lampadaire(x + 10, 16, C.cyan)
end

---------------------------------------------------------------------------
-- 4. LE MARAIS (Gator Swamp)
---------------------------------------------------------------------------
terrain:FillBlock(CFrame.new(230, -8, -40), Vector3.new(240, 4, 400), Enum.Material.Mud)
terrain:FillBlock(CFrame.new(230, -3.5, -40), Vector3.new(240, 5, 400), Enum.Material.Water)

-- Ponton au bout de la route
bloc(dMarais, {
	Name = "Ponton",
	Size = Vector3.new(30, 1, 30),
	CFrame = CFrame.new(125, -0.5, 0),
	Color = C.bois,
	Material = Enum.Material.WoodPlanks,
})

-- Îlots
local function ilot(nom, x, z, taille)
	return bloc(dMarais, {
		Name = nom,
		Size = Vector3.new(taille, 8, taille),
		CFrame = CFrame.new(x, -4, z),
		Color = Color3.fromRGB(90, 130, 60),
		Material = Enum.Material.Grass,
	})
end
ilot("IlotPlanque", 300, -60, 44)
ilot("IlotGus", 200, 70, 30)
ilot("Ilot", 190, -110, 20)
ilot("Ilot", 280, 80, 18)
ilot("Ilot", 330, 40, 16)

-- La planque du duo (porte tournée vers le ponton)
local planque = batiment("Planque", dMarais, CFrame.new(300, 0, -60) * CFrame.Angles(0, -math.pi / 2, 0),
	26, 22, 12, C.bois, C.orange, "LA PLANQUE")
local depot = bloc(planque, {
	Name = "Depot",
	Size = Vector3.new(6, 3, 6),
	CFrame = CFrame.new(300, 1.5, -60),
	Color = Color3.fromRGB(255, 200, 40),
	Material = Enum.Material.Neon,
})
bouton(depot, "Déposer le butin", "Planque", 0)
for _, d in ipairs({ { 5, -7 }, { -5, -7 } }) do
	bloc(planque, {
		Name = "Vitrine",
		Size = Vector3.new(4, 5, 3),
		CFrame = CFrame.new(300 + d[1], 2.5, -60 + d[2]),
		Color = C.blanc,
		Material = Enum.Material.Glass,
		Transparency = 0.5,
	})
end

-- Don Flamingo (silhouette rose à remplacer)
silhouette("DonFlamingo", planque, CFrame.new(306, 0, -52), C.rose, "Don Flamingo")

-- Gus du marais et ses alligators
silhouette("Gus", dMarais, CFrame.new(200, 0, 70), Color3.fromRGB(150, 120, 70), "Gus du marais")

local function alligator(x, z, rot)
	local m = modele("Alligator", dMarais)
	local cf = CFrame.new(x, -0.9, z) * CFrame.Angles(0, rot, 0)
	local corps = bloc(m, { Name = "Corps", Size = Vector3.new(3, 1.4, 8), CFrame = cf, Color = C.alligator })
	bloc(m, { Name = "Tete", Size = Vector3.new(2.2, 1, 3.5), CFrame = cf * CFrame.new(0, -0.1, -5.5), Color = C.alligator })
	bloc(m, { Name = "Queue", Size = Vector3.new(1.2, 0.8, 5), CFrame = cf * CFrame.new(0, -0.2, 6.3), Color = C.alligator })
	for _, ox in ipairs({ -0.6, 0.6 }) do
		bloc(m, {
			Name = "Oeil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = cf * CFrame.new(ox, 0.55, -4.5),
			Color = Color3.fromRGB(255, 230, 60),
		})
	end
	m.PrimaryPart = corps
	return m
end
alligator(175, 100, math.rad(30))
alligator(230, 40, math.rad(-120))
alligator(250, -10, math.rad(90))
alligator(170, -80, math.rad(200))

-- Hydroglisseurs (à rendre pilotables plus tard)
local function hydroglisseur(x, z)
	local m = modele("Hydroglisseur", dMarais)
	local coque = bloc(m, {
		Name = "Coque",
		Size = Vector3.new(7, 1.2, 12),
		CFrame = CFrame.new(x, -0.6, z),
		Color = C.cyan,
	})
	bloc(m, { Name = "Siege", Size = Vector3.new(3, 2, 2), CFrame = CFrame.new(x, 0.9, z), Color = C.noir })
	bloc(m, {
		Name = "Ventilateur",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 7, 7),
		CFrame = CFrame.new(x, 3, z + 5) * CFrame.Angles(0, math.rad(90), 0),
		Color = C.noir,
		Material = Enum.Material.Metal,
	})
	m.PrimaryPart = coque
	return m
end
hydroglisseur(145, 20)
hydroglisseur(145, -20)

-- Roseaux
local hasard = Random.new(42)
for _ = 1, 120 do
	local x = hasard:NextNumber(140, 345)
	local z = hasard:NextNumber(-230, 150)
	local h = hasard:NextNumber(3, 7)
	bloc(dDecor, {
		Name = "Roseau",
		Size = Vector3.new(0.3, h, 0.3),
		CFrame = CFrame.new(x, -1 + h / 2, z) * CFrame.Angles(math.rad(hasard:NextNumber(-10, 10)), 0, math.rad(hasard:NextNumber(-10, 10))),
		Color = Color3.fromRGB(110, 150, 60),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

---------------------------------------------------------------------------
-- 4 bis. MUSCLE BEACH (salle de muscu en plein air, sur la plage)
--    Chaque appareil est un Model avec les attributs ForceRequise et Gain.
--    Le script MuscleService (ServerScriptService) s'en sert.
---------------------------------------------------------------------------
local dMuscle = dossier("MuscleBeach", dPlage)

bloc(dMuscle, {
	Name = "TapisDeSol",
	Size = Vector3.new(110, 0.4, 24),
	CFrame = CFrame.new(-290, 0.5, 68),
	Color = Color3.fromRGB(60, 60, 70),
	Material = Enum.Material.Rubber,
})

-- Arche d'entrée, tournée vers le point de départ des Malins
for _, dx in ipairs({ -20, 20 }) do
	bloc(dMuscle, {
		Name = "PilierArche",
		Size = Vector3.new(2, 14, 2),
		CFrame = CFrame.new(-290 + dx, 7, 57),
		Color = C.rose,
		Material = Enum.Material.Neon,
	})
end
local arche = bloc(dMuscle, {
	Name = "Arche",
	Size = Vector3.new(42, 5, 1),
	CFrame = CFrame.new(-290, 16, 57),
	Color = C.noir,
})
texteSurFace(arche, Enum.NormalId.Front, "MUSCLE BEACH", C.orange)

local appareils = {
	{ nom = "Halteres", texte = "Haltères", requise = 0, gain = 1, action = "Soulever", x = -330, couleur = C.cyan },
	{ nom = "SacDeFrappe", texte = "Sac de frappe", requise = 50, gain = 3, action = "Frapper", x = -310, couleur = Color3.fromRGB(220, 50, 50) },
	{ nom = "TapisDeCourse", texte = "Tapis de course", requise = 200, gain = 6, action = "Courir", x = -290, couleur = C.menthe },
	{ nom = "DeveloppeCouche", texte = "Développé couché", requise = 800, gain = 15, action = "Pousser", x = -270, couleur = C.violet },
	{ nom = "LeMonstre", texte = "LE MONSTRE", requise = 3000, gain = 40, action = "Soulever", x = -250, couleur = C.orange },
}

for _, a in ipairs(appareils) do
	local m = modele(a.nom, dMuscle)
	m:SetAttribute("ForceRequise", a.requise)
	m:SetAttribute("Gain", a.gain)
	local base = CFrame.new(a.x, 0.7, 70)
	local principal

	if a.nom == "Halteres" then
		principal = bloc(m, { Name = "Banc", Size = Vector3.new(3, 2, 6), CFrame = base * CFrame.new(0, 1, 0), Color = C.noir })
		for _, dx in ipairs({ -3, 3 }) do
			bloc(m, { Name = "Barre", Size = Vector3.new(0.4, 0.4, 2), CFrame = base * CFrame.new(dx, 0.4, -4), Color = C.trottoir, Material = Enum.Material.Metal })
			for _, dz in ipairs({ -1, 1 }) do
				bloc(m, { Name = "Poids", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = base * CFrame.new(dx, 0.6, -4 + dz), Color = a.couleur })
			end
		end
	elseif a.nom == "SacDeFrappe" then
		bloc(m, { Name = "Potence", Size = Vector3.new(0.6, 12, 0.6), CFrame = base * CFrame.new(-3, 6, 0), Color = C.noir, Material = Enum.Material.Metal })
		bloc(m, { Name = "Bras", Size = Vector3.new(4, 0.6, 0.6), CFrame = base * CFrame.new(-1, 11.7, 0), Color = C.noir, Material = Enum.Material.Metal })
		principal = bloc(m, {
			Name = "Sac",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 3, 3),
			CFrame = base * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = a.couleur,
			Material = Enum.Material.Fabric,
		})
	elseif a.nom == "TapisDeCourse" then
		principal = bloc(m, { Name = "Tapis", Size = Vector3.new(4, 1, 9), CFrame = base * CFrame.new(0, 0.5, 0), Color = C.noir })
		bloc(m, { Name = "Rail", Size = Vector3.new(0.4, 4, 0.4), CFrame = base * CFrame.new(-2, 3, -4), Color = a.couleur, Material = Enum.Material.Neon })
		bloc(m, { Name = "Rail", Size = Vector3.new(0.4, 4, 0.4), CFrame = base * CFrame.new(2, 3, -4), Color = a.couleur, Material = Enum.Material.Neon })
		bloc(m, { Name = "Console", Size = Vector3.new(4.4, 1.5, 0.6), CFrame = base * CFrame.new(0, 5, -4), Color = C.noir })
	else
		-- Développé couché et Le Monstre : banc + barre avec disques
		local geant = (a.nom == "LeMonstre")
		local largeurBarre = geant and 14 or 9
		local disque = geant and 6 or 3
		principal = bloc(m, { Name = "Banc", Size = Vector3.new(3, 2, 7), CFrame = base * CFrame.new(0, 1, 0), Color = C.noir })
		for _, dx in ipairs({ -1.5, 1.5 }) do
			bloc(m, { Name = "Support", Size = Vector3.new(0.4, 5, 0.4), CFrame = base * CFrame.new(dx, 2.5, -3), Color = C.trottoir, Material = Enum.Material.Metal })
		end
		bloc(m, {
			Name = "Barre",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(largeurBarre, 0.5, 0.5),
			CFrame = base * CFrame.new(0, 5, -3),
			Color = C.trottoir,
			Material = Enum.Material.Metal,
		})
		for _, dx in ipairs({ -largeurBarre / 2 + 1, largeurBarre / 2 - 1 }) do
			bloc(m, {
				Name = "Disque",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(geant and 1.5 or 0.8, disque, disque),
				CFrame = base * CFrame.new(dx, 5, -3),
				Color = a.couleur,
				Material = geant and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			})
		end
	end

	m.PrimaryPart = principal
	local prompt = bouton(principal, a.action, a.texte, 0)
	prompt.Name = "Entrainement"
	local texteRequis = (a.requise == 0) and "pour tous" or ("dès " .. a.requise .. " de force")
	etiquette(principal, a.texte .. " : +" .. a.gain .. " (" .. texteRequis .. ")", a.couleur)
end

---------------------------------------------------------------------------
-- 5. ÉQUIPES
---------------------------------------------------------------------------
for _, nom in ipairs({ "Malins", "Gardiens" }) do
	local t = Teams:FindFirstChild(nom)
	if t then t:Destroy() end
end
local malins = Instance.new("Team")
malins.Name = "Malins"
malins.TeamColor = BrickColor.new("Deep orange")
malins.AutoAssignable = true
malins.Parent = Teams

local gardiens = Instance.new("Team")
gardiens.Name = "Gardiens"
gardiens.TeamColor = BrickColor.new("Bright blue")
gardiens.AutoAssignable = true
gardiens.Parent = Teams

---------------------------------------------------------------------------
-- 6. ÉCLAIRAGE : COUCHER DE SOLEIL NÉON
---------------------------------------------------------------------------
Lighting.ClockTime = 18.1
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(90, 70, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(170, 120, 140)
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6

for _, nom in ipairs({ "NeonBayAtmosphere", "NeonBayCouleurs", "NeonBayBloom" }) do
	local e = Lighting:FindFirstChild(nom)
	if e then e:Destroy() end
end

local atmo = Instance.new("Atmosphere")
atmo.Name = "NeonBayAtmosphere"
atmo.Density = 0.3
atmo.Offset = 0.2
atmo.Color = Color3.fromRGB(255, 170, 160)
atmo.Decay = Color3.fromRGB(150, 90, 160)
atmo.Glare = 0.4
atmo.Haze = 1.5
atmo.Parent = Lighting

local couleurs = Instance.new("ColorCorrectionEffect")
couleurs.Name = "NeonBayCouleurs"
couleurs.Saturation = 0.25
couleurs.Contrast = 0.08
couleurs.TintColor = Color3.fromRGB(255, 235, 240)
couleurs.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Name = "NeonBayBloom"
bloom.Intensity = 0.8
bloom.Size = 30
bloom.Threshold = 0.9
bloom.Parent = Lighting

pcall(function() ChangeHistoryService:SetWaypoint("Neon Bay généré") end)
print("Neon Bay est prêt ! Regarde dans Workspace > NeonBay. (Ctrl+Z pour annuler)")
