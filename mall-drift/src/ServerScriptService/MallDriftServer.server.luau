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
local TYPE = Config.TypeDePlace() -- rôle de cette place (voir KartConfig > Config.Places)

-- (bloom, couleurs, rayons du soleil, profondeur de champ : voir Config.AppliquerAmbiance)
-- Vrais nuages dans le ciel de Dubaï (vus du parking et par la verrière)
pcall(function()
	local nuages = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	nuages.Cover = 0.45
	nuages.Density = 0.55
	nuages.Color = Color3.fromRGB(255, 248, 240)
	nuages.Parent = workspace.Terrain
end)

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
	sg.Brightness = 1.5 -- les textes lumineux « brillent » (halo du bloom)
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
local LARGEUR, PROFONDEUR, HAUTEUR = 420, 320, 52 -- murs assez hauts pour 2 étages
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
	   z=+13   │ ▓ │food│ ▓▓ │  PLACE   │ ▓▓ │ ▓▓ │ ▓ │   food = food court
	           │ ▓ │crt │ ▓▓ │ CENTRALE │ ▓▓ │ ▓▓ │ ▓ │
	  z=+124   │   ALLÉE SUD (toute la largeur)            │
	   z=+160  └───────── ENTRÉE (grande ouverte) ────────┘
	                        PARKING (dehors)
	   z=+250            ┌─────────────────────┐
	                     │     GARAGE VIP      │  ← bâtiment à part, on y apparaît
	   z=+330            └─────────────────────┘
]]

-- Les îlots de boutiques (x = centre ; 48 de large : 2 rangées dos à dos)
local ILOTS_X = { -136, -62, 62, 136 }
local ALLEE_NORD = { -150, -124 }
local ALLEE_SUD = { 124, 150 }

---------------------------------------------------------------------
-- SOL, MURS, VERRIÈRE, LUMIÈRES
---------------------------------------------------------------------
-- Grand carrelage clair et brillant (comme dans les vidéos)
local sol = bloc("SolCarrelage", Vector3.new(LARGEUR, 1, PROFONDEUR), CFrame.new(0, SOL - 0.5, 0), Color3.fromRGB(232, 228, 220), Enum.Material.Marble)
sol.Reflectance = 0.12 -- marbre poli (avec l'éclairage Future, on voit les reflets des néons)
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
-- Les portes vitrées sont ouvertes (coulissées sur les côtés) : on entre et sort en kart
for _, cote in ipairs({ -1, 1 }) do
	local porte = deco(bloc("PorteOuverte", Vector3.new(6, 16, 0.4), CFrame.new(cote * (largeurPortes / 2 + 3), SOL + 8, DZ + 2.4), Color3.fromRGB(170, 205, 230), Enum.Material.Glass))
	porte.Transparency = 0.55
end
-- Barrière de l'entrée : invisible en temps normal, fermée pendant une manche en ligne
local barriere = bloc("BarriereManche", Vector3.new(largeurPortes, 16, 1), CFrame.new(0, SOL + 8, DZ + 1), Color3.fromRGB(200, 30, 40), Enum.Material.ForceField)
barriere.Transparency = 1
barriere.CanCollide = false
local texteBarriere = texte(barriere, Enum.NormalId.Back, "🚨 MANCHE EN COURS 🚨", Color3.new(1, 1, 1))
texteBarriere.TextTransparency = 1
pancarte("EnseigneExterieure", Vector3.new(60, 6, 0.5), Vector3.new(0, SOL + 22, DZ + 2.3), Vector3.new(0, 0, 1), "✦ GOLDEN MALL ✦", NOIR_LUXE, OR)
bloc("DessusPortes", Vector3.new(largeurPortes, HAUTEUR - 16, 2), CFrame.new(0, SOL + 16 + (HAUTEUR - 16) / 2, DZ + 1), MUR_MALL, Enum.Material.Marble)
pancarte("Enseigne", Vector3.new(60, 6, 0.5), Vector3.new(0, SOL + 22, DZ - 0.3), Vector3.new(0, 0, -1), "✦ GOLDEN MALL ✦", NOIR_LUXE, OR)

-- 2 ÉTAGES : le plafond du rez-de-chaussée est le plancher du 1er étage.
-- Au centre, l'ATRIUM (au-dessus de la place centrale) est ouvert sur les 2 étages,
-- traversé par une PASSERELLE au 1er étage. Deux RAMPES permettent de monter en kart.
local HAUT_PLAFOND = 24 -- hauteur du rez-de-chaussée
local ETAGE = HAUT_PLAFOND + 1 -- dessus du plancher du 1er étage
local HAUT_PLAFOND_2 = ETAGE + 24 -- plafond du 1er étage
local ATRIUM_X = 30 -- l'atrium va de x = -30 à 30 (au 1er étage, une galerie de 8 passe devant les boutiques)
local ATRIUM_Z = 124 -- ... et de z = -124 à 124 (hors passerelle)
local PASSERELLE_Z = 13 -- la passerelle va de z = -13 à 13
local COULEUR_PLANCHER = Color3.fromRGB(236, 234, 228)
local plancher = Instance.new("Folder")
plancher.Name = "Plancher1erEtage"
plancher.Parent = carte
local function dalle(nom: string, x1: number, x2: number, z1: number, z2: number)
	local d = bloc(nom, Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, SOL + HAUT_PLAFOND + 0.5, (z1 + z2) / 2), COULEUR_PLANCHER, Enum.Material.Marble, plancher)
	d.CastShadow = false
	d.Reflectance = 0.1
	return d
end
dalle("DalleOuest", -DX - 2, -ATRIUM_X, -DZ - 2, DZ + 2)
dalle("DalleEst", ATRIUM_X, DX + 2, -DZ - 2, DZ + 2)
dalle("DalleNord", -ATRIUM_X, ATRIUM_X, -DZ - 2, -ATRIUM_Z)
dalle("DalleSud", -ATRIUM_X, ATRIUM_X, ATRIUM_Z, DZ + 2)
dalle("Passerelle", -ATRIUM_X, ATRIUM_X, -PASSERELLE_Z, PASSERELLE_Z)
local plafond = bloc("Plafond", Vector3.new(LARGEUR + 4, 1, PROFONDEUR + 4), CFrame.new(0, SOL + HAUT_PLAFOND_2 + 0.5, 0), Color3.fromRGB(245, 244, 240), Enum.Material.SmoothPlastic)
plafond.CastShadow = false
local puits = Instance.new("Folder")
puits.Name = "PuitsDeLumiere"
puits.Parent = carte
local function puitsDeLumiere(x: number, z: number, taille: Vector3, hauteur: number?)
	local h = hauteur or HAUT_PLAFOND
	if h == HAUT_PLAFOND and math.abs(x) < ATRIUM_X and math.abs(z) < ATRIUM_Z and math.abs(z) > PASSERELLE_Z then
		return -- pas de plafond ici au rez-de-chaussée : c'est l'atrium
	end
	local p = deco(bloc("PuitsDeLumiere", taille, CFrame.new(x, SOL + h - 0.05, z), Color3.fromRGB(150, 180, 205), Enum.Material.Neon, puits))
	p.CastShadow = false
	deco(bloc("CadrePuits", taille + Vector3.new(1, -0.05, 1), CFrame.new(x, SOL + h - 0.02, z), Color3.fromRGB(225, 225, 228), Enum.Material.Metal, puits))
end
for x = -175, 175, 50 do
	for _, h in ipairs({ HAUT_PLAFOND, HAUT_PLAFOND_2 }) do
		puitsDeLumiere(x, 0, Vector3.new(18, 0.1, 7), h) -- allée centrale
		puitsDeLumiere(x, -137, Vector3.new(18, 0.1, 7), h) -- allée nord
		puitsDeLumiere(x, 137, Vector3.new(18, 0.1, 7), h) -- allée sud
	end
end
for _, z in ipairs({ -110, -60, 60, 110 }) do
	puitsDeLumiere(0, z, Vector3.new(22, 0.1, 30), HAUT_PLAFOND_2) -- grande verrière de l'atrium
end

-- Lumières des allées
local lampes = Instance.new("Folder")
lampes.Name = "Lampes"
lampes.Parent = carte
local nombreSpots = 0
local function lampe(x: number, z: number, hauteur: number?)
	local h = hauteur or HAUT_PLAFOND
	if h == HAUT_PLAFOND and math.abs(x) < ATRIUM_X and math.abs(z) < ATRIUM_Z and math.abs(z) > PASSERELLE_Z then
		return
	end
	nombreSpots += 1
	local l = bloc("Spot", Vector3.new(2.2, 0.2, 2.2), CFrame.new(x, SOL + h - 0.1, z), Color3.fromRGB(200, 195, 185), Enum.Material.Neon, lampes)
	deco(l)
	l.CastShadow = false
	if nombreSpots % 2 == 0 then
		return -- 1 spot sur 2 éclaire vraiment (bon pour les petits téléphones)
	end
	local pl = Instance.new("SpotLight")
	pl.Face = Enum.NormalId.Bottom
	pl.Angle = 120
	pl.Range = 30
	pl.Brightness = 1.4
	pl.Color = Color3.fromRGB(255, 232, 195)
	pl.Shadows = nombreSpots % 6 == 1 -- quelques vraies ombres portées
	pl.Parent = l
end
for _, h in ipairs({ HAUT_PLAFOND, HAUT_PLAFOND_2 }) do
	for x = -200, 200, 25 do
		lampe(x, -137, h)
		lampe(x, 0, h)
		lampe(x, 137, h)
	end
	for _, x in ipairs({ -173, -99, 99, 173 }) do
		for _, z in ipairs({ -70, 70 }) do
			lampe(x, z, h)
		end
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
	superette = { Couleur = Color3.fromRGB(70, 185, 90), Sol = Color3.fromRGB(235, 235, 232), SolMat = Enum.Material.SmoothPlastic, Mur = BLANC },
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
	{ "tacos", "TACOS LOCO" }, { "vetements", "MAISON DORÉE" }, { "superette", "MARCHÉ FRAIS" },
	{ "jeux", "RETRO GAMES" }, { "superette", "ÉPICERIE DU MALL" },
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
	poste: (x: number, z: number, versX: number, versZ: number, role: string) -> (),
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
	-- Cabines d'essayage (2 cabines avec rideau)
	for _, x in ipairs({ 6.5, 11, 15.5 }) do
		o.meuble("CloisonCabine", Vector3.new(0.3, 8, 4.5), x, 4, 20.75, Color3.fromRGB(235, 230, 220), Enum.Material.SmoothPlastic)
	end
	for _, x in ipairs({ 8.75, 13.25 }) do
		deco(o.meuble("Rideau", Vector3.new(4.2, 7, 0.15), x, 4, 18.6, Color3.fromRGB(120, 40, 60), Enum.Material.Fabric))
		deco(o.meuble("MiroirCabine", Vector3.new(2.5, 5, 0.1), x, 4.5, 22.85, Color3.fromRGB(210, 230, 240), Enum.Material.Glass)).Reflectance = 0.5
	end
	local panneauCabines = deco(o.meuble("PanneauCabines", Vector3.new(8, 1.2, 0.2), 11, 8.8, 18.4, Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic))
	texte(panneauCabines, Enum.NormalId.Front, "CABINES D'ESSAYAGE", Color3.new(1, 1, 1))
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
	o.poste(-5, 20.6, 0, -1, "vendeur")
	o.poste(5, 20.6, 0, -1, "vendeur")
	o.poste(-4, 15, 0, 1, "client")
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
	o.poste(15.2, 15, -1, 0, "vendeur")
	o.poste(9, 12, 1, 0, "client")
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
	libre(o.meuble("FauteuilGamer", Vector3.new(2.4, 3.4, 2.4), -8, 1.7, 6, Color3.fromRGB(200, 30, 50), Enum.Material.Fabric))
	-- Bornes de démo avec écran
	for _, x in ipairs({ -4, 4 }) do
		o.meuble("BorneDemo", Vector3.new(2.4, 4, 1.5), x, 2, 20.5, Color3.fromRGB(30, 30, 40), Enum.Material.SmoothPlastic)
		deco(o.meuble("EcranDemo", Vector3.new(2, 1.4, 0.1), x, 4.6, 19.7, Color3.fromRGB(80, 200, 255), Enum.Material.Neon))
	end
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
	for _, x in ipairs({ -11, -6 }) do
		local ballon = libre(o.meuble("Ballon", Vector3.new(2, 2, 2), x, 1, 16, Color3.fromRGB(240, 120, 40), Enum.Material.SmoothPlastic))
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
	o.poste(0, 19.8, 0, -1, "vendeur")
	o.poste(3, 14.2, 0, 1, "client")
end

AMENAGEMENTS.superette = function(o)
	-- Rayons de produits
	for _, x in ipairs({ -11, -3 }) do
		o.meuble("Rayon", Vector3.new(3, 6.5, 10), x, 3.25, 14, Color3.fromRGB(200, 205, 210), Enum.Material.Metal)
		for etage = 0, 2 do
			for _, cote in ipairs({ -1, 1 }) do
				deco(o.meuble("Produits", Vector3.new(0.4, 1.4, 4.6), x + cote * 1.65, 1.2 + etage * 2, 11.6, couleurAuHasard(), Enum.Material.SmoothPlastic))
				deco(o.meuble("Produits", Vector3.new(0.4, 1.4, 4.6), x + cote * 1.65, 1.2 + etage * 2, 16.4, couleurAuHasard(), Enum.Material.SmoothPlastic))
			end
		end
	end
	-- Frigos à boissons vitrés au fond
	o.meuble("Frigos", Vector3.new(20, 8, 2.5), -4, 4, 22.6, BLANC, Enum.Material.SmoothPlastic)
	local vitreFrigo = deco(o.meuble("PortesFrigo", Vector3.new(19, 6.5, 0.15), -4, 4.2, 21.3, Color3.fromRGB(170, 215, 255), Enum.Material.Neon))
	vitreFrigo.Transparency = 0.35
	for etage = 0, 2 do
		for k = 0, 5 do
			deco(o.cylindre("Bouteille", 1.2, 0.5, -12.5 + k * 3.4, 1.8 + etage * 2.1, 21.8, couleurAuHasard(), Enum.Material.Glass))
		end
	end
	-- Étal de fruits
	o.meuble("Cagette", Vector3.new(5, 2.5, 4), 11, 1.25, 17, Color3.fromRGB(170, 120, 70), Enum.Material.WoodPlanks)
	local fruits = { Color3.fromRGB(255, 150, 30), Color3.fromRGB(200, 30, 40), Color3.fromRGB(120, 200, 60), Color3.fromRGB(250, 220, 50) }
	for k = 0, 5 do
		local f = deco(o.meuble("Fruit", Vector3.new(1.1, 1.1, 1.1), 9.5 + (k % 3) * 1.5, 3, 16.3 + math.floor(k / 3) * 1.4, fruits[(k % 4) + 1], Enum.Material.SmoothPlastic))
		f.Shape = Enum.PartType.Ball
	end
	-- Caisse avec tapis roulant
	o.meuble("Caisse", Vector3.new(3, 3.2, 8), 11.5, 1.6, 7, Color3.fromRGB(60, 65, 75), Enum.Material.SmoothPlastic)
	deco(o.meuble("Tapis", Vector3.new(2.6, 0.15, 5), 11.5, 3.25, 6, Color3.fromRGB(20, 20, 20), Enum.Material.Fabric))
	deco(o.meuble("Caisseenregistreuse", Vector3.new(1.5, 1, 1.4), 11.5, 3.7, 9.6, Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic))
	o.poste(14, 9.5, -1, 0, "vendeur")
	o.poste(8.5, 5, 1, 0, "client")
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
	if compteurBoutiques % 2 == 0 then
		local halo = Instance.new("SurfaceLight") -- la couleur de l'enseigne éclaire la façade et le sol
		halo.Face = Enum.NormalId.Front
		halo.Angle = 100
		halo.Range = 12
		halo.Brightness = 1.2
		halo.Color = style.Couleur
		halo.Parent = enseigne
	end

	-- Lumière intérieure
	local plafonnier = deco(bloc("Plafonnier", Vector3.new(12, 0.3, 4), ici(0, HAUT_B - 0.2, PROF_B / 2), Color3.fromRGB(215, 210, 200), Enum.Material.Neon, modele))
	local lumiere = Instance.new("PointLight")
	lumiere.Range = 20
	lumiere.Brightness = 0.6
	lumiere.Color = Color3.fromRGB(255, 245, 230)
	lumiere.Enabled = compteurBoutiques % 2 == 1 -- 1 boutique sur 2 (bon pour les petits téléphones)
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
		-- Emplacement d'une personne (le script PNJServer y place un vendeur ou un client)
		poste = function(x, z, versX, versZ, role)
			local pied = ici(x, 0, z).Position
			local regard = ici(x + versX, 0, z + versZ).Position
			local p = Instance.new("Part")
			p.Name = "PostePNJ"
			p.Size = Vector3.new(1, 0.1, 1)
			p.CFrame = CFrame.lookAt(pied, regard)
			p.Transparency = 1
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p:SetAttribute("Role", role)
			p:SetAttribute("Couleur", style.Couleur)
			p.Parent = modele
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

	-- La caisse (pour les boutiques qui n'ont pas déjà un comptoir)
	local AVEC_COMPTOIR = { burger = true, pizza = true, tacos = true, cafe = true, glaces = true, superette = true }
	if not AVEC_COMPTOIR[typeB] then
		outils.meuble("Caisse", Vector3.new(5, 3.4, 2.6), 11, 1.7, 9, style.Couleur, Enum.Material.SmoothPlastic)
		deco(outils.meuble("PlanCaisse", Vector3.new(5.4, 0.25, 3), 11, 3.5, 9, BLANC, Enum.Material.Marble))
		deco(outils.meuble("Caisseenregistreuse", Vector3.new(1.5, 0.9, 1.3), 12, 4.1, 9.3, Color3.fromRGB(30, 30, 34), Enum.Material.SmoothPlastic))
		local ecranCaisse = deco(outils.meuble("EcranCaisse", Vector3.new(1.3, 0.9, 0.1), 12, 5, 9.6, Color3.fromRGB(80, 170, 255), Enum.Material.Neon))
		ecranCaisse.CFrame *= CFrame.Angles(math.rad(-15), 0, 0)
		deco(outils.meuble("TerminalCarte", Vector3.new(0.5, 0.25, 0.8), 9.8, 3.75, 8.6, Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic))
		deco(outils.meuble("SacShopping", Vector3.new(1.2, 1.4, 0.6), 9.7, 4.3, 9.4, style.Couleur, Enum.Material.Fabric))
		outils.poste(11, 11.7, 0, -1, "vendeur")
		local POSTES_CLIENTS = {
			vetements = { -9, 14.5, 0, -1 }, jeux = { -12, 12, -1, 0 }, tech = { -8, 16.5, 0, -1 },
			sport = { 0, 20, 0, 1 }, bijoux = { -9, 9, 0, 1 }, parfum = { 5, 20, 0, 1 },
			jouets = { 6, 14, 1, 0 }, livres = { -12, 10, -1, 0 }, coiffeur = { 0, 19.5, 0, 1 },
		}
		local c = POSTES_CLIENTS[typeB]
		if c then
			outils.poste(c[1], c[2], c[3], c[4], if typeB == "coiffeur" then "assis" else "client")
		end
		outils.poste(11, 6.2, 0, 1, "client") -- un client qui paie à la caisse
	end
	if ferme then
		-- Boutique fermée : personne dedans
		for _, d in ipairs(modele:GetChildren()) do
			if d.Name == "PostePNJ" then
				d:Destroy()
			end
		end
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
local function rangee(xFacade: number, dehorsX: number, z1: number, z2: number, epaisseurRangee: number, hauteur: number?)
	local y = hauteur or 0
	local zCentres = if z1 < 0 then { z1 + 17, z1 + 51, z1 + 85 } else { z2 - 17, z2 - 51, z2 - 85 }
	for _, z in ipairs(zCentres) do
		local typeB, nom = enseigneSuivante()
		boutique(Vector3.new(xFacade, y, z), Vector3.new(dehorsX, 0, 0), typeB, nom)
	end
	-- Comble l'espace restant (côté allée centrale) avec un mur plein
	local reste = (z2 - z1) - 3 * LARG_B
	local zReste = if z1 < 0 then z2 - reste / 2 else z1 + reste / 2
	local xCentre = xFacade - dehorsX * epaisseurRangee / 2
	bloc("Mur", Vector3.new(epaisseurRangee, HAUT_B + 10, reste), CFrame.new(xCentre, y + SOL + (HAUT_B + 10) / 2, zReste), MUR_MALL, Enum.Material.Marble)
end

-- Îlots centraux : 2 rangées dos à dos (sauf le food court et le garage)
for _, cx in ipairs(ILOTS_X) do
	for i, moitie in ipairs(MOITIES) do
		local estFoodCourt = cx == -136 and i == 2
		if not estFoodCourt then
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

-- LE 1er ÉTAGE : les mêmes allées, avec d'autres boutiques
for _, cx in ipairs(ILOTS_X) do
	for _, moitie in ipairs(MOITIES) do
		rangee(cx - PROF_B, -1, moitie.z1, moitie.z2, PROF_B, ETAGE)
		rangee(cx + PROF_B, 1, moitie.z1, moitie.z2, PROF_B, ETAGE)
	end
end
for _, moitie in ipairs(MOITIES) do
	rangee(-DX + PROF_B, 1, moitie.z1, moitie.z2, PROF_B, ETAGE)
	rangee(DX - PROF_B, -1, moitie.z1, moitie.z2, PROF_B, ETAGE)
end

---------------------------------------------------------------------
-- LES TAPIS ROULANTS entre les 2 étages (au-dessus de la place centrale) :
-- celui de gauche (ouest) MONTE, celui de droite (est) DESCEND. Ils emportent
-- le kart tout seuls (le script du joueur lit l'attribut « Tapis »).
do
---------------------------------------------------------------------
local rampes = Instance.new("Folder")
rampes.Name = "Rampes"
rampes.Parent = carte
local RAMPE_BAS_Z, RAMPE_HAUT_Z = 107, PASSERELLE_Z
local RAMPE_LONGUEUR_SOL = RAMPE_BAS_Z - RAMPE_HAUT_Z
local PENTE = math.atan2(ETAGE, RAMPE_LONGUEUR_SOL)
local RAMPE_LONGUEUR = math.sqrt(RAMPE_LONGUEUR_SOL ^ 2 + ETAGE ^ 2)
local RAMPE_MILIEU_Z = (RAMPE_BAS_Z + RAMPE_HAUT_Z) / 2
local function rampe(xCentre: number, largeur: number, monte: boolean)
	local milieu = CFrame.new(xCentre, SOL + ETAGE / 2, RAMPE_MILIEU_Z) * CFrame.Angles(PENTE, 0, 0)
	-- Longueur exacte : le haut arrive pile au niveau de la passerelle (pas de marche qui bloque)
	local r = bloc("Rampe", Vector3.new(largeur, 1, RAMPE_LONGUEUR), milieu * CFrame.new(0, -0.52, 0), Color3.fromRGB(70, 72, 80), Enum.Material.DiamondPlate, rampes)
	r.CastShadow = true
	-- Le sens du tapis : vers le haut (LookVector = vers le 1er étage) ou vers le bas
	r:SetAttribute("Tapis", if monte then milieu.LookVector else -milieu.LookVector)
	r:SetAttribute("Longueur", RAMPE_LONGUEUR)
	-- Bandes jaunes sur les bords + garde-corps vitrés
	for _, cote in ipairs({ -1, 1 }) do
		deco(bloc("BandeJaune", Vector3.new(0.6, 0.06, RAMPE_LONGUEUR), milieu * CFrame.new(cote * (largeur / 2 - 0.5), 0.03, 0), Color3.fromRGB(250, 200, 20), Enum.Material.SmoothPlastic, rampes))
		local vitre = bloc("GardeCorps", Vector3.new(0.3, 3.2, RAMPE_LONGUEUR), milieu * CFrame.new(cote * (largeur / 2 + 0.15), 1.6, 0), Color3.fromRGB(200, 225, 245), Enum.Material.Glass, rampes)
		vitre.Transparency = 0.55
		deco(bloc("MainCourante", Vector3.new(0.5, 0.35, RAMPE_LONGUEUR), milieu * CFrame.new(cote * (largeur / 2 + 0.15), 3.3, 0), Color3.fromRGB(20, 20, 22), Enum.Material.Rubber, rampes))
		deco(bloc("Plinthe", Vector3.new(0.4, 0.8, RAMPE_LONGUEUR), milieu * CFrame.new(cote * (largeur / 2 + 0.15), 0.4, 0), Color3.fromRGB(200, 200, 205), Enum.Material.Metal, rampes))
	end
	-- Piliers sous la rampe
	for z = RAMPE_HAUT_Z + 15, RAMPE_BAS_Z - 20, 20 do
		local hauteurSousRampe = ETAGE * (RAMPE_BAS_Z - z) / RAMPE_LONGUEUR_SOL - 1
		if hauteurSousRampe > 2 then
			cylindreDebout("Pilier", hauteurSousRampe, 1.6, Vector3.new(xCentre, SOL + hauteurSousRampe / 2, z), Color3.fromRGB(235, 235, 238), Enum.Material.SmoothPlastic, rampes)
		end
	end
	-- Panneaux en bas et en haut
	pancarte("PanneauRampe", Vector3.new(largeur, 2, 0.3), Vector3.new(xCentre, SOL + 4.5, RAMPE_BAS_Z + 1), Vector3.new(0, 0, 1), if monte then "⬆ MONTÉE · 1er ÉTAGE" else "⛔ SENS INTERDIT", if monte then Color3.fromRGB(30, 120, 60) else Color3.fromRGB(170, 30, 30), Color3.new(1, 1, 1), rampes)
	pancarte("PanneauRampeHaut", Vector3.new(largeur, 2, 0.3), Vector3.new(xCentre, SOL + ETAGE + 4.5, RAMPE_HAUT_Z - 1), Vector3.new(0, 0, -1), if monte then "⛔ SENS INTERDIT" else "⬇ DESCENTE · REZ-DE-CHAUSSÉE", if monte then Color3.fromRGB(170, 30, 30) else Color3.fromRGB(30, 120, 60), Color3.new(1, 1, 1), rampes)
end
rampe(-22, 10, true) -- tapis qui monte
rampe(22, 10, false) -- tapis qui descend

-- Garde-corps vitrés autour de l'atrium au 1er étage (pour ne pas tomber)
local function gardeCorps(x1: number, x2: number, z1: number, z2: number)
	local longueur = math.max(math.abs(x2 - x1), math.abs(z2 - z1))
	local surX = math.abs(x2 - x1) > math.abs(z2 - z1)
	local taille = if surX then Vector3.new(longueur, 3.4, 0.3) else Vector3.new(0.3, 3.4, longueur)
	local centre = Vector3.new((x1 + x2) / 2, SOL + ETAGE + 1.7, (z1 + z2) / 2)
	local v = bloc("GardeCorps", taille, CFrame.new(centre), Color3.fromRGB(200, 225, 245), Enum.Material.Glass, rampes)
	v.Transparency = 0.55
	local tailleMain = if surX then Vector3.new(longueur, 0.3, 0.45) else Vector3.new(0.45, 0.3, longueur)
	deco(bloc("MainCourante", tailleMain, CFrame.new(centre + Vector3.new(0, 1.85, 0)), OR, Enum.Material.Foil, rampes))
	-- Ruban LED doré sous le bord du balcon (éclairage indirect, très « luxe »)
	local tailleLed = if surX then Vector3.new(longueur, 0.15, 0.35) else Vector3.new(0.35, 0.15, longueur)
	local led = deco(bloc("RubanLED", tailleLed, CFrame.new(centre.X, SOL + HAUT_PLAFOND - 0.08, centre.Z), Color3.fromRGB(255, 205, 130), Enum.Material.Neon, rampes))
	led.CastShadow = false
end
for _, sens in ipairs({ -1, 1 }) do
	-- côtés est et ouest de l'atrium (moitiés nord et sud)
	gardeCorps(sens * ATRIUM_X, sens * ATRIUM_X, -ATRIUM_Z, -PASSERELLE_Z)
	gardeCorps(sens * ATRIUM_X, sens * ATRIUM_X, PASSERELLE_Z, ATRIUM_Z)
end
gardeCorps(-ATRIUM_X, ATRIUM_X, -ATRIUM_Z, -ATRIUM_Z)
gardeCorps(-ATRIUM_X, ATRIUM_X, ATRIUM_Z, ATRIUM_Z)
gardeCorps(-ATRIUM_X, ATRIUM_X, -PASSERELLE_Z, -PASSERELLE_Z)
-- Côté sud de la passerelle : ouvert là où arrivent les rampes
gardeCorps(-ATRIUM_X, -27, PASSERELLE_Z, PASSERELLE_Z)
gardeCorps(-17, 17, PASSERELLE_Z, PASSERELLE_Z)
gardeCorps(27, ATRIUM_X, PASSERELLE_Z, PASSERELLE_Z)
pancarte("PanneauEtage", Vector3.new(16, 2.4, 0.3), Vector3.new(0, SOL + ETAGE + 6, 0), Vector3.new(0, 0, 1), "1er ÉTAGE ✦ BOUTIQUES", Color3.fromRGB(30, 30, 36), OR, rampes)

-- Façades décoratives : mur nord (hors aquarium) et mur sud (hors entrée)
for _, x in ipairs({ -185, -145, -105, 105, 145, 185 }) do
	facade(Vector3.new(x, 0, -DZ), Vector3.new(0, 0, 1), 36, ({ "LUNE BLEUE", "FALCON MONTRES", "SABLE & SOIE", "PERLE D'ORIENT", "DATTES ROYALES", "SKY OPTIC" })[(x + 185) // 40 % 6 + 1], Color3.fromRGB(255, 220, 160))
end
for _, x in ipairs({ -185, -145, -105, -65, 65, 105, 145, 185 }) do
	facade(Vector3.new(x, 0, DZ), Vector3.new(0, 0, -1), 36, ({ "OPTIQUE LUNE", "CHOCO LOCO", "ÉCLAT BEAUTÉ", "VOYAGES SOLEIL", "PHARMACIE", "PRESSING", "FLEURS DU DÉSERT", "CORDONNERIE" })[(x + 185) // 40 % 8 + 1], Color3.fromRGB(200, 230, 255))
end

end -- (bloc : garde le nombre de variables du script sous la limite de Roblox)
do
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
local lustre = cylindreDebout("Lustre", 0.8, 14, Vector3.new(0, SOL + HAUT_PLAFOND - 3, 0), Color3.fromRGB(255, 225, 150), Enum.Material.Neon)
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

for _, z in ipairs({ -105, -75, -45 }) do -- (côté sud : ce sont les rampes)
	palmier(-28, z)
	palmier(28, z)
end
for _, z in ipairs({ -90, -60 }) do
	banc(-28, z)
	banc(28, z)
end
kiosque(-75, "COQUES & CO", Color3.fromRGB(90, 160, 255))
kiosque(75, "BARBE À PAPA", Color3.fromRGB(255, 150, 200))

-- Des gens assis sur les bancs et un vendeur à chaque kiosque
local function posteLibre(position: Vector3, versOu: Vector3, role: string, couleur: Color3, hauteurSiege: number?)
	local p = Instance.new("Part")
	p.Name = "PostePNJ"
	p.Size = Vector3.new(1, 0.1, 1)
	p.CFrame = CFrame.lookAt(position, position + versOu)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p:SetAttribute("Role", role)
	p:SetAttribute("Couleur", couleur)
	if hauteurSiege then
		p:SetAttribute("HauteurSiege", hauteurSiege)
	end
	p.Parent = carte
end
for _, z in ipairs({ -91.5, -58.5 }) do
	posteLibre(Vector3.new(-28, SOL, z), Vector3.new(1, 0, 0), "assis", Color3.fromRGB(90, 120, 200), 1.6)
	posteLibre(Vector3.new(28, SOL, z), Vector3.new(-1, 0, 0), "assis", Color3.fromRGB(200, 90, 90), 1.6)
end
posteLibre(Vector3.new(7.8, SOL, -75), Vector3.new(-1, 0, 0), "vendeur", Color3.fromRGB(90, 160, 255))
posteLibre(Vector3.new(7.8, SOL, 75), Vector3.new(-1, 0, 0), "vendeur", Color3.fromRGB(255, 150, 200))

end -- (bloc : garde le nombre de variables du script sous la limite de Roblox)
---------------------------------------------------------------------
-- LA LIGNE DE DÉPART : à l'intérieur du mall, juste après l'entrée, au début
-- de la place centrale. Les karts sont derrière la ligne, face à la fontaine ;
-- le portique et ses 3 feux sont au-dessus. 3, 2, 1... PARTEZ !
---------------------------------------------------------------------
local LIGNE_Z = 122 -- la ligne (la fontaine est au nord, vers les z plus petits)
local ligneDepart = Instance.new("Model")
ligneDepart.Name = "LigneDepart"
ligneDepart.Parent = carte
for i = 0, 12 do
	for rangee = 0, 1 do
		local noir = (i + rangee) % 2 == 0
		deco(bloc("Damier", Vector3.new(2, 0.06, 2), CFrame.new(-12 + i * 2, SOL + 0.04, LIGNE_Z + rangee * 2), noir and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, ligneDepart))
	end
end
-- Portique au-dessus de la piste
for _, x in ipairs({ -12.4, 12.4 }) do
	bloc("PilierPortique", Vector3.new(1, 15, 1), CFrame.new(x, SOL + 7.5, LIGNE_Z - 4), Color3.fromRGB(30, 30, 34), Enum.Material.Metal, ligneDepart)
end
deco(bloc("PoutrePortique", Vector3.new(26, 1.4, 1.4), CFrame.new(0, SOL + 15, LIGNE_Z - 4), Color3.fromRGB(30, 30, 34), Enum.Material.Metal, ligneDepart))
local bandeauDepart = deco(bloc("BandeauDepart", Vector3.new(14, 2.2, 0.4), CFrame.new(0, SOL + 16.8, LIGNE_Z - 3.4), Color3.fromRGB(20, 20, 24), Enum.Material.SmoothPlastic, ligneDepart))
texte(bandeauDepart, Enum.NormalId.Back, "🏁 DÉPART 🏁", OR)
-- Les 3 feux, tournés vers les karts (le script du joueur les allume)
for i, x in ipairs({ -4, 0, 4 }) do
	deco(bloc("BoitierFeu", Vector3.new(2.8, 2.8, 1), CFrame.new(x, SOL + 12.6, LIGNE_Z - 4), Color3.fromRGB(15, 15, 18), Enum.Material.SmoothPlastic, ligneDepart))
	local feu = cylindreDebout("Feu" .. i, 0.25, 2, Vector3.new(x, SOL + 12.6, LIGNE_Z - 3.45), Color3.fromRGB(60, 12, 12), Enum.Material.Neon, ligneDepart)
	feu.CFrame = CFrame.new(feu.Position) * CFrame.Angles(0, math.rad(90), 0) -- disque tourné vers les karts
	deco(feu)
end

do
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

end -- (bloc : garde le nombre de variables du script sous la limite de Roblox)
do
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

end -- (bloc : garde le nombre de variables du script sous la limite de Roblox)
---------------------------------------------------------------------
-- SOL MOUILLÉ + panneaux jaunes « ATTENTION SOL GLISSANT »
---------------------------------------------------------------------
local COULEUR_EAU = Color3.fromRGB(110, 170, 225)

-- Étage où l'on pose les flaques et les obstacles (0 = rez-de-chaussée, ETAGE = 1er étage)
local NIVEAU = 0

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
	morceau(bloc("Eau", Vector3.new(tailleX, 0.1, tailleZ), CFrame.new(centre.X, SOL + NIVEAU + 0.09, centre.Y), COULEUR_EAU, Enum.Material.Glass, zone))
	for _ = 1, 3 do
		local d = random:NextNumber(3, 6)
		morceau(cylindreDebout("EauRonde", 0.1, d, Vector3.new(centre.X + random:NextNumber(-tailleX / 2, tailleX / 2), SOL + NIVEAU + 0.1, centre.Y + random:NextNumber(-tailleZ / 2, tailleZ / 2)), COULEUR_EAU, Enum.Material.Glass, zone))
	end
end

local function panneauJaune(position: Vector2, versOu: Vector3)
	local modele = Instance.new("Model")
	modele.Name = "PanneauSolGlissant"
	local pos = Vector3.new(position.X, 0, position.Y)
	local base = CFrame.lookAt(pos, pos + versOu)
	local jaune = Color3.fromRGB(255, 205, 0)
	local devant = bloc("Devant", Vector3.new(2.4, 3.4, 0.15), base * CFrame.new(0, SOL + NIVEAU + 1.7, -0.45) * CFrame.Angles(math.rad(15), 0, 0), jaune, Enum.Material.SmoothPlastic, modele)
	local derriere = bloc("Derriere", Vector3.new(2.4, 3.4, 0.15), base * CFrame.new(0, SOL + NIVEAU + 1.7, 0.45) * CFrame.Angles(math.rad(-15), 0, 0), jaune, Enum.Material.SmoothPlastic, modele)
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
	libre(cylindreDebout("Seau", 1.8, 2, Vector3.new(position.X, SOL + NIVEAU + 0.9, position.Y), Color3.fromRGB(255, 200, 0)))
	deco(bloc("Serpilliere", Vector3.new(0.2, 6, 0.2), CFrame.new(position.X + 0.6, SOL + NIVEAU + 3.5, position.Y) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(80, 140, 230)))
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
-- OBSTACLES DANS LE MALL (la plupart se renversent quand on les percute)
---------------------------------------------------------------------
local obstacles = Instance.new("Folder")
obstacles.Name = "Obstacles"
obstacles.Parent = carte

local function attacher(base: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
	p.Massless = true
end

local ORANGE = Color3.fromRGB(255, 110, 20)

-- 1) Slalom de plots orange (allée centrale, côté ouest)
local function plot(x: number, z: number)
	local m = Instance.new("Model")
	m.Name = "Plot"
	m.Parent = obstacles
	local base = libre(bloc("BasePlot", Vector3.new(1.8, 0.25, 1.8), CFrame.new(x, SOL + NIVEAU + 0.13, z), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, m))
	local cone = cylindreDebout("Cone", 2.2, 1.1, Vector3.new(x, SOL + NIVEAU + 1.35, z), ORANGE, Enum.Material.SmoothPlastic, m)
	cone.Anchored = false
	attacher(base, cone)
	local bande = deco(cylindreDebout("BandeBlanche", 0.4, 1.15, Vector3.new(x, SOL + NIVEAU + 1.7, z), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, m))
	bande.Anchored = false
	attacher(base, bande)
end
for k = 0, 9 do
	plot(-58 - k * 12, if k % 2 == 0 then 4 else -4)
end

-- 2) Caddies abandonnés (allée sud et allée nord)
local function caddie(x: number, z: number, angle: number)
	local m = Instance.new("Model")
	m.Name = "Caddie"
	m.Parent = obstacles
	local cf = CFrame.new(x, SOL + NIVEAU + 0.5, z) * CFrame.Angles(0, math.rad(angle), 0)
	local base = libre(bloc("Base", Vector3.new(2.2, 0.3, 3.2), cf, Color3.fromRGB(150, 155, 165), Enum.Material.Metal, m))
	local panier = bloc("Panier", Vector3.new(2.4, 1.8, 3), cf * CFrame.new(0, 1.3, 0), Color3.fromRGB(180, 185, 195), Enum.Material.DiamondPlate, m)
	panier.Transparency = 0.35
	panier.Anchored = false
	attacher(base, panier)
	local poignee = bloc("Poignee", Vector3.new(2.4, 0.25, 0.25), cf * CFrame.new(0, 2.4, 1.7), Color3.fromRGB(220, 40, 45), Enum.Material.SmoothPlastic, m)
	poignee.Anchored = false
	attacher(base, poignee)
	for _, dx in ipairs({ -0.9, 0.9 }) do
		for _, dz in ipairs({ -1.3, 1.3 }) do
			local roue = deco(bloc("Roulette", Vector3.new(0.3, 0.5, 0.5), cf * CFrame.new(dx, -0.35, dz), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, m))
			roue.Shape = Enum.PartType.Cylinder
			roue.Anchored = false
			attacher(base, roue)
		end
	end
	base.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.2)
end
for _, c in ipairs({ { -120, 132, 20 }, { -116, 137, -35 }, { -40, 141, 80 }, { 55, 133, 10 }, { 128, 142, -60 }, { 150, 135, 30 }, { -170, -143, 45 }, { 120, -143, -20 } }) do
	caddie(c[1], c[2], c[3])
end

-- 3) Palettes de cartons « PROMO » (allée nord) : on fonce dedans, ça vole !
local function palette(x: number, z: number)
	local m = Instance.new("Model")
	m.Name = "PalettePromo"
	m.Parent = obstacles
	bloc("Palette", Vector3.new(6, 0.5, 6), CFrame.new(x, SOL + NIVEAU + 0.25, z), Color3.fromRGB(190, 150, 100), Enum.Material.WoodPlanks, m)
	for etage = 0, 1 do
		for _, xz in ipairs({ { -1.4, -1.4 }, { 1.4, -1.4 }, { -1.4, 1.4 }, { 1.4, 1.4 } }) do
			libre(bloc("Carton", Vector3.new(2.6, 2.6, 2.6), CFrame.new(x + xz[1], SOL + NIVEAU + 1.85 + etage * 2.6, z + xz[2]), Color3.fromRGB(200, 160, 110), Enum.Material.Cardboard, m))
		end
	end
	libre(bloc("Carton", Vector3.new(2.6, 2.6, 2.6), CFrame.new(x, SOL + NIVEAU + 6.95, z), Color3.fromRGB(200, 160, 110), Enum.Material.Cardboard, m))
	pancarte("PanneauPromo", Vector3.new(6, 2.2, 0.3), Vector3.new(x, SOL + NIVEAU + 10.5, z), Vector3.new(0, 0, 1), "PROMO -50%", Color3.fromRGB(255, 210, 0), Color3.fromRGB(200, 20, 20), m)
end
for _, pos in ipairs({ Vector2.new(-150, -143), Vector2.new(-62, -143), Vector2.new(85, -143), Vector2.new(155, -131) }) do
	palette(pos.X, pos.Y)
end

-- 4) Panneaux « SOLDES » sur pied (allée centrale, côté est)
local function panneauxSoldes(xDepart: number)
for k = 0, 5 do
	local x = xDepart + k * 17
	local z = if k % 2 == 0 then 6 else -6
	local m = Instance.new("Model")
	m.Name = "PanneauSoldes"
	m.Parent = obstacles
	local pied = libre(bloc("Pied", Vector3.new(2, 0.3, 1.4), CFrame.new(x, SOL + NIVEAU + 0.15, z), Color3.fromRGB(40, 40, 45), Enum.Material.Metal, m))
	local affiche = bloc("Affiche", Vector3.new(2.4, 5, 0.15), CFrame.new(x, SOL + NIVEAU + 2.8, z) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(230, 30, 60), Enum.Material.SmoothPlastic, m)
	affiche.Anchored = false
	attacher(pied, affiche)
	texte(affiche, Enum.NormalId.Front, "SOLDES\n-70%", Color3.new(1, 1, 1))
	texte(affiche, Enum.NormalId.Back, "SOLDES\n-70%", Color3.new(1, 1, 1))
end
end
panneauxSoldes(85)

-- 5) Zone de travaux en chicane (allée étroite ouest, x ≈ -173)
local function barriere(x1: number, x2: number, z: number)
	local longueur = x2 - x1
	local m = Instance.new("Model")
	m.Name = "BarriereTravaux"
	m.Parent = obstacles
	for k = 0, math.floor(longueur / 3) - 1 do
		local rouge = k % 2 == 0
		bloc("Planche", Vector3.new(3, 1, 0.3), CFrame.new(x1 + 1.5 + k * 3, SOL + NIVEAU + 2.6, z), rouge and Color3.fromRGB(220, 30, 30) or Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, m)
	end
	for _, x in ipairs({ x1 + 0.3, x2 - 0.3 }) do
		bloc("PiedBarriere", Vector3.new(0.4, 3, 1.4), CFrame.new(x, SOL + NIVEAU + 1.5, z), Color3.fromRGB(240, 200, 20), Enum.Material.SmoothPlastic, m)
	end
end
barriere(-186, -174, 52)
barriere(-172, -160, 70)
barriere(-186, -174, 88)
pancarte("PanneauTravaux", Vector3.new(6, 3, 0.3), Vector3.new(-173, SOL + NIVEAU + 9, 40), Vector3.new(0, 0, -1), "🚧 TRAVAUX 🚧", Color3.fromRGB(250, 200, 20), Color3.fromRGB(20, 20, 20), obstacles)
plot(-166, 52)
plot(-180, 70)

-- 6) Autolaveuses : les machines de ménage circulent et laissent de l'eau derrière elles
local function autolaveuse(xA: number, xB: number, z: number, duree: number)
	local m = Instance.new("Model")
	m.Name = "Autolaveuse"
	m.Parent = obstacles
	local depart = CFrame.lookAt(Vector3.new(xA, SOL + NIVEAU, z), Vector3.new(xB, SOL + NIVEAU, z))
	local corps = bloc("Corps", Vector3.new(3.2, 3, 5), depart * CFrame.new(0, 1.8, 0), Color3.fromRGB(250, 200, 30), Enum.Material.SmoothPlastic, m)
	m.PrimaryPart = corps
	bloc("Siege", Vector3.new(2, 0.6, 1.6), depart * CFrame.new(0, 3.6, 1.2), Color3.fromRGB(30, 30, 30), Enum.Material.Fabric, m)
	bloc("Volant", Vector3.new(1.6, 0.2, 0.2), depart * CFrame.new(0, 4.2, -1), Color3.fromRGB(30, 30, 30), Enum.Material.SmoothPlastic, m)
	local brosse = bloc("Brosse", Vector3.new(0.6, 3.6, 3.6), depart * CFrame.new(0, 0.4, -2.2) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 60, 200), Enum.Material.SmoothPlastic, m)
	brosse.Shape = Enum.PartType.Cylinder
	local gyro = deco(bloc("Gyrophare", Vector3.new(0.5, 0.4, 0.5), depart * CFrame.new(0, 3.5, -2), ORANGE, Enum.Material.Neon, m))
	local lumiere = Instance.new("PointLight")
	lumiere.Color = ORANGE
	lumiere.Range = 10
	lumiere.Parent = gyro
	-- La traînée d'eau derrière la machine (elle fait glisser les karts !)
	local trainee = bloc("Trainee", Vector3.new(4, 0.1, 12), depart * CFrame.new(0, 0.1, 8.5), Color3.fromRGB(110, 170, 225), Enum.Material.Glass, m)
	trainee.Transparency = 0.45
	trainee.Reflectance = 0.25
	trainee.CanCollide = false
	trainee.CanTouch = false
	trainee:SetAttribute("Mouille", true)
	local panneau = pancarte("Attention", Vector3.new(3, 1.2, 0.2), (depart * CFrame.new(0, 3, 2.6)).Position, depart.LookVector * -1, "⚠ NETTOYAGE", Color3.fromRGB(255, 205, 0), Color3.fromRGB(20, 20, 20), m)
	panneau.CFrame = depart * CFrame.new(0, 3, 2.6) * CFrame.Angles(0, math.rad(180), 0)

	-- Aller-retour sans fin
	local position = Instance.new("CFrameValue")
	position.Value = m:GetPivot()
	position.Changed:Connect(function(v)
		m:PivotTo(v)
	end)
	task.spawn(function()
		local aller = true
		while m.Parent do
			local actuel = m:GetPivot()
			local cible = actuel.Position + Vector3.new((if aller then xB - xA else xA - xB), 0, 0)
			local tween = TweenService:Create(position, TweenInfo.new(duree, Enum.EasingStyle.Linear), { Value = CFrame.lookAt(actuel.Position, cible) - actuel.Position + cible })
			position.Value = CFrame.lookAt(actuel.Position, cible)
			tween:Play()
			tween.Completed:Wait()
			task.wait(1)
			aller = not aller
		end
	end)
end
autolaveuse(-185, -40, -131, 18) -- allée nord

---------------------------------------------------------------------
-- LE 1er ÉTAGE : obstacles, flaques et autolaveuse
---------------------------------------------------------------------
NIVEAU = ETAGE
for k = 0, 7 do
	plot(-58 - k * 15, if k % 2 == 0 then 5 else -5) -- slalom, allée centrale ouest
end
for _, c in ipairs({ { 60, 135, 25 }, { 130, 140, -40 }, { -120, -134, 60 }, { 170, -140, 10 } }) do
	caddie(c[1], c[2], c[3])
end
palette(-172, 140)
palette(150, -143)
panneauxSoldes(45)
flaque(Vector2.new(170, 0), 26, 10)
panneauJaune(Vector2.new(155, 4), Vector3.new(-1, 0, 0))
panneauJaune(Vector2.new(185, -4), Vector3.new(1, 0, 0))
flaque(Vector2.new(-99, 60), 12, 24)
panneauJaune(Vector2.new(-99, 46), Vector3.new(0, 0, -1))
autolaveuse(-150, 150, 137, 30) -- allée sud du 1er étage
NIVEAU = 0

do
---------------------------------------------------------------------
-- DEHORS : le parking devant l'entrée du mall
---------------------------------------------------------------------
local dehors = Instance.new("Folder")
dehors.Name = "Exterieur"
dehors.Parent = carte
local EXT_Z1, EXT_Z2 = DZ + 2, DZ + 182 -- de la façade du mall jusqu'au fond du terrain
local EXT_CZ = (EXT_Z1 + EXT_Z2) / 2
bloc("SolParking", Vector3.new(LARGEUR, 1, EXT_Z2 - EXT_Z1), CFrame.new(0, SOL - 0.5, EXT_CZ), Color3.fromRGB(150, 150, 156), Enum.Material.Concrete, dehors)
-- Places de parking (lignes blanches) des deux côtés de l'allée centrale
for _, zLigne in ipairs({ DZ + 30, DZ + 62 }) do
	for x = -190, 190, 12 do
		if math.abs(x) > 34 then
			deco(bloc("LigneParking", Vector3.new(0.35, 0.05, 14), CFrame.new(x, SOL + 0.03, zLigne), Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, dehors))
		end
	end
end
-- Flèches au sol vers le garage
for _, z in ipairs({ DZ + 55 }) do
	local f = deco(bloc("Fleche", Vector3.new(6, 0.05, 6), CFrame.new(0, SOL + 0.03, z), Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, dehors))
	texte(f, Enum.NormalId.Top, "▼ GARAGE ▼", Color3.fromRGB(60, 60, 70))
end
-- Murets autour du terrain + palmiers
bloc("MuretOuest", Vector3.new(2, 6, EXT_Z2 - EXT_Z1), CFrame.new(-DX - 1, SOL + 3, EXT_CZ), BLANC, Enum.Material.Concrete, dehors)
bloc("MuretEst", Vector3.new(2, 6, EXT_Z2 - EXT_Z1), CFrame.new(DX + 1, SOL + 3, EXT_CZ), BLANC, Enum.Material.Concrete, dehors)
bloc("MuretSud", Vector3.new(LARGEUR + 4, 6, 2), CFrame.new(0, SOL + 3, EXT_Z2 + 1), BLANC, Enum.Material.Concrete, dehors)
-- Lampadaires
for _, x in ipairs({ -150, -75, 75, 150 }) do
	for _, z in ipairs({ DZ + 20, DZ + 75 }) do
		deco(cylindreDebout("Poteau", 16, 0.8, Vector3.new(x, SOL + 8, z), Color3.fromRGB(60, 60, 65), Enum.Material.Metal, dehors))
		local tete = deco(bloc("Lanterne", Vector3.new(3, 0.6, 1.6), CFrame.new(x, SOL + 16, z), Color3.fromRGB(255, 245, 220), Enum.Material.Neon, dehors))
		local pl = Instance.new("PointLight")
		pl.Range = 45
		pl.Brightness = 2
		pl.Color = Color3.fromRGB(255, 240, 210)
		pl.Parent = tete
	end
end

end -- (bloc : garde le nombre de variables du script sous la limite de Roblox)
---------------------------------------------------------------------
-- LE GARAGE VIP : un grand bâtiment à part, au bout du parking.
-- On y apparaît, on y personnalise son kart, puis on part vers le mall.
---------------------------------------------------------------------
local garage = Instance.new("Model")
garage.Name = "GarageVIP"
garage.Parent = carte
local G_X1, G_X2 = -90, 90
local G_Z1, G_Z2 = DZ + 90, DZ + 170 -- devant (côté mall) / fond
local G_CX, G_CZ = (G_X1 + G_X2) / 2, (G_Z1 + G_Z2) / 2
local G_HAUT = 18
local LARG_ENTREE = 50
local VIOLET = Color3.fromRGB(170, 80, 255)
local MUR_GARAGE = Color3.fromRGB(48, 48, 56) -- anthracite, façon showroom

local solGarage = bloc("SolGarage", Vector3.new(G_X2 - G_X1, 0.1, G_Z2 - G_Z1), CFrame.new(G_CX, SOL + 0.05, G_CZ), Color3.fromRGB(58, 58, 66), Enum.Material.SmoothPlastic, garage)
solGarage.Reflectance = 0.35 -- sol époxy brillant
bloc("MurFondGarage", Vector3.new(G_X2 - G_X1, G_HAUT, 1), CFrame.new(G_CX, SOL + G_HAUT / 2, G_Z2 - 0.5), MUR_GARAGE, Enum.Material.SmoothPlastic, garage)
bloc("MurOuestGarage", Vector3.new(1, G_HAUT, G_Z2 - G_Z1), CFrame.new(G_X1 + 0.5, SOL + G_HAUT / 2, G_CZ), MUR_GARAGE, Enum.Material.SmoothPlastic, garage)
bloc("MurEstGarage", Vector3.new(1, G_HAUT, G_Z2 - G_Z1), CFrame.new(G_X2 - 0.5, SOL + G_HAUT / 2, G_CZ), MUR_GARAGE, Enum.Material.SmoothPlastic, garage)
-- Façade vitrée avec une grande entrée au milieu
local largFacade = ((G_X2 - G_X1) - LARG_ENTREE) / 2
for _, cote in ipairs({ -1, 1 }) do
	local vitre = bloc("VitreGarage", Vector3.new(largFacade, G_HAUT - 4, 0.5), CFrame.new(cote * (LARG_ENTREE / 2 + largFacade / 2), SOL + (G_HAUT - 4) / 2, G_Z1), Color3.fromRGB(200, 220, 240), Enum.Material.Glass, garage)
	vitre.Transparency = 0.5
end
bloc("LinteauGarage", Vector3.new(G_X2 - G_X1, 4, 1), CFrame.new(G_CX, SOL + G_HAUT - 2, G_Z1), Color3.fromRGB(30, 30, 36), Enum.Material.SmoothPlastic, garage)
bloc("ToitGarage", Vector3.new(G_X2 - G_X1 + 2, 1, G_Z2 - G_Z1 + 2), CFrame.new(G_CX, SOL + G_HAUT + 0.5, G_CZ), Color3.fromRGB(26, 26, 30), Enum.Material.SmoothPlastic, garage).CastShadow = false
pancarte("EnseigneGarage", Vector3.new(44, 3.5, 0.5), Vector3.new(G_CX, SOL + G_HAUT - 2, G_Z1 - 0.8), Vector3.new(0, 0, -1), "★ GARAGE VIP ★", Color3.fromRGB(30, 30, 36), Color3.fromRGB(210, 160, 255), garage)
-- Bandes néon violettes et éclairage bien lumineux
for _, x in ipairs({ G_X1 + 1.2, G_X2 - 1.2 }) do
	deco(bloc("NeonMur", Vector3.new(0.3, 0.4, G_Z2 - G_Z1 - 4), CFrame.new(x, SOL + 10, G_CZ), VIOLET, Enum.Material.Neon, garage))
end
deco(bloc("NeonMur", Vector3.new(G_X2 - G_X1 - 4, 0.4, 0.3), CFrame.new(G_CX, SOL + 10, G_Z2 - 1.2), VIOLET, Enum.Material.Neon, garage))
for x = -60, 60, 40 do
	for _, z in ipairs({ G_Z1 + 20, G_Z1 + 55 }) do
		local panneauLumiere = deco(bloc("Eclairage", Vector3.new(14, 0.3, 3), CFrame.new(x, SOL + G_HAUT - 0.3, z), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, garage))
		local pl = Instance.new("PointLight")
		pl.Range = 34
		pl.Brightness = 0.8
		pl.Parent = panneauLumiere
	end
end

-- Plateau tournant au centre (ton kart s'affiche dessus)
local POSITION_PLATEAU = Vector3.new(0, SOL, G_CZ + 8)
local plateau = cylindreDebout("PlateauTournant", 1, 26, POSITION_PLATEAU + Vector3.new(0, 0.5, 0), Color3.fromRGB(45, 45, 55), Enum.Material.Metal, garage)
deco(cylindreDebout("AnneauNeon", 0.9, 27, POSITION_PLATEAU + Vector3.new(0, 0.45, 0), VIOLET, Enum.Material.Neon, garage))
local spot = Instance.new("PointLight")
spot.Range = 26
spot.Brightness = 2.5
spot.Parent = plateau

-- Vitrine des karts à débloquer (ça donne envie de monter de niveau !)
local function kartExpose(typeKart: string, couleur: string, neon: string, position: Vector3)
	cylindreDebout("Podium", 1.4, 13, position + Vector3.new(0, 0.7, 0), Color3.fromRGB(30, 30, 36), Enum.Material.Metal, garage)
	deco(cylindreDebout("AnneauPodium", 1.3, 13.6, position + Vector3.new(0, 0.65, 0), OR, Enum.Material.Neon, garage))
	local perso = table.clone(Config.PersoParDefaut)
	perso.Kart = typeKart
	perso.Carrosserie = couleur
	perso.Neon = neon
	perso.Finition = if typeKart == "ProDubai" then "Chrome" else "Métallisé"
	local expose = KartBuilder.Construire(perso, CFrame.lookAt(position + Vector3.new(0, 2, 0), position + Vector3.new(0, 2, 0) + Vector3.new(0, 0, -1)), true)
	expose.Name = "Vitrine_" .. typeKart
	expose.Parent = garage
	local info = Config.Karts[typeKart]
	local titreKart = if info.Exclusif then ("✨ %s · EXCLUSIF"):format(string.upper(info.Nom)) else ("%s · NIVEAU %d"):format(info.Nom, info.Niveau)
	pancarte("PanneauKart", Vector3.new(14, 2.4, 0.3), position + Vector3.new(0, 8, 0), Vector3.new(0, 0, -1), titreKart, if info.Exclusif then Color3.fromRGB(120, 40, 200) else Color3.fromRGB(30, 30, 36), if info.Exclusif then Color3.new(1, 1, 1) else OR, garage)
	if info.Exclusif then
		-- Socle lumineux arc-en-ciel sous le kart exclusif
		local socle = deco(cylindreDebout("SocleExclusif", 0.3, 11, position + Vector3.new(0, 0.15, 0), Color3.fromRGB(255, 120, 230), Enum.Material.Neon, garage))
		socle:SetAttribute("ArcEnCiel", true)
		local lumiere = Instance.new("PointLight")
		lumiere.Color = Color3.fromRGB(220, 120, 255)
		lumiere.Range = 16
		lumiere.Brightness = 2
		lumiere.Parent = socle
	end
end
kartExpose("Chariot", "Rouge", "Rose", Vector3.new(-62, SOL, G_Z2 - 16))
kartExpose("Bolide", "Jaune", "Vert", Vector3.new(-32, SOL, G_Z2 - 12))
kartExpose("ProDubai", "Or", "Or", Vector3.new(32, SOL, G_Z2 - 12))
kartExpose("Galaxie", "Rose", "Arc-en-ciel", Vector3.new(62, SOL, G_Z2 - 16))

---------------------------------------------------------------------
-- LA DÉCO DU GARAGE VIP
--   à gauche (ouest) : le salon VIP   ·   à droite (est) : l'atelier mécanique
--   au fond : écran géant + karts exposés   ·   devant : tapis rouge + drapeaux
do
---------------------------------------------------------------------
local decoGarage = Instance.new("Folder")
decoGarage.Name = "DecoGarage"
decoGarage.Parent = garage

local function d(nom: string, taille: Vector3, position: Vector3, couleur: Color3, matiere: Enum.Material?, solide: boolean?): Part
	local p = bloc(nom, taille, CFrame.new(position), couleur, matiere, decoGarage)
	if not solide then
		deco(p)
	end
	return p
end
local function dCyl(nom: string, hauteur: number, diametre: number, position: Vector3, couleur: Color3, matiere: Enum.Material?, solide: boolean?): Part
	local p = cylindreDebout(nom, hauteur, diametre, position, couleur, matiere, decoGarage)
	if not solide then
		deco(p)
	end
	return p
end
local function boule(nom: string, diametre: number, position: Vector3, couleur: Color3, matiere: Enum.Material?): Part
	local p = d(nom, Vector3.new(diametre, diametre, diametre), position, couleur, matiere)
	p.Shape = Enum.PartType.Ball
	return p
end

local CUIR = Color3.fromRGB(24, 24, 28)
local BOIS = Color3.fromRGB(150, 105, 70)
local ROUGE_OUTILS = Color3.fromRGB(205, 35, 40)
local JAUNE_SECURITE = Color3.fromRGB(250, 200, 20)
local y0 = SOL + 0.1 -- dessus du sol du garage

-- 1) SOL : ligne de départ en damier devant la porte + lignes jaunes des zones
for i = 0, 12 do
	for rangee = 0, 1 do
		local noir = (i + rangee) % 2 == 0
		d("Damier", Vector3.new(4, 0.06, 2), Vector3.new(-24 + i * 4, y0 + 0.03, G_Z1 + 6 + rangee * 2), noir and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(240, 240, 240))
	end
end
for _, x in ipairs({ -45, 45 }) do
	d("LigneJaune", Vector3.new(0.5, 0.06, G_Z2 - G_Z1 - 12), Vector3.new(x, y0 + 0.03, G_CZ + 2), JAUNE_SECURITE)
end

-- 2) MUR DU FOND : écran géant + lames de bois de chaque côté
d("CadreEcran", Vector3.new(44, 12, 0.6), Vector3.new(0, SOL + 11, G_Z2 - 1.3), Color3.fromRGB(12, 12, 14), Enum.Material.SmoothPlastic)
local ecranGeant = d("EcranGeant", Vector3.new(42, 10.4, 0.2), Vector3.new(0, SOL + 11, G_Z2 - 1.7), Color3.fromRGB(30, 22, 70), Enum.Material.Neon)
texte(ecranGeant, Enum.NormalId.Front, "GOLDEN MALL DRIFT\n★ GARAGE VIP ★", OR)
for x = -86, 86, 2.4 do
	if math.abs(x) > 24 then
		d("LameBois", Vector3.new(1.2, 13, 0.4), Vector3.new(x, SOL + 9.5, G_Z2 - 1.2), BOIS, Enum.Material.WoodPlanks)
	end
end

-- 3) PLAFOND : poutres métalliques + rubans LED, projecteurs sur le plateau
for z = G_Z1 + 10, G_Z2 - 10, 20 do
	d("Poutre", Vector3.new(G_X2 - G_X1, 1.2, 1.2), Vector3.new(0, SOL + G_HAUT - 1.5, z), Color3.fromRGB(70, 70, 78), Enum.Material.Metal)
	d("RubanLED", Vector3.new(G_X2 - G_X1 - 2, 0.15, 0.3), Vector3.new(0, SOL + G_HAUT - 2.2, z), Color3.fromRGB(220, 200, 255), Enum.Material.Neon)
end
for _, decalage in ipairs({ Vector3.new(12, 0, 12), Vector3.new(-12, 0, 12), Vector3.new(12, 0, -12), Vector3.new(-12, 0, -12) }) do
	local pos = POSITION_PLATEAU + decalage + Vector3.new(0, G_HAUT - 3, 0)
	local projecteur = bloc("Projecteur", Vector3.new(1.4, 1.4, 2), CFrame.lookAt(pos, POSITION_PLATEAU), Color3.fromRGB(20, 20, 22), Enum.Material.Metal, decoGarage)
	deco(projecteur)
	local faisceau = Instance.new("SpotLight")
	faisceau.Face = Enum.NormalId.Front
	faisceau.Angle = 45
	faisceau.Range = 30
	faisceau.Brightness = 2.5
	faisceau.Color = Color3.fromRGB(255, 245, 230)
	faisceau.Parent = projecteur
end

-- 4) LE SALON VIP (côté ouest)
local SX, SZ = -68, 272 -- centre du salon
d("Tapis", Vector3.new(34, 0.06, 28), Vector3.new(SX, y0 + 0.03, SZ), Color3.fromRGB(90, 40, 130), Enum.Material.Fabric)
-- Canapé en L
d("CanapeAssise", Vector3.new(16, 2, 4.5), Vector3.new(SX, SOL + 1, SZ + 11), CUIR, Enum.Material.Fabric, true)
d("CanapeDossier", Vector3.new(16, 3.2, 1.2), Vector3.new(SX, SOL + 2.6, SZ + 13.4), CUIR, Enum.Material.Fabric, true)
d("CanapeAssise", Vector3.new(4.5, 2, 14), Vector3.new(SX - 14, SOL + 1, SZ + 1), CUIR, Enum.Material.Fabric, true)
d("CanapeDossier", Vector3.new(1.2, 3.2, 14), Vector3.new(SX - 16.4, SOL + 2.6, SZ + 1), CUIR, Enum.Material.Fabric, true)
for i = -1, 1 do
	d("Coussin", Vector3.new(4, 1.6, 0.8), Vector3.new(SX + i * 5, SOL + 2.6, SZ + 12.4), OR, Enum.Material.Fabric)
end
-- Table basse en verre
d("TableVerre", Vector3.new(9, 0.3, 5), Vector3.new(SX, SOL + 1.6, SZ + 2), Color3.fromRGB(200, 220, 235), Enum.Material.Glass, true).Transparency = 0.5
for _, dx in ipairs({ -4, 4 }) do
	d("PiedTable", Vector3.new(0.3, 1.5, 4.6), Vector3.new(SX + dx, SOL + 0.8, SZ + 2), OR, Enum.Material.Foil)
end
dCyl("Canette", 0.8, 0.45, Vector3.new(SX - 2, SOL + 2.15, SZ + 2), Color3.fromRGB(220, 40, 40), Enum.Material.Metal)
dCyl("Canette", 0.8, 0.45, Vector3.new(SX + 1.5, SOL + 2.15, SZ + 1.4), Color3.fromRGB(40, 160, 240), Enum.Material.Metal)
-- Borne d'arcade
d("Arcade", Vector3.new(3, 6.5, 3), Vector3.new(-86.5, SOL + 3.25, 258), Color3.fromRGB(30, 20, 60), Enum.Material.SmoothPlastic, true)
local ecranArcade = d("EcranArcade", Vector3.new(0.1, 2.2, 2.4), Vector3.new(-84.95, SOL + 4.6, 258), Color3.fromRGB(60, 200, 255), Enum.Material.Neon)
texte(ecranArcade, Enum.NormalId.Right, "🏁 DRIFT\nARCADE", Color3.new(1, 1, 1))
d("NeonArcade", Vector3.new(0.1, 0.2, 3), Vector3.new(-84.95, SOL + 6.4, 258), Color3.fromRGB(255, 60, 200), Enum.Material.Neon)
-- Frigo à boissons
d("Frigo", Vector3.new(3, 6, 3), Vector3.new(-86.5, SOL + 3, 264), Color3.fromRGB(235, 235, 240), Enum.Material.SmoothPlastic, true)
local porteFrigo = d("PorteFrigo", Vector3.new(0.1, 5, 2.6), Vector3.new(-84.95, SOL + 3, 264), Color3.fromRGB(160, 210, 255), Enum.Material.Neon)
porteFrigo.Transparency = 0.3
-- Étagère à trophées sur le mur ouest
for etage = 0, 1 do
	d("EtagereTrophees", Vector3.new(1.4, 0.3, 18), Vector3.new(-88.6, SOL + 6 + etage * 4, 305), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
	for k = 0, 3 do
		local z = 298 + k * 4.5
		local y = SOL + 6.15 + etage * 4
		dCyl("SocleTrophee", 0.5, 1, Vector3.new(-88.6, y + 0.25, z), Color3.fromRGB(20, 20, 20), Enum.Material.Marble)
		dCyl("CoupeTrophee", 1.4, 0.7, Vector3.new(-88.6, y + 1.2, z), OR, Enum.Material.Foil)
		boule("CoupeHaut", 1.3, Vector3.new(-88.6, y + 2.2, z), OR, Enum.Material.Foil)
	end
end
pancarte("EnseigneSalon", Vector3.new(16, 3, 0.3), Vector3.new(-89.2, SOL + 13, SZ), Vector3.new(1, 0, 0), "LOUNGE VIP", Color3.fromRGB(20, 20, 24), Color3.fromRGB(210, 160, 255), decoGarage)
-- Plantes
for _, pos in ipairs({ Vector3.new(-50, 0, 258), Vector3.new(-50, 0, 289), Vector3.new(-86, 0, 288) }) do
	dCyl("Pot", 2.4, 2.6, Vector3.new(pos.X, SOL + 1.2, pos.Z), Color3.fromRGB(240, 240, 240), Enum.Material.Marble, true)
	boule("Feuillage", 3.6, Vector3.new(pos.X, SOL + 3.8, pos.Z), Color3.fromRGB(50, 140, 70), Enum.Material.Grass)
end

-- 5) L'ATELIER MÉCANIQUE (côté est)
-- Pont élévateur avec un kart soulevé
local PX, PZ = 68, 282
for _, dx in ipairs({ -7, 7 }) do
	d("PilierPont", Vector3.new(1.6, 12, 1.6), Vector3.new(PX + dx, SOL + 6, PZ), ROUGE_OUTILS, Enum.Material.Metal, true)
	d("BrasPont", Vector3.new(5.5, 0.5, 0.8), Vector3.new(PX + dx * 0.55, SOL + 4.6, PZ - 1.5), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	d("BrasPont", Vector3.new(5.5, 0.5, 0.8), Vector3.new(PX + dx * 0.55, SOL + 4.6, PZ + 1.5), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
end
d("TraverseePont", Vector3.new(15.6, 1, 1.6), Vector3.new(PX, SOL + 12.5, PZ), ROUGE_OUTILS, Enum.Material.Metal)
do
	local persoPont = table.clone(Config.PersoParDefaut)
	persoPont.Carrosserie = "Orange"
	persoPont.Neon = "Aucun"
	local kartPont = KartBuilder.Construire(persoPont, CFrame.new(PX, SOL + 5.6, PZ) * CFrame.Angles(0, math.rad(90), 0), true)
	kartPont.Name = "KartSurLePont"
	kartPont.Parent = decoGarage
end
-- Bandes de sécurité jaunes et noires autour du pont
for i = 0, 7 do
	d("BandeDanger", Vector3.new(2, 0.06, 0.8), Vector3.new(PX - 8 + i * 2.3, y0 + 0.03, PZ - 6), i % 2 == 0 and JAUNE_SECURITE or Color3.fromRGB(20, 20, 20))
	d("BandeDanger", Vector3.new(2, 0.06, 0.8), Vector3.new(PX - 8 + i * 2.3, y0 + 0.03, PZ + 6), i % 2 == 0 and JAUNE_SECURITE or Color3.fromRGB(20, 20, 20))
end
-- Servantes d'outils (armoires rouges à tiroirs) contre le mur est
for k = 0, 2 do
	local z = 300 + k * 7
	d("Servante", Vector3.new(3, 5, 6), Vector3.new(87, SOL + 2.5, z), ROUGE_OUTILS, Enum.Material.Metal, true)
	for t = 0, 3 do
		d("Tiroir", Vector3.new(0.1, 0.15, 5), Vector3.new(85.45, SOL + 1 + t * 1.1, z), Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
	end
end
-- Établi + panneau à outils
d("Etabli", Vector3.new(4, 3.5, 12), Vector3.new(86.5, SOL + 1.75, 322), BOIS, Enum.Material.WoodPlanks, true)
d("PanneauOutils", Vector3.new(0.3, 6, 12), Vector3.new(88.7, SOL + 7.5, 322), Color3.fromRGB(120, 125, 130), Enum.Material.DiamondPlate)
for k = 0, 4 do
	d("Outil", Vector3.new(0.2, 2.2 - (k % 2) * 0.6, 0.35), Vector3.new(88.45, SOL + 7.5, 317.5 + k * 2.2), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
end
-- Râtelier à pneus mural
for etage = 0, 1 do
	local y = SOL + 3 + etage * 4.5
	d("RatelierPneus", Vector3.new(2.6, 0.3, 18), Vector3.new(87.6, y, 264), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	for k = 0, 4 do
		local pneu = bloc("Pneu", Vector3.new(1.1, 3, 3), CFrame.new(87.6, y + 1.65, 257 + k * 3.4) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(22, 22, 22), Enum.Material.Rubber, decoGarage)
		pneu.Shape = Enum.PartType.Cylinder
		deco(pneu)
	end
end
-- Fûts d'huile et compresseur
for k, couleur in ipairs({ Color3.fromRGB(30, 90, 200), ROUGE_OUTILS, JAUNE_SECURITE }) do
	dCyl("Fut", 3.4, 2.4, Vector3.new(52 + k * 2.7, SOL + 1.7, 258), couleur, Enum.Material.Metal, true)
end
d("Compresseur", Vector3.new(3, 2.4, 2), Vector3.new(80, SOL + 1.2, 296), ROUGE_OUTILS, Enum.Material.Metal, true)
pancarte("EnseigneAtelier", Vector3.new(16, 3, 0.3), Vector3.new(89.2, SOL + 13, 282), Vector3.new(-1, 0, 0), "🔧 ATELIER", Color3.fromRGB(20, 20, 24), JAUNE_SECURITE, decoGarage)

-- 6) BANNIÈRES suspendues
for _, b in ipairs({ { -38, "VIP" }, { 38, "DRIFT" }, { -14, "★" }, { 14, "★" } }) do
	local banniere = d("Banniere", Vector3.new(5, 7, 0.15), Vector3.new(b[1], SOL + 12.5, G_Z1 + 14), Color3.fromRGB(70, 30, 120), Enum.Material.Fabric)
	texte(banniere, Enum.NormalId.Front, b[2], OR)
	texte(banniere, Enum.NormalId.Back, b[2], OR)
	d("TringleBanniere", Vector3.new(5.6, 0.25, 0.25), Vector3.new(b[1], SOL + 16.1, G_Z1 + 14), OR, Enum.Material.Foil)
end

-- 7) DEVANT LE GARAGE : tapis rouge, potelets dorés, drapeaux, néon autour de la porte
d("TapisRouge", Vector3.new(12, 0.06, 26), Vector3.new(0, SOL + 0.03, G_Z1 - 13), Color3.fromRGB(170, 20, 30), Enum.Material.Fabric)
for _, x in ipairs({ -7.5, 7.5 }) do
	for z = G_Z1 - 24, G_Z1 - 4, 10 do
		dCyl("Potelet", 3, 0.5, Vector3.new(x, SOL + 1.5, z), OR, Enum.Material.Foil)
		boule("BoulePotelet", 0.8, Vector3.new(x, SOL + 3.1, z), OR, Enum.Material.Foil)
	end
	d("Cordon", Vector3.new(0.25, 0.25, 20), Vector3.new(x, SOL + 2.5, G_Z1 - 14), Color3.fromRGB(150, 15, 25), Enum.Material.Fabric)
end
for _, x in ipairs({ -34, 34 }) do
	dCyl("MatDrapeau", 16, 0.5, Vector3.new(x, SOL + 8, G_Z1 - 6), Color3.fromRGB(220, 220, 225), Enum.Material.Metal, true)
	local drapeau = d("Drapeau", Vector3.new(0.12, 3.5, 6), Vector3.new(x, SOL + 14, G_Z1 - 9.2), Color3.fromRGB(70, 30, 120), Enum.Material.Fabric)
	texte(drapeau, Enum.NormalId.Left, "GM", OR)
	texte(drapeau, Enum.NormalId.Right, "GM", OR)
end
d("NeonPorte", Vector3.new(LARG_ENTREE + 1, 0.4, 0.3), Vector3.new(0, SOL + G_HAUT - 4.2, G_Z1 - 0.7), VIOLET, Enum.Material.Neon)
for _, x in ipairs({ -LARG_ENTREE / 2 - 0.4, LARG_ENTREE / 2 + 0.4 }) do
	d("NeonPorte", Vector3.new(0.4, G_HAUT - 4, 0.3), Vector3.new(x, SOL + (G_HAUT - 4) / 2, G_Z1 - 0.7), VIOLET, Enum.Material.Neon)
end

-- L'atelier : la borne pour personnaliser son kart (touche E)
local POSITION_BORNE = Vector3.new(-26, SOL, G_CZ - 6)
local borne = bloc("Atelier", Vector3.new(2.5, 4, 2.5), CFrame.new(POSITION_BORNE + Vector3.new(0, 2, 0)), Color3.fromRGB(30, 30, 36), Enum.Material.Metal, garage)
deco(bloc("Ecran", Vector3.new(2.2, 1.4, 0.2), CFrame.new(POSITION_BORNE + Vector3.new(0, 4.5, -0.6)) * CFrame.Angles(math.rad(-25), 0, 0), VIOLET, Enum.Material.Neon, garage))
pancarte("PanneauAtelier", Vector3.new(10, 2, 0.3), POSITION_BORNE + Vector3.new(0, 8, 0), Vector3.new(0, 0, -1), "🎨 PERSONNALISER (E)", Color3.fromRGB(30, 30, 36), Color3.fromRGB(210, 160, 255), garage)
local invitePerso = Instance.new("ProximityPrompt")
invitePerso.Name = "PromptGarage"
invitePerso.ActionText = "Personnaliser mon kart"
invitePerso.ObjectText = "Atelier"
invitePerso.KeyboardKeyCode = Enum.KeyCode.E
invitePerso.HoldDuration = 0
invitePerso.MaxActivationDistance = 14
invitePerso.RequiresLineOfSight = false
invitePerso.Parent = borne

local apparition = Instance.new("SpawnLocation")
apparition.Name = "ApparitionGarage"
apparition.Size = Vector3.new(10, 0.4, 8)
apparition.CFrame = CFrame.lookAt(Vector3.new(-12, SOL + 0.3, G_CZ - 14), Vector3.new(-12, SOL + 0.3, G_CZ - 30))
apparition.Anchored = true
apparition.Neutral = true
apparition.Duration = 0
apparition.Color = VIOLET
apparition.Material = Enum.Material.Neon
apparition.Parent = garage

end -- (bloc : garde le nombre de variables du script sous la limite de Roblox)

---------------------------------------------------------------------
-- QUALITÉ DE LA CARTE : rayons de lumière sous les verrières, écrans géants
-- animés au-dessus de l'atrium, grandes bannières suspendues
---------------------------------------------------------------------
do
	local decor = Instance.new("Folder")
	decor.Name = "DecorPlus"
	decor.Parent = carte
	local rayonSol = RaycastParams.new()
	rayonSol.FilterType = Enum.RaycastFilterType.Exclude

	-- 0) LE MALL EST FERMÉ : on ne voit plus le parking ni le garage depuis l'intérieur.
	--    Les portes vitrées ouvertes sont remplacées par de grandes portes teintées, fermées.
	for _, d in ipairs(carte:GetChildren()) do
		if d:IsA("BasePart") and (d.Name == "PorteOuverte" or d.Name == "BarriereManche") then
			d:Destroy() -- (l'entrée est fermée pour de bon : plus besoin de la barrière des manches)
		end
	end
	local zPorte = DZ + 1
	-- Fond opaque (rien ne se voit au travers) + deux grands battants de verre fumé
	local fond = bloc("FondPortes", Vector3.new(largeurPortes, 16, 0.6), CFrame.new(0, SOL + 8, zPorte + 0.6), Color3.fromRGB(18, 20, 26), Enum.Material.SmoothPlastic, decor)
	fond.CastShadow = false
	for _, cote in ipairs({ -1, 1 }) do
		local battant = bloc("PorteFermee", Vector3.new(largeurPortes / 2 - 0.6, 15.4, 0.5), CFrame.new(cote * largeurPortes / 4, SOL + 7.7, zPorte), Color3.fromRGB(45, 60, 82), Enum.Material.Glass, decor)
		battant.Transparency = 0.1
		battant.Reflectance = 0.35
		-- Poignée dorée verticale, près du centre
		deco(bloc("Poignee", Vector3.new(0.4, 5, 0.6), CFrame.new(cote * 2.2, SOL + 7.5, zPorte - 0.5), OR, Enum.Material.Foil, decor))
		-- Lettres dorées sur chaque battant
		local plaque = deco(bloc("LettresPorte", Vector3.new(largeurPortes / 2 - 6, 3, 0.1), CFrame.new(cote * largeurPortes / 4, SOL + 11.5, zPorte - 0.32), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, decor))
		plaque.Transparency = 1
		texte(plaque, Enum.NormalId.Front, if cote < 0 then "GOLDEN" else "MALL", OR)
	end
	-- Cadre doré autour de l'entrée
	deco(bloc("CadrePorte", Vector3.new(largeurPortes + 1.2, 0.8, 1), CFrame.new(0, SOL + 15.8, zPorte - 0.4), OR, Enum.Material.Foil, decor))
	deco(bloc("CadrePorte", Vector3.new(0.6, 16, 1), CFrame.new(0, SOL + 8, zPorte - 0.4), OR, Enum.Material.Foil, decor))
	for _, cote in ipairs({ -1, 1 }) do
		deco(bloc("CadrePorte", Vector3.new(0.8, 16, 1), CFrame.new(cote * (largeurPortes / 2 + 0.2), SOL + 8, zPorte - 0.4), OR, Enum.Material.Foil, decor))
	end

	-- 1) Rayons de lumière (lumière du jour qui tombe des verrières)
	local dossierPuits = carte:FindFirstChild("PuitsDeLumiere")
	if dossierPuits then
		rayonSol.FilterDescendantsInstances = { dossierPuits }
		for _, panneau in ipairs(dossierPuits:GetChildren()) do
			if panneau:IsA("BasePart") and panneau.Name == "PuitsDeLumiere" then
				local haut = panneau.Position - Vector3.new(0, 0.2, 0)
				local sol = workspace:Raycast(haut, Vector3.new(0, -60, 0), rayonSol)
				local bas = if sol then sol.Position.Y else SOL
				local hauteur = haut.Y - bas
				if hauteur > 4 then
					local rayon = bloc("RayonLumiere", Vector3.new(panneau.Size.X * 0.85, hauteur, panneau.Size.Z * 0.85), CFrame.new(haut.X, bas + hauteur / 2, haut.Z), Color3.fromRGB(255, 246, 228), Enum.Material.Neon, decor)
					deco(rayon)
					rayon.Transparency = 0.955
					rayon.CastShadow = false
				end
			end
		end
	end

	-- 2) Écrans géants suspendus au-dessus de l'atrium (messages qui défilent)
	local MESSAGES = {
		{ "GOLDEN MALL DRIFT", Color3.fromRGB(255, 205, 70) },
		{ "⏱ NOUVEAU : COURSE CHRONO", Color3.fromRGB(90, 200, 255) },
		{ "🏆 TOP 10 DE LA SEMAINE", Color3.fromRGB(255, 120, 200) },
		{ "🔥 DRIFT BATTLE : BATS LE RECORD", Color3.fromRGB(255, 120, 60) },
		{ "🚓 ATTENTION : POLICE DU MALL", Color3.fromRGB(110, 160, 255) },
	}
	local textesEcrans = {}
	for _, z in ipairs({ -80, 80 }) do
		local y = SOL + HAUT_PLAFOND_2 - 13
		local ecran = bloc("EcranGeant", Vector3.new(30, 12, 1.2), CFrame.new(0, y, z), Color3.fromRGB(12, 12, 16), Enum.Material.SmoothPlastic, decor)
		deco(ecran)
		local cadre = bloc("CadreEcran", Vector3.new(31.2, 13.2, 0.8), CFrame.new(0, y, z), OR, Enum.Material.Foil, decor)
		deco(cadre)
		for _, x in ipairs({ -12, 12 }) do
			deco(bloc("CableEcran", Vector3.new(0.15, HAUT_PLAFOND_2 - (y - SOL) - 6, 0.15), CFrame.new(x, (y + 6 + SOL + HAUT_PLAFOND_2) / 2, z), Color3.fromRGB(40, 40, 45), Enum.Material.Metal, decor))
		end
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local l = texte(ecran, face, MESSAGES[1][1], MESSAGES[1][2], Color3.fromRGB(10, 10, 14))
			table.insert(textesEcrans, l)
		end
	end
	task.spawn(function()
		local i = 1
		while true do
			task.wait(4)
			i = i % #MESSAGES + 1
			for _, l in ipairs(textesEcrans) do
				l.Text = MESSAGES[i][1]
				l.TextColor3 = MESSAGES[i][2]
			end
		end
	end)

	-- 3) Grandes bannières suspendues dans l'atrium (rouge et or, aux couleurs du mall)
	local n = 0
	for _, z in ipairs({ -110, -70, -35, 35, 70, 110 }) do
		for _, x in ipairs({ -22, 22 }) do
			n += 1
			local couleur = if n % 2 == 0 then Color3.fromRGB(190, 25, 35) else Color3.fromRGB(25, 25, 30)
			local hautB = SOL + HAUT_PLAFOND_2 - 0.5
			deco(bloc("TringleBanniere", Vector3.new(0.4, 0.4, 7), CFrame.new(x, hautB, z), OR, Enum.Material.Foil, decor))
			local banniere = bloc("Banniere", Vector3.new(0.2, 13, 6), CFrame.new(x, hautB - 6.8, z), couleur, Enum.Material.Fabric, decor)
			deco(banniere)
			banniere.CastShadow = false
			for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
				local l = texte(banniere, face, "✦\nGOLDEN\nMALL\n✦", OR)
				l.TextScaled = true
			end
		end
	end
end

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
local Alerte = Instance.new("RemoteEvent") -- utilisé par le script de la sécurité
Alerte.Name = "Alerte"
Alerte.Parent = remotes
local TutoTermine = Instance.new("RemoteEvent") -- le joueur a fini (ou passé) le tuto du début
TutoTermine.Name = "TutoTermine"
TutoTermine.Parent = remotes
local DebutTuto = Instance.new("RemoteEvent") -- le tuto commence : on donne un kart, même au lobby
DebutTuto.Name = "DebutTuto"
DebutTuto.Parent = remotes

-- Les autres scripts serveur (la sécurité) peuvent donner de l'XP avec cet événement
local AjouterXP = Instance.new("BindableEvent")
AjouterXP.Name = "AjouterXP"
AjouterXP.Parent = game:GetService("ServerStorage")
-- Chaque drift validé est signalé au script des manches (classements, Drift Battle)
local DriftEnregistre = Instance.new("BindableEvent")
DriftEnregistre.Name = "DriftEnregistre"
DriftEnregistre.Parent = game:GetService("ServerStorage")

-- Groupes de collision : les gardes ne se font pas renverser par les karts
local PhysicsService = game:GetService("PhysicsService")
for _, groupe in ipairs({ "Karts", "Gardes", "KartsManche", "BarriereManche" }) do
	if not PhysicsService:IsCollisionGroupRegistered(groupe) then
		PhysicsService:RegisterCollisionGroup(groupe)
	end
end
PhysicsService:CollisionGroupSetCollidable("Karts", "Gardes", false)
PhysicsService:CollisionGroupSetCollidable("KartsManche", "Gardes", false)
-- La barrière de l'entrée (pendant une manche) ne bloque QUE les karts de la manche :
-- les joueurs en entraînement passent librement
PhysicsService:CollisionGroupSetCollidable("BarriereManche", "Default", false)
PhysicsService:CollisionGroupSetCollidable("BarriereManche", "Karts", false)
PhysicsService:CollisionGroupSetCollidable("BarriereManche", "Gardes", false)
PhysicsService:CollisionGroupSetCollidable("BarriereManche", "KartsManche", true)
do
	local barriere = carte:FindFirstChild("BarriereManche", true)
	if barriere then
		(barriere :: BasePart).CollisionGroup = "BarriereManche"
	end
end
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

type Profil = {
	XP: number,
	Record: number,
	Perso: { [string]: any },
	Charge: boolean,
	Pieces: number, -- la monnaie du jeu 💰
	Possessions: { Couleurs: { [string]: boolean }, Premium: { [string]: boolean }, Produits: { [string]: boolean }, Karts: { [string]: boolean }, Trainees: { [string]: boolean } },
	TutoFait: boolean, -- le tuto du début a déjà été vu
	ToursRoue: number, -- tours de roue achetés (ou offerts) pas encore joués
	DernierJourRoue: number, -- dernier jour (UTC) où le tour gratuit a été joué
	ToursGratuitsJour: number, -- tours gratuits déjà joués ce jour-là
	SerieJours: number, -- série de connexion (1 à 7)
	DernierJourConnexion: number,
	JourSeriePris: number, -- jour où le cadeau de la série a été pris
}
local profils: { [Player]: Profil } = {}
local kartsJoueurs: { [Player]: Model } = {}
local derniereAction: { [Player]: { [string]: number } } = {}

local dossierKarts = Instance.new("Folder")
dossierKarts.Name = "KartsJoueurs"
dossierKarts.Parent = workspace

local function niveauDe(profil: Profil): number
	return (Config.NiveauDepuisXP(profil.XP))
end

-- La roue du jour : 1 tour gratuit par jour (2 avec le Pass VIP)
local function jourActuel(): number
	return os.time() // 86400
end
local function toursGratuitsRestants(profil: Profil): number
	local parJour = if profil.Possessions.Produits.PassVIP then 2 else 1
	if profil.DernierJourRoue ~= jourActuel() then
		return parJour
	end
	return math.max(parJour - profil.ToursGratuitsJour, 0)
end
-- Pass VIP : pièces x2
local function multiplicateurPieces(profil: Profil): number
	return if profil.Possessions.Produits.PassVIP then 2 else 1
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
		Pieces = profil.Pieces,
		Possessions = profil.Possessions,
		TutoFait = profil.TutoFait,
		VIP = profil.Possessions.Produits.PassVIP == true,
		ToursRoue = profil.ToursRoue,
		ToursGratuitsRestants = toursGratuitsRestants(profil),
		ProchainTourGratuit = 86400 - os.time() % 86400, -- secondes avant minuit (UTC)
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
	local donnees = { XP = profil.XP, Record = profil.Record, Perso = profil.Perso, Pieces = profil.Pieces, Possessions = profil.Possessions, TutoFait = profil.TutoFait,
		ToursRoue = profil.ToursRoue, DernierJourRoue = profil.DernierJourRoue, ToursGratuitsJour = profil.ToursGratuitsJour,
		SerieJours = profil.SerieJours, DernierJourConnexion = profil.DernierJourConnexion, JourSeriePris = profil.JourSeriePris }
	local ok, err = pcall(function()
		magasin:SetAsync("joueur_" .. joueur.UserId, donnees)
	end)
	if not ok then
		warn("[Golden Mall] Échec de sauvegarde pour " .. joueur.Name .. " : " .. tostring(err))
	end
end

local function chargerProfil(joueur: Player)
	local profil: Profil = {
		XP = 0,
		Record = 0,
		Perso = table.clone(Config.PersoParDefaut),
		Charge = magasin == nil,
		Pieces = 0,
		Possessions = { Couleurs = {}, Premium = {}, Produits = {}, Karts = {}, Trainees = {} },
		TutoFait = false,
		ToursRoue = 0,
		DernierJourRoue = 0,
		ToursGratuitsJour = 0,
		SerieJours = 0,
		DernierJourConnexion = 0,
		JourSeriePris = 0,
	}
	if magasin then
		local ok, donnees = pcall(function()
			return magasin:GetAsync("joueur_" .. joueur.UserId)
		end)
		if ok then
			profil.Charge = true
			if type(donnees) == "table" then
				profil.XP = type(donnees.XP) == "number" and math.max(0, math.floor(donnees.XP)) or 0
				profil.Record = type(donnees.Record) == "number" and math.max(0, math.floor(donnees.Record)) or 0
				profil.Pieces = type(donnees.Pieces) == "number" and math.max(0, math.floor(donnees.Pieces)) or 0
				profil.TutoFait = donnees.TutoFait == true
				profil.ToursRoue = type(donnees.ToursRoue) == "number" and math.clamp(math.floor(donnees.ToursRoue), 0, 9999) or 0
				profil.DernierJourRoue = type(donnees.DernierJourRoue) == "number" and donnees.DernierJourRoue or 0
				profil.ToursGratuitsJour = type(donnees.ToursGratuitsJour) == "number" and donnees.ToursGratuitsJour or 0
				profil.SerieJours = type(donnees.SerieJours) == "number" and donnees.SerieJours or 0
				profil.DernierJourConnexion = type(donnees.DernierJourConnexion) == "number" and donnees.DernierJourConnexion or 0
				profil.JourSeriePris = type(donnees.JourSeriePris) == "number" and donnees.JourSeriePris or 0
				if type(donnees.Possessions) == "table" then
					for _, liste in ipairs({ "Couleurs", "Premium", "Produits", "Karts", "Trainees" }) do
						if type(donnees.Possessions[liste]) == "table" then
							for nom, possede in pairs(donnees.Possessions[liste]) do
								if type(nom) == "string" and possede == true then
									profil.Possessions[liste][nom] = true
								end
							end
						end
					end
				end
				profil.Perso = KartBuilder.Nettoyer(donnees.Perso, (Config.NiveauDepuisXP(profil.XP)), profil.Possessions)
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
-- Assoit le joueur dans son kart (plusieurs essais si le premier rate).
-- On téléporte d'abord le personnage à côté du kart : sinon l'ordinateur du joueur
-- peut garder son personnage là où il était… et y ramener le kart !
local function asseoir(joueur: Player, kart: Model)
	task.spawn(function()
		local siege = kart:FindFirstChild("Siege") :: Seat?
		local perso = joueur.Character
		if siege and perso and perso.Parent then
			perso:PivotTo(siege.CFrame * CFrame.new(0, 3, 0))
			task.wait(0.2)
		end
		for _ = 1, 6 do
			local perso = joueur.Character
			local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
			if not siege or not siege.Parent or not humanoide or humanoide.Health <= 0 then
				return
			end
			if siege.Occupant == humanoide then
				return -- c'est bon, il est assis
			end
			if humanoide.SeatPart and humanoide.SeatPart ~= siege then
				humanoide.Sit = false
				task.wait(0.1)
			end
			if not siege.Occupant then
				siege:Sit(humanoide)
			end
			task.wait(0.25)
		end
	end)
end

-- CASQUE DE PILOTE : il apparaît quand on monte dans un kart (couleur du kart)
-- et disparaît quand on en descend. Soudé à la tête : marche en R6 et en R15.
local function mettreCasque(perso: Model, couleur: Color3)
	local tete = perso:FindFirstChild("Head") :: BasePart?
	if not tete or perso:FindFirstChild("CasquePilote") then
		return
	end
	local casque = Instance.new("Model")
	casque.Name = "CasquePilote"
	local function partie(nom: string, taille: Vector3, decalage: CFrame, c: Color3, matiere: Enum.Material, sphere: boolean): Part
		local p = Instance.new("Part")
		p.Name = nom
		p.Size = taille
		p.CFrame = tete.CFrame * decalage
		p.Color = c
		p.Material = matiere
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		if sphere then
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = p
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = tete
		w.Part1 = p
		w.Parent = p
		p.Parent = casque
		return p
	end
	partie("Coque", Vector3.new(1.55, 1.6, 1.65), CFrame.new(0, 0.12, 0.02), couleur, Enum.Material.SmoothPlastic, true).Reflectance = 0.15
	partie("Visiere", Vector3.new(1.15, 0.5, 0.5), CFrame.new(0, 0.08, -0.62), Color3.fromRGB(25, 30, 40), Enum.Material.Glass, true).Reflectance = 0.5
	partie("Bande", Vector3.new(0.28, 1.63, 1.68), CFrame.new(0, 0.12, 0.02), Color3.fromRGB(245, 245, 245), Enum.Material.SmoothPlastic, true)
	partie("Mentonniere", Vector3.new(1.2, 0.35, 0.7), CFrame.new(0, -0.48, -0.4), couleur:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.SmoothPlastic, true)
	casque.Parent = perso
end

local function couleurDuKart(kart: Instance): Color3
	for _, d in ipairs(kart:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Peinture") == "Carrosserie" then
			return d.Color
		end
	end
	return Color3.fromRGB(215, 35, 40)
end

local function surveillerCasque(perso: Model)
	local humanoide = perso:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoide then
		return
	end
	humanoide:GetPropertyChangedSignal("SeatPart"):Connect(function()
		local siege = humanoide.SeatPart
		local kart = siege and siege.Parent
		if kart and kart:GetAttribute("KartType") then
			mettreCasque(perso, couleurDuKart(kart))
		else
			local ancien = perso:FindFirstChild("CasquePilote")
			if ancien then
				ancien:Destroy()
			end
		end
	end)
end
local function suivreJoueurCasque(j: Player)
	j.CharacterAdded:Connect(surveillerCasque)
	if j.Character then
		task.spawn(surveillerCasque, j.Character)
	end
end
Players.PlayerAdded:Connect(suivreJoueurCasque)
for _, j in ipairs(Players:GetPlayers()) do
	suivreJoueurCasque(j)
end

local function creerKart(joueur: Player, cf: CFrame, persoForce: { [string]: any }?): Model
	local profil = profils[joueur]
	local ancien = kartsJoueurs[joueur]
	if ancien then
		ancien:Destroy()
	end

	local kart = KartBuilder.Construire(persoForce or profil.Perso, cf, false)
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

	for _, p in ipairs(kart:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Karts"
		end
	end
	kart.Parent = dossierKarts
	kartsJoueurs[joueur] = kart
	return kart
end

-- F / « SORTIR MON KART » : le kart apparaît sur la ligne de départ dans le mall,
-- et le joueur est assis dedans automatiquement
-- Les places de départ :
--   • joueurs libres et FUGITIFS : la grille de départ, au SUD (24 places, face au nord)
--   • POLICIERS (mode en ligne) : au NORD, à l'opposé (18 places, face au sud)
local function placesDepart(role: string?): { CFrame }
	local liste = {}
	if role == "Police" then
		for _, z in ipairs({ -129, -136, -143 }) do
			for _, x in ipairs({ -5, 5, -15, 15, -25, 25 }) do
				local pos = Vector3.new(x, SOL + 0.6, z)
				table.insert(liste, CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))) -- face au sud
			end
		end
	else
		for _, dz in ipairs({ 7, 14, 21 }) do
			for _, x in ipairs({ -5, 5, -15, 15, -25, 25, -35, 35 }) do
				local pos = Vector3.new(x, SOL + 0.6, LIGNE_Z + dz)
				table.insert(liste, CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))) -- face à la fontaine
			end
		end
	end
	return liste
end

local function placeLibre(role: string?): CFrame
	local liste = placesDepart(role)
	for _, cf in ipairs(liste) do
		local libre = true
		for _, k in pairs(kartsJoueurs) do
			if k.Parent and k.PrimaryPart and (k.PrimaryPart.Position - cf.Position).Magnitude < 7 then
				libre = false
			end
		end
		if libre then
			return cf
		end
	end
	return liste[math.random(1, #liste)] + Vector3.new(0, 3, 0)
end

-- Le kart du policier : la personnalisation du joueur, en blanc et bleu avec gyrophare
local function persoPolice(perso: { [string]: any }): { [string]: any }
	local p = table.clone(perso)
	p.Carrosserie = "Blanc"
	p.Finition = "Brillant"
	p.Bandes = "Bleu"
	p.BandesActives = true
	p.Neon = "Bleu"
	p.Police = true
	return p
end

-- Mettre le joueur au volant de son kart, sur la bonne place de départ.
-- avecDepart = true : survol de la map + feux 3, 2, 1, PARTEZ !
local function placerKart(joueur: Player, avecDepart: boolean, departCourt: boolean?): Model?
	local profil = profils[joueur]
	if not profil or joueur:GetAttribute("Arrete") then
		return nil -- (un fugitif arrêté attend la fin de la manche)
	end
	local perso = joueur.Character
	local racine = perso and perso:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
	if not racine or not humanoide or humanoide.Health <= 0 then
		return nil
	end
	if humanoide.SeatPart then
		humanoide.Sit = false
	end
	local role = joueur:GetAttribute("Role")
	local cf = placeLibre(role)
	local kart = creerKart(joueur, cf, if role == "Police" then persoPolice(profil.Perso) else nil)
	if avecDepart then
		kart:SetAttribute("DepartHall", true)
		if departCourt then
			kart:SetAttribute("DepartCourt", true) -- juste 3, 2, 1 (sans le survol de la map)
		end
	end
	if role == nil then
		-- Mode libre : la police du mall laisse tranquille pendant le départ
		kart:SetAttribute("ProtegeJusqua", workspace:GetServerTimeNow() + 12)
	else
		-- Mode en ligne : les karts de la manche sont bloqués par la barrière de l'entrée
		for _, piece in ipairs(kart:GetDescendants()) do
			if piece:IsA("BasePart") then
				piece.CollisionGroup = "KartsManche"
			end
		end
		-- Mode en ligne : un repère au-dessus du kart (🚓 ou 🏃) pour reconnaître les équipes
		local repere = Instance.new("BillboardGui")
		repere.Name = "RepereEquipe"
		repere.Size = UDim2.new(0, 160, 0, 40)
		repere.StudsOffset = Vector3.new(0, 5, 0)
		repere.AlwaysOnTop = true
		repere.MaxDistance = 220
		repere.Parent = kart.PrimaryPart
		local etiquette = Instance.new("TextLabel")
		etiquette.Size = UDim2.fromScale(1, 1)
		etiquette.BackgroundTransparency = 1
		etiquette.TextScaled = true
		etiquette.Font = Enum.Font.GothamBlack
		etiquette.Text = (if role == "Police" then "🚓 " elseif role == "Battle" then "🔥 " else "🏃 ") .. joueur.DisplayName
		etiquette.TextColor3 = if role == "Police" then Color3.fromRGB(90, 150, 255) elseif role == "Battle" then Color3.fromRGB(255, 90, 170) else Color3.fromRGB(255, 150, 40)
		local contour = Instance.new("UIStroke")
		contour.Thickness = 2
		contour.Parent = etiquette
		etiquette.Parent = repere
	end
	asseoir(joueur, kart)
	-- Sécurité : on redonne le contrôle du kart au joueur (sinon il ne pourrait pas rouler)
	task.delay(1, function()
		local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
		if kart.Parent and kart.PrimaryPart and h and h.SeatPart and h.SeatPart:IsDescendantOf(kart) then
			pcall(function()
				kart.PrimaryPart:SetNetworkOwner(joueur)
			end)
		end
	end)
	return kart
end

-- F / « SORTIR MON KART »
local function sortirKart(joueur: Player)
	if not profils[joueur] or tropRapide(joueur, "sortir", 1.5) then
		return
	end
	local humanoide = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	local ancien = kartsJoueurs[joueur]
	if ancien and humanoide and humanoide.SeatPart and humanoide.SeatPart:IsDescendantOf(ancien) then
		return -- déjà au volant
	end
	if joueur:GetAttribute("EnSalle") then
		return -- page d'attente : la manche va commencer
	end
	if TYPE == "Lobby" and not joueur:GetAttribute("EnTuto") then
		return -- dans le lobby, on ne roule pas (sauf pendant le tuto) : on choisit son mode dans le menu
	end
	-- Mode libre : départ avec le survol et les feux ; en manche : on repart tout de suite
	placerKart(joueur, joueur:GetAttribute("Role") == nil)
end

-- Pour le script des manches (ManchesServer)
local PlacerKart = Instance.new("BindableFunction")
PlacerKart.Name = "PlacerKart"
PlacerKart.OnInvoke = function(joueur: Player, avecDepart: boolean, departCourt: boolean?)
	return placerKart(joueur, avecDepart, departCourt)
end
PlacerKart.Parent = game:GetService("ServerStorage")
local RetirerKart = Instance.new("BindableFunction")
RetirerKart.Name = "RetirerKart"
RetirerKart.OnInvoke = function(joueur: Player)
	local humanoide = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	if humanoide and humanoide.SeatPart then
		humanoide.Sit = false
	end
	local kart = kartsJoueurs[joueur]
	if kart then
		kart:Destroy()
	end
	kartsJoueurs[joueur] = nil
	return true
end
RetirerKart.Parent = game:GetService("ServerStorage")

SortirKart.OnServerEvent:Connect(sortirKart)

-- Place Entraînement : en arrivant, le kart t'attend sur la ligne de départ
if TYPE == "Entrainement" then
	local function arrivee(joueur: Player)
		joueur.CharacterAdded:Connect(function()
			task.spawn(function()
				local debut = os.clock()
				while not profils[joueur] and os.clock() - debut < 15 do
					task.wait(0.3)
				end
				task.wait(1.5)
				if joueur.Parent and not kartsJoueurs[joueur] then
					placerKart(joueur, true)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(arrivee)
	for _, j in ipairs(Players:GetPlayers()) do
		arrivee(j)
	end
end

-- Toutes les secondes : chaque joueur au volant doit avoir le contrôle physique
-- de son kart (sinon il ne peut pas avancer). On le lui redonne si besoin.
task.spawn(function()
	while true do
		task.wait(1)
		for joueur, kart in pairs(kartsJoueurs) do
			local chassis = kart.Parent and kart.PrimaryPart
			local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
			if chassis and h and h.SeatPart and h.SeatPart:IsDescendantOf(kart) and not chassis.Anchored then
				local ok, proprietaire = pcall(function()
					return chassis:GetNetworkOwner()
				end)
				if ok and proprietaire ~= joueur then
					local reussi, erreur = pcall(function()
						chassis:SetNetworkOwner(joueur)
					end)
					if not reussi then
						warn(("[Golden Mall] Impossible de donner le kart à %s : %s"):format(joueur.Name, tostring(erreur)))
					end
				end
			end
		end
	end
end)

Personnaliser.OnServerEvent:Connect(function(joueur: Player, perso: any)
	local profil = profils[joueur]
	if not profil or tropRapide(joueur, "perso", 0.3) then
		return
	end
	local ancienType = profil.Perso.Kart
	profil.Perso = KartBuilder.Nettoyer(perso, niveauDe(profil), profil.Possessions)

	-- Met à jour le kart déjà sorti (sauf pendant une manche en ligne)
	local kart = kartsJoueurs[joueur]
	if kart and kart.Parent and joueur:GetAttribute("Role") == nil then
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
	DriftEnregistre:Fire(joueur, points)

	local niveauAvant = niveauDe(profil)
	profil.XP += points
	profil.Pieces += math.floor(points / ((Config.Monnaie and Config.Monnaie.PointsParPiece) or 20)) * multiplicateurPieces(profil)
	if points > profil.Record then
		profil.Record = points
	end
	local niveauApres = niveauDe(profil)
	majClassement(joueur, profil)
	ProfilMisAJour:FireClient(joueur, versionPublique(profil), niveauApres > niveauAvant and niveauApres or nil)
end)

AjouterXP.Event:Connect(function(joueur: Player, quantite: number)
	local profil = profils[joueur]
	if not profil or type(quantite) ~= "number" then
		return
	end
	local niveauAvant = niveauDe(profil)
	profil.XP += math.max(0, math.floor(quantite))
	profil.Pieces += math.floor(math.max(0, quantite) / ((Config.Monnaie and Config.Monnaie.XPParPiece) or 10)) * multiplicateurPieces(profil)
	local niveauApres = niveauDe(profil)
	majClassement(joueur, profil)
	ProfilMisAJour:FireClient(joueur, versionPublique(profil), niveauApres > niveauAvant and niveauApres or nil)
end)

do
-- Donner des pièces depuis un autre script (récompenses du classement de la semaine…)
do
	local AjouterPieces = Instance.new("BindableEvent")
	AjouterPieces.Name = "AjouterPieces"
	AjouterPieces.Parent = game:GetService("ServerStorage")
	AjouterPieces.Event:Connect(function(joueur: Player, quantite: number, message: string?)
		local profil = profils[joueur]
		if not profil or type(quantite) ~= "number" or quantite <= 0 then
			return
		end
		profil.Pieces += math.floor(quantite)
		task.spawn(sauvegarder, joueur)
		ProfilMisAJour:FireClient(joueur, versionPublique(profil))
		if message then
			Alerte:FireClient(joueur, { etat = "message", texte = message })
		end
	end)
end

-- TITRES au-dessus des joueurs (donne envie de progresser… et d'avoir le VIP)
do
	local function titreDe(joueur: Player, profil: Profil): (string, Color3)
		if profil.Possessions.Produits.PassVIP then
			return "👑 VIP", Color3.fromRGB(255, 205, 60)
		elseif (joueur:GetAttribute("RecordBattle") or 0) >= 3000 then
			return "🔥 ROI DU DRIFT", Color3.fromRGB(255, 120, 60)
		elseif niveauDe(profil) >= 10 then
			return "⭐ PILOTE PRO", Color3.fromRGB(120, 200, 255)
		end
		return "PILOTE", Color3.fromRGB(220, 220, 230)
	end
	task.spawn(function()
		while true do
			for _, joueur in ipairs(Players:GetPlayers()) do
				local profil = profils[joueur]
				local tete = joueur.Character and joueur.Character:FindFirstChild("Head")
				if profil and tete then
					local panneau = tete:FindFirstChild("TitreJoueur") :: BillboardGui?
					if not panneau then
						local p = Instance.new("BillboardGui")
						p.Name = "TitreJoueur"
						p.Size = UDim2.fromOffset(160, 40)
						p.StudsOffset = Vector3.new(0, 3.2, 0)
						p.MaxDistance = 70
						p.LightInfluence = 0
						p.Parent = tete
						local titre = Instance.new("TextLabel")
						titre.Name = "Titre"
						titre.Size = UDim2.new(1, 0, 0.55, 0)
						titre.BackgroundTransparency = 1
						titre.Font = Enum.Font.FredokaOne
						titre.TextScaled = true
						titre.Parent = p
						local contour = Instance.new("UIStroke")
						contour.Thickness = 2
						contour.Parent = titre
						local niveau = Instance.new("TextLabel")
						niveau.Name = "Niveau"
						niveau.Size = UDim2.new(1, 0, 0.42, 0)
						niveau.Position = UDim2.fromScale(0, 0.58)
						niveau.BackgroundTransparency = 1
						niveau.Font = Enum.Font.FredokaOne
						niveau.TextScaled = true
						niveau.TextColor3 = Color3.new(1, 1, 1)
						niveau.Parent = p
						local contour2 = Instance.new("UIStroke")
						contour2.Thickness = 2
						contour2.Parent = niveau
						panneau = p
					end
					local p = panneau :: BillboardGui
					local texteTitre, couleur = titreDe(joueur, profil)
					local titre = p:FindFirstChild("Titre") :: TextLabel
					titre.Text = texteTitre
					titre.TextColor3 = couleur
					local etiquetteNiveau = p:FindFirstChild("Niveau") :: TextLabel
					etiquetteNiveau.Text = ("NIV. %d"):format(niveauDe(profil))
					-- (pendant une manche, c'est l'étiquette du kart qui compte)
					p.Enabled = joueur:GetAttribute("Role") == nil
				end
			end
			task.wait(3)
		end
	end)
end

---------------------------------------------------------------------
-- LES ACHATS
--   • couleurs : avec les pièces 💰 gagnées en jouant
--   • peintures premium + magasin : en Robux (produits pour développeurs).
--     Dans Studio, tant que ProduitId = 0, c'est gratuit (pour tester).
---------------------------------------------------------------------
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Acheter = Instance.new("RemoteFunction")
Acheter.Name = "Acheter"
Acheter.Parent = remotes

local function accorderProduit(joueur: Player, profil: Profil, produit: { [string]: any })
	if produit.Pieces then
		profil.Pieces += produit.Pieces
	end
	if produit.Premium then
		profil.Possessions.Premium[produit.Premium] = true
	end
	for _, nom in ipairs(produit.Premiums or {}) do
		profil.Possessions.Premium[nom] = true
	end
	if produit.Trainee and Config.Trainee(produit.Trainee) then
		profil.Possessions.Trainees[produit.Trainee] = true
	end
	if produit.Tours then
		profil.ToursRoue += produit.Tours
	end
	if produit.Vengeance then
		-- ⚡ VENGEANCE (mode Police contre Fugitifs) : géré par ManchesServer
		local appliquer = game:GetService("ServerStorage"):FindFirstChild("AppliquerVengeance") :: BindableFunction?
		local ok = appliquer and appliquer:Invoke(joueur)
		if not ok then
			profil.Pieces += 250 -- (la manche était finie : on dédommage en pièces)
		end
	end
	if produit.Kart and Config.Karts[produit.Kart] and Config.Karts[produit.Kart].Exclusif then
		profil.Possessions.Karts[produit.Kart] = true -- kart exclusif débloqué
	end
	if produit.Id then
		profil.Possessions.Produits[produit.Id] = true
	end
	if produit.Nom and Config.PeinturePremium(produit.Nom) then
		profil.Possessions.Premium[produit.Nom] = true
	end
	ProfilMisAJour:FireClient(joueur, versionPublique(profil))
end

-- Retrouve ce qu'on vend à partir du numéro de produit Roblox
local function produitDepuisId(produitId: number): { [string]: any }?
	for _, peinture in ipairs(Config.PeinturesPremium or {}) do
		if peinture.ProduitId ~= 0 and peinture.ProduitId == produitId then
			return peinture
		end
	end
	for _, offre in ipairs(Config.Boutique or {}) do
		if offre.ProduitId ~= 0 and offre.ProduitId == produitId then
			return offre
		end
	end
	for _, k in pairs(Config.Karts) do
		if k.Exclusif and k.ProduitId ~= 0 and k.ProduitId == produitId then
			return k
		end
	end
	local vengeance = Config.Partie and Config.Partie.ProduitVengeance or 0
	if vengeance ~= 0 and vengeance == produitId then
		return { Vengeance = true, Nom = "Vengeance" }
	end
	return nil
end

Acheter.OnServerInvoke = function(joueur: Player, info: any)
	local profil = profils[joueur]
	if not profil or type(info) ~= "table" or tropRapide(joueur, "achat", 0.3) then
		return { ok = false, message = "Patiente un instant…" }
	end
	if info.type == "couleur" then
		local c = type(info.nom) == "string" and Config.Couleur(info.nom)
		if not c then
			return { ok = false, message = "Couleur inconnue." }
		end
		if (c.Prix or 0) == 0 or profil.Possessions.Couleurs[c.Nom] then
			return { ok = true, message = "Tu l'as déjà !", profil = versionPublique(profil) }
		end
		if profil.Pieces < c.Prix then
			return { ok = false, message = ("Il te manque %d 💰 : drifte pour en gagner !"):format(c.Prix - profil.Pieces) }
		end
		profil.Pieces -= c.Prix
		profil.Possessions.Couleurs[c.Nom] = true
		task.spawn(sauvegarder, joueur)
		return { ok = true, message = ("%s achetée ! -%d 💰"):format(c.Nom, c.Prix), profil = versionPublique(profil) }
	elseif info.type == "test" then
		-- Achat Robux pas encore configuré : gratuit dans Studio pour tester
		if not RunService:IsStudio() then
			return { ok = false, message = "Ce produit n'est pas encore en vente." }
		end
		local produit = type(info.nom) == "string" and (Config.PeinturePremium(info.nom) or nil)
		if not produit then
			for _, offre in ipairs(Config.Boutique or {}) do
				if offre.Id == info.nom then
					produit = offre
				end
			end
		end
		if not produit and type(info.nom) == "string" and Config.Karts[info.nom] and Config.Karts[info.nom].Exclusif then
			produit = Config.Karts[info.nom]
		end
		if not produit then
			return { ok = false, message = "Produit inconnu." }
		end
		accorderProduit(joueur, profil, produit)
		return { ok = true, message = "(Test Studio : gratuit) " .. tostring(produit.Nom) .. " débloqué !", profil = versionPublique(profil) }
	end
	return { ok = false, message = "Achat inconnu." }
end

-- 🎡 LA ROUE DU JOUR : c'est le SERVEUR qui tire le cadeau (impossible de tricher)
local RoueDuJour = Instance.new("RemoteFunction")
RoueDuJour.Name = "RoueDuJour"
RoueDuJour.Parent = remotes
local aleaRoue = Random.new()

local function tirerCase(): number
	local total = 0
	for _, case in ipairs(Config.Roue) do
		total += case.Poids
	end
	local tirage = aleaRoue:NextNumber(0, total)
	for i, case in ipairs(Config.Roue) do
		tirage -= case.Poids
		if tirage <= 0 then
			return i
		end
	end
	return 1
end

local function auHasard(liste: { string }): string?
	if #liste == 0 then
		return nil
	end
	return liste[aleaRoue:NextInteger(1, #liste)]
end

-- Donne le cadeau de la case ; renvoie le texte affiché au joueur
local function donnerCadeau(joueur: Player, profil: Profil, case: { [string]: any }): string
	local bonus = multiplicateurPieces(profil)
	local function pieces(n: number): string
		profil.Pieces += n * bonus
		return ("+%d 💰%s"):format(n * bonus, if bonus > 1 then " (VIP x2)" else "")
	end
	if case.Type == "Pieces" then
		return pieces(case.Valeur)
	elseif case.Type == "XP" then
		profil.XP += case.Valeur
		majClassement(joueur, profil)
		return ("+%d XP"):format(case.Valeur)
	elseif case.Type == "Couleur" then
		local possibles = {}
		for _, c in ipairs(Config.Couleurs) do
			if (c.Prix or 0) > 0 and not profil.Possessions.Couleurs[c.Nom] then
				table.insert(possibles, c.Nom)
			end
		end
		local nom = auHasard(possibles)
		if nom then
			profil.Possessions.Couleurs[nom] = true
			return ("Nouvelle couleur : %s 🎨"):format(nom)
		end
		return pieces(case.Valeur) .. " (tu as déjà toutes les couleurs)"
	elseif case.Type == "Trainee" then
		local possibles = {}
		for _, t in ipairs(Config.Trainees) do
			if t.Couleurs and not profil.Possessions.Trainees[t.Nom] then
				table.insert(possibles, t.Nom)
			end
		end
		local nom = auHasard(possibles)
		if nom then
			profil.Possessions.Trainees[nom] = true
			return ("Traînée %s débloquée ! ✨"):format(nom)
		end
		return pieces(case.Valeur) .. " (tu as déjà toutes les traînées)"
	elseif case.Type == "Kart" then
		if not profil.Possessions.Karts.Galaxie then
			profil.Possessions.Karts.Galaxie = true
			return "🦄 JACKPOT ! Le kart Licorne Galaxie est à toi !"
		end
		return "JACKPOT ! " .. pieces(case.Valeur)
	end
	return ""
end

RoueDuJour.OnServerInvoke = function(joueur: Player, action: any)
	local profil = profils[joueur]
	if not profil then
		return { ok = false, message = "Profil pas encore chargé…" }
	end
	if action ~= "lancer" then
		return { ok = true, profil = versionPublique(profil) }
	end
	if tropRapide(joueur, "roue", 4) then
		return { ok = false, message = "La roue tourne encore !" }
	end
	-- D'abord le tour gratuit du jour, sinon un tour acheté
	if toursGratuitsRestants(profil) > 0 then
		if profil.DernierJourRoue ~= jourActuel() then
			profil.DernierJourRoue = jourActuel()
			profil.ToursGratuitsJour = 0
		end
		profil.ToursGratuitsJour += 1
	elseif profil.ToursRoue > 0 then
		profil.ToursRoue -= 1
	else
		return { ok = false, message = "Plus de tour aujourd'hui : reviens demain, ou achète des tours au magasin !" }
	end
	local indice = tirerCase()
	local cadeau = donnerCadeau(joueur, profil, Config.Roue[indice])
	task.spawn(sauvegarder, joueur)
	-- (le joueur voit son profil à jour quand la roue s'arrête)
	task.delay(5.5, function()
		if profils[joueur] then
			ProfilMisAJour:FireClient(joueur, versionPublique(profil))
		end
	end)
	return { ok = true, indice = indice, message = cadeau, profil = versionPublique(profil) }
end

-- 🎁 CADEAUX GRATUITS : temps de jeu, série de connexion, amis, groupe
do
	local Cadeaux = Instance.new("RemoteFunction")
	Cadeaux.Name = "Cadeaux"
	Cadeaux.Parent = remotes
	local C = Config.Cadeaux or {}
	local debutSession: { [Player]: number } = {}
	local cadeauxPris: { [Player]: { [number]: boolean } } = {}
	local amisDejaRecompenses: { [string]: boolean } = {}

	local function donner(joueur: Player, profil: Profil, c: { [string]: any })
		if c.Pieces then
			profil.Pieces += c.Pieces
		end
		if c.Tours then
			profil.ToursRoue += c.Tours
		end
		task.spawn(sauvegarder, joueur)
		ProfilMisAJour:FireClient(joueur, versionPublique(profil))
	end

	-- Met à jour la série de connexion (appelé quand le joueur regarde ses cadeaux)
	local function majSerie(profil: Profil)
		local aujourdhui = jourActuel()
		if profil.DernierJourConnexion ~= aujourdhui then
			if profil.DernierJourConnexion == aujourdhui - 1 then
				profil.SerieJours = profil.SerieJours % #(C.Serie or { 1 }) + 1
			else
				profil.SerieJours = 1 -- (série cassée : on recommence au jour 1)
			end
			profil.DernierJourConnexion = aujourdhui
		end
	end

	local function etat(joueur: Player, profil: Profil)
		majSerie(profil)
		local minutes = (os.clock() - (debutSession[joueur] or os.clock())) / 60
		local temps = {}
		for i, c in ipairs(C.TempsDeJeu or {}) do
			temps[i] = {
				texte = Config.TexteCadeau(c),
				minutes = c.Minutes,
				pret = minutes >= c.Minutes and not (cadeauxPris[joueur] and cadeauxPris[joueur][i]),
				pris = cadeauxPris[joueur] ~= nil and cadeauxPris[joueur][i] == true,
				reste = math.max(0, math.ceil(c.Minutes * 60 - minutes * 60)),
			}
		end
		return {
			temps = temps,
			serieJour = profil.SerieJours,
			seriePrete = profil.JourSeriePris ~= jourActuel(),
			groupe = (C.GroupeId or 0) ~= 0 and not profil.Possessions.Produits.BonusGroupe,
		}
	end

	Cadeaux.OnServerInvoke = function(joueur: Player, action: any, indice: any)
		local profil = profils[joueur]
		if not profil then
			return nil
		end
		if tropRapide(joueur, "cadeau", 0.3) then
			return etat(joueur, profil)
		end
		if action == "temps" and type(indice) == "number" then
			local c = (C.TempsDeJeu or {})[indice]
			local minutes = (os.clock() - (debutSession[joueur] or os.clock())) / 60
			cadeauxPris[joueur] = cadeauxPris[joueur] or {}
			if c and minutes >= c.Minutes and not cadeauxPris[joueur][indice] then
				cadeauxPris[joueur][indice] = true
				donner(joueur, profil, c)
			end
		elseif action == "serie" then
			majSerie(profil)
			local c = (C.Serie or {})[profil.SerieJours]
			if c and profil.JourSeriePris ~= jourActuel() then
				profil.JourSeriePris = jourActuel()
				donner(joueur, profil, c)
			end
		elseif action == "groupe" and (C.GroupeId or 0) ~= 0 and not profil.Possessions.Produits.BonusGroupe then
			local ok, membre = pcall(function()
				return joueur:IsInGroup(C.GroupeId)
			end)
			if ok and membre then
				profil.Possessions.Produits.BonusGroupe = true
				donner(joueur, profil, { Pieces = C.BonusGroupe or 500 })
			end
		end
		return etat(joueur, profil)
	end

	-- Jouer avec un ami = bonus pour les deux
	local function arrivee(joueur: Player)
		debutSession[joueur] = os.clock()
		task.delay(8, function()
			for _, autre in ipairs(Players:GetPlayers()) do
				if autre ~= joueur and joueur.Parent then
					local cle = if joueur.UserId < autre.UserId then (joueur.UserId .. "_" .. autre.UserId) else (autre.UserId .. "_" .. joueur.UserId)
					local ok, amis = pcall(function()
						return joueur:IsFriendsWith(autre.UserId)
					end)
					if ok and amis and not amisDejaRecompenses[cle] then
						amisDejaRecompenses[cle] = true
						for _, j in ipairs({ joueur, autre }) do
							local p = profils[j]
							if p then
								donner(j, p, { Pieces = C.BonusAmi or 150 })
								Alerte:FireClient(j, { etat = "message", texte = ("👥 TU JOUES AVEC TON AMI ! +%d 💰"):format(C.BonusAmi or 150) })
							end
						end
					end
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(arrivee)
	for _, j in ipairs(Players:GetPlayers()) do
		arrivee(j)
	end
	Players.PlayerRemoving:Connect(function(j)
		debutSession[j] = nil
		cadeauxPris[j] = nil
	end)
end

-- Les achats en Robux : Roblox appelle cette fonction quand un paiement a réussi
MarketplaceService.ProcessReceipt = function(recu)
	local joueur = Players:GetPlayerByUserId(recu.PlayerId)
	local profil = joueur and profils[joueur]
	local produit = produitDepuisId(recu.ProductId)
	if not joueur or not profil or not produit or not profil.Charge then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox réessaiera plus tard
	end
	local recus = profil.Possessions.Produits
	local cle = "recu_" .. tostring(recu.PurchaseId)
	if not recus[cle] then
		recus[cle] = true -- (pour ne jamais donner deux fois le même achat)
		accorderProduit(joueur, profil, produit)
	end
	local ok = pcall(sauvegarder, joueur)
	return if ok then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

ObtenirProfil.OnServerInvoke = function(joueur: Player)
	local debut = os.clock()
	while not profils[joueur] and os.clock() - debut < 15 do
		task.wait(0.2)
	end
	local profil = profils[joueur]
	return profil and versionPublique(profil) or nil
end

-- TUTO SUR LA PISTE : le joueur reçoit un kart sur la ligne de départ (3, 2, 1)
DebutTuto.OnServerEvent:Connect(function(joueur: Player)
	if not profils[joueur] or tropRapide(joueur, "tuto", 3) or joueur:GetAttribute("EnSalle") then
		return
	end
	joueur:SetAttribute("EnTuto", true)
	placerKart(joueur, false) -- directement sur la piste, sans décompte
end)

TutoTermine.OnServerEvent:Connect(function(joueur: Player)
	local profil = profils[joueur]
	if profil and not profil.TutoFait then
		profil.TutoFait = true
		task.spawn(sauvegarder, joueur)
	end
	if joueur:GetAttribute("EnTuto") then
		joueur:SetAttribute("EnTuto", nil)
		if TYPE == "Lobby" then
			-- Au lobby, on ne garde pas le kart : retour au garage pour choisir son mode
			local kart = kartsJoueurs[joueur]
			if kart then
				kart:Destroy()
				kartsJoueurs[joueur] = nil
			end
			task.wait(0.2)
			if joueur.Parent then
				joueur:LoadCharacter()
			end
		end
	end
end)

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

end -- (bloc : garde le nombre de variables du script sous la limite de Roblox)