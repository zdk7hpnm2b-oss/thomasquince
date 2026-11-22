--[[
	MallDriftServer  (Script)
	À placer dans : ServerScriptService   — nom conseillé : MallDriftServer

	Ce script construit automatiquement, au lancement du jeu :
	  • le niveau 1 « Le Petit Marché » (rayons, caisses, frigos, fruits…)
	  • les zones de sol mouillé avec les panneaux jaunes « ATTENTION SOL GLISSANT »
	  • des cartons « PROMO » qu'on peut renverser
	  • les karts garés à l'entrée (on monte dedans avec la touche E ou en s'asseyant)
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))

Config.AppliquerAmbiance(Config.NuitParDefaut)

-- Un peu de "bloom" pour que les néons brillent joliment
if not Lighting:FindFirstChildOfClass("BloomEffect") then
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
end
if not Lighting:FindFirstChild("CouleursMallDrift") then
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CouleursMallDrift"
	cc.Saturation = 0.12
	cc.Contrast = 0.05
	cc.Parent = Lighting
end

local niveau = Instance.new("Folder")
niveau.Name = "Niveau1_LePetitMarche"
niveau.Parent = workspace

local random = Random.new(42) -- toujours le même magasin à chaque partie

---------------------------------------------------------------------
-- Petits outils de construction
---------------------------------------------------------------------
local function bloc(nom: string, taille: Vector3, cf: CFrame, couleur: Color3, matiere: Enum.Material?, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.CFrame = cf
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or niveau
	return p
end

local function deco(p: BasePart): BasePart
	-- Élément purement décoratif : on ne le percute pas
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function texte(part: BasePart, face: Enum.NormalId, txt: string, couleurTexte: Color3?, fond: Color3?): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence = 0 -- le texte reste lisible la nuit
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = fond and 0 or 1
	l.BackgroundColor3 = fond or Color3.new(0, 0, 0)
	l.TextColor3 = couleurTexte or Color3.new(1, 1, 1)
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.Text = txt
	l.Parent = sg
	return l
end

-- Une pancarte dont la face avant regarde dans la direction "versOu"
local function pancarte(nom: string, taille: Vector3, position: Vector3, versOu: Vector3, txt: string, couleur: Color3, couleurTexte: Color3?, doubleFace: boolean?)
	local p = bloc(nom, taille, CFrame.lookAt(position, position + versOu), couleur, Enum.Material.SmoothPlastic)
	deco(p)
	texte(p, Enum.NormalId.Front, txt, couleurTexte)
	if doubleFace then
		texte(p, Enum.NormalId.Back, txt, couleurTexte)
	end
	return p
end

local SOL = 1 -- hauteur du dessus du sol
local LARGEUR, PROFONDEUR = 180, 140 -- taille du magasin (X, Z)
local HAUTEUR_MURS = 16

local BLANC = Color3.fromRGB(240, 240, 235)
local GRIS = Color3.fromRGB(120, 125, 135)
local GRIS_CLAIR = Color3.fromRGB(190, 195, 200)

---------------------------------------------------------------------
-- Sol, murs, plafond vitré, lumières
---------------------------------------------------------------------
local sol = bloc("Sol", Vector3.new(LARGEUR, 1, PROFONDEUR), CFrame.new(0, SOL - 0.5, 0), Color3.fromRGB(230, 226, 214), Enum.Material.Marble)
sol.Reflectance = 0.12

local demiX, demiZ = LARGEUR / 2, PROFONDEUR / 2
local yMur = SOL + HAUTEUR_MURS / 2
bloc("MurFond", Vector3.new(LARGEUR + 4, HAUTEUR_MURS, 2), CFrame.new(0, yMur, -demiZ - 1), BLANC)
bloc("MurGauche", Vector3.new(2, HAUTEUR_MURS, PROFONDEUR), CFrame.new(-demiX - 1, yMur, 0), BLANC)
bloc("MurDroit", Vector3.new(2, HAUTEUR_MURS, PROFONDEUR), CFrame.new(demiX + 1, yMur, 0), BLANC)

-- Façade avant : murs + grande vitrine au milieu
local largeurVitrine = 30
local largeurCote = (LARGEUR + 4 - largeurVitrine) / 2
bloc("FacadeGauche", Vector3.new(largeurCote, HAUTEUR_MURS, 2), CFrame.new(-(largeurVitrine / 2 + largeurCote / 2), yMur, demiZ + 1), BLANC)
bloc("FacadeDroite", Vector3.new(largeurCote, HAUTEUR_MURS, 2), CFrame.new(largeurVitrine / 2 + largeurCote / 2, yMur, demiZ + 1), BLANC)
local vitrine = bloc("PortesVitrees", Vector3.new(largeurVitrine, HAUTEUR_MURS, 1), CFrame.new(0, yMur, demiZ + 1), Color3.fromRGB(170, 205, 230), Enum.Material.Glass)
vitrine.Transparency = 0.55

-- Plafond vitré (laisse passer le jour ou la lune)
local plafond = bloc("PlafondVitre", Vector3.new(LARGEUR + 4, 1, PROFONDEUR + 4), CFrame.new(0, SOL + HAUTEUR_MURS + 2.5, 0), Color3.fromRGB(200, 220, 235), Enum.Material.Glass)
plafond.Transparency = 0.82
plafond.CastShadow = false
deco(plafond)

-- Grand logo du magasin au fond
pancarte("Logo", Vector3.new(70, 7, 0.5), Vector3.new(0, SOL + 12.5, -demiZ + 0.3), Vector3.new(0, 0, 1), "LE PETIT MARCHÉ", Color3.fromRGB(220, 40, 50), Color3.new(1, 1, 1))

-- Néons au plafond
local lampes = Instance.new("Folder")
lampes.Name = "Lampes"
lampes.Parent = niveau
for x = -75, 75, 25 do
	for z = -60, 60, 30 do
		local neon = bloc("Neon", Vector3.new(10, 0.3, 1.5), CFrame.new(x, SOL + HAUTEUR_MURS + 1.5, z), Color3.fromRGB(255, 252, 240), Enum.Material.Neon, lampes)
		deco(neon)
		neon.CastShadow = false
		local lumiere = Instance.new("PointLight")
		lumiere.Range = 30
		lumiere.Brightness = 1.3
		lumiere.Color = Color3.fromRGB(255, 245, 225)
		lumiere.Parent = neon
	end
end

---------------------------------------------------------------------
-- Les rayons (les allées étroites, parfaites pour drifter)
---------------------------------------------------------------------
local COULEURS_PRODUITS = {
	Color3.fromRGB(230, 60, 60), Color3.fromRGB(250, 170, 40), Color3.fromRGB(250, 220, 60),
	Color3.fromRGB(80, 180, 90), Color3.fromRGB(60, 130, 220), Color3.fromRGB(150, 90, 200),
	Color3.fromRGB(240, 120, 170), Color3.fromRGB(245, 245, 245), Color3.fromRGB(140, 90, 60),
}
local NOMS_RAYONS = { "BOISSONS", "BONBONS", "CÉRÉALES", "GOÛTERS", "PÂTES & RIZ", "SURGELÉS", "HYGIÈNE", "JOUETS" }

local RAYON_LONGUEUR, RAYON_CENTRE_Z = 50, -15
local rayonsX = { -72, -54, -36, -18, 18, 36, 54, 72 }

for i, x in ipairs(rayonsX) do
	local dossier = Instance.new("Model")
	dossier.Name = "Rayon_" .. NOMS_RAYONS[i]
	dossier.Parent = niveau

	-- Bloc invisible qui sert de "mur" pour les collisions (plus fluide pour le kart)
	local collision = bloc("Collision", Vector3.new(4, 9, RAYON_LONGUEUR), CFrame.new(x, SOL + 4.5, RAYON_CENTRE_Z), GRIS, nil, dossier)
	collision.Transparency = 1

	deco(bloc("Socle", Vector3.new(4, 0.6, RAYON_LONGUEUR), CFrame.new(x, SOL + 0.3, RAYON_CENTRE_Z), GRIS, Enum.Material.Metal, dossier))
	deco(bloc("Fond", Vector3.new(0.4, 9, RAYON_LONGUEUR), CFrame.new(x, SOL + 4.5, RAYON_CENTRE_Z), GRIS_CLAIR, Enum.Material.Metal, dossier))

	for _, hauteur in ipairs({ 0.6, 3.3, 6.0 }) do
		deco(bloc("Etagere", Vector3.new(4, 0.25, RAYON_LONGUEUR), CFrame.new(x, SOL + hauteur, RAYON_CENTRE_Z), GRIS_CLAIR, Enum.Material.Metal, dossier))
		-- Produits colorés posés sur l'étagère
		for z = RAYON_CENTRE_Z - RAYON_LONGUEUR / 2 + 2.5, RAYON_CENTRE_Z + RAYON_LONGUEUR / 2 - 2.5, 5 do
			local couleur = COULEURS_PRODUITS[random:NextInteger(1, #COULEURS_PRODUITS)]
			local hauteurProduit = random:NextNumber(1.2, 2.2)
			deco(bloc("Produits", Vector3.new(3.6, hauteurProduit, 4.6), CFrame.new(x, SOL + hauteur + 0.125 + hauteurProduit / 2, z), couleur, Enum.Material.SmoothPlastic, dossier))
		end
	end

	-- Panneau suspendu au bout du rayon (côté caisses)
	pancarte("PanneauRayon", Vector3.new(12, 2.5, 0.3), Vector3.new(x, SOL + 13, RAYON_CENTRE_Z + RAYON_LONGUEUR / 2), Vector3.new(0, 0, 1), NOMS_RAYONS[i], Color3.fromRGB(30, 120, 70), Color3.new(1, 1, 1), true).Parent = dossier
end

---------------------------------------------------------------------
-- Les frigos du fond + les étals de fruits
---------------------------------------------------------------------
bloc("Frigos", Vector3.new(LARGEUR - 10, 8, 3), CFrame.new(0, SOL + 4, -demiZ + 1.5), BLANC, Enum.Material.SmoothPlastic)
local vitreFrigo = bloc("VitreFrigos", Vector3.new(LARGEUR - 10, 6, 0.2), CFrame.new(0, SOL + 4, -demiZ + 3.1), Color3.fromRGB(150, 200, 240), Enum.Material.Glass)
vitreFrigo.Transparency = 0.4
deco(vitreFrigo)
deco(bloc("NeonFrigos", Vector3.new(LARGEUR - 10, 0.4, 0.4), CFrame.new(0, SOL + 7.6, -demiZ + 3.2), Color3.fromRGB(90, 190, 255), Enum.Material.Neon))
pancarte("PanneauFrais", Vector3.new(24, 3, 0.4), Vector3.new(45, SOL + 10, -demiZ + 0.4), Vector3.new(0, 0, 1), "PRODUITS FRAIS", Color3.fromRGB(40, 120, 200))

local FRUITS = { Color3.fromRGB(255, 150, 30), Color3.fromRGB(200, 30, 40), Color3.fromRGB(120, 200, 60), Color3.fromRGB(250, 220, 50) }
for i, x in ipairs({ -75, -20, 20, 75 }) do
	local etal = Instance.new("Model")
	etal.Name = "EtalFruits"
	etal.Parent = niveau
	bloc("Cagette", Vector3.new(8, 2.5, 5), CFrame.new(x, SOL + 1.25, -52), Color3.fromRGB(170, 120, 70), Enum.Material.WoodPlanks, etal)
	for n = 1, 8 do
		local fruit = bloc("Fruit", Vector3.new(1.2, 1.2, 1.2), CFrame.new(x - 3 + (n - 1) % 4 * 2, SOL + 3.1, -53 + (n > 4 and 2 or 0)), FRUITS[i], Enum.Material.SmoothPlastic, etal)
		fruit.Shape = Enum.PartType.Ball
		deco(fruit)
	end
end

---------------------------------------------------------------------
-- Les caisses (près de l'entrée)
---------------------------------------------------------------------
for n, x in ipairs({ -62, -44, -26, 26, 44, 62 }) do
	local caisse = Instance.new("Model")
	caisse.Name = "Caisse" .. n
	caisse.Parent = niveau
	bloc("Comptoir", Vector3.new(3, 3.2, 12), CFrame.new(x, SOL + 1.6, 38), Color3.fromRGB(60, 65, 75), Enum.Material.SmoothPlastic, caisse)
	deco(bloc("TapisRoulant", Vector3.new(2.6, 0.2, 8), CFrame.new(x, SOL + 3.3, 36), Color3.fromRGB(25, 25, 25), Enum.Material.Fabric, caisse))
	deco(bloc("Poteau", Vector3.new(0.3, 5, 0.3), CFrame.new(x, SOL + 5.7, 43.5), GRIS_CLAIR, Enum.Material.Metal, caisse))
	local numero = bloc("Numero", Vector3.new(2, 1.4, 0.3), CFrame.new(x, SOL + 8.9, 43.5), Color3.fromRGB(230, 40, 50), Enum.Material.Neon, caisse)
	deco(numero)
	texte(numero, Enum.NormalId.Front, tostring(n))
	texte(numero, Enum.NormalId.Back, tostring(n))
end

---------------------------------------------------------------------
-- Palettes PROMO avec des cartons qu'on peut renverser (c'est drôle !)
---------------------------------------------------------------------
local function palettePromo(position: Vector3)
	bloc("Palette", Vector3.new(6, 0.5, 6), CFrame.new(position + Vector3.new(0, SOL + 0.25, 0)), Color3.fromRGB(190, 150, 100), Enum.Material.WoodPlanks)
	local etages = { { -1.5, -1.5 }, { 1.5, -1.5 }, { -1.5, 1.5 }, { 1.5, 1.5 } }
	for etage = 0, 2 do
		for i, xz in ipairs(etages) do
			if etage == 2 and i > 1 then
				break -- un seul carton tout en haut
			end
			local carton = bloc("Carton", Vector3.new(2.8, 2.8, 2.8), CFrame.new(position + Vector3.new(etage == 2 and 0 or xz[1], SOL + 0.5 + 1.4 + etage * 2.8, etage == 2 and 0 or xz[2])), Color3.fromRGB(200, 160, 110), Enum.Material.Cardboard)
			carton.Anchored = false
			carton.CustomPhysicalProperties = PhysicalProperties.new(0.25, 0.5, 0.2)
		end
	end
	pancarte("PanneauPromo", Vector3.new(6, 2.5, 0.3), position + Vector3.new(0, SOL + 11, 0), Vector3.new(0, 0, 1), "PROMO -50%", Color3.fromRGB(255, 210, 0), Color3.fromRGB(200, 20, 20), true)
end
palettePromo(Vector3.new(-45, 0, 22))
palettePromo(Vector3.new(45, 0, 22))

---------------------------------------------------------------------
-- SOL MOUILLÉ + panneaux jaunes « ATTENTION SOL GLISSANT »
---------------------------------------------------------------------
local COULEUR_EAU = Color3.fromRGB(110, 170, 225)

local function flaque(centre: Vector3, tailleX: number, tailleZ: number)
	local zone = Instance.new("Model")
	zone.Name = "SolMouille"
	zone.Parent = niveau

	local function morceau(p: BasePart)
		p.Transparency = 0.4
		p.Reflectance = 0.25
		p.CanCollide = false -- on roule dessus sans bosse
		p.CanTouch = false
		p.CastShadow = false
		p:SetAttribute("Mouille", true) -- le kart détecte cet attribut
	end

	morceau(bloc("Eau", Vector3.new(tailleX, 0.1, tailleZ), CFrame.new(centre.X, SOL + 0.06, centre.Z), COULEUR_EAU, Enum.Material.Glass, zone))
	-- Quelques flaques rondes autour pour un bord plus naturel
	for _ = 1, 4 do
		local d = random:NextNumber(4, 8)
		local px = centre.X + random:NextNumber(-tailleX / 2, tailleX / 2)
		local pz = centre.Z + random:NextNumber(-tailleZ / 2, tailleZ / 2)
		local rond = bloc("EauRonde", Vector3.new(0.1, d, d), CFrame.new(px, SOL + 0.07, pz) * CFrame.Angles(0, 0, math.rad(90)), COULEUR_EAU, Enum.Material.Glass, zone)
		rond.Shape = Enum.PartType.Cylinder
		morceau(rond)
	end
end

-- Panneau jaune en "A", qu'on peut renverser en le percutant
local function panneauJaune(position: Vector3, versOu: Vector3)
	local modele = Instance.new("Model")
	modele.Name = "PanneauSolGlissant"
	local base = CFrame.lookAt(position, position + versOu)
	local jaune = Color3.fromRGB(255, 205, 0)

	local devant = bloc("Devant", Vector3.new(2.4, 3.4, 0.15), base * CFrame.new(0, SOL + 1.7, -0.45) * CFrame.Angles(math.rad(15), 0, 0), jaune, Enum.Material.SmoothPlastic, modele)
	local derriere = bloc("Derriere", Vector3.new(2.4, 3.4, 0.15), base * CFrame.new(0, SOL + 1.7, 0.45) * CFrame.Angles(math.rad(-15), 0, 0), jaune, Enum.Material.SmoothPlastic, modele)
	texte(devant, Enum.NormalId.Front, "⚠\nATTENTION\nSOL GLISSANT", Color3.fromRGB(20, 20, 20))
	texte(derriere, Enum.NormalId.Back, "⚠\nATTENTION\nSOL GLISSANT", Color3.fromRGB(20, 20, 20))

	for _, p in ipairs({ devant, derriere }) do
		p.Anchored = false
		p.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.4, 0.3)
	end
	local soudure = Instance.new("WeldConstraint")
	soudure.Part0 = devant
	soudure.Part1 = derriere
	soudure.Parent = devant
	modele.PrimaryPart = devant
	modele.Parent = niveau
end

-- Seau + serpillière (le coupable !)
local function seau(position: Vector3)
	local s = bloc("Seau", Vector3.new(2, 1.8, 1.8), CFrame.new(position.X, SOL + 1, position.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 200, 0), Enum.Material.SmoothPlastic)
	s.Shape = Enum.PartType.Cylinder
	deco(bloc("Manche", Vector3.new(0.2, 6, 0.2), CFrame.new(position.X + 0.6, SOL + 3.5, position.Z) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(80, 140, 230), Enum.Material.SmoothPlastic))
end

-- Zone 1 : au milieu de l'allée centrale
flaque(Vector3.new(0, 0, -15), 18, 22)
panneauJaune(Vector3.new(7, 0, -2), Vector3.new(0, 0, 1))
panneauJaune(Vector3.new(-7, 0, -28), Vector3.new(0, 0, -1))
seau(Vector3.new(11, 0, -4))

-- Zone 2 : le frigo du fond qui fuit
flaque(Vector3.new(-48, 0, -58), 24, 10)
panneauJaune(Vector3.new(-34, 0, -58), Vector3.new(1, 0, 0))
panneauJaune(Vector3.new(-62, 0, -58), Vector3.new(-1, 0, 0))

-- Zone 3 : dans un rayon étroit (pour les pros)
flaque(Vector3.new(27, 0, -20), 9, 16)
panneauJaune(Vector3.new(30, 0, -6), Vector3.new(0, 0, 1))
panneauJaune(Vector3.new(24, 0, -34), Vector3.new(0, 0, -1))

---------------------------------------------------------------------
-- LES KARTS
---------------------------------------------------------------------
local function construireKart(typeKart: string, cf: CFrame): Model
	local stats = Config.Karts[typeKart]
	local modele = Instance.new("Model")
	modele.Name = "Kart_" .. typeKart
	modele:SetAttribute("KartType", typeKart)
	modele.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	-- Le châssis : la seule pièce qui touche le sol. Friction 0 : c'est le script
	-- du joueur qui gère la glisse, pas le moteur physique.
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(4, 0.8, 6)
	chassis.CFrame = cf
	chassis.Color = stats.Couleur
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Parent = modele
	modele.PrimaryPart = chassis

	local function piece(nom: string, taille: Vector3, decalage: CFrame, couleur: Color3, matiere: Enum.Material?, forme: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = nom
		p.Size = taille
		p.CFrame = chassis.CFrame * decalage
		p.Color = couleur
		p.Material = matiere or Enum.Material.SmoothPlastic
		p.Shape = forme or Enum.PartType.Block
		p.CanCollide = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local w = Instance.new("WeldConstraint")
		w.Part0 = chassis
		w.Part1 = p
		w.Parent = p
		p.Parent = modele
		return p
	end

	local NOIR = Color3.fromRGB(25, 25, 25)
	local OR = Color3.fromRGB(230, 180, 40)
	local ROUE = CFrame.Angles(0, 0, 0) -- les cylindres Roblox sont couchés sur l'axe X : parfait pour des roues

	-- Roues avant (grandes) et roues arrière pivotantes (petites, comme dans la vidéo)
	piece("RoueAVG", Vector3.new(0.8, 1.6, 1.6), CFrame.new(-2.2, 0.2, -2.3) * ROUE, NOIR, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece("RoueAVD", Vector3.new(0.8, 1.6, 1.6), CFrame.new(2.2, 0.2, -2.3) * ROUE, NOIR, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece("RoueARG", Vector3.new(0.6, 1.1, 1.1), CFrame.new(-1.9, -0.05, 2.5) * ROUE, OR, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece("RoueARD", Vector3.new(0.6, 1.1, 1.1), CFrame.new(1.9, -0.05, 2.5) * ROUE, OR, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)

	piece("PareChoc", Vector3.new(4.6, 0.5, 0.6), CFrame.new(0, 0, -3.2), NOIR)
	piece("Colonne", Vector3.new(0.3, 0.3, 2), CFrame.new(0, 1.1, -1.6) * CFrame.Angles(math.rad(35), 0, 0), GRIS)
	piece("Volant", Vector3.new(0.2, 1.7, 1.7), CFrame.new(0, 1.7, -0.9) * CFrame.Angles(math.rad(-35), math.rad(90), 0), OR, Enum.Material.Metal, Enum.PartType.Cylinder)
	piece("Dossier", Vector3.new(2.4, 2, 0.4), CFrame.new(0, 1.6, 2.2) * CFrame.Angles(math.rad(-10), 0, 0), NOIR, Enum.Material.Fabric)

	-- Le siège (on s'assoit dedans)
	local siege = Instance.new("Seat")
	siege.Name = "Siege"
	siege.Size = Vector3.new(2.4, 0.6, 2.2)
	siege.CFrame = chassis.CFrame * CFrame.new(0, 0.7, 1)
	siege.Color = NOIR
	siege.Material = Enum.Material.Fabric
	siege.CanCollide = false
	siege.Massless = true
	local ws = Instance.new("WeldConstraint")
	ws.Part0 = chassis
	ws.Part1 = siege
	ws.Parent = siege
	siege.Parent = modele

	-- Garde le kart à plat (il peut tourner sur lui-même, mais pas se retourner)
	local attRedresse = Instance.new("Attachment")
	attRedresse.Name = "Redresse"
	attRedresse.CFrame = CFrame.Angles(0, 0, math.rad(90)) -- l'axe principal pointe vers le haut
	attRedresse.Parent = chassis
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attRedresse
	align.AlignType = Enum.AlignType.PrimaryAxisParallel
	align.PrimaryAxis = Vector3.yAxis
	align.MaxTorque = 1e6
	align.Responsiveness = 30
	align.Parent = chassis

	-- Effets : traces de pneus, fumée de gomme, gerbes d'eau
	for _, cote in ipairs({ -1.9, 1.9 }) do
		local a0 = Instance.new("Attachment")
		a0.Name = "Trace0"
		a0.Position = Vector3.new(cote - 0.3, -0.38, 2.6)
		a0.Parent = chassis
		local a1 = Instance.new("Attachment")
		a1.Name = "Trace1"
		a1.Position = Vector3.new(cote + 0.3, -0.38, 2.6)
		a1.Parent = chassis
		local trace = Instance.new("Trail")
		trace.Name = "TracePneu"
		trace.Attachment0 = a0
		trace.Attachment1 = a1
		trace.Color = ColorSequence.new(Color3.fromRGB(30, 30, 30))
		trace.Transparency = NumberSequence.new(0.45, 1)
		trace.Lifetime = 4
		trace.LightInfluence = 1
		trace.Enabled = false
		trace.Parent = chassis

		local attEffet = Instance.new("Attachment")
		attEffet.Name = "EffetRoue"
		attEffet.Position = Vector3.new(cote, -0.3, 2.6)
		attEffet.Parent = chassis

		local fumee = Instance.new("ParticleEmitter")
		fumee.Name = "Fumee"
		fumee.Color = ColorSequence.new(Color3.fromRGB(215, 215, 215))
		fumee.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3) })
		fumee.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		fumee.Lifetime = NumberRange.new(0.6, 1.1)
		fumee.Speed = NumberRange.new(1, 3)
		fumee.SpreadAngle = Vector2.new(40, 40)
		fumee.Rate = 35
		fumee.Enabled = false
		fumee.Parent = attEffet

		local eau = Instance.new("ParticleEmitter")
		eau.Name = "Eclaboussures"
		eau.Color = ColorSequence.new(Color3.fromRGB(190, 225, 255))
		eau.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
		eau.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		eau.Lifetime = NumberRange.new(0.3, 0.6)
		eau.Speed = NumberRange.new(8, 14)
		eau.SpreadAngle = Vector2.new(50, 50)
		eau.Acceleration = Vector3.new(0, -60, 0)
		eau.EmissionDirection = Enum.NormalId.Top
		eau.Rate = 80
		eau.Enabled = false
		eau.Parent = attEffet
	end

	-- Bouton « Conduire » (touche E sur PC, bouton à l'écran sur mobile)
	local invite = Instance.new("ProximityPrompt")
	invite.ActionText = "Conduire"
	invite.ObjectText = stats.Nom
	invite.HoldDuration = 0
	invite.MaxActivationDistance = 10
	invite.RequiresLineOfSight = false
	invite.Parent = siege

	invite.Triggered:Connect(function(joueur: Player)
		if siege.Occupant then
			return
		end
		local perso = joueur.Character
		local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
		if humanoide and humanoide.Health > 0 and not humanoide.SeatPart then
			siege:Sit(humanoide)
		end
	end)

	-- Le joueur assis prend le contrôle physique du kart (conduite fluide, sans lag)
	siege:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoide = siege.Occupant
		if humanoide then
			invite.Enabled = false
			local joueur = Players:GetPlayerFromCharacter(humanoide.Parent)
			if joueur then
				pcall(function()
					chassis:SetNetworkOwner(joueur)
				end)
			end
		else
			invite.Enabled = true
			pcall(function()
				chassis:SetNetworkOwnershipAuto()
			end)
		end
	end)

	modele.Parent = niveau
	return modele
end

-- Les karts garés à l'entrée, face aux rayons
local xKarts = { -24, -8, 8, 24 }
for i, typeKart in ipairs(Config.OrdreKarts) do
	local x = xKarts[i] or (i * 10 - 40)
	construireKart(typeKart, CFrame.new(x, SOL + 0.45, 56))
end

-- Point d'apparition des joueurs (à l'entrée)
local apparition = Instance.new("SpawnLocation")
apparition.Name = "Entree"
apparition.Size = Vector3.new(10, 0.4, 6)
apparition.CFrame = CFrame.new(0, SOL + 0.2, 64)
apparition.Anchored = true
apparition.Neutral = true
apparition.Duration = 0
apparition.Color = Color3.fromRGB(230, 40, 50)
apparition.Material = Enum.Material.SmoothPlastic
apparition.TopSurface = Enum.SurfaceType.Smooth
apparition.Parent = niveau

print("[Mall Drift] Niveau 1 « Le Petit Marché » construit, " .. #Config.OrdreKarts .. " karts prêts !")
