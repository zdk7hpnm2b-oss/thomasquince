--[[
	MallDriftServer  (Script)
	À placer dans : ServerScriptService   — nom conseillé : MallDriftServer

	Au lancement du jeu, ce script :
	  • construit le GOLDEN MALL de Dubaï : fontaine géante, aquarium avec poissons,
	    palmiers, colonnes dorées, boutiques de luxe, food court, piste de ski…
	  • crée le GARAGE VIP (plateau tournant, atelier de personnalisation)
	  • pose les zones de sol mouillé + panneaux jaunes « ATTENTION SOL GLISSANT »
	  • sauvegarde la progression de chaque joueur (XP, niveau, kart personnalisé)
	  • fait apparaître le kart personnel de chaque joueur
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
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
end
if not Lighting:FindFirstChild("CouleursMallDrift") then
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "CouleursMallDrift"
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.TintColor = Color3.fromRGB(255, 248, 235) -- ambiance chaude et dorée
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

local function cylindreDebout(nom: string, hauteur: number, diametre: number, position: Vector3, couleur: Color3, matiere: Enum.Material?, parent: Instance?): Part
	local p = bloc(nom, Vector3.new(hauteur, diametre, diametre), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), couleur, matiere, parent)
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

-- Pancarte dont la face avant regarde dans la direction "versOu"
local function pancarte(nom: string, taille: Vector3, position: Vector3, versOu: Vector3, txt: string, couleur: Color3, couleurTexte: Color3?, matiere: Enum.Material?): Part
	local p = bloc(nom, taille, CFrame.lookAt(position, position + versOu), couleur, matiere or Enum.Material.SmoothPlastic)
	deco(p)
	texte(p, Enum.NormalId.Front, txt, couleurTexte)
	return p
end

local SOL = 1
local LARGEUR, PROFONDEUR, HAUTEUR = 420, 320, 40
local DX, DZ = LARGEUR / 2, PROFONDEUR / 2

local MARBRE = Color3.fromRGB(242, 235, 220)
local OR = Color3.fromRGB(225, 175, 45)
local OR_FONCE = Color3.fromRGB(180, 135, 30)
local NOIR_LUXE = Color3.fromRGB(22, 22, 26)

---------------------------------------------------------------------
-- SOL, MURS, VERRIÈRE, LUMIÈRES
---------------------------------------------------------------------
local sol = bloc("SolMarbre", Vector3.new(LARGEUR, 1, PROFONDEUR), CFrame.new(0, SOL - 0.5, 0), MARBRE, Enum.Material.Marble)
sol.Reflectance = 0.18

-- Incrustations dorées dans le marbre
deco(bloc("IncrustationOr", Vector3.new(LARGEUR, 0.05, 1.2), CFrame.new(0, SOL + 0.03, 0), OR, Enum.Material.Foil))
deco(bloc("IncrustationOr", Vector3.new(1.2, 0.05, PROFONDEUR), CFrame.new(0, SOL + 0.03, 0), OR, Enum.Material.Foil))
for _, z in ipairs({ -80, 80 }) do
	deco(bloc("IncrustationOr", Vector3.new(LARGEUR, 0.05, 0.6), CFrame.new(0, SOL + 0.03, z), OR, Enum.Material.Foil))
end

local yMur = SOL + HAUTEUR / 2
local couleurMur = Color3.fromRGB(246, 240, 228)
bloc("MurNord", Vector3.new(LARGEUR + 4, HAUTEUR, 2), CFrame.new(0, yMur, -DZ - 1), couleurMur, Enum.Material.Marble)
bloc("MurOuest", Vector3.new(2, HAUTEUR, PROFONDEUR), CFrame.new(-DX - 1, yMur, 0), couleurMur, Enum.Material.Marble)
bloc("MurEst", Vector3.new(2, HAUTEUR, PROFONDEUR), CFrame.new(DX + 1, yMur, 0), couleurMur, Enum.Material.Marble)
-- Façade sud avec les grandes portes vitrées de l'entrée
local largeurPortes = 40
local largeurCote = (LARGEUR + 4 - largeurPortes) / 2
bloc("MurSudOuest", Vector3.new(largeurCote, HAUTEUR, 2), CFrame.new(-(largeurPortes / 2 + largeurCote / 2), yMur, DZ + 1), couleurMur, Enum.Material.Marble)
bloc("MurSudEst", Vector3.new(largeurCote, HAUTEUR, 2), CFrame.new(largeurPortes / 2 + largeurCote / 2, yMur, DZ + 1), couleurMur, Enum.Material.Marble)
local portes = bloc("PortesEntree", Vector3.new(largeurPortes, HAUTEUR, 1), CFrame.new(0, yMur, DZ + 1), Color3.fromRGB(170, 205, 230), Enum.Material.Glass)
portes.Transparency = 0.55
pancarte("Enseigne", Vector3.new(70, 7, 0.5), Vector3.new(0, SOL + 31, DZ - 0.4), Vector3.new(0, 0, -1), "✦ GOLDEN MALL ✦", NOIR_LUXE, OR)

-- Verrière + poutres dorées
local verriere = bloc("Verriere", Vector3.new(LARGEUR + 4, 1, PROFONDEUR + 4), CFrame.new(0, SOL + HAUTEUR + 1.5, 0), Color3.fromRGB(200, 220, 235), Enum.Material.Glass)
verriere.Transparency = 0.85
verriere.CastShadow = false
deco(verriere)
for x = -180, 180, 60 do
	deco(bloc("Poutre", Vector3.new(1.5, 1.5, PROFONDEUR), CFrame.new(x, SOL + HAUTEUR + 0.5, 0), OR, Enum.Material.Foil))
end
for z = -120, 120, 60 do
	deco(bloc("Poutre", Vector3.new(LARGEUR, 1.5, 1.5), CFrame.new(0, SOL + HAUTEUR + 0.5, z), OR, Enum.Material.Foil))
end

local lampes = Instance.new("Folder")
lampes.Name = "Lampes"
lampes.Parent = carte
for x = -180, 180, 60 do
	for z = -120, 120, 60 do
		local l = bloc("Lampe", Vector3.new(6, 0.4, 6), CFrame.new(x, SOL + HAUTEUR - 2, z), Color3.fromRGB(255, 245, 220), Enum.Material.Neon, lampes)
		deco(l)
		l.CastShadow = false
		local pl = Instance.new("PointLight")
		pl.Range = 45
		pl.Brightness = 1.4
		pl.Color = Color3.fromRGB(255, 236, 200)
		pl.Parent = l
	end
end

---------------------------------------------------------------------
-- LA FONTAINE GÉANTE (au centre) + lustre + colonnes dorées
---------------------------------------------------------------------
local fontaine = Instance.new("Model")
fontaine.Name = "Fontaine"
fontaine.Parent = carte
cylindreDebout("Bassin", 3, 40, Vector3.new(0, SOL + 1.5, 0), Color3.fromRGB(250, 248, 242), Enum.Material.Marble, fontaine)
local eauFontaine = cylindreDebout("Eau", 0.3, 37, Vector3.new(0, SOL + 2.9, 0), Color3.fromRGB(60, 160, 230), Enum.Material.Glass, fontaine)
eauFontaine.Transparency = 0.3
deco(eauFontaine)
cylindreDebout("Colonne", 12, 4, Vector3.new(0, SOL + 7, 0), OR, Enum.Material.Foil, fontaine)
local vasque = cylindreDebout("Vasque", 1, 14, Vector3.new(0, SOL + 13, 0), OR, Enum.Material.Foil, fontaine)
local attJet = Instance.new("Attachment")
attJet.Position = Vector3.new(0.6, 0, 0) -- dessus de la vasque (axe X = vertical ici)
attJet.Parent = vasque
local jet = Instance.new("ParticleEmitter")
jet.Name = "JetDEau"
jet.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
jet.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.3) })
jet.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
jet.Lifetime = NumberRange.new(1.2, 1.6)
jet.Speed = NumberRange.new(22, 28)
jet.SpreadAngle = Vector2.new(18, 18)
jet.Acceleration = Vector3.new(0, -35, 0)
jet.EmissionDirection = Enum.NormalId.Right -- = vers le haut pour ce cylindre couché
jet.Rate = 140
jet.Parent = attJet
local lumiereFontaine = Instance.new("PointLight")
lumiereFontaine.Color = Color3.fromRGB(90, 180, 255)
lumiereFontaine.Range = 30
lumiereFontaine.Brightness = 2
lumiereFontaine.Parent = eauFontaine

local lustre = cylindreDebout("Lustre", 1, 26, Vector3.new(0, SOL + 32, 0), Color3.fromRGB(255, 225, 150), Enum.Material.Neon)
deco(lustre)
local lumiereLustre = Instance.new("PointLight")
lumiereLustre.Range = 60
lumiereLustre.Brightness = 2
lumiereLustre.Color = Color3.fromRGB(255, 225, 170)
lumiereLustre.Parent = lustre

for i = 0, 7 do
	local angle = i * math.pi / 4 + math.pi / 8
	cylindreDebout("ColonneDoree", HAUTEUR, 5, Vector3.new(math.cos(angle) * 58, SOL + HAUTEUR / 2, math.sin(angle) * 58), OR_FONCE, Enum.Material.Foil)
end

---------------------------------------------------------------------
-- L'AQUARIUM GÉANT (mur nord) avec des poissons qui nagent
---------------------------------------------------------------------
local aquarium = Instance.new("Model")
aquarium.Name = "Aquarium"
aquarium.Parent = carte
local AQ_LARGEUR, AQ_HAUT = 160, 32
local eauAq = bloc("Eau", Vector3.new(AQ_LARGEUR, AQ_HAUT, 8), CFrame.new(0, SOL + AQ_HAUT / 2, -DZ + 5), Color3.fromRGB(25, 105, 185), Enum.Material.SmoothPlastic, aquarium)
eauAq.Transparency = 0.5
deco(eauAq)
local vitreAq = bloc("Vitre", Vector3.new(AQ_LARGEUR, AQ_HAUT, 0.6), CFrame.new(0, SOL + AQ_HAUT / 2, -DZ + 9.3), Color3.fromRGB(190, 225, 245), Enum.Material.Glass, aquarium)
vitreAq.Transparency = 0.75
deco(bloc("Sable", Vector3.new(AQ_LARGEUR, 2, 8), CFrame.new(0, SOL + 1, -DZ + 5), Color3.fromRGB(225, 200, 150), Enum.Material.Sand, aquarium))
bloc("CadreHaut", Vector3.new(AQ_LARGEUR + 2, 1.5, 1.5), CFrame.new(0, SOL + AQ_HAUT + 0.75, -DZ + 9.3), OR, Enum.Material.Foil, aquarium)
local lumiereAq = Instance.new("PointLight")
lumiereAq.Color = Color3.fromRGB(80, 170, 255)
lumiereAq.Range = 40
lumiereAq.Brightness = 1.5
lumiereAq.Parent = eauAq
pancarte("PanneauAquarium", Vector3.new(50, 4, 0.5), Vector3.new(0, SOL + 36, -DZ + 0.3), Vector3.new(0, 0, 1), "AQUARIUM GÉANT", NOIR_LUXE, Color3.fromRGB(120, 210, 255))

local CORAUX = { Color3.fromRGB(255, 110, 120), Color3.fromRGB(255, 170, 60), Color3.fromRGB(190, 90, 220), Color3.fromRGB(80, 220, 160) }
for _ = 1, 14 do
	local h = random:NextNumber(2, 6)
	deco(bloc("Corail", Vector3.new(random:NextNumber(1, 2.5), h, random:NextNumber(1, 2.5)), CFrame.new(random:NextNumber(-75, 75), SOL + 2 + h / 2, -DZ + random:NextNumber(2.5, 7.5)), CORAUX[random:NextInteger(1, #CORAUX)], Enum.Material.SmoothPlastic, aquarium))
end
local POISSONS = { Color3.fromRGB(255, 150, 30), Color3.fromRGB(255, 230, 60), Color3.fromRGB(60, 160, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(240, 80, 120) }
for _ = 1, 18 do
	local y = SOL + random:NextNumber(5, AQ_HAUT - 3)
	local z = -DZ + random:NextNumber(2.5, 7.5)
	local depart = random:NextNumber(-75, -10)
	local taille = random:NextNumber(0.8, 1.6)
	local poisson = bloc("Poisson", Vector3.new(2.2, 1.1, 0.6) * taille, CFrame.new(depart, y, z), POISSONS[random:NextInteger(1, #POISSONS)], Enum.Material.SmoothPlastic, aquarium)
	deco(poisson)
	local info = TweenInfo.new(random:NextNumber(8, 16), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(poisson, info, { CFrame = CFrame.new(random:NextNumber(10, 75), y + random:NextNumber(-3, 3), z) }):Play()
end

---------------------------------------------------------------------
-- BOUTIQUES DE LUXE (vitrines + enseignes dorées)
---------------------------------------------------------------------
local BOUTIQUES = {
	"MAISON DORÉE", "OASIS PARFUMS", "SABLE & SOIE", "AURUM JOAILLERIE", "PERLE D'ORIENT",
	"SKY TECH", "DUNE SPORT", "ÉLÉGANCE", "PALMIER CAFÉ", "FALCON MONTRES", "DATTES ROYALES", "LUNE BLEUE",
}
local TEINTES = {
	Color3.fromRGB(255, 220, 160), Color3.fromRGB(200, 230, 255), Color3.fromRGB(255, 200, 220),
	Color3.fromRGB(210, 255, 220), Color3.fromRGB(235, 215, 255),
}
local numeroBoutique = 0

-- Vitrine collée contre un mur ; "versInterieur" = direction vers le centre du mall
local function vitrine(position: Vector3, versInterieur: Vector3, largeur: number, nom: string?)
	numeroBoutique += 1
	local nomBoutique = nom or BOUTIQUES[(numeroBoutique - 1) % #BOUTIQUES + 1]
	local base = CFrame.lookAt(position, position + versInterieur)
	local boutique = Instance.new("Model")
	boutique.Name = "Boutique_" .. nomBoutique
	boutique.Parent = carte

	local fond = bloc("FondLumineux", Vector3.new(largeur - 2, 14, 0.3), base * CFrame.new(0, SOL + 7, -0.2), TEINTES[numeroBoutique % #TEINTES + 1], Enum.Material.Neon, boutique)
	deco(fond)
	local verre = bloc("Vitrine", Vector3.new(largeur - 2, 14, 0.4), base * CFrame.new(0, SOL + 7, -1.2), Color3.fromRGB(200, 220, 235), Enum.Material.Glass, boutique)
	verre.Transparency = 0.6
	for _, cote in ipairs({ -1, 1 }) do
		bloc("Pilier", Vector3.new(1, 16, 1.6), base * CFrame.new(cote * largeur / 2, SOL + 8, -1), OR, Enum.Material.Foil, boutique)
	end
	local enseigne = bloc("Enseigne", Vector3.new(largeur - 4, 3.5, 0.5), base * CFrame.new(0, SOL + 17, -1), NOIR_LUXE, Enum.Material.SmoothPlastic, boutique)
	deco(enseigne)
	texte(enseigne, Enum.NormalId.Front, nomBoutique, OR)
end

-- Mur ouest
for _, z in ipairs({ -130, -80, -30, 20, 70 }) do
	vitrine(Vector3.new(-DX, 0, z), Vector3.new(1, 0, 0), 40)
end
-- Mur nord (de chaque côté de l'aquarium)
for _, x in ipairs({ -180, -130, 130, 180 }) do
	vitrine(Vector3.new(x, 0, -DZ), Vector3.new(0, 0, 1), 40)
end
-- Mur est
for _, z in ipairs({ -125, 55 }) do
	vitrine(Vector3.new(DX, 0, z), Vector3.new(-1, 0, 0), 40)
end
-- Mur sud (de chaque côté de l'entrée)
for _, x in ipairs({ -75, 75 }) do
	vitrine(Vector3.new(x, 0, DZ), Vector3.new(0, 0, -1), 40)
end

-- Fenêtre sur la piste de ski intérieure (mur est)
local ski = Instance.new("Model")
ski.Name = "PisteDeSki"
ski.Parent = carte
local baseSki = CFrame.lookAt(Vector3.new(DX, 0, -35), Vector3.new(DX - 1, 0, -35))
deco(bloc("Ciel", Vector3.new(80, 26, 0.2), baseSki * CFrame.new(0, SOL + 15, -0.2), Color3.fromRGB(170, 210, 245), Enum.Material.SmoothPlastic, ski))
deco(bloc("Neige", Vector3.new(90, 14, 0.25), baseSki * CFrame.new(-5, SOL + 7, -0.35) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(250, 252, 255), Enum.Material.Snow, ski))
for i = 1, 6 do
	cylindreDebout("Sapin", 6, 2.5, (baseSki * CFrame.new(-30 + i * 9, SOL + 6 + i * 1.6, -0.5)).Position, Color3.fromRGB(30, 100, 60), Enum.Material.SmoothPlastic, ski).CanCollide = false
end
local vitreSki = bloc("Vitre", Vector3.new(80, 26, 0.5), baseSki * CFrame.new(0, SOL + 15, -0.8), Color3.fromRGB(220, 235, 250), Enum.Material.Glass, ski)
vitreSki.Transparency = 0.7
pancarte("PanneauSki", Vector3.new(36, 4, 0.5), (baseSki * CFrame.new(0, SOL + 31, -0.6)).Position, Vector3.new(-1, 0, 0), "❄ PISTE DE SKI ❄", Color3.fromRGB(30, 90, 160), Color3.new(1, 1, 1))

---------------------------------------------------------------------
-- ÎLOTS DE BOUTIQUES autour de la fontaine (ils créent des circuits)
---------------------------------------------------------------------
for _, pos in ipairs({ Vector2.new(-115, -75), Vector2.new(115, -75), Vector2.new(-115, 70), Vector2.new(115, 70) }) do
	local ilot = Instance.new("Model")
	ilot.Name = "Ilot"
	ilot.Parent = carte
	bloc("Kiosque", Vector3.new(60, 16, 30), CFrame.new(pos.X, SOL + 8, pos.Y), Color3.fromRGB(250, 246, 238), Enum.Material.Marble, ilot)
	deco(bloc("BandeauOr", Vector3.new(61, 1.2, 31), CFrame.new(pos.X, SOL + 16.6, pos.Y), OR, Enum.Material.Foil, ilot))
	for _, cote in ipairs({ -1, 1 }) do
		numeroBoutique += 1
		local nomB = BOUTIQUES[(numeroBoutique - 1) % #BOUTIQUES + 1]
		pancarte("Enseigne", Vector3.new(44, 4, 0.4), Vector3.new(pos.X, SOL + 11, pos.Y + cote * 15.3), Vector3.new(0, 0, cote), nomB, NOIR_LUXE, OR).Parent = ilot
		local verre = bloc("Vitrine", Vector3.new(50, 7, 0.3), CFrame.new(pos.X, SOL + 4.5, pos.Y + cote * 15.2), TEINTES[numeroBoutique % #TEINTES + 1], Enum.Material.Neon, ilot)
		deco(verre)
	end
end

---------------------------------------------------------------------
-- PALMIERS
---------------------------------------------------------------------
local function palmier(x: number, z: number)
	local arbre = Instance.new("Model")
	arbre.Name = "Palmier"
	arbre.Parent = carte
	cylindreDebout("Bac", 2, 7, Vector3.new(x, SOL + 1, z), Color3.fromRGB(250, 246, 238), Enum.Material.Marble, arbre)
	deco(cylindreDebout("BordOr", 0.3, 7.4, Vector3.new(x, SOL + 2.1, z), OR, Enum.Material.Foil, arbre))
	deco(cylindreDebout("Tronc", 16, 1.4, Vector3.new(x, SOL + 10, z), Color3.fromRGB(140, 100, 60), Enum.Material.Wood, arbre))
	for i = 0, 6 do
		local feuille = bloc("Feuille", Vector3.new(8, 0.3, 2.2), CFrame.new(x, SOL + 18, z) * CFrame.Angles(0, i * math.pi * 2 / 7, 0) * CFrame.new(3.6, 0, 0) * CFrame.Angles(0, 0, math.rad(-28)), Color3.fromRGB(45, 140, 60), Enum.Material.Grass, arbre)
		deco(feuille)
	end
end
for _, x in ipairs({ -160, -100, -40, 40, 100, 160 }) do
	palmier(x, -120)
end
for _, x in ipairs({ -80, -30, 30, 80 }) do
	palmier(x, 125)
end

---------------------------------------------------------------------
-- FOOD COURT (coin sud-ouest) avec des chaises qu'on peut renverser
---------------------------------------------------------------------
local foodCourt = Instance.new("Model")
foodCourt.Name = "FoodCourt"
foodCourt.Parent = carte
deco(bloc("SolTerrasse", Vector3.new(95, 0.05, 62), CFrame.new(-162, SOL + 0.03, 128), Color3.fromRGB(200, 120, 80), Enum.Material.Slate, foodCourt))
vitrine(Vector3.new(-DX, 0, 125), Vector3.new(1, 0, 0), 40, "SHAWARMA STAR")
vitrine(Vector3.new(-185, 0, DZ), Vector3.new(0, 0, -1), 40, "BURGER DUNE")
vitrine(Vector3.new(-140, 0, DZ), Vector3.new(0, 0, -1), 40, "GLACES DU DÉSERT")
local COULEURS_CHAISES = { Color3.fromRGB(230, 70, 60), Color3.fromRGB(250, 200, 40), Color3.fromRGB(60, 170, 220) }
for _, x in ipairs({ -185, -160, -135 }) do
	for _, z in ipairs({ 110, 142 }) do
		local table_ = Instance.new("Model")
		table_.Name = "Table"
		table_.Parent = foodCourt
		local collision = cylindreDebout("Collision", 3.4, 6, Vector3.new(x, SOL + 1.7, z), Color3.new(1, 1, 1), nil, table_)
		collision.Transparency = 1
		deco(cylindreDebout("Plateau", 0.4, 6, Vector3.new(x, SOL + 3.2, z), Color3.new(1, 1, 1), Enum.Material.Marble, table_))
		deco(cylindreDebout("Pied", 3, 0.6, Vector3.new(x, SOL + 1.5, z), OR, Enum.Material.Foil, table_))
		for k, d in ipairs({ Vector3.new(4.5, 0, 0), Vector3.new(-4.5, 0, 0), Vector3.new(0, 0, 4.5), Vector3.new(0, 0, -4.5) }) do
			local chaise = bloc("Chaise", Vector3.new(2, 2.6, 2), CFrame.new(Vector3.new(x, SOL + 1.3, z) + d), COULEURS_CHAISES[(k % 3) + 1], Enum.Material.SmoothPlastic, table_)
			chaise.Anchored = false
			chaise.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.5, 0.2)
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
	morceau(bloc("Eau", Vector3.new(tailleX, 0.1, tailleZ), CFrame.new(centre.X, SOL + 0.07, centre.Y), COULEUR_EAU, Enum.Material.Glass, zone))
	for _ = 1, 4 do
		local d = random:NextNumber(4, 8)
		local rond = cylindreDebout("EauRonde", 0.1, d, Vector3.new(centre.X + random:NextNumber(-tailleX / 2, tailleX / 2), SOL + 0.08, centre.Y + random:NextNumber(-tailleZ / 2, tailleZ / 2)), COULEUR_EAU, Enum.Material.Glass, zone)
		morceau(rond)
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
		p.Anchored = false
		p.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.4, 0.3)
	end
	local soudure = Instance.new("WeldConstraint")
	soudure.Part0 = devant
	soudure.Part1 = derriere
	soudure.Parent = devant
	modele.PrimaryPart = devant
	modele.Parent = carte
end

local function seau(position: Vector2)
	local s = cylindreDebout("Seau", 1.8, 2, Vector3.new(position.X, SOL + 0.9, position.Y), Color3.fromRGB(255, 200, 0))
	s.Anchored = false
	deco(bloc("Serpilliere", Vector3.new(0.2, 6, 0.2), CFrame.new(position.X + 0.6, SOL + 3.5, position.Y) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(80, 140, 230)))
end

-- Autour de la fontaine (elle éclabousse !)
flaque(Vector2.new(0, -28), 22, 10)
flaque(Vector2.new(0, 28), 22, 10)
flaque(Vector2.new(28, 0), 10, 22)
flaque(Vector2.new(-28, 0), 10, 22)
panneauJaune(Vector2.new(13, -36), Vector3.new(0, 0, -1))
panneauJaune(Vector2.new(-13, 36), Vector3.new(0, 0, 1))
panneauJaune(Vector2.new(36, 13), Vector3.new(1, 0, 0))
panneauJaune(Vector2.new(-36, -13), Vector3.new(-1, 0, 0))
-- Soda renversé au food court
flaque(Vector2.new(-160, 126), 16, 8)
panneauJaune(Vector2.new(-149, 126), Vector3.new(1, 0, 0))
panneauJaune(Vector2.new(-171, 126), Vector3.new(-1, 0, 0))
-- Nettoyage devant l'aquarium
flaque(Vector2.new(50, -135), 28, 9)
panneauJaune(Vector2.new(33, -135), Vector3.new(-1, 0, 0))
panneauJaune(Vector2.new(67, -131), Vector3.new(1, 0, 0))
seau(Vector2.new(68, -138))

---------------------------------------------------------------------
-- LE GARAGE VIP (coin sud-est) : on personnalise son kart ici
---------------------------------------------------------------------
local garage = Instance.new("Model")
garage.Name = "GarageVIP"
garage.Parent = carte
local G_X1, G_X2, G_Z1, G_Z2 = 125, DX, 85, DZ
local G_CX, G_CZ = (G_X1 + G_X2) / 2, (G_Z1 + G_Z2) / 2
local sombre = deco(bloc("SolGarage", Vector3.new(G_X2 - G_X1, 0.05, G_Z2 - G_Z1), CFrame.new(G_CX, SOL + 0.04, G_CZ), Color3.fromRGB(28, 28, 34), Enum.Material.SmoothPlastic, garage))
sombre.Reflectance = 0.3

local function vitreGarage(taille: Vector3, position: Vector3)
	local v = bloc("VitreGarage", taille, CFrame.new(position), Color3.fromRGB(40, 40, 55), Enum.Material.Glass, garage)
	v.Transparency = 0.55
end
vitreGarage(Vector3.new(G_X2 - G_X1, 14, 0.6), Vector3.new(G_CX, SOL + 7, G_Z1))
local PORTE_Z1, PORTE_Z2 = 105, 140 -- l'ouverture de la porte du garage
vitreGarage(Vector3.new(0.6, 14, PORTE_Z1 - G_Z1), Vector3.new(G_X1, SOL + 7, (G_Z1 + PORTE_Z1) / 2))
vitreGarage(Vector3.new(0.6, 14, G_Z2 - PORTE_Z2), Vector3.new(G_X1, SOL + 7, (PORTE_Z2 + G_Z2) / 2))
-- Néons violets et dorés au sol, comme un vrai showroom
deco(bloc("NeonSol", Vector3.new(G_X2 - G_X1, 0.08, 0.4), CFrame.new(G_CX, SOL + 0.06, G_Z1 + 1), Color3.fromRGB(170, 80, 255), Enum.Material.Neon, garage))
deco(bloc("NeonSol", Vector3.new(G_X2 - G_X1, 0.08, 0.4), CFrame.new(G_CX, SOL + 0.06, G_Z2 - 1), Color3.fromRGB(170, 80, 255), Enum.Material.Neon, garage))
pancarte("EnseigneGarage", Vector3.new(34, 5, 0.5), Vector3.new(G_X1 - 0.5, SOL + 17, (PORTE_Z1 + PORTE_Z2) / 2), Vector3.new(-1, 0, 0), "GARAGE VIP", NOIR_LUXE, Color3.fromRGB(200, 140, 255))
pancarte("EnseigneGarageInt", Vector3.new(40, 6, 0.5), Vector3.new(DX - 0.4, SOL + 20, G_CZ), Vector3.new(-1, 0, 0), "★ GARAGE VIP ★", NOIR_LUXE, OR)

-- Plateau tournant (le kart du joueur s'affiche dessus dans le menu)
local POSITION_PLATEAU = Vector3.new(180, SOL, G_CZ)
local plateau = cylindreDebout("PlateauTournant", 1, 22, POSITION_PLATEAU + Vector3.new(0, 0.5, 0), Color3.fromRGB(40, 40, 48), Enum.Material.Metal, garage)
plateau:SetAttribute("PlateauGarage", true)
deco(cylindreDebout("AnneauNeon", 0.9, 23, POSITION_PLATEAU + Vector3.new(0, 0.45, 0), Color3.fromRGB(200, 140, 255), Enum.Material.Neon, garage))
local spot = Instance.new("PointLight")
spot.Range = 25
spot.Brightness = 2.5
spot.Parent = plateau
-- Piles de pneus (déco)
for i = 0, 5 do
	for h = 0, 3 do
		deco(cylindreDebout("Pneu", 1.2, 3, Vector3.new(140 + i * 4, SOL + 0.6 + h * 1.2, G_Z2 - 4), Color3.fromRGB(20, 20, 20), Enum.Material.Rubber, garage))
	end
end

-- L'atelier : borne pour personnaliser / sortir son kart
local borne = bloc("Atelier", Vector3.new(2, 4, 2), CFrame.new(158, SOL + 2, G_CZ), NOIR_LUXE, Enum.Material.Metal, garage)
local ecranBorne = bloc("Ecran", Vector3.new(1.8, 1.2, 0.2), CFrame.new(158, SOL + 4.4, G_CZ) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(170, 80, 255), Enum.Material.Neon, garage)
deco(ecranBorne)
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
apparition.Size = Vector3.new(10, 0.4, 6)
apparition.CFrame = CFrame.new(150, SOL + 0.2, G_Z2 - 15)
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
	local pos = Vector3.new(G_X1 - 14, SOL + 0.45, z)
	table.insert(PLACES_SORTIE, CFrame.lookAt(pos, pos + Vector3.new(-1, 0, 0)))
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
	return PLACES_SORTIE[1] + Vector3.new(-10, 0, 0)
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
