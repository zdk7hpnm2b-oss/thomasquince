--[[
	SecuriteServer  (Script)
	À placer dans : ServerScriptService   — nom conseillé : SecuriteServer

	LA POLICE DU GOLDEN MALL
	  • 3 policiers patrouillent À PIED dans les allées. Quand l'un d'eux te voit,
	    il saute dans son KART DE POLICE et te prend en chasse
	  • chaque policier a un champ de vision : s'il voit ton kart, il te poursuit (❗),
	    allume son gyrophare et appelle ses collègues en renfort. Il vise l'endroit où
	    tu vas, et garde ta trace par radio quelques secondes s'il te perd de vue
	  • s'il arrive tout près de ton kart : ATTRAPÉ ! Il te raccompagne au garage
	  • si personne ne te voit pendant quelques secondes : tu les as SEMÉS (+XP)
	  • un garde qui court sur le sol mouillé glisse et tombe (+XP pour toi) 😂
	  • à pied, tu es un client normal. Dehors (parking, garage), tu es en sécurité.

	Pas de violence : les gardes sifflent, lèvent la main et te ramènent au garage.
	Tous les réglages sont dans KartConfig > Config.Securite.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
-- Le dossier des remotes est créé après la construction de la carte : on l'attend
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")
local Alerte = remotes:WaitForChild("Alerte") :: RemoteEvent
local AjouterXP = ServerStorage:WaitForChild("AjouterXP") :: BindableEvent
local carte = workspace:WaitForChild("GoldenMall")
local dossierKarts = workspace:WaitForChild("KartsJoueurs")

local R = Config.Securite
local SOL = 1
local random = Random.new()

local dossierGardes = Instance.new("Folder")
dossierGardes.Name = "Securite"
dossierGardes.Parent = workspace

-- Animations Roblox par défaut (R15)
local ANIMATIONS = {
	Marche = "rbxassetid://507777826",
	Course = "rbxassetid://507767714",
	Repos = "rbxassetid://507766388",
	Assis = "rbxassetid://2506281703", -- assis au volant du kart de police
}

-- Les rondes des policiers (points x, z dans les allées du mall)
local RONDES_A_PIED = { -- (non utilisées pour l'instant : garde-les pour ajouter des gardes à pied)
	{ Vector2.new(-190, -137), Vector2.new(-25, -137) }, -- allée nord, ouest
	{ Vector2.new(25, -137), Vector2.new(190, -137) }, -- allée nord, est
	{ Vector2.new(-190, 0), Vector2.new(-45, 0) }, -- allée centrale, ouest
	{ Vector2.new(45, 0), Vector2.new(190, 0) }, -- allée centrale, est
	{ Vector2.new(-99, -115), Vector2.new(-99, 115) }, -- allée étroite ouest
	{ Vector2.new(99, -115), Vector2.new(99, 115) }, -- allée étroite est
	{ Vector2.new(-20, -36), Vector2.new(20, -36), Vector2.new(20, 36), Vector2.new(-20, 36) }, -- tour de la fontaine
	{ Vector2.new(-136, 28), Vector2.new(-136, 112) }, -- food court
	{ Vector2.new(-173, -115), Vector2.new(-173, 115) },
	{ Vector2.new(173, -115), Vector2.new(173, 115) },
}
local RONDES_SEGWAY = {
	{ Vector2.new(-195, 137), Vector2.new(195, 137) }, -- allée sud (devant l'entrée)
	{ Vector2.new(-190, -137), Vector2.new(173, -137), Vector2.new(173, 0), Vector2.new(36, 0), Vector2.new(36, -128) }, -- allée nord + allée centrale (boucle)
	{ Vector2.new(-34.5, -110), Vector2.new(-34.5, 110), Vector2.new(34.5, 110), Vector2.new(34.5, -110) }, -- place centrale (entre palmiers et boutiques)
}

-- Rondes du 1er étage (x, hauteur du plancher, z)
local HAUTEUR_ETAGE = SOL + 25
local RONDES_ETAGE = {
	{ Vector3.new(-190, HAUTEUR_ETAGE, -137), Vector3.new(190, HAUTEUR_ETAGE, -137) }, -- allée nord
	{ Vector3.new(-190, HAUTEUR_ETAGE, 130), Vector3.new(190, HAUTEUR_ETAGE, 130) }, -- allée sud
	{ Vector3.new(-190, HAUTEUR_ETAGE, -8), Vector3.new(-45, HAUTEUR_ETAGE, -8) }, -- allée centrale
}

local PEAUX = { Color3.fromRGB(255, 220, 185), Color3.fromRGB(225, 175, 130), Color3.fromRGB(165, 115, 80), Color3.fromRGB(100, 70, 50) }
local BLEU_UNIFORME = Color3.fromRGB(28, 42, 92)
local NOIR_PANTALON = Color3.fromRGB(28, 28, 34)
local JAUNE = Color3.fromRGB(255, 210, 40)

---------------------------------------------------------------------
-- Construction d'un garde
---------------------------------------------------------------------
local function souder(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function accessoire(modele: Model, support: BasePart, nom: string, taille: Vector3, decalage: CFrame, couleur: Color3, matiere: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = nom
	p.Size = taille
	p.CFrame = support.CFrame * decalage
	p.Color = couleur
	p.Material = matiere or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	souder(support, p)
	p.Parent = modele
	return p
end

-- Si le modèle Roblox complet ne peut pas être créé, on fabrique un garde simple
local function gardeSimple(peau: Color3): Model
	local m = Instance.new("Model")
	local racine = Instance.new("Part")
	racine.Name = "HumanoidRootPart"
	racine.Size = Vector3.new(2, 2, 1)
	racine.Transparency = 1
	racine.Parent = m
	m.PrimaryPart = racine
	local function morceau(nom: string, taille: Vector3, y: number, couleur: Color3)
		local p = Instance.new("Part")
		p.Name = nom
		p.Size = taille
		p.CFrame = racine.CFrame * CFrame.new(0, y, 0)
		p.Color = couleur
		p.CanCollide = false
		p.Massless = true
		souder(racine, p)
		p.Parent = m
		return p
	end
	morceau("UpperTorso", Vector3.new(2, 2, 1), 0, BLEU_UNIFORME)
	morceau("Head", Vector3.new(1.2, 1.2, 1.2), 1.6, peau)
	morceau("Jambes", Vector3.new(1.8, 2, 0.9), -2, NOIR_PANTALON)
	local h = Instance.new("Humanoid")
	h.RigType = Enum.HumanoidRigType.R15
	h.HipHeight = 2
	h.Parent = m
	return m
end

type Garde = {
	modele: Model,
	hum: Humanoid,
	racine: BasePart,
	tete: BasePart,
	bulle: TextLabel,
	segway: boolean,
	ronde: { Vector3 },
	indexRonde: number,
	etat: string, -- "patrouille" | "poursuite" | "recherche" | "glisse" | "arrestation"
	cible: Player?,
	derniereVue: number,
	dernierePos: Vector3?,
	finEtat: number,
	prochaineGlissade: number,
	chemin: { Vector3 }?,
	indexChemin: number,
	destinationChemin: Vector3?,
	prochainCalcul: number,
	pistes: { [string]: AnimationTrack },
	animEnCours: string?,
	enKart: boolean,
	hanchesBase: number,
}

local gardes: { Garde } = {}

local function creerGarde(ronde: { any }, segway: boolean, numero: number): Garde
	local peau = PEAUX[random:NextInteger(1, #PEAUX)]
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = peau
	description.TorsoColor = BLEU_UNIFORME
	description.LeftArmColor = BLEU_UNIFORME
	description.RightArmColor = BLEU_UNIFORME
	description.LeftLegColor = NOIR_PANTALON
	description.RightLegColor = NOIR_PANTALON
	local ok, modele = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modele then
		modele = gardeSimple(peau)
	end
	modele.Name = (segway and "Policier_" or "Garde_") .. numero
	local hum = modele:FindFirstChildOfClass("Humanoid") :: Humanoid
	local racine = modele:FindFirstChild("HumanoidRootPart") :: BasePart
	local tete = (modele:FindFirstChild("Head") or racine) :: BasePart
	local torse = (modele:FindFirstChild("UpperTorso") or modele:FindFirstChild("Torso") or racine) :: BasePart
	local animate = modele:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- on gère les animations nous-mêmes
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.BreakJointsOnDeath = false

	-- Uniforme : casquette, insigne, « SÉCURITÉ » dans le dos
	accessoire(modele, tete, "Casquette", Vector3.new(1.3, 0.35, 1.35), CFrame.new(0, 0.6, 0.05), BLEU_UNIFORME, Enum.Material.Fabric)
	accessoire(modele, tete, "Visiere", Vector3.new(1.1, 0.1, 0.6), CFrame.new(0, 0.45, -0.8), Color3.fromRGB(15, 15, 20))
	accessoire(modele, torse, "Insigne", Vector3.new(0.35, 0.35, 0.05), CFrame.new(-0.45, 0.35, -0.53), JAUNE, Enum.Material.Foil)
	local dos = accessoire(modele, torse, "Dos", Vector3.new(1.8, 0.55, 0.05), CFrame.new(0, 0.3, 0.53), BLEU_UNIFORME)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50
	sg.Parent = dos
	local mot = Instance.new("TextLabel")
	mot.Size = UDim2.fromScale(1, 1)
	mot.BackgroundTransparency = 1
	mot.TextScaled = true
	mot.Font = Enum.Font.GothamBlack
	mot.TextColor3 = JAUNE
	mot.Text = "POLICE"
	mot.TextColor3 = Color3.new(1, 1, 1)
	mot.Parent = sg

	-- Gyropode
	if segway then
		hum.HipHeight += 0.7
		local pieds = -(hum.HipHeight + racine.Size.Y / 2) + 0.15
		accessoire(modele, racine, "Plateforme", Vector3.new(2.3, 0.3, 1.3), CFrame.new(0, pieds, 0), Color3.fromRGB(35, 35, 40))
		for _, cote in ipairs({ -1, 1 }) do
			local roue = accessoire(modele, racine, "Roue", Vector3.new(0.5, 1.4, 1.4), CFrame.new(cote * 1.35, pieds, 0), Color3.fromRGB(20, 20, 20), Enum.Material.Rubber)
			roue.Shape = Enum.PartType.Cylinder
		end
		accessoire(modele, racine, "Colonne", Vector3.new(0.2, 3.3, 0.2), CFrame.new(0, pieds + 1.7, -0.75), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
		accessoire(modele, racine, "Guidon", Vector3.new(1.6, 0.2, 0.2), CFrame.new(0, pieds + 3.3, -0.75), Color3.fromRGB(60, 60, 65), Enum.Material.Metal)
		accessoire(modele, racine, "Gyrophare", Vector3.new(0.6, 0.35, 0.4), CFrame.new(0, pieds + 3.55, -0.75), Color3.fromRGB(40, 90, 255), Enum.Material.Neon)
	end

	-- La bulle au-dessus de la tête (❗ = il te voit, ❓ = il te cherche)
	local panneau = Instance.new("BillboardGui")
	panneau.Name = "Bulle"
	panneau.Size = UDim2.new(4, 0, 2, 0)
	panneau.StudsOffset = Vector3.new(0, 2.6, 0)
	panneau.AlwaysOnTop = true
	panneau.MaxDistance = 150
	panneau.Parent = tete
	local bulle = Instance.new("TextLabel")
	bulle.Size = UDim2.fromScale(1, 1)
	bulle.BackgroundTransparency = 1
	bulle.TextScaled = true
	bulle.Font = Enum.Font.GothamBlack
	bulle.TextColor3 = Color3.fromRGB(255, 60, 60)
	bulle.Text = ""
	local contour = Instance.new("UIStroke")
	contour.Thickness = 2
	contour.Parent = bulle
	bulle.Parent = panneau

	for _, p in ipairs(modele:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Gardes"
		end
	end

	local points = {}
	for _, v in ipairs(ronde) do
		if typeof(v) == "Vector3" then
			table.insert(points, v + Vector3.new(0, 3, 0)) -- point avec sa hauteur (1er étage)
		else
			table.insert(points, Vector3.new(v.X, SOL + 3, v.Y))
		end
	end
	modele:PivotTo(CFrame.new(points[1] + Vector3.new(0, 1, 0)))
	modele.Parent = dossierGardes
	pcall(function()
		racine:SetNetworkOwner(nil) -- le serveur pilote les gardes (pas de saccades)
	end)

	-- Animations
	local animateur = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animateur.Parent = hum
	local pistes = {}
	for nom, id in pairs(ANIMATIONS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local okAnim, piste = pcall(function()
			return animateur:LoadAnimation(anim)
		end)
		if okAnim and piste then
			piste.Looped = true
			pistes[nom] = piste
		end
	end

	local g: Garde = {
		modele = modele,
		hum = hum,
		racine = racine,
		tete = tete,
		bulle = bulle,
		segway = segway,
		ronde = points,
		indexRonde = 2,
		etat = "patrouille",
		cible = nil,
		derniereVue = 0,
		dernierePos = nil,
		finEtat = 0,
		prochaineGlissade = 0,
		chemin = nil,
		indexChemin = 1,
		destinationChemin = nil,
		prochainCalcul = 0,
		pistes = pistes,
		animEnCours = nil,
		enKart = false,
		hanchesBase = hum.HipHeight,
	}
	table.insert(gardes, g)
	return g
end

---------------------------------------------------------------------
-- Outils
---------------------------------------------------------------------
local function aplat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function dansLeMall(pos: Vector3): boolean
	return pos.Z < 159 and pos.Z > -160 and math.abs(pos.X) < 210
end

local function animer(g: Garde)
	local vitesse = aplat(g.racine.AssemblyLinearVelocity).Magnitude
	local voulue = "Repos"
	if g.etat == "glisse" then
		voulue = "Aucune"
	elseif g.enKart then
		voulue = "Assis"
	elseif not g.segway and vitesse > 16 then
		voulue = "Course"
	elseif not g.segway and vitesse > 1 then
		voulue = "Marche"
	end
	if voulue ~= g.animEnCours then
		for _, piste in pairs(g.pistes) do
			piste:Stop(0.2)
		end
		local piste = g.pistes[voulue]
		if piste then
			piste:Play(0.2)
		end
		g.animEnCours = voulue
	end
end

-- Les karts conduits en ce moment (un par joueur)
type KartConduit = { joueur: Player, kart: Model, chassis: BasePart }
local kartsConduits: { KartConduit } = {}

local function mettreAJourKarts()
	local liste = {}
	for _, kart in ipairs(dossierKarts:GetChildren()) do
		local proprietaire = Players:GetPlayerByUserId(kart:GetAttribute("Proprietaire") or 0)
		local siege = kart:FindFirstChild("Siege") :: Seat?
		local chassis = (kart :: Model).PrimaryPart
		local protege = (kart:GetAttribute("ProtegeJusqua") or 0) > workspace:GetServerTimeNow()
		if proprietaire and siege and chassis and not protege and siege.Occupant and siege.Occupant.Parent == proprietaire.Character then
			table.insert(liste, { joueur = proprietaire, kart = kart :: Model, chassis = chassis })
		end
	end
	kartsConduits = liste
end

local function kartDe(joueur: Player?): KartConduit?
	for _, k in ipairs(kartsConduits) do
		if k.joueur == joueur then
			return k
		end
	end
	return nil
end

local parametresVue = RaycastParams.new()
parametresVue.FilterType = Enum.RaycastFilterType.Exclude
parametresVue.RespectCanCollide = true

local function majFiltreVue()
	local exclus = { dossierGardes, dossierKarts }
	for _, j in ipairs(Players:GetPlayers()) do
		if j.Character then
			table.insert(exclus, j.Character)
		end
	end
	parametresVue.FilterDescendantsInstances = exclus
end

-- Le garde voit-il ce kart ? (distance, angle de vue, et pas de mur entre les deux)
local function voit(g: Garde, chassis: BasePart): boolean
	local vers = chassis.Position - g.tete.Position
	local distance = aplat(vers).Magnitude
	if distance > R.DistanceVue then
		return false
	end
	if distance > R.DistanceOuie then
		local regard = aplat(g.racine.CFrame.LookVector).Unit
		if regard:Dot(aplat(vers).Unit) < math.cos(math.rad(R.AngleVue)) then
			return false
		end
	end
	return workspace:Raycast(g.tete.Position, vers, parametresVue) == nil
end

local parametresSol = RaycastParams.new()
parametresSol.FilterType = Enum.RaycastFilterType.Exclude

local function surSolMouille(g: Garde): boolean
	parametresSol.FilterDescendantsInstances = { dossierGardes, dossierKarts }
	local r = workspace:Raycast(g.racine.Position, Vector3.new(0, -8, 0), parametresSol)
	return r ~= nil and r.Instance:GetAttribute("Mouille") == true
end

-- Se déplacer vers un point : tout droit si la voie est libre, sinon avec un chemin calculé
local function allerVers(g: Garde, destination: Vector3)
	local depart = g.racine.Position
	local direct = workspace:Raycast(depart, destination - depart, parametresVue)
	if direct == nil or (direct.Position - depart).Magnitude > (destination - depart).Magnitude - 2 then
		g.chemin = nil
		g.hum:MoveTo(destination)
		return
	end
	local maintenant = os.clock()
	local doitRecalculer = g.chemin == nil
		or maintenant > g.prochainCalcul
		or (g.destinationChemin and (g.destinationChemin - destination).Magnitude > 12)
	if doitRecalculer then
		g.prochainCalcul = maintenant + 0.6
		g.destinationChemin = destination
		local chemin = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 6 })
		local ok = pcall(function()
			chemin:ComputeAsync(depart, destination)
		end)
		if ok and chemin.Status == Enum.PathStatus.Success then
			local points = {}
			for _, w in ipairs(chemin:GetWaypoints()) do
				table.insert(points, w.Position)
			end
			g.chemin = points
			g.indexChemin = math.min(2, #points)
		else
			g.chemin = nil
			g.hum:MoveTo(destination)
			return
		end
	end
	local points = g.chemin
	if points and points[g.indexChemin] then
		if aplat(points[g.indexChemin] - g.racine.Position).Magnitude < 6 and g.indexChemin < #points then
			g.indexChemin += 1
		end
		g.hum:MoveTo(points[g.indexChemin])
	end
end

---------------------------------------------------------------------
-- Le kart de police : il apparaît sous le policier quand il te prend en chasse
---------------------------------------------------------------------
local BLANC_POLICE = Color3.fromRGB(240, 242, 248)
local BLEU_POLICE = Color3.fromRGB(25, 60, 170)

local function monterEnKart(g: Garde)
	if g.enKart then
		return
	end
	g.enKart = true
	g.hum.HipHeight = 0.7
	local r = g.racine
	-- Position du châssis : au ras du sol, sous les hanches du policier assis
	local base = r.CFrame * CFrame.new(0, -(0.7 + r.Size.Y / 2) + 0.45, 0.6)
	local kartPolice = Instance.new("Model")
	kartPolice.Name = "KartPolice"
	local function piece(nom: string, taille: Vector3, decalage: CFrame, couleur: Color3, matiere: Enum.Material?, forme: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = nom
		p.Size = taille
		p.CFrame = base * decalage
		p.Color = couleur
		p.Material = matiere or Enum.Material.SmoothPlastic
		p.Shape = forme or Enum.PartType.Block
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CollisionGroup = "Gardes"
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		souder(r, p)
		p.Parent = kartPolice
		return p
	end
	piece("Chassis", Vector3.new(4, 0.8, 6), CFrame.new(), BLANC_POLICE)
	piece("Capot", Vector3.new(3.2, 0.6, 1.8), CFrame.new(0, 0.55, -2.2) * CFrame.Angles(math.rad(-12), 0, 0), BLEU_POLICE)
	piece("PareChoc", Vector3.new(4.6, 0.5, 0.6), CFrame.new(0, 0, -3.2), Color3.fromRGB(25, 25, 25))
	for _, cote in ipairs({ -1, 1 }) do
		piece("BandeBleue", Vector3.new(0.1, 0.45, 5.6), CFrame.new(cote * 2.02, 0.05, 0), BLEU_POLICE)
		piece("RoueAvant", Vector3.new(0.8, 1.6, 1.6), CFrame.new(cote * 2.2, 0.2, -2.3), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		piece("RoueArriere", Vector3.new(0.7, 1.3, 1.3), CFrame.new(cote * 2.1, 0.05, 2.4), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local flanc = piece("Flanc", Vector3.new(0.05, 0.7, 3.4), CFrame.new(cote * 2.06, 0.05, -0.3), BLANC_POLICE)
		flanc.Transparency = 1
		local sg = Instance.new("SurfaceGui")
		sg.Face = if cote < 0 then Enum.NormalId.Left else Enum.NormalId.Right
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 60
		sg.Parent = flanc
		local mot = Instance.new("TextLabel")
		mot.Size = UDim2.fromScale(1, 1)
		mot.BackgroundTransparency = 1
		mot.TextScaled = true
		mot.Font = Enum.Font.GothamBlack
		mot.TextColor3 = BLEU_POLICE
		mot.Text = "POLICE"
		mot.Parent = sg
	end
	piece("Volant", Vector3.new(0.2, 1.5, 1.5), CFrame.new(0, 1.6, -1) * CFrame.Angles(math.rad(-35), math.rad(90), 0), Color3.fromRGB(25, 25, 25), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	piece("MatGyrophare", Vector3.new(0.2, 1.8, 0.2), CFrame.new(0, 1.3, 2.7), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	local gyro = piece("Gyrophare", Vector3.new(2.2, 0.35, 0.6), CFrame.new(0, 2.25, 2.7), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	local lumiere = Instance.new("PointLight")
	lumiere.Name = "LumiereGyro"
	lumiere.Range = 14
	lumiere.Brightness = 3
	lumiere.Parent = gyro
	kartPolice.Parent = g.modele
end

local function descendreDuKart(g: Garde)
	if not g.enKart then
		return
	end
	g.enKart = false
	local k = g.modele:FindFirstChild("KartPolice")
	if k then
		k:Destroy()
	end
	g.hum.HipHeight = g.hanchesBase
end

---------------------------------------------------------------------
-- Poursuites (qui poursuit qui) et messages envoyés aux joueurs
---------------------------------------------------------------------
local poursuivants: { [Player]: { [Garde]: boolean } } = {}
local enArrestation: { [Player]: boolean } = {}

local function nombrePoursuivants(joueur: Player): number
	local n = 0
	for _ in pairs(poursuivants[joueur] or {}) do
		n += 1
	end
	return n
end

local function commencerPoursuite(g: Garde, joueur: Player, position: Vector3, renfort: boolean)
	if enArrestation[joueur] then
		return
	end
	g.cible = joueur
	g.derniereVue = os.clock()
	g.dernierePos = position
	g.chemin = nil
	g.bulle.TextColor3 = Color3.fromRGB(255, 60, 60)
	if g.enKart then
		g.etat = "poursuite"
		g.hum.WalkSpeed = R.VitessePoursuite
		g.bulle.Text = "❗"
	else
		-- Il s'arrête une fraction de seconde... et saute dans son kart de police !
		g.etat = "monte"
		g.finEtat = os.clock() + R.TempsMonteeKart
		g.hum:MoveTo(g.racine.Position)
		g.bulle.Text = "❗🚓"
	end
	local liste = poursuivants[joueur]
	local premier = liste == nil or next(liste) == nil
	if not liste then
		liste = {}
		poursuivants[joueur] = liste
	end
	liste[g] = true
	local niveau = math.min(nombrePoursuivants(joueur), 3)
	Alerte:FireClient(joueur, { etat = if premier then "repere" else "niveau", niveau = niveau })

	-- Le garde appelle les collègues proches en renfort
	if not renfort then
		for _, autre in ipairs(gardes) do
			if autre ~= g and (autre.etat == "patrouille" or autre.etat == "recherche") and (autre.racine.Position - position).Magnitude < R.DistanceRenfort then
				commencerPoursuite(autre, joueur, position, true)
			end
		end
	end
end

local function finirPoursuite(g: Garde, nouvelEtat: string)
	local joueur = g.cible
	g.etat = nouvelEtat
	g.cible = nil
	g.chemin = nil
	descendreDuKart(g)
	g.hum.WalkSpeed = R.VitessePatrouille
	if nouvelEtat == "recherche" then
		g.bulle.Text = "❓"
		g.bulle.TextColor3 = Color3.fromRGB(255, 220, 80)
		g.finEtat = os.clock() + 2.5
		g.hum:MoveTo(g.racine.Position)
	else
		g.bulle.Text = ""
	end
	if joueur and poursuivants[joueur] then
		poursuivants[joueur][g] = nil
		if next(poursuivants[joueur]) == nil then
			poursuivants[joueur] = nil
			if not enArrestation[joueur] and joueur.Parent then
				-- Plus personne ne te poursuit : tu les as semés !
				Alerte:FireClient(joueur, { etat = "seme", bonus = R.BonusSemer })
				AjouterXP:Fire(joueur, R.BonusSemer)
			end
		else
			Alerte:FireClient(joueur, { etat = "niveau", niveau = math.min(nombrePoursuivants(joueur), 3) })
		end
	end
end

local function arreter(g: Garde, joueur: Player)
	if enArrestation[joueur] then
		return
	end
	enArrestation[joueur] = true
	local k = kartDe(joueur)
	-- Tous les gardes qui le poursuivaient arrêtent la poursuite
	for autre in pairs(poursuivants[joueur] or {}) do
		autre.etat = "patrouille"
		autre.cible = nil
		autre.chemin = nil
		autre.bulle.Text = ""
		if autre ~= g then
			descendreDuKart(autre)
		end
		autre.hum.WalkSpeed = R.VitessePatrouille
	end
	poursuivants[joueur] = nil
	g.etat = "arrestation"
	g.finEtat = os.clock() + 2.5
	g.bulle.Text = "STOP ✋"
	g.bulle.TextColor3 = Color3.new(1, 1, 1)
	g.hum:MoveTo(g.racine.Position)
	Alerte:FireClient(joueur, { etat = "attrape" })
	if k then
		k.chassis.Anchored = true -- le kart est immobilisé
	end
	task.delay(2.2, function()
		local perso = joueur.Character
		local humanoide = perso and perso:FindFirstChildOfClass("Humanoid")
		if humanoide then
			humanoide.Sit = false
		end
		if k and k.kart.Parent then
			k.kart:Destroy()
		end
		task.wait(0.15)
		local garage = carte:FindFirstChild("GarageVIP")
		local apparition = garage and garage:FindFirstChild("ApparitionGarage") :: BasePart?
		if perso and perso.Parent and apparition then
			perso:PivotTo(apparition.CFrame + Vector3.new(0, 4, 0))
		end
		enArrestation[joueur] = nil
	end)
end

local function glisser(g: Garde)
	local joueur = g.cible
	g.etat = "glisse"
	g.finEtat = os.clock() + R.DureeGlissade
	g.prochaineGlissade = os.clock() + R.DureeGlissade + 5
	g.bulle.Text = "😵"
	g.hum.PlatformStand = true
	local regard = aplat(g.racine.CFrame.LookVector)
	g.racine.AssemblyLinearVelocity = regard * 22 + Vector3.new(0, 6, 0)
	g.racine.AssemblyAngularVelocity = g.racine.CFrame.RightVector * 7 -- il part en arrière
	if joueur then
		g.cible = joueur -- il reprendra la poursuite en se relevant
		Alerte:FireClient(joueur, { etat = "glisse", bonus = R.BonusGlissade })
		AjouterXP:Fire(joueur, R.BonusGlissade)
	end
end

local function relever(g: Garde)
	g.hum.PlatformStand = false
	local regard = aplat(g.racine.CFrame.LookVector)
	if regard.Magnitude < 0.1 then
		regard = Vector3.new(0, 0, -1)
	end
	local pos = g.racine.Position + Vector3.new(0, 2.5, 0)
	g.racine.AssemblyLinearVelocity = Vector3.zero
	g.racine.AssemblyAngularVelocity = Vector3.zero
	g.racine.CFrame = CFrame.lookAt(pos, pos + regard.Unit)
	g.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	if g.cible and kartDe(g.cible) and not enArrestation[g.cible] then
		g.etat = "poursuite"
		g.derniereVue = os.clock()
		g.bulle.Text = "❗"
		g.bulle.TextColor3 = Color3.fromRGB(255, 60, 60)
	else
		finirPoursuite(g, "patrouille")
	end
end

---------------------------------------------------------------------
-- Le cerveau d'un garde (tourne en boucle)
---------------------------------------------------------------------
local function cerveau(g: Garde)
	g.hum.WalkSpeed = R.VitessePatrouille
	while g.modele.Parent and g.hum.Health > 0 do
		task.wait(0.15)
		local maintenant = os.clock()

		if g.etat == "glisse" then
			if maintenant > g.finEtat then
				relever(g)
			end
		elseif g.etat == "arrestation" then
			if maintenant > g.finEtat then
				g.etat = "patrouille"
				g.bulle.Text = ""
				descendreDuKart(g)
				g.hum.WalkSpeed = R.VitessePatrouille
			end
		elseif g.etat == "monte" then
			-- Le temps de sauter dans le kart, puis c'est parti
			if not g.cible or enArrestation[g.cible] then
				finirPoursuite(g, "patrouille")
			elseif maintenant > g.finEtat then
				monterEnKart(g)
				g.etat = "poursuite"
				g.hum.WalkSpeed = R.VitessePoursuite
				g.derniereVue = maintenant
				g.bulle.Text = "❗"
			end
		elseif g.etat == "recherche" then
			-- Il regarde autour de lui... puis reprend sa ronde
			g.racine.CFrame *= CFrame.Angles(0, math.rad(25), 0)
			if maintenant > g.finEtat then
				g.etat = "patrouille"
				g.bulle.Text = ""
			end
		end

		-- En patrouille ou en recherche : il guette les karts
		if g.etat == "patrouille" or g.etat == "recherche" then
			for _, k in ipairs(kartsConduits) do
				if dansLeMall(k.chassis.Position) and not enArrestation[k.joueur] and voit(g, k.chassis) then
					commencerPoursuite(g, k.joueur, k.chassis.Position, false)
					break
				end
			end
		end

		if g.etat == "poursuite" then
			local k = kartDe(g.cible)
			if not k or not dansLeMall(k.chassis.Position) or enArrestation[k.joueur] then
				finirPoursuite(g, "recherche") -- il a perdu sa cible (dehors, descendu du kart...)
			else
				if voit(g, k.chassis) then
					g.derniereVue = maintenant
				end
				-- Tant qu'il te voit (ou que la radio le guide), il sait où tu es
				-- et vise un peu devant toi pour te couper la route
				if maintenant - g.derniereVue < R.Radio then
					local vitesseKart = aplat(k.chassis.AssemblyLinearVelocity)
					g.dernierePos = k.chassis.Position + vitesseKart * 0.35
				end
				local ecart = k.chassis.Position - g.racine.Position
				if aplat(ecart).Magnitude < R.DistanceArrestation and math.abs(ecart.Y) < 6 then
					arreter(g, k.joueur)
				elseif maintenant - g.derniereVue > R.TempsPourSemer then
					finirPoursuite(g, "recherche")
				else
					allerVers(g, g.dernierePos or k.chassis.Position)
					-- Il fonce sur le sol mouillé ? Il glisse !
					if maintenant > g.prochaineGlissade and aplat(g.racine.AssemblyLinearVelocity).Magnitude > 12 and surSolMouille(g) then
						glisser(g)
					end
				end
			end
		elseif g.etat == "patrouille" then
			local point = g.ronde[g.indexRonde]
			if aplat(point - g.racine.Position).Magnitude < 4 then
				g.indexRonde = g.indexRonde % #g.ronde + 1
				point = g.ronde[g.indexRonde]
			end
			allerVers(g, point)
		end

		-- Gyrophare du kart de police : bleu / rouge
		local gyrophare = g.modele:FindFirstChild("Gyrophare", true) :: BasePart?
		if gyrophare then
			local couleur = if math.floor(maintenant * 5) % 2 == 0 then Color3.fromRGB(40, 90, 255) else Color3.fromRGB(255, 40, 40)
			gyrophare.Color = couleur
			local lumiere = gyrophare:FindFirstChild("LumiereGyro") :: PointLight?
			if lumiere then
				lumiere.Color = couleur
			end
		end
		animer(g)
	end
end

---------------------------------------------------------------------
-- Démarrage
---------------------------------------------------------------------
for i = 1, R.Policiers do
	local ronde = RONDES_SEGWAY[(i - 1) % #RONDES_SEGWAY + 1]
	local g = creerGarde(ronde, false, i) -- à pied (il monte dans son kart en poursuite)
	task.spawn(cerveau, g)
end

-- Mise à jour régulière de la liste des karts conduits
task.spawn(function()
	while true do
		mettreAJourKarts()
		majFiltreVue()
		task.wait(0.15)
	end
end)

Players.PlayerRemoving:Connect(function(joueur: Player)
	for g in pairs(poursuivants[joueur] or {}) do
		g.cible = nil
		g.etat = "patrouille"
		g.bulle.Text = ""
	end
	poursuivants[joueur] = nil
	enArrestation[joueur] = nil
end)

for i = 1, (R.PoliciersEtage or 0) do
	local ronde = RONDES_ETAGE[(i - 1) % #RONDES_ETAGE + 1]
	local g = creerGarde(ronde, false, 100 + i)
	task.spawn(cerveau, g)
end

print(("[Golden Mall] Police en place : %d policiers en bas, %d à l'étage."):format(R.Policiers, R.PoliciersEtage or 0))
