--[[
	MallDriftServer  (Script)
	À placer dans : ServerScriptService   — nom conseillé : MallDriftServer

	Au lancement du jeu, ce script :
	  • construit le GOLDEN MALL de Dubaï : des allées bordées de 48 BOUTIQUES
	    où l'on peut entrer en kart (coiffeur, vêtements, fast-food, jeux vidéo,
	    téléphonie, sport, bijouterie, parfumerie, jouets, librairie, glacier, café),
	    une place centrale avec fontaine, palmiers et kiosques, un aquarium géant,
	    un food court
	  • crée le GARAGE VIP (plateau tournant, atelier de personnalisation)
	  • pose les zones de sol mouillé + panneaux jaunes « ATTENTION SOL GLISSANT »
	  • sauvegarde la progression de chaque joueur (XP, niveau, kart personnalisé)
	  • fait apparaître le kart personnel de chaque joueur

	Les noms de magasins sont inventés : les vraies marques (McDonald's, etc.)
	sont protégées et Roblox peut retirer un jeu qui les utilise sans autorisation.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local KartBuilder = require(ReplicatedStorage:WaitForChild("KartBuilder"))

Config.AppliquerAmbiance(Config.NuitParDefaut)

if not Lighting:FindFirstChildOfClass("BloomEffect") then
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 26
	bloom.Threshold = 1.15
	bloom.Parent = Lighting
end
if not Lighting:FindFirstChild("CouleursMallDrift") then
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CouleursMallDrift"
	cc.Saturation = 0.1
	cc.Contrast = 0.06
	cc.TintColor = Color3.fromRGB(255, 249, 238)
	cc.Parent = Lighting
end

local carte = Instance.new("Folder")
carte.Name = "GoldenMall"
carte.Parent = workspace

local random = Random.new(2026) -- toujours le même décor

---------------------------------------------------------------------
-- Outils de construction
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
	p.Parent = parent or carte
	return p
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function libre(p: BasePart): BasePart
	-- Objet qu'on peut renverser avec le kart
	p.Anchored = false
	p.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.5, 0.2)
	return p
end

local DEBOUT = CFrame.Angles(0, 0, math.rad(90)) -- couche un cylindre Roblox à la verticale

local function cylindreDebout(nom: string, hauteur: number, diametre: number, position: Vector3, couleur: Color3, matiere: Enum.Material?, parent: Instance?): Part
	local p = bloc(nom, Vector3.new(hauteur, diametre, diametre), CFrame.new(position) * DEBOUT, couleur, matiere, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function texte(part: BasePart, face: Enum.NormalId, txt: string, couleurTexte: Color3?, fond: Color3?): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
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

local function pancarte(nom: string, taille: Vector3, position: Vector3, versOu: Vector3, txt: string, couleur: Color3, couleurTexte: Color3?, parent: Instance?): Part
	local p = bloc(nom, taille, CFrame.lookAt(position, position + versOu), couleur, Enum.Material.SmoothPlastic, parent)
	deco(p)
	texte(p, Enum.NormalId.Front, txt, couleurTexte)
	return p
end

local SOL = 1
local LARGEUR, PROFONDEUR, HAUTEUR = 420, 320, 40
local DX, DZ = LARGEUR / 2, PROFONDEUR / 2

local MARBRE = Color3.fromRGB(242, 236, 224)
local MUR_MALL = Color3.fromRGB(246, 241, 231)
local OR = Color3.fromRGB(225, 175, 45)
local NOIR_LUXE = Color3.fromRGB(22, 22, 26)
local BLANC = Color3.fromRGB(248, 248, 246)
local NOIR = Color3.fromRGB(28, 28, 32)
local GRIS_METAL = Color3.fromRGB(150, 155, 165)

--[[ PLAN DU MALL (vu de dessus, nord en haut)

	   z=-160  ┌─────────── aquarium + façades ───────────┐
	           │   ALLÉE NORD (toute la largeur)           │
	  z=-124   │ ▓ │ ▓▓ │ ▓▓ │  PLACE   │ ▓▓ │ ▓▓ │ ▓ │   ▓ = boutiques (on entre dedans)
	           │ ▓ │ ▓▓ │ ▓▓ │ CENTRALE │ ▓▓ │ ▓▓ │ ▓ │
	   z=-13   │   ALLÉE CENTRALE  (fontaine)              │
	   z=+13   │ ▓ │food│ ▓▓ │  PLACE   │ ▓▓ │GAR │ ▓ │   food = food court, GAR = garage VIP
	           │ ▓ │crt │ ▓▓ │ CENTRALE │ ▓▓ │VIP │ ▓ │
	  z=+124   │   ALLÉE SUD (toute la largeur)            │
	   z=+160  └──────────── entrée + façades ────────────┘
]]

-- Les îlots de boutiques (x = centre ; 48 de large : 2 rangées dos à dos)
local ILOTS_X = { -136, -62, 62, 136 }
local ALLEE_NORD = { -150, -124 }
local ALLEE_SUD = { 124, 150 }

---------------------------------------------------------------------
-- SOL, MURS, VERRIÈRE, LUMIÈRES
---------------------------------------------------------------------
-- Grand carrelage clair et brillant (comme dans les vidéos)
local sol = bloc("SolCarrelage", Vector3.new(LARGEUR, 1, PROFONDEUR), CFrame.new(0, SOL - 0.5, 0), Color3.fromRGB(226, 223, 216), Enum.Material.SmoothPlastic)
sol.Reflectance = 0.22
local joints = Instance.new("Folder")
joints.Name = "JointsCarrelage"
joints.Parent = carte
local COULEUR_JOINT = Color3.fromRGB(196, 192, 184)
local TAILLE_CARREAU = 8
for x = -DX + TAILLE_CARREAU, DX - TAILLE_CARREAU, TAILLE_CARREAU do
	deco(bloc("Joint", Vector3.new(0.15, 0.04, PROFONDEUR), CFrame.new(x, SOL + 0.02, 0), COULEUR_JOINT, Enum.Material.SmoothPlastic, joints))
end
for z = -DZ + TAILLE_CARREAU, DZ - TAILLE_CARREAU, TAILLE_CARREAU do
	deco(bloc("Joint", Vector3.new(LARGEUR, 0.04, 0.15), CFrame.new(0, SOL + 0.02, z), COULEUR_JOINT, Enum.Material.SmoothPlastic, joints))
end

local yMur = SOL + HAUTEUR / 2
bloc("MurNord", Vector3.new(LARGEUR + 4, HAUTEUR, 2), CFrame.new(0, yMur, -DZ - 1), MUR_MALL, Enum.Material.Marble)
bloc("MurOuest", Vector3.new(2, HAUTEUR, PROFONDEUR), CFrame.new(-DX - 1, yMur, 0), MUR_MALL, Enum.Material.Marble)
bloc("MurEst", Vector3.new(2, HAUTEUR, PROFONDEUR), CFrame.new(DX + 1, yMur, 0), MUR_MALL, Enum.Material.Marble)
local largeurPortes = 40
local largeurCote = (LARGEUR + 4 - largeurPortes) / 2
bloc("MurSudOuest", Vector3.new(largeurCote, HAUTEUR, 2), CFrame.new(-(largeurPortes / 2 + largeurCote / 2), yMur, DZ + 1), MUR_MALL, Enum.Material.Marble)
bloc("MurSudEst", Vector3.new(largeurCote, HAUTEUR, 2), CFrame.new(largeurPortes / 2 + largeurCote / 2, yMur, DZ + 1), MUR_MALL, Enum.Material.Marble)
local portes = bloc("PortesEntree", Vector3.new(largeurPortes, 16, 1), CFrame.new(0, SOL + 8, DZ + 1), Color3.fromRGB(170, 205, 230), Enum.Material.Glass)
portes.Transparency = 0.55
bloc("DessusPortes", Vector3.new(largeurPortes, HAUTEUR - 16, 2), CFrame.new(0, SOL + 16 + (HAUTEUR - 16) / 2, DZ + 1), MUR_MALL, Enum.Material.Marble)
pancarte("Enseigne", Vector3.new(60, 6, 0.5), Vector3.new(0, SOL + 22, DZ - 0.3), Vector3.new(0, 0, -1), "✦ GOLDEN MALL ✦", NOIR_LUXE, OR)

-- Plafond blanc (au ras du haut des boutiques) avec des puits de lumière
local HAUT_PLAFOND = 24
local plafond = bloc("Plafond", Vector3.new(LARGEUR + 4, 1, PROFONDEUR + 4), CFrame.new(0, SOL + HAUT_PLAFOND + 0.5, 0), Color3.fromRGB(245, 244, 240), Enum.Material.SmoothPlastic)
plafond.CastShadow = false
local puits = Instance.new("Folder")
puits.Name = "PuitsDeLumiere"
puits.Parent = carte
local function puitsDeLumiere(x: number, z: number, taille: Vector3)
	local p = deco(bloc("PuitsDeLumiere", taille, CFrame.new(x, SOL + HAUT_PLAFOND - 0.05, z), Color3.fromRGB(205, 232, 255), Enum.Material.Neon, puits))
	p.CastShadow = false
	deco(bloc("CadrePuits", taille + Vector3.new(1, -0.05, 1), CFrame.new(x, SOL + HAUT_PLAFOND - 0.02, z), Color3.fromRGB(225, 225, 228), Enum.Material.Metal, puits))
end
for x = -175, 175, 50 do
	puitsDeLumiere(x, 0, Vector3.new(18, 0.1, 7)) -- allée centrale
	puitsDeLumiere(x, -137, Vector3.new(18, 0.1, 7)) -- allée nord
	puitsDeLumiere(x, 137, Vector3.new(18, 0.1, 7)) -- allée sud
end
for _, z in ipairs({ -110, -60, 60, 110 }) do
	puitsDeLumiere(0, z, Vector3.new(10, 0.1, 22)) -- place centrale
end

-- Lumières des allées
local lampes = Instance.new("Folder")
lampes.Name = "Lampes"
lampes.Parent = carte
local nombreSpots = 0
local function lampe(x: number, z: number)
	nombreSpots += 1
	local l = bloc("Spot", Vector3.new(2.2, 0.2, 2.2), CFrame.new(x, SOL + HAUT_PLAFOND - 0.1, z), Color3.fromRGB(255, 248, 232), Enum.Material.Neon, lampes)
	deco(l)
	l.CastShadow = false
	if nombreSpots % 2 == 0 then
		return -- 1 spot sur 2 éclaire vraiment (bon pour les petits téléphones)
	end
	local pl = Instance.new("PointLight")
	pl.Range = 32
	pl.Brightness = 1.2
	pl.Color = Color3.fromRGB(255, 236, 200)
	pl.Parent = l
end
for x = -200, 200, 25 do
	lampe(x, -137)
	lampe(x, 0)
	lampe(x, 137)
end
for _, x in ipairs({ -173, -99, 99, 173 }) do
	for _, z in ipairs({ -70, 70 }) do
		lampe(x, z)
	end
end

---------------------------------------------------------------------
-- LES STYLES DE BOUTIQUES (couleurs du sol, des murs, de l'enseigne)
---------------------------------------------------------------------
local STYLES = {
	coiffeur = { Couleur = Color3.fromRGB(245, 130, 180), Sol = BLANC, SolMat = Enum.Material.Marble, Mur = BLANC },
	vetements = { Couleur = Color3.fromRGB(255, 255, 255), Sol = Color3.fromRGB(215, 185, 140), SolMat = Enum.Material.WoodPlanks, Mur = Color3.fromRGB(245, 243, 238) },
	burger = { Couleur = Color3.fromRGB(235, 55, 40), Sol = Color3.fromRGB(70, 70, 75), SolMat = Enum.Material.Slate, Mur = Color3.fromRGB(250, 215, 80) },
	pizza = { Couleur = Color3.fromRGB(60, 175, 80), Sol = Color3.fromRGB(190, 110, 75), SolMat = Enum.Material.Brick, Mur = Color3.fromRGB(250, 240, 225) },
	tacos = { Couleur = Color3.fromRGB(250, 165, 30), Sol = Color3.fromRGB(80, 60, 50), SolMat = Enum.Material.Slate, Mur = Color3.fromRGB(255, 235, 200) },
	cafe = { Couleur = Color3.fromRGB(200, 150, 100), Sol = Color3.fromRGB(120, 85, 55), SolMat = Enum.Material.WoodPlanks, Mur = Color3.fromRGB(240, 230, 215) },
	jeux = { Couleur = Color3.fromRGB(80, 200, 255), Sol = Color3.fromRGB(30, 30, 40), SolMat = Enum.Material.SmoothPlastic, Mur = Color3.fromRGB(38, 38, 52) },
	tech = { Couleur = Color3.fromRGB(110, 170, 255), Sol = Color3.fromRGB(235, 235, 240), SolMat = Enum.Material.SmoothPlastic, Mur = BLANC },
	sport = { Couleur = Color3.fromRGB(255, 95, 45), Sol = Color3.fromRGB(70, 70, 76), SolMat = Enum.Material.Rubber, Mur = Color3.fromRGB(235, 235, 235) },
	bijoux = { Couleur = OR, Sol = Color3.fromRGB(45, 25, 35), SolMat = Enum.Material.Fabric, Mur = Color3.fromRGB(32, 26, 32) },
	parfum = { Couleur = Color3.fromRGB(210, 160, 240), Sol = BLANC, SolMat = Enum.Material.Marble, Mur = Color3.fromRGB(252, 250, 248) },
	jouets = { Couleur = Color3.fromRGB(255, 205, 40), Sol = Color3.fromRGB(120, 200, 240), SolMat = Enum.Material.SmoothPlastic, Mur = Color3.fromRGB(255, 250, 240) },
	livres = { Couleur = Color3.fromRGB(130, 210, 150), Sol = Color3.fromRGB(150, 110, 75), SolMat = Enum.Material.WoodPlanks, Mur = Color3.fromRGB(245, 240, 230) },
	glaces = { Couleur = Color3.fromRGB(120, 220, 230), Sol = BLANC, SolMat = Enum.Material.Marble, Mur = Color3.fromRGB(255, 225, 235) },
}

-- Les enseignes (noms inventés). Elles sont réparties dans les allées dans cet ordre.
local CATALOGUE = {
	{ "vetements", "MODE URBAINE" }, { "coiffeur", "BELLE COUPE" }, { "jeux", "GAME ZONE" },
	{ "burger", "BIG BURGER" }, { "tech", "SKY TECH" }, { "sport", "SPORT ATTITUDE" },
	{ "parfum", "OASIS PARFUMS" }, { "cafe", "PALMIER CAFÉ" }, { "vetements", "STYLE & CO" },
	{ "jouets", "MÉGA JOUETS" }, { "bijoux", "AURUM JOAILLERIE" }, { "livres", "PAGE & PLUME" },
	{ "glaces", "GLACES POLAIRES" }, { "coiffeur", "BARBER CLUB" }, { "vetements", "DENIM STREET" },
	{ "jeux", "PIXEL PLAY" }, { "tech", "PHONE CENTER" }, { "pizza", "PIZZA ROMA" },
	{ "sport", "DUNE RUNNERS" }, { "vetements", "ÉLÉGANCE" }, { "cafe", "CAFÉ DES DUNES" },
	{ "tacos", "TACOS LOCO" }, { "vetements", "MAISON DORÉE" },
}
local prochaineEnseigne = 0
local function enseigneSuivante(): (string, string)
	prochaineEnseigne += 1
	local e = CATALOGUE[(prochaineEnseigne - 1) % #CATALOGUE + 1]
	return e[1], e[2]
end

local COULEURS_VIVES = {
	Color3.fromRGB(230, 60, 60), Color3.fromRGB(250, 170, 40), Color3.fromRGB(250, 220, 60),
	Color3.fromRGB(80, 180, 90), Color3.fromRGB(60, 130, 220), Color3.fromRGB(150, 90, 200),
	Color3.fromRGB(240, 120, 170), Color3.fromRGB(245, 245, 245), Color3.fromRGB(40, 40, 45),
}
local function couleurAuHasard(): Color3
	return COULEURS_VIVES[random:NextInteger(1, #COULEURS_VIVES)]
end

---------------------------------------------------------------------
-- LES AMÉNAGEMENTS INTÉRIEURS (minimalistes)
-- Coordonnées locales de la boutique : x de -16 à 16 (largeur),
-- z de 0 (vitrine) à 24 (mur du fond), y = hauteur au-dessus du sol.
-- La porte est au milieu (x de -7 à 7) : on garde ce passage libre.
---------------------------------------------------------------------
type Outils = {
	meuble: (nom: string, taille: Vector3, x: number, y: number, z: number, couleur: Color3, matiere: Enum.Material?) -> Part,
	cylindre: (nom: string, hauteur: number, diametre: number, x: number, y: number, z: number, couleur: Color3, matiere: Enum.Material?) -> Part,
	ecran: (x: number, y: number, z: number, largeur: number, hauteur: number, couleur: Color3, txt: string?) -> (),
	style: { [string]: any },
	nom: string,
}

local function chaise(o: Outils, x: number, z: number, couleur: Color3)
	libre(o.meuble("Chaise", Vector3.new(2, 2.4, 2), x, 1.2, z, couleur, Enum.Material.SmoothPlastic))
end

local function mannequin(o: Outils, x: number, z: number, tenue: Color3)
	local corps = libre(o.cylindre("Mannequin", 4.6, 1.6, x, 2.3, z, tenue, Enum.Material.Fabric))
	local tete = o.meuble("Tete", Vector3.new(1.3, 1.3, 1.3), x, 5.3, z, BLANC, Enum.Material.SmoothPlastic)
	tete.Shape = Enum.PartType.Ball
	tete.Anchored = false
	tete.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = corps
	w.Part1 = tete
	w.Parent = tete
end

local AMENAGEMENTS: { [string]: (Outils) -> () } = {}

AMENAGEMENTS.coiffeur = function(o)
	for _, x in ipairs({ -11, 0, 11 }) do
		deco(o.meuble("Miroir", Vector3.new(5, 6, 0.2), x, 6, 22.8, Color3.fromRGB(210, 230, 240), Enum.Material.Glass)).Reflectance = 0.5
		deco(o.meuble("CadreMiroir", Vector3.new(5.6, 0.3, 0.3), x, 9.1, 22.8, o.style.Couleur, Enum.Material.Neon))
		o.cylindre("PiedFauteuil", 1.6, 1.2, x, 0.8, 19.5, NOIR, Enum.Material.Metal)
		o.meuble("Fauteuil", Vector3.new(3, 1.2, 3), x, 2.1, 19.5, NOIR, Enum.Material.Fabric)
		o.meuble("DossierFauteuil", Vector3.new(3, 3, 0.6), x, 3.6, 21, NOIR, Enum.Material.Fabric)
	end
	o.meuble("Accueil", Vector3.new(6, 3.5, 2.5), 11.5, 1.75, 6, o.style.Couleur, Enum.Material.SmoothPlastic)
	o.cylindre("Pot", 2, 2.2, -13.5, 1, 4, BLANC, Enum.Material.SmoothPlastic)
	local plante = o.meuble("Plante", Vector3.new(3, 3, 3), -13.5, 3.4, 4, Color3.fromRGB(60, 150, 70), Enum.Material.Grass)
	plante.Shape = Enum.PartType.Ball
end

AMENAGEMENTS.vetements = function(o)
	local teintes = { Color3.fromRGB(30, 30, 35), Color3.fromRGB(240, 240, 240), Color3.fromRGB(60, 90, 160), Color3.fromRGB(190, 60, 60), Color3.fromRGB(200, 180, 140), Color3.fromRGB(90, 130, 90) }
	for _, z in ipairs({ 11, 18 }) do
		deco(o.meuble("Portant", Vector3.new(13, 0.3, 0.3), -9, 6, z, GRIS_METAL, Enum.Material.Metal))
		o.meuble("PiedPortant", Vector3.new(0.3, 6, 0.3), -15, 3, z, GRIS_METAL, Enum.Material.Metal)
		o.meuble("PiedPortant", Vector3.new(0.3, 6, 0.3), -3, 3, z, GRIS_METAL, Enum.Material.Metal)
		for i = 0, 5 do
			deco(o.meuble("Vetement", Vector3.new(0.5, 4, 2.4), -14 + i * 2, 3.9, z, teintes[(i % #teintes) + 1], Enum.Material.Fabric))
		end
	end
	o.meuble("Table", Vector3.new(6, 2.5, 5), 10, 1.25, 14, Color3.fromRGB(225, 200, 160), Enum.Material.WoodPlanks)
	for i = 0, 2 do
		deco(o.meuble("PilePulls", Vector3.new(1.6, 0.9, 1.6), 8 + i * 2, 2.95, 14, teintes[i + 2], Enum.Material.Fabric))
	end
	deco(o.meuble("Miroir", Vector3.new(6, 9, 0.2), 10, 5.5, 22.8, Color3.fromRGB(210, 230, 240), Enum.Material.Glass)).Reflectance = 0.5
	mannequin(o, -12, 4, teintes[3])
	mannequin(o, 12, 4, teintes[4])
end

local MENUS = {
	burger = { "MENU MAXI 7€", "BURGERS", "FRITES · BOISSONS" },
	pizza = { "PIZZAS", "MENU 9€", "DESSERTS" },
	tacos = { "TACOS XXL", "MENU 8€", "SAUCES MAISON" },
	["CRISPY CHICKEN"] = { "POULET CROUSTI", "MENU 7€", "WINGS · FRITES" },
	["SHAWARMA STAR"] = { "SHAWARMA", "MENU 8€", "FALAFELS" },
}
local function fastFood(o: Outils, typeB: string)
	o.meuble("Comptoir", Vector3.new(26, 3.5, 3), 0, 1.75, 18, o.style.Couleur, Enum.Material.SmoothPlastic)
	deco(o.meuble("PlanComptoir", Vector3.new(27, 0.3, 3.4), 0, 3.65, 18, BLANC, Enum.Material.Marble))
	for i, x in ipairs({ -9, 0, 9 }) do
		o.ecran(x, 9, 22.8, 7.5, 3.5, NOIR, (MENUS[o.nom] or MENUS[typeB])[i])
	end
	for _, x in ipairs({ -6, 6 }) do
		deco(o.meuble("Caisse", Vector3.new(1.6, 1.2, 0.3), x, 4.4, 17.5, NOIR, Enum.Material.SmoothPlastic))
	end
	for _, x in ipairs({ -10, 10 }) do
		o.cylindre("Table", 3, 4, x, 1.5, 9, BLANC, Enum.Material.Marble)
		chaise(o, x - 3.4, 9, o.style.Couleur)
		chaise(o, x + 3.4, 9, o.style.Couleur)
	end
end
AMENAGEMENTS.burger = function(o) fastFood(o, "burger") end
AMENAGEMENTS.pizza = function(o) fastFood(o, "pizza") end
AMENAGEMENTS.tacos = function(o) fastFood(o, "tacos") end

AMENAGEMENTS.cafe = function(o)
	o.meuble("Comptoir", Vector3.new(4, 3.5, 14), 13, 1.75, 15, Color3.fromRGB(110, 75, 50), Enum.Material.WoodPlanks)
	o.meuble("MachineCafe", Vector3.new(2, 2.5, 2.2), 13, 4.75, 19, GRIS_METAL, Enum.Material.Metal)
	o.ecran(0, 9, 22.8, 12, 3, Color3.fromRGB(40, 30, 25), "CAFÉ · THÉ · PÂTISSERIES")
	for _, pos in ipairs({ Vector2.new(-10, 9), Vector2.new(-10, 17), Vector2.new(1, 14) }) do
		o.cylindre("TableRonde", 3, 3.4, pos.X, 1.5, pos.Y, BLANC, Enum.Material.Marble)
		chaise(o, pos.X + 3, pos.Y, Color3.fromRGB(110, 75, 50))
	end
end

AMENAGEMENTS.jeux = function(o)
	for _, cote in ipairs({ -1, 1 }) do
		o.meuble("Etagere", Vector3.new(1.5, 9, 18), cote * 15, 4.5, 13, Color3.fromRGB(55, 55, 72), Enum.Material.Metal)
		for rangee = 0, 2 do
			for i = 0, 2 do
				deco(o.meuble("Jeux", Vector3.new(0.4, 1.4, 5.4), cote * 14.05, 1.6 + rangee * 2.6, 7 + i * 6, couleurAuHasard(), Enum.Material.SmoothPlastic))
			end
		end
	end
	o.ecran(0, 7, 22.8, 13, 6.5, Color3.fromRGB(30, 120, 255), "NOUVEAUTÉS 🎮")
	o.meuble("Presentoir", Vector3.new(8, 3, 4), 0, 1.5, 15, Color3.fromRGB(45, 45, 60), Enum.Material.SmoothPlastic)
	deco(o.meuble("Console", Vector3.new(1.6, 0.5, 1.1), -2, 3.25, 15, BLANC, Enum.Material.SmoothPlastic))
	deco(o.meuble("Console", Vector3.new(1.6, 0.5, 1.1), 2, 3.25, 15, NOIR, Enum.Material.SmoothPlastic))
	libre(o.meuble("FauteuilGamer", Vector3.new(2.4, 3.4, 2.4), 9, 1.7, 6, Color3.fromRGB(200, 30, 50), Enum.Material.Fabric))
end

AMENAGEMENTS.tech = function(o)
	for _, x in ipairs({ -8, 8 }) do
		o.meuble("TableExpo", Vector3.new(8, 3, 4), x, 1.5, 13, BLANC, Enum.Material.SmoothPlastic)
		for i = 0, 3 do
			deco(o.meuble("Telephone", Vector3.new(0.7, 0.08, 1.2), x - 3 + i * 2, 3.05, 13, NOIR, Enum.Material.Glass))
		end
	end
	local couleursTV = { Color3.fromRGB(40, 120, 255), Color3.fromRGB(150, 60, 220), Color3.fromRGB(30, 180, 120) }
	for i, x in ipairs({ -10, 0, 10 }) do
		o.ecran(x, 8, 22.8, 8, 4.5, couleursTV[i], nil)
	end
end

AMENAGEMENTS.sport = function(o)
	for etage = 0, 2 do
		local y = 2.5 + etage * 3
		deco(o.meuble("EtagereChaussures", Vector3.new(30, 0.25, 1.6), 0, y, 23, BLANC, Enum.Material.SmoothPlastic))
		for i = 0, 5 do
			deco(o.meuble("Chaussures", Vector3.new(2.2, 0.9, 1.2), -12.5 + i * 5, y + 0.6, 23, couleurAuHasard(), Enum.Material.SmoothPlastic))
		end
	end
	o.meuble("Banc", Vector3.new(8, 1.5, 2.5), 0, 0.75, 14, Color3.fromRGB(200, 170, 120), Enum.Material.WoodPlanks)
	for _, x in ipairs({ -11, 11 }) do
		local ballon = libre(o.meuble("Ballon", Vector3.new(2, 2, 2), x, 1, 9, Color3.fromRGB(240, 120, 40), Enum.Material.SmoothPlastic))
		ballon.Shape = Enum.PartType.Ball
	end
	mannequin(o, -12, 4, Color3.fromRGB(255, 95, 45))
end

AMENAGEMENTS.bijoux = function(o)
	for _, pos in ipairs({ Vector2.new(-9, 12), Vector2.new(0, 18), Vector2.new(9, 12) }) do
		o.meuble("Presentoir", Vector3.new(6, 3, 3), pos.X, 1.5, pos.Y, Color3.fromRGB(60, 40, 45), Enum.Material.WoodPlanks)
		local vitre = deco(o.meuble("Cloche", Vector3.new(6, 1.4, 3), pos.X, 3.7, pos.Y, Color3.fromRGB(220, 235, 245), Enum.Material.Glass))
		vitre.Transparency = 0.6
		for i = -1, 1 do
			deco(o.meuble("Bijou", Vector3.new(0.6, 0.3, 0.6), pos.X + i * 1.8, 3.15, pos.Y, OR, Enum.Material.Foil))
		end
	end
	deco(o.meuble("BandeauOr", Vector3.new(30, 0.4, 0.3), 0, 10, 22.8, OR, Enum.Material.Neon))
end

AMENAGEMENTS.parfum = function(o)
	for etage = 0, 2 do
		local y = 3 + etage * 2.6
		deco(o.meuble("Etagere", Vector3.new(28, 0.3, 2), 0, y, 22.8, BLANC, Enum.Material.Glass))
		for i = 0, 5 do
			deco(o.cylindre("Flacon", 1.4, 0.8, -12 + i * 4.8, y + 0.85, 22.8, couleurAuHasard(), Enum.Material.Glass))
		end
	end
	o.cylindre("Podium", 2.5, 6, 0, 1.25, 13, BLANC, Enum.Material.Marble)
	deco(o.cylindre("GrandFlacon", 3, 1.6, 0, 4, 13, OR, Enum.Material.Glass))
end

AMENAGEMENTS.jouets = function(o)
	for i = 0, 7 do
		local cube = libre(o.meuble("Cube", Vector3.new(2, 2, 2), -12 + (i % 3) * 2.2, 1 + math.floor(i / 3) * 2, 12, couleurAuHasard(), Enum.Material.SmoothPlastic))
		cube.Name = "CubeJouet"
	end
	local marron = Color3.fromRGB(150, 100, 60)
	for _, b in ipairs({ { 0, 2.2, 4.4 }, { 0, 5.4, 3 }, { -1.3, 6.8, 1.2 }, { 1.3, 6.8, 1.2 } }) do
		local boule = o.meuble("Nounours", Vector3.new(b[3], b[3], b[3]), 10 + b[1], b[2], 17, marron, Enum.Material.Fabric)
		boule.Shape = Enum.PartType.Ball
	end
	o.meuble("Etagere", Vector3.new(1.5, 7, 16), 15, 3.5, 13, Color3.fromRGB(255, 205, 40), Enum.Material.SmoothPlastic)
	for i = 0, 3 do
		deco(o.meuble("Boite", Vector3.new(0.6, 2, 3), 14.05, 2 + (i % 2) * 3, 8 + i * 3, couleurAuHasard(), Enum.Material.SmoothPlastic))
	end
end

AMENAGEMENTS.livres = function(o)
	for _, cote in ipairs({ -1, 1 }) do
		o.meuble("Bibliotheque", Vector3.new(1.5, 9, 20), cote * 15, 4.5, 13, Color3.fromRGB(130, 90, 60), Enum.Material.WoodPlanks)
		for rangee = 0, 2 do
			for i = 0, 3 do
				deco(o.meuble("Livres", Vector3.new(0.6, 1.9, 4.4), cote * 14, 1.5 + rangee * 2.8, 5.5 + i * 5, couleurAuHasard(), Enum.Material.SmoothPlastic))
			end
		end
	end
	o.meuble("TableLecture", Vector3.new(7, 2.6, 4), 0, 1.3, 15, Color3.fromRGB(150, 110, 75), Enum.Material.WoodPlanks)
	deco(o.meuble("PileLivres", Vector3.new(1.6, 1, 2.2), -1.5, 3.1, 15, couleurAuHasard(), Enum.Material.SmoothPlastic))
end

AMENAGEMENTS.glaces = function(o)
	o.meuble("Comptoir", Vector3.new(18, 3.5, 3), 0, 1.75, 17, Color3.fromRGB(255, 225, 235), Enum.Material.SmoothPlastic)
	local parfums = { Color3.fromRGB(255, 240, 200), Color3.fromRGB(120, 70, 40), Color3.fromRGB(255, 150, 170), Color3.fromRGB(150, 220, 140), Color3.fromRGB(250, 220, 90), Color3.fromRGB(170, 120, 220) }
	for i, c in ipairs(parfums) do
		deco(o.meuble("BacGlace", Vector3.new(2.2, 0.4, 2), -7.5 + (i - 1) * 3, 3.7, 17, c, Enum.Material.SmoothPlastic))
	end
	o.ecran(0, 8.5, 22.8, 12, 3, Color3.fromRGB(120, 220, 230), "GLACES ARTISANALES 🍦")
	for _, x in ipairs({ -10, 10 }) do
		o.cylindre("TableRonde", 3, 3.4, x, 1.5, 8, BLANC, Enum.Material.Marble)
		chaise(o, x, 11, Color3.fromRGB(255, 180, 200))
	end
end

---------------------------------------------------------------------
-- UNE BOUTIQUE (pièce fermée avec vitrine, porte, enseigne, lumière)
--   devant : milieu de la vitrine, côté allée
--   dehors : direction de l'allée
---------------------------------------------------------------------
local LARG_B, PROF_B, HAUT_B = 34, 24, 14 -- largeur, profondeur, hauteur intérieure
local LARG_PORTE = 14

local boutiquesConstruites: { { base: CFrame, typeB: string, ferme: boolean } } = {}
local compteurBoutiques = 0

local function boutique(devant: Vector3, dehors: Vector3, typeB: string, nom: string)
	compteurBoutiques += 1
	local ferme = compteurBoutiques % 6 == 0 -- 1 boutique sur 6 a son rideau baissé
	local style = STYLES[typeB]
	local base = CFrame.lookAt(devant, devant + dehors)
	local modele = Instance.new("Model")
	modele.Name = "Boutique_" .. nom
	modele.Parent = carte

	local function ici(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, SOL + y, z)
	end

	-- Le "toit" de la boutique : un étage plein qui ferme la pièce par le haut
	bloc("Etage", Vector3.new(LARG_B, 10, PROF_B), ici(0, HAUT_B + 5, PROF_B / 2), MUR_MALL, Enum.Material.Marble, modele)
	-- Murs intérieurs
	bloc("MurFond", Vector3.new(LARG_B, HAUT_B, 1), ici(0, HAUT_B / 2, PROF_B - 0.5), style.Mur, Enum.Material.SmoothPlastic, modele)
	bloc("MurGauche", Vector3.new(1, HAUT_B, PROF_B), ici(-LARG_B / 2 + 0.5, HAUT_B / 2, PROF_B / 2), style.Mur, Enum.Material.SmoothPlastic, modele)
	bloc("MurDroit", Vector3.new(1, HAUT_B, PROF_B), ici(LARG_B / 2 - 0.5, HAUT_B / 2, PROF_B / 2), style.Mur, Enum.Material.SmoothPlastic, modele)
	-- Sol intérieur (couleur du magasin)
	local solB = deco(bloc("SolBoutique", Vector3.new(LARG_B - 2, 0.05, PROF_B - 1), ici(0, 0.04, PROF_B / 2), style.Sol, style.SolMat, modele))
	solB.Reflectance = if style.SolMat == Enum.Material.Marble then 0.15 else 0

	-- Façade : 2 vitrines + la porte au milieu (assez large pour un kart)
	local largVitre = (LARG_B - LARG_PORTE) / 2 - 1
	for _, cote in ipairs({ -1, 1 }) do
		local vitre = bloc("Vitrine", Vector3.new(largVitre, HAUT_B - 3, 0.4), ici(cote * (LARG_PORTE / 2 + largVitre / 2), (HAUT_B - 3) / 2, 0.3), Color3.fromRGB(205, 225, 240), Enum.Material.Glass, modele)
		vitre.Transparency = 0.72
		bloc("Pilier", Vector3.new(1, HAUT_B, 1.2), ici(cote * (LARG_B / 2 - 0.5), HAUT_B / 2, 0.4), OR, Enum.Material.Foil, modele)
		bloc("Montant", Vector3.new(0.6, HAUT_B - 3, 0.8), ici(cote * (LARG_PORTE / 2 + 0.3), (HAUT_B - 3) / 2, 0.3), NOIR, Enum.Material.Metal, modele)
	end
	bloc("Bandeau", Vector3.new(LARG_B, 3, 0.8), ici(0, HAUT_B - 1.5, 0.4), style.Couleur, Enum.Material.SmoothPlastic, modele)

	-- Enseigne lumineuse
	local enseigne = deco(bloc("Enseigne", Vector3.new(LARG_B - 6, 4, 0.4), ici(0, HAUT_B + 4.5, -0.25), NOIR_LUXE, Enum.Material.SmoothPlastic, modele))
	texte(enseigne, Enum.NormalId.Front, nom, style.Couleur)

	-- Lumière intérieure
	local plafonnier = deco(bloc("Plafonnier", Vector3.new(12, 0.3, 4), ici(0, HAUT_B - 0.2, PROF_B / 2), Color3.fromRGB(255, 250, 240), Enum.Material.Neon, modele))
	local lumiere = Instance.new("PointLight")
	lumiere.Range = 24
	lumiere.Brightness = 1.2
	lumiere.Color = Color3.fromRGB(255, 245, 230)
	lumiere.Parent = plafonnier

	-- Aménagement intérieur
	local outils: Outils = {
		style = style,
		nom = nom,
		meuble = function(n, taille, x, y, z, couleur, matiere)
			return bloc(n, taille, ici(x, y, z), couleur, matiere, modele)
		end,
		cylindre = function(n, hauteur, diametre, x, y, z, couleur, matiere)
			local p = bloc(n, Vector3.new(hauteur, diametre, diametre), ici(x, y, z) * DEBOUT, couleur, matiere, modele)
			p.Shape = Enum.PartType.Cylinder
			return p
		end,
		ecran = function(x, y, z, largeur, hauteur, couleur, txt)
			deco(bloc("CadreEcran", Vector3.new(largeur, hauteur, 0.3), ici(x, y, z), NOIR, Enum.Material.SmoothPlastic, modele))
			local e = deco(bloc("Ecran", Vector3.new(largeur - 0.5, hauteur - 0.5, 0.1), ici(x, y, z - 0.25), couleur, Enum.Material.Neon, modele))
			if txt then
				texte(e, Enum.NormalId.Front, txt, Color3.new(1, 1, 1))
			end
		end,
	}
	AMENAGEMENTS[typeB](outils)
	if ferme then
		local rideau = bloc("RideauMetallique", Vector3.new(LARG_PORTE, HAUT_B - 3, 0.3), ici(0, (HAUT_B - 3) / 2, -0.1), Color3.fromRGB(150, 152, 158), Enum.Material.DiamondPlate, modele)
		rideau.Transparency = 0.1
		deco(bloc("Coffre", Vector3.new(LARG_PORTE + 1, 1, 1), ici(0, HAUT_B - 3.5, -0.2), Color3.fromRGB(110, 112, 118), Enum.Material.Metal, modele))
		plafonnier.Color = Color3.fromRGB(120, 120, 120)
		lumiere.Brightness = 0.3
	end
	table.insert(boutiquesConstruites, { base = base, typeB = typeB, ferme = ferme })
end

-- Façade décorative plate (contre les murs nord et sud)
local function facade(devant: Vector3, dehors: Vector3, largeur: number, nom: string, couleur: Color3)
	local base = CFrame.lookAt(devant, devant + dehors)
	local m = Instance.new("Model")
	m.Name = "Facade_" .. nom
	m.Parent = carte
	deco(bloc("FondLumineux", Vector3.new(largeur - 2, 12, 0.3), base * CFrame.new(0, SOL + 6, -0.2), couleur, Enum.Material.Neon, m)).Transparency = 0.3
	local verre = bloc("Vitrine", Vector3.new(largeur - 2, 12, 0.4), base * CFrame.new(0, SOL + 6, -1), Color3.fromRGB(205, 225, 240), Enum.Material.Glass, m)
	verre.Transparency = 0.6
	for _, cote in ipairs({ -1, 1 }) do
		bloc("Pilier", Vector3.new(1, 14, 1.6), base * CFrame.new(cote * largeur / 2, SOL + 7, -0.8), OR, Enum.Material.Foil, m)
	end
	local e = deco(bloc("Enseigne", Vector3.new(largeur - 6, 3.5, 0.4), base * CFrame.new(0, SOL + 15.5, -0.8), NOIR_LUXE, Enum.Material.SmoothPlastic, m))
	texte(e, Enum.NormalId.Front, nom, couleur)
end

---------------------------------------------------------------------
-- CONSTRUCTION DES ALLÉES DE BOUTIQUES
---------------------------------------------------------------------
local MOITIES = {
	{ z1 = -124, z2 = -13 }, -- moitié nord
	{ z1 = 13, z2 = 124 }, -- moitié sud
}

-- Une rangée de 3 boutiques côte à côte + un bout de mur pour combler
local function rangee(xFacade: number, dehorsX: number, z1: number, z2: number, epaisseurRangee: number)
	local zCentres = if z1 < 0 then { z1 + 17, z1 + 51, z1 + 85 } else { z2 - 17, z2 - 51, z2 - 85 }
	for _, z in ipairs(zCentres) do
		local typeB, nom = enseigneSuivante()
		boutique(Vector3.new(xFacade, 0, z), Vector3.new(dehorsX, 0, 0), typeB, nom)
	end
	-- Comble l'espace restant (côté allée centrale) avec un mur plein
	local reste = (z2 - z1) - 3 * LARG_B
	local zReste = if z1 < 0 then z2 - reste / 2 else z1 + reste / 2
	local xCentre = xFacade - dehorsX * epaisseurRangee / 2
	bloc("Mur", Vector3.new(epaisseurRangee, HAUT_B + 10, reste), CFrame.new(xCentre, SOL + (HAUT_B + 10) / 2, zReste), MUR_MALL, Enum.Material.Marble)
end

-- Îlots centraux : 2 rangées dos à dos (sauf le food court et le garage)
for _, cx in ipairs(ILOTS_X) do
	for i, moitie in ipairs(MOITIES) do
		local estFoodCourt = cx == -136 and i == 2
		local estGarage = cx == 136 and i == 2
		if not estFoodCourt and not estGarage then
			rangee(cx - PROF_B, -1, moitie.z1, moitie.z2, PROF_B)
			rangee(cx + PROF_B, 1, moitie.z1, moitie.z2, PROF_B)
		end
	end
end
-- Rangées contre les murs ouest et est
for i, moitie in ipairs(MOITIES) do
	if i == 1 then
		rangee(-DX + PROF_B, 1, moitie.z1, moitie.z2, PROF_B)
	end
	rangee(DX - PROF_B, -1, moitie.z1, moitie.z2, PROF_B)
end

-- Façades décoratives : mur nord (hors aquarium) et mur sud (hors entrée)
for _, x in ipairs({ -185, -145, -105, 105, 145, 185 }) do
	facade(Vector3.new(x, 0, -DZ), Vector3.new(0, 0, 1), 36, ({ "LUNE BLEUE", "FALCON MONTRES", "SABLE & SOIE", "PERLE D'ORIENT", "DATTES ROYALES", "SKY OPTIC" })[(x + 185) // 40 % 6 + 1], Color3.fromRGB(255, 220, 160))
end
for _, x in ipairs({ -185, -145, -105, -65, 65, 105, 145, 185 }) do
	facade(Vector3.new(x, 0, DZ), Vector3.new(0, 0, -1), 36, ({ "OPTIQUE LUNE", "CHOCO LOCO", "ÉCLAT BEAUTÉ", "VOYAGES SOLEIL", "PHARMACIE", "PRESSING", "FLEURS DU DÉSERT", "CORDONNERIE" })[(x + 185) // 40 % 8 + 1], Color3.fromRGB(200, 230, 255))
end

---------------------------------------------------------------------
-- LA PLACE CENTRALE : fontaine, lustre, palmiers, kiosques, bancs
---------------------------------------------------------------------
local fontaine = Instance.new("Model")
fontaine.Name = "Fontaine"
fontaine.Parent = carte
cylindreDebout("Bassin", 3, 30, Vector3.new(0, SOL + 1.5, 0), Color3.fromRGB(250, 248, 242), Enum.Material.Marble, fontaine)
local eauFontaine = cylindreDebout("Eau", 0.3, 27, Vector3.new(0, SOL + 2.9, 0), Color3.fromRGB(60, 160, 230), Enum.Material.Glass, fontaine)
eauFontaine.Transparency = 0.3
deco(eauFontaine)
cylindreDebout("Colonne", 10, 3, Vector3.new(0, SOL + 6, 0), OR, Enum.Material.Foil, fontaine)
local vasque = cylindreDebout("Vasque", 1, 11, Vector3.new(0, SOL + 11, 0), OR, Enum.Material.Foil, fontaine)
local attJet = Instance.new("Attachment")
attJet.Position = Vector3.new(0.6, 0, 0)
attJet.Parent = vasque
local jet = Instance.new("ParticleEmitter")
jet.Name = "JetDEau"
jet.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.25) })
jet.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
jet.Lifetime = NumberRange.new(1.1, 1.5)
jet.Speed = NumberRange.new(20, 26)
jet.SpreadAngle = Vector2.new(16, 16)
jet.Acceleration = Vector3.new(0, -35, 0)
jet.EmissionDirection = Enum.NormalId.Right -- = vers le haut pour ce cylindre
jet.Rate = 120
jet.Parent = attJet
local lumiereFontaine = Instance.new("PointLight")
lumiereFontaine.Color = Color3.fromRGB(90, 180, 255)
lumiereFontaine.Range = 26
lumiereFontaine.Brightness = 2
lumiereFontaine.Parent = eauFontaine
local lustre = cylindreDebout("Lustre", 0.8, 14, Vector3.new(0, SOL + HAUT_PLAFOND - 2, 0), Color3.fromRGB(255, 225, 150), Enum.Material.Neon)
deco(lustre)
local lumiereLustre = Instance.new("PointLight")
lumiereLustre.Range = 55
lumiereLustre.Brightness = 2
lumiereLustre.Color = Color3.fromRGB(255, 225, 170)
lumiereLustre.Parent = lustre

local function palmier(x: number, z: number)
	local arbre = Instance.new("Model")
	arbre.Name = "Palmier"
	arbre.Parent = carte
	cylindreDebout("Bac", 2, 6, Vector3.new(x, SOL + 1, z), BLANC, Enum.Material.Marble, arbre)
	deco(cylindreDebout("BordOr", 0.3, 6.4, Vector3.new(x, SOL + 2.1, z), OR, Enum.Material.Foil, arbre))
	deco(cylindreDebout("Tronc", 15, 1.3, Vector3.new(x, SOL + 9.5, z), Color3.fromRGB(140, 100, 60), Enum.Material.Wood, arbre))
	for i = 0, 6 do
		deco(bloc("Feuille", Vector3.new(7.5, 0.3, 2), CFrame.new(x, SOL + 17, z) * CFrame.Angles(0, i * math.pi * 2 / 7, 0) * CFrame.new(3.4, 0, 0) * CFrame.Angles(0, 0, math.rad(-28)), Color3.fromRGB(45, 140, 60), Enum.Material.Grass, arbre))
	end
end

local function banc(x: number, z: number)
	bloc("Banc", Vector3.new(2.4, 1.6, 7), CFrame.new(x, SOL + 0.8, z), Color3.fromRGB(190, 150, 100), Enum.Material.WoodPlanks)
end

local function kiosque(z: number, nom: string, couleur: Color3)
	local k = Instance.new("Model")
	k.Name = "Kiosque_" .. nom
	k.Parent = carte
	bloc("Comptoir", Vector3.new(12, 3.5, 7), CFrame.new(0, SOL + 1.75, z), couleur, Enum.Material.SmoothPlastic, k)
	deco(bloc("PlanComptoir", Vector3.new(12.6, 0.3, 7.6), CFrame.new(0, SOL + 3.65, z), BLANC, Enum.Material.Marble, k))
	for _, dx in ipairs({ -5.5, 5.5 }) do
		for _, dz in ipairs({ -3, 3 }) do
			deco(bloc("Poteau", Vector3.new(0.4, 5.5, 0.4), CFrame.new(dx, SOL + 6.5, z + dz), OR, Enum.Material.Foil, k))
		end
	end
	deco(bloc("Toit", Vector3.new(14, 0.6, 9), CFrame.new(0, SOL + 9.5, z), couleur, Enum.Material.SmoothPlastic, k))
	local e = deco(bloc("Enseigne", Vector3.new(10, 2, 0.3), CFrame.new(0, SOL + 11, z), NOIR_LUXE, Enum.Material.SmoothPlastic, k))
	texte(e, Enum.NormalId.Front, nom, couleur)
	texte(e, Enum.NormalId.Back, nom, couleur)
end

for _, z in ipairs({ -105, -75, -45, 45, 75, 105 }) do
	palmier(-28, z)
	palmier(28, z)
end
for _, z in ipairs({ -90, -60, 60, 90 }) do
	banc(-28, z)
	banc(28, z)
end
kiosque(-75, "COQUES & CO", Color3.fromRGB(90, 160, 255))
kiosque(75, "BARBE À PAPA", Color3.fromRGB(255, 150, 200))

---------------------------------------------------------------------
-- L'AQUARIUM GÉANT (mur nord, au bout de la place centrale)
---------------------------------------------------------------------
local aquarium = Instance.new("Model")
aquarium.Name = "Aquarium"
aquarium.Parent = carte
local AQ_LARGEUR, AQ_HAUT = 120, 18
local eauAq = bloc("Eau", Vector3.new(AQ_LARGEUR, AQ_HAUT, 8), CFrame.new(0, SOL + AQ_HAUT / 2, -DZ + 4.5), Color3.fromRGB(25, 105, 185), Enum.Material.SmoothPlastic, aquarium)
eauAq.Transparency = 0.5
deco(eauAq)
local vitreAq = bloc("Vitre", Vector3.new(AQ_LARGEUR, AQ_HAUT, 0.6), CFrame.new(0, SOL + AQ_HAUT / 2, -DZ + 8.8), Color3.fromRGB(190, 225, 245), Enum.Material.Glass, aquarium)
vitreAq.Transparency = 0.75
deco(bloc("Sable", Vector3.new(AQ_LARGEUR, 2, 8), CFrame.new(0, SOL + 1, -DZ + 4.5), Color3.fromRGB(225, 200, 150), Enum.Material.Sand, aquarium))
bloc("CadreHaut", Vector3.new(AQ_LARGEUR + 2, 1.5, 1.5), CFrame.new(0, SOL + AQ_HAUT + 0.75, -DZ + 8.8), OR, Enum.Material.Foil, aquarium)
local lumiereAq = Instance.new("PointLight")
lumiereAq.Color = Color3.fromRGB(80, 170, 255)
lumiereAq.Range = 40
lumiereAq.Brightness = 1.5
lumiereAq.Parent = eauAq
pancarte("PanneauAquarium", Vector3.new(40, 3.5, 0.5), Vector3.new(0, SOL + AQ_HAUT + 3, -DZ + 1), Vector3.new(0, 0, 1), "AQUARIUM GÉANT", NOIR_LUXE, Color3.fromRGB(120, 210, 255))
local CORAUX = { Color3.fromRGB(255, 110, 120), Color3.fromRGB(255, 170, 60), Color3.fromRGB(190, 90, 220), Color3.fromRGB(80, 220, 160) }
for _ = 1, 12 do
	local h = random:NextNumber(2, 6)
	deco(bloc("Corail", Vector3.new(random:NextNumber(1, 2.5), h, random:NextNumber(1, 2.5)), CFrame.new(random:NextNumber(-55, 55), SOL + 2 + h / 2, -DZ + random:NextNumber(2, 7)), CORAUX[random:NextInteger(1, #CORAUX)], Enum.Material.SmoothPlastic, aquarium))
end
local POISSONS = { Color3.fromRGB(255, 150, 30), Color3.fromRGB(255, 230, 60), Color3.fromRGB(60, 160, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(240, 80, 120) }
for _ = 1, 16 do
	local y = SOL + random:NextNumber(5, AQ_HAUT - 3)
	local z = -DZ + random:NextNumber(2, 7)
	local taille = random:NextNumber(0.8, 1.6)
	local poisson = bloc("Poisson", Vector3.new(2.2, 1.1, 0.6) * taille, CFrame.new(random:NextNumber(-55, -5), y, z), POISSONS[random:NextInteger(1, #POISSONS)], Enum.Material.SmoothPlastic, aquarium)
	deco(poisson)
	local info = TweenInfo.new(random:NextNumber(7, 14), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(poisson, info, { CFrame = CFrame.new(random:NextNumber(5, 55), y + random:NextNumber(-3, 3), z) }):Play()
end

---------------------------------------------------------------------
-- FOOD COURT (îlot sud-ouest) : tables + chaises qu'on peut renverser
-- Les restaurants sont dans la rangée contre le mur ouest, juste en face.
---------------------------------------------------------------------
local foodCourt = Instance.new("Model")
foodCourt.Name = "FoodCourt"
foodCourt.Parent = carte
deco(bloc("SolTerrasse", Vector3.new(48, 0.05, 111), CFrame.new(-136, SOL + 0.03, 68.5), Color3.fromRGB(200, 125, 85), Enum.Material.Slate, foodCourt))
pancarte("PanneauFoodCourt", Vector3.new(30, 4, 0.4), Vector3.new(-136, SOL + 14, 14), Vector3.new(0, 0, -1), "🍔 FOOD COURT 🍕", NOIR_LUXE, Color3.fromRGB(255, 200, 80), foodCourt)
-- Les 3 restaurants le long du mur ouest, côté sud
for _, resto in ipairs({ { "burger", "CRISPY CHICKEN", 107 }, { "pizza", "PIZZA NAPOLI", 73 }, { "tacos", "SHAWARMA STAR", 39 } }) do
	boutique(Vector3.new(-DX + PROF_B, 0, resto[3]), Vector3.new(1, 0, 0), resto[1], resto[2])
end
bloc("Mur", Vector3.new(PROF_B, HAUT_B + 10, 9), CFrame.new(-DX + PROF_B / 2, SOL + (HAUT_B + 10) / 2, 17.5), MUR_MALL, Enum.Material.Marble)
local COULEURS_CHAISES = { Color3.fromRGB(230, 70, 60), Color3.fromRGB(250, 200, 40), Color3.fromRGB(60, 170, 220) }
for _, x in ipairs({ -148, -124 }) do
	for _, z in ipairs({ 32, 56, 82, 106 }) do
		local t = Instance.new("Model")
		t.Name = "Table"
		t.Parent = foodCourt
		local collision = cylindreDebout("Collision", 3.4, 6, Vector3.new(x, SOL + 1.7, z), BLANC, nil, t)
		collision.Transparency = 1
		deco(cylindreDebout("Plateau", 0.4, 6, Vector3.new(x, SOL + 3.2, z), BLANC, Enum.Material.Marble, t))
		deco(cylindreDebout("Pied", 3, 0.6, Vector3.new(x, SOL + 1.5, z), OR, Enum.Material.Foil, t))
		for k, d in ipairs({ Vector3.new(4.5, 0, 0), Vector3.new(-4.5, 0, 0), Vector3.new(0, 0, 4.5), Vector3.new(0, 0, -4.5) }) do
			libre(bloc("Chaise", Vector3.new(2, 2.6, 2), CFrame.new(Vector3.new(x, SOL + 1.3, z) + d), COULEURS_CHAISES[(k % 3) + 1], Enum.Material.SmoothPlastic, t))
		end
	end
end

---------------------------------------------------------------------
-- SOL MOUILLÉ + panneaux jaunes « ATTENTION SOL GLISSANT »
---------------------------------------------------------------------
local COULEUR_EAU = Color3.fromRGB(110, 170, 225)

local function flaque(centre: Vector2, tailleX: number, tailleZ: number)
	local zone = Instance.new("Model")
	zone.Name = "SolMouille"
	zone.Parent = carte
	local function morceau(p: BasePart)
		p.Transparency = 0.4
		p.Reflectance = 0.25
		p.CanCollide = false
		p.CanTouch = false
		p.CastShadow = false
		p:SetAttribute("Mouille", true) -- le kart détecte cet attribut
	end
	morceau(bloc("Eau", Vector3.new(tailleX, 0.1, tailleZ), CFrame.new(centre.X, SOL + 0.09, centre.Y), COULEUR_EAU, Enum.Material.Glass, zone))
	for _ = 1, 3 do
		local d = random:NextNumber(3, 6)
		morceau(cylindreDebout("EauRonde", 0.1, d, Vector3.new(centre.X + random:NextNumber(-tailleX / 2, tailleX / 2), SOL + 0.1, centre.Y + random:NextNumber(-tailleZ / 2, tailleZ / 2)), COULEUR_EAU, Enum.Material.Glass, zone))
	end
end

local function panneauJaune(position: Vector2, versOu: Vector3)
	local modele = Instance.new("Model")
	modele.Name = "PanneauSolGlissant"
	local pos = Vector3.new(position.X, 0, position.Y)
	local base = CFrame.lookAt(pos, pos + versOu)
	local jaune = Color3.fromRGB(255, 205, 0)
	local devant = bloc("Devant", Vector3.new(2.4, 3.4, 0.15), base * CFrame.new(0, SOL + 1.7, -0.45) * CFrame.Angles(math.rad(15), 0, 0), jaune, Enum.Material.SmoothPlastic, modele)
	local derriere = bloc("Derriere", Vector3.new(2.4, 3.4, 0.15), base * CFrame.new(0, SOL + 1.7, 0.45) * CFrame.Angles(math.rad(-15), 0, 0), jaune, Enum.Material.SmoothPlastic, modele)
	texte(devant, Enum.NormalId.Front, "⚠\nATTENTION\nSOL GLISSANT", Color3.fromRGB(20, 20, 20))
	texte(derriere, Enum.NormalId.Back, "⚠\nATTENTION\nSOL GLISSANT", Color3.fromRGB(20, 20, 20))
	for _, p in ipairs({ devant, derriere }) do
		libre(p)
	end
	local soudure = Instance.new("WeldConstraint")
	soudure.Part0 = devant
	soudure.Part1 = derriere
	soudure.Parent = devant
	modele.PrimaryPart = devant
	modele.Parent = carte
end

local function seau(position: Vector2)
	libre(cylindreDebout("Seau", 1.8, 2, Vector3.new(position.X, SOL + 0.9, position.Y), Color3.fromRGB(255, 200, 0)))
	deco(bloc("Serpilliere", Vector3.new(0.2, 6, 0.2), CFrame.new(position.X + 0.6, SOL + 3.5, position.Y) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(80, 140, 230)))
end

-- Autour de la fontaine (elle éclabousse !)
flaque(Vector2.new(0, -22), 20, 9)
flaque(Vector2.new(0, 22), 20, 9)
flaque(Vector2.new(22, 0), 9, 20)
flaque(Vector2.new(-22, 0), 9, 20)
panneauJaune(Vector2.new(11, -30), Vector3.new(0, 0, -1))
panneauJaune(Vector2.new(-11, 30), Vector3.new(0, 0, 1))
-- Devant l'aquarium (nettoyage en cours)
flaque(Vector2.new(30, -137), 26, 9)
panneauJaune(Vector2.new(15, -137), Vector3.new(-1, 0, 0))
panneauJaune(Vector2.new(45, -133), Vector3.new(1, 0, 0))
seau(Vector2.new(46, -140))
-- Soda renversé au food court
flaque(Vector2.new(-136, 69), 14, 8)
panneauJaune(Vector2.new(-136, 62), Vector3.new(0, 0, -1))
-- Dans une allée étroite
flaque(Vector2.new(-99, -60), 12, 22)
panneauJaune(Vector2.new(-99, -74), Vector3.new(0, 0, -1))
panneauJaune(Vector2.new(-99, -46), Vector3.new(0, 0, 1))
-- Dans le premier salon de coiffure (shampoing renversé !) et un fast-food
local dejaMouille: { [string]: boolean } = {}
for _, b in ipairs(boutiquesConstruites) do
	if (b.typeB == "coiffeur" or b.typeB == "burger") and not b.ferme and not dejaMouille[b.typeB] then
		dejaMouille[b.typeB] = true
		local centre = (b.base * CFrame.new(0, 0, 9)).Position
		flaque(Vector2.new(centre.X, centre.Z), 9, 7)
		local posPanneau = (b.base * CFrame.new(-5, 0, 3)).Position
		panneauJaune(Vector2.new(posPanneau.X, posPanneau.Z), b.base.LookVector)
	end
end

---------------------------------------------------------------------
-- LE GARAGE VIP (îlot sud-est) : on personnalise son kart ici
---------------------------------------------------------------------
local garage = Instance.new("Model")
garage.Name = "GarageVIP"
garage.Parent = carte
local G_X1, G_X2, G_Z1, G_Z2 = 112, 160, 13, 124
local G_CX, G_CZ = (G_X1 + G_X2) / 2, (G_Z1 + G_Z2) / 2
local PORTE_Z1, PORTE_Z2 = 45, 85 -- la grande porte du garage (côté ouest)
local sombre = deco(bloc("SolGarage", Vector3.new(G_X2 - G_X1, 0.05, G_Z2 - G_Z1), CFrame.new(G_CX, SOL + 0.04, G_CZ), Color3.fromRGB(28, 28, 34), Enum.Material.SmoothPlastic, garage))
sombre.Reflectance = 0.3

local function vitreGarage(taille: Vector3, position: Vector3)
	local v = bloc("VitreGarage", taille, CFrame.new(position), Color3.fromRGB(40, 40, 55), Enum.Material.Glass, garage)
	v.Transparency = 0.5
end
vitreGarage(Vector3.new(G_X2 - G_X1, HAUT_B, 0.6), Vector3.new(G_CX, SOL + HAUT_B / 2, G_Z1))
vitreGarage(Vector3.new(G_X2 - G_X1, HAUT_B, 0.6), Vector3.new(G_CX, SOL + HAUT_B / 2, G_Z2))
vitreGarage(Vector3.new(0.6, HAUT_B, G_Z2 - G_Z1), Vector3.new(G_X2, SOL + HAUT_B / 2, G_CZ))
vitreGarage(Vector3.new(0.6, HAUT_B, PORTE_Z1 - G_Z1), Vector3.new(G_X1, SOL + HAUT_B / 2, (G_Z1 + PORTE_Z1) / 2))
vitreGarage(Vector3.new(0.6, HAUT_B, G_Z2 - PORTE_Z2), Vector3.new(G_X1, SOL + HAUT_B / 2, (PORTE_Z2 + G_Z2) / 2))
bloc("ToitGarage", Vector3.new(G_X2 - G_X1, 2, G_Z2 - G_Z1), CFrame.new(G_CX, SOL + HAUT_B + 1, G_CZ), NOIR_LUXE, Enum.Material.SmoothPlastic, garage)
deco(bloc("NeonSol", Vector3.new(0.4, 0.08, G_Z2 - G_Z1), CFrame.new(G_X2 - 1.5, SOL + 0.06, G_CZ), Color3.fromRGB(170, 80, 255), Enum.Material.Neon, garage))
deco(bloc("NeonPlafond", Vector3.new(G_X2 - G_X1 - 4, 0.3, 0.6), CFrame.new(G_CX, SOL + HAUT_B - 0.2, G_CZ), Color3.fromRGB(170, 80, 255), Enum.Material.Neon, garage))
pancarte("EnseigneGarage", Vector3.new(30, 4, 0.5), Vector3.new(G_X1 - 0.5, SOL + HAUT_B + 4, (PORTE_Z1 + PORTE_Z2) / 2), Vector3.new(-1, 0, 0), "★ GARAGE VIP ★", NOIR_LUXE, Color3.fromRGB(200, 140, 255))
local lumiereGarage = Instance.new("PointLight")
lumiereGarage.Range = 40
lumiereGarage.Brightness = 1.5
lumiereGarage.Color = Color3.fromRGB(220, 200, 255)
lumiereGarage.Parent = sombre

-- Plateau tournant (le kart du joueur s'affiche dessus)
local POSITION_PLATEAU = Vector3.new(143, SOL, 62)
local plateau = cylindreDebout("PlateauTournant", 1, 20, POSITION_PLATEAU + Vector3.new(0, 0.5, 0), Color3.fromRGB(40, 40, 48), Enum.Material.Metal, garage)
deco(cylindreDebout("AnneauNeon", 0.9, 21, POSITION_PLATEAU + Vector3.new(0, 0.45, 0), Color3.fromRGB(200, 140, 255), Enum.Material.Neon, garage))
local spot = Instance.new("PointLight")
spot.Range = 22
spot.Brightness = 2.5
spot.Parent = plateau
for i = 0, 4 do
	for h = 0, 3 do
		deco(cylindreDebout("Pneu", 1.2, 3, Vector3.new(G_X2 - 4, SOL + 0.6 + h * 1.2, 92 + i * 4), Color3.fromRGB(20, 20, 20), Enum.Material.Rubber, garage))
	end
end

-- L'atelier : borne pour personnaliser / sortir son kart
local borne = bloc("Atelier", Vector3.new(2, 4, 2), CFrame.new(124, SOL + 2, 100), NOIR_LUXE, Enum.Material.Metal, garage)
deco(bloc("Ecran", Vector3.new(1.8, 1.2, 0.2), CFrame.new(124, SOL + 4.4, 100) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(170, 80, 255), Enum.Material.Neon, garage))
local invitePerso = Instance.new("ProximityPrompt")
invitePerso.Name = "PromptGarage"
invitePerso.ActionText = "Personnaliser mon kart"
invitePerso.ObjectText = "Atelier"
invitePerso.KeyboardKeyCode = Enum.KeyCode.E
invitePerso.HoldDuration = 0
invitePerso.MaxActivationDistance = 12
invitePerso.RequiresLineOfSight = false
invitePerso.Parent = borne
local inviteSortir = Instance.new("ProximityPrompt")
inviteSortir.Name = "PromptSortir"
inviteSortir.ActionText = "Sortir mon kart"
inviteSortir.ObjectText = "Garage"
inviteSortir.KeyboardKeyCode = Enum.KeyCode.F
inviteSortir.GamepadKeyCode = Enum.KeyCode.ButtonY
inviteSortir.UIOffset = Vector2.new(0, 80)
inviteSortir.HoldDuration = 0
inviteSortir.MaxActivationDistance = 12
inviteSortir.RequiresLineOfSight = false
inviteSortir.Parent = borne

local apparition = Instance.new("SpawnLocation")
apparition.Name = "ApparitionGarage"
apparition.Size = Vector3.new(8, 0.4, 6)
apparition.CFrame = CFrame.new(134, SOL + 0.2, 108)
apparition.Anchored = true
apparition.Neutral = true
apparition.Duration = 0
apparition.Color = Color3.fromRGB(170, 80, 255)
apparition.Material = Enum.Material.Neon
apparition.Parent = garage

---------------------------------------------------------------------
-- COMMUNICATION CLIENT ↔ SERVEUR
---------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "MallDriftRemotes"
local ObtenirProfil = Instance.new("RemoteFunction")
ObtenirProfil.Name = "ObtenirProfil"
ObtenirProfil.Parent = remotes
local ProfilMisAJour = Instance.new("RemoteEvent")
ProfilMisAJour.Name = "ProfilMisAJour"
ProfilMisAJour.Parent = remotes
local Personnaliser = Instance.new("RemoteEvent")
Personnaliser.Name = "Personnaliser"
Personnaliser.Parent = remotes
local SortirKart = Instance.new("RemoteEvent")
SortirKart.Name = "SortirKart"
SortirKart.Parent = remotes
local DriftTermine = Instance.new("RemoteEvent")
DriftTermine.Name = "DriftTermine"
DriftTermine.Parent = remotes
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------
-- SAUVEGARDE DES JOUEURS (XP, record, kart personnalisé)
-- Pour que ça marche dans Studio : Paramètres du jeu > Sécurité >
-- « Autoriser l'accès Studio aux services API ». Sinon le jeu marche
-- quand même, mais la progression n'est pas gardée entre deux parties.
---------------------------------------------------------------------
local okStore, magasin = pcall(function()
	return DataStoreService:GetDataStore("GoldenMallDrift_v1")
end)
if not okStore then
	warn("[Golden Mall] Sauvegarde indisponible (normal dans Studio si l'accès API est désactivé).")
	magasin = nil
end

type Profil = { XP: number, Record: number, Perso: { [string]: any }, Charge: boolean }
local profils: { [Player]: Profil } = {}
local kartsJoueurs: { [Player]: Model } = {}
local derniereAction: { [Player]: { [string]: number } } = {}

local dossierKarts = Instance.new("Folder")
dossierKarts.Name = "KartsJoueurs"
dossierKarts.Parent = workspace

local function niveauDe(profil: Profil): number
	return (Config.NiveauDepuisXP(profil.XP))
end

local function versionPublique(profil: Profil)
	local niveau, xpDansNiveau, xpRequis = Config.NiveauDepuisXP(profil.XP)
	return {
		XP = profil.XP,
		Niveau = niveau,
		XPDansNiveau = xpDansNiveau,
		XPRequis = xpRequis,
		Record = profil.Record,
		Perso = profil.Perso,
	}
end

local function tropRapide(joueur: Player, action: string, delai: number): boolean
	local t = derniereAction[joueur]
	if not t then
		t = {}
		derniereAction[joueur] = t
	end
	local maintenant = os.clock()
	if t[action] and maintenant - t[action] < delai then
		return true
	end
	t[action] = maintenant
	return false
end

local function majClassement(joueur: Player, profil: Profil)
	local stats = joueur:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Niveau") :: IntValue).Value = niveauDe(profil);
		(stats:FindFirstChild("Record") :: IntValue).Value = profil.Record
	end
end

local function sauvegarder(joueur: Player)
	local profil = profils[joueur]
	if not profil or not profil.Charge or not magasin then
		return
	end
	local donnees = { XP = profil.XP, Record = profil.Record, Perso = profil.Perso }
	local ok, err = pcall(function()
		magasin:SetAsync("joueur_" .. joueur.UserId, donnees)
	end)
	if not ok then
		warn("[Golden Mall] Échec de sauvegarde pour " .. joueur.Name .. " : " .. tostring(err))
	end
end

local function chargerProfil(joueur: Player)
	local profil: Profil = { XP = 0, Record = 0, Perso = table.clone(Config.PersoParDefaut), Charge = magasin == nil }
	if magasin then
		local ok, donnees = pcall(function()
			return magasin:GetAsync("joueur_" .. joueur.UserId)
		end)
		if ok then
			profil.Charge = true
			if type(donnees) == "table" then
				profil.XP = type(donnees.XP) == "number" and math.max(0, math.floor(donnees.XP)) or 0
				profil.Record = type(donnees.Record) == "number" and math.max(0, math.floor(donnees.Record)) or 0
				profil.Perso = KartBuilder.Nettoyer(donnees.Perso, Config.NiveauDepuisXP(profil.XP))
			end
		else
			-- On ne sauvegardera pas ce joueur, pour ne pas écraser ses vraies données
			warn("[Golden Mall] Chargement impossible pour " .. joueur.Name .. " : " .. tostring(donnees))
		end
	end
	profils[joueur] = profil

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local niv = Instance.new("IntValue")
	niv.Name = "Niveau"
	niv.Parent = stats
	local rec = Instance.new("IntValue")
	rec.Name = "Record"
	rec.Parent = stats
	stats.Parent = joueur
	majClassement(joueur, profil)
end

---------------------------------------------------------------------
-- LES KARTS DES JOUEURS
---------------------------------------------------------------------
-- Places de sortie devant la porte du garage (face au mall)
local PLACES_SORTIE = {}
for z = PORTE_Z1 + 5, PORTE_Z2 - 5, 8 do
	local pos = Vector3.new(G_X1 - 13, SOL + 0.45, z)
	table.insert(PLACES_SORTIE, CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))) -- face à l'allée
end

local function placeLibre(): CFrame
	for _, cf in ipairs(PLACES_SORTIE) do
		local libre = true
		for _, k in pairs(kartsJoueurs) do
			if k.PrimaryPart and (k.PrimaryPart.Position - cf.Position).Magnitude < 7 then
				libre = false
				break
			end
		end
		if libre then
			return cf
		end
	end
	return PLACES_SORTIE[1] + Vector3.new(0, 0, -12)
end

local function asseoir(joueur: Player, kart: Model)
	local siege = kart:FindFirstChild("Siege") :: Seat
	local perso = joueur.Character
	local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
	if siege and humanoide and humanoide.Health > 0 and not siege.Occupant then
		if humanoide.SeatPart then
			humanoide.Sit = false
			task.wait(0.1)
		end
		siege:Sit(humanoide)
	end
end

local function creerKart(joueur: Player, cf: CFrame): Model
	local profil = profils[joueur]
	local ancien = kartsJoueurs[joueur]
	if ancien then
		ancien:Destroy()
	end

	local kart = KartBuilder.Construire(profil.Perso, cf, false)
	kart.Name = "Kart_" .. joueur.Name
	kart.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	kart:SetAttribute("Proprietaire", joueur.UserId)
	local chassis = kart.PrimaryPart :: BasePart
	local siege = kart:FindFirstChild("Siege") :: Seat

	local invite = Instance.new("ProximityPrompt")
	invite.ActionText = "Conduire"
	invite.ObjectText = "Kart de " .. joueur.DisplayName
	invite.HoldDuration = 0
	invite.MaxActivationDistance = 10
	invite.RequiresLineOfSight = false
	invite.Parent = siege
	invite.Triggered:Connect(function(qui: Player)
		if qui == joueur then
			asseoir(joueur, kart)
		end
	end)

	siege:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoide = siege.Occupant
		if humanoide then
			local qui = Players:GetPlayerFromCharacter(humanoide.Parent)
			if qui ~= joueur then
				-- Seul le propriétaire peut conduire son kart
				local soudure = siege:FindFirstChild("SeatWeld")
				if soudure then
					soudure:Destroy()
				end
				return
			end
			invite.Enabled = false
			pcall(function()
				chassis:SetNetworkOwner(joueur)
			end)
		else
			invite.Enabled = true
			pcall(function()
				chassis:SetNetworkOwnershipAuto()
			end)
		end
	end)

	kart.Parent = dossierKarts
	kartsJoueurs[joueur] = kart
	return kart
end

SortirKart.OnServerEvent:Connect(function(joueur: Player)
	if not profils[joueur] or tropRapide(joueur, "sortir", 2) then
		return
	end
	local kart = creerKart(joueur, placeLibre())
	asseoir(joueur, kart)
end)

inviteSortir.Triggered:Connect(function(joueur: Player)
	if not profils[joueur] or tropRapide(joueur, "sortir", 2) then
		return
	end
	local kart = creerKart(joueur, placeLibre())
	asseoir(joueur, kart)
end)

Personnaliser.OnServerEvent:Connect(function(joueur: Player, perso: any)
	local profil = profils[joueur]
	if not profil or tropRapide(joueur, "perso", 0.3) then
		return
	end
	local ancienType = profil.Perso.Kart
	profil.Perso = KartBuilder.Nettoyer(perso, niveauDe(profil))

	-- Met à jour le kart déjà sorti
	local kart = kartsJoueurs[joueur]
	if kart and kart.Parent then
		if profil.Perso.Kart == ancienType then
			KartBuilder.Peindre(kart, profil.Perso)
		else
			local etaitAssis = (kart:FindFirstChild("Siege") :: Seat).Occupant ~= nil
			local nouveau = creerKart(joueur, (kart.PrimaryPart :: BasePart).CFrame + Vector3.new(0, 1, 0))
			if etaitAssis then
				asseoir(joueur, nouveau)
			end
		end
	end
	ProfilMisAJour:FireClient(joueur, versionPublique(profil))
end)

DriftTermine.OnServerEvent:Connect(function(joueur: Player, points: any)
	local profil = profils[joueur]
	if not profil or type(points) ~= "number" or points ~= points or tropRapide(joueur, "drift", 0.3) then
		return
	end
	-- Le joueur doit être assis dans SON kart
	local kart = kartsJoueurs[joueur]
	local humanoide = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	if not kart or not humanoide or not humanoide.SeatPart or not humanoide.SeatPart:IsDescendantOf(kart) then
		return
	end
	points = math.clamp(math.floor(points), 0, Config.Score.MaxParDrift)

	local niveauAvant = niveauDe(profil)
	profil.XP += points
	if points > profil.Record then
		profil.Record = points
	end
	local niveauApres = niveauDe(profil)
	majClassement(joueur, profil)
	ProfilMisAJour:FireClient(joueur, versionPublique(profil), niveauApres > niveauAvant and niveauApres or nil)
end)

ObtenirProfil.OnServerInvoke = function(joueur: Player)
	local debut = os.clock()
	while not profils[joueur] and os.clock() - debut < 15 do
		task.wait(0.2)
	end
	local profil = profils[joueur]
	return profil and versionPublique(profil) or nil
end

Players.PlayerAdded:Connect(chargerProfil)
for _, j in ipairs(Players:GetPlayers()) do
	task.spawn(chargerProfil, j)
end

Players.PlayerRemoving:Connect(function(joueur: Player)
	sauvegarder(joueur)
	if kartsJoueurs[joueur] then
		kartsJoueurs[joueur]:Destroy()
	end
	kartsJoueurs[joueur] = nil
	profils[joueur] = nil
	derniereAction[joueur] = nil
end)

game:BindToClose(function()
	for _, j in ipairs(Players:GetPlayers()) do
		sauvegarder(j)
	end
end)

-- Sauvegarde automatique toutes les 2 minutes
task.spawn(function()
	while true do
		task.wait(120)
		for _, j in ipairs(Players:GetPlayers()) do
			sauvegarder(j)
		end
	end
end)

print("[Golden Mall] Le Golden Mall de Dubaï est prêt ! Garage VIP ouvert.")
