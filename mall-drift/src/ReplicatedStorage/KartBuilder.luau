--[[
	KartBuilder  (ModuleScript)
	À placer dans : ReplicatedStorage   — nom exact : KartBuilder

	Construit un kart à partir de sa personnalisation (type, couleurs, finition,
	bandes, autocollant, numéro). Utilisé :
	  • par le serveur, pour le vrai kart du joueur
	  • par le garage, pour l'aperçu sur le plateau tournant
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))

local KartBuilder = {}

local NOIR = Color3.fromRGB(25, 25, 25)
local GRIS = Color3.fromRGB(120, 125, 135)
local OR = Color3.fromRGB(225, 175, 45)

---------------------------------------------------------------------
-- Vérifie une personnalisation : tout ce qui est inconnu ou pas encore
-- débloqué au niveau du joueur est remplacé par la valeur par défaut.
---------------------------------------------------------------------
function KartBuilder.Nettoyer(perso: any, niveau: number): { [string]: any }
	local defaut = Config.PersoParDefaut
	local propre = table.clone(defaut)
	if type(perso) ~= "table" then
		return propre
	end

	local function couleurOk(nom)
		local c = type(nom) == "string" and Config.Couleur(nom)
		return c and c.Niveau <= niveau
	end

	local kart = Config.Karts[perso.Kart]
	if kart and kart.Niveau <= niveau then
		propre.Kart = perso.Kart
	end
	for _, champ in ipairs({ "Carrosserie", "Jantes", "Siege", "Bandes" }) do
		if couleurOk(perso[champ]) then
			propre[champ] = perso[champ]
		end
	end
	local finition = type(perso.Finition) == "string" and Config.Finition(perso.Finition)
	if finition and finition.Niveau <= niveau then
		propre.Finition = perso.Finition
	end
	local autocollant = type(perso.Autocollant) == "string" and Config.Autocollant(perso.Autocollant)
	if autocollant and autocollant.Niveau <= niveau then
		propre.Autocollant = perso.Autocollant
	end
	if type(perso.BandesActives) == "boolean" then
		propre.BandesActives = perso.BandesActives
	end
	if type(perso.Numero) == "number" and perso.Numero == perso.Numero then
		propre.Numero = math.clamp(math.floor(perso.Numero), 0, 99)
	end
	return propre
end

---------------------------------------------------------------------
-- Applique les couleurs / finition / déco sur un kart déjà construit
---------------------------------------------------------------------
function KartBuilder.Peindre(modele: Model, perso: { [string]: any })
	local function couleur(nom: string): Color3
		local c = Config.Couleur(nom)
		return c and c.Couleur or Color3.new(1, 1, 1)
	end
	local finition = Config.Finition(perso.Finition) or Config.Finitions[1]

	for _, p in ipairs(modele:GetDescendants()) do
		if p:IsA("BasePart") then
			local role = p:GetAttribute("Peinture")
			if role == "Carrosserie" then
				p.Color = couleur(perso.Carrosserie)
				p.Material = finition.Materiau
				p.Reflectance = finition.Reflet
			elseif role == "Jantes" then
				p.Color = couleur(perso.Jantes)
			elseif role == "Siege" then
				p.Color = couleur(perso.Siege)
			elseif role == "Bandes" then
				p.Color = couleur(perso.Bandes)
				p.Transparency = perso.BandesActives and 0 or 1
			end
		elseif p:IsA("TextLabel") and p.Name == "Deco" then
			local autocollant = Config.Autocollant(perso.Autocollant)
			local symbole = autocollant and autocollant.Texte or ""
			p.Text = (symbole ~= "" and (symbole .. " ") or "") .. tostring(perso.Numero)
		end
	end
	modele:SetAttribute("KartType", perso.Kart)
end

---------------------------------------------------------------------
-- Construit le kart
--   perso  : la personnalisation (voir Config.PersoParDefaut)
--   cf     : position / orientation
--   apercu : true = kart de vitrine (fixe, sans physique ni effets)
---------------------------------------------------------------------
function KartBuilder.Construire(perso: { [string]: any }, cf: CFrame, apercu: boolean?): Model
	local typeKart = Config.Karts[perso.Kart] and perso.Kart or "Basique"
	local modele = Instance.new("Model")
	modele.Name = "Kart_" .. typeKart

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(4, 0.8, 6)
	chassis.CFrame = cf
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	-- Friction 0 : c'est le script de conduite qui gère la glisse
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
	chassis.Anchored = apercu == true
	chassis:SetAttribute("Peinture", "Carrosserie")
	chassis.Parent = modele
	modele.PrimaryPart = chassis

	local function piece(nom: string, taille: Vector3, decalage: CFrame, couleur: Color3, peinture: string?, matiere: Enum.Material?, forme: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = nom
		p.Size = taille
		p.CFrame = chassis.CFrame * decalage
		p.Color = couleur
		p.Material = matiere or Enum.Material.SmoothPlastic
		p.Shape = forme or Enum.PartType.Block
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if peinture then
			p:SetAttribute("Peinture", peinture)
		end
		if apercu then
			p.Anchored = true
		else
			local w = Instance.new("WeldConstraint")
			w.Part0 = chassis
			w.Part1 = p
			w.Parent = p
		end
		p.Parent = modele
		return p
	end

	local CYL = Enum.PartType.Cylinder -- les cylindres Roblox sont couchés sur l'axe X : parfait pour des roues

	-- Roues avant + roues arrière pivotantes (plus petites, comme les vrais karts de drift)
	for _, r in ipairs({
		{ x = -2.2, y = 0.2, z = -2.3, d = 1.6, l = 0.8 },
		{ x = 2.2, y = 0.2, z = -2.3, d = 1.6, l = 0.8 },
		{ x = -1.9, y = -0.05, z = 2.5, d = 1.1, l = 0.6 },
		{ x = 1.9, y = -0.05, z = 2.5, d = 1.1, l = 0.6 },
	}) do
		piece("Roue", Vector3.new(r.l, r.d, r.d), CFrame.new(r.x, r.y, r.z), NOIR, nil, Enum.Material.SmoothPlastic, CYL)
		local dehors = math.sign(r.x) * (math.abs(r.x) + r.l / 2 + 0.03)
		piece("Jante", Vector3.new(0.06, r.d * 0.6, r.d * 0.6), CFrame.new(dehors, r.y, r.z), Color3.new(1, 1, 1), "Jantes", Enum.Material.Metal, CYL)
	end

	piece("PareChoc", Vector3.new(4.6, 0.5, 0.6), CFrame.new(0, 0, -3.2), NOIR)
	piece("Colonne", Vector3.new(0.3, 0.3, 2), CFrame.new(0, 1.1, -1.6) * CFrame.Angles(math.rad(35), 0, 0), GRIS)
	piece("Volant", Vector3.new(0.2, 1.7, 1.7), CFrame.new(0, 1.7, -0.9) * CFrame.Angles(math.rad(-35), math.rad(90), 0), OR, nil, Enum.Material.Metal, CYL)
	piece("Dossier", Vector3.new(2.4, 2, 0.4), CFrame.new(0, 1.6, 2.2) * CFrame.Angles(math.rad(-10), 0, 0), NOIR, "Siege", Enum.Material.Fabric)

	-- Bandes de course sur le capot
	piece("Bande", Vector3.new(0.45, 0.05, 3.6), CFrame.new(-0.6, 0.42, -1.2), Color3.new(1, 1, 1), "Bandes")
	piece("Bande", Vector3.new(0.45, 0.05, 3.6), CFrame.new(0.6, 0.42, -1.2), Color3.new(1, 1, 1), "Bandes")

	-- Flancs avec autocollant + numéro
	for _, cote in ipairs({ -1, 1 }) do
		local flanc = piece("Flanc", Vector3.new(0.05, 0.7, 3), CFrame.new(cote * 2.03, 0, -0.6), Color3.new(1, 1, 1), nil)
		flanc.Transparency = 1
		local sg = Instance.new("SurfaceGui")
		sg.Face = cote < 0 and Enum.NormalId.Left or Enum.NormalId.Right
		sg.LightInfluence = 0.5
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 60
		sg.Parent = flanc
		local deco = Instance.new("TextLabel")
		deco.Name = "Deco"
		deco.Size = UDim2.fromScale(1, 1)
		deco.BackgroundTransparency = 1
		deco.TextScaled = true
		deco.Font = Enum.Font.GothamBlack
		deco.TextColor3 = Color3.new(1, 1, 1)
		local contour = Instance.new("UIStroke")
		contour.Thickness = 2
		contour.Parent = deco
		deco.Parent = sg
	end

	-- Éléments propres à chaque modèle de kart
	if typeKart == "Chariot" then
		local panier = piece("Panier", Vector3.new(3.6, 2, 2.2), CFrame.new(0, 1.4, -2.1), GRIS, nil, Enum.Material.DiamondPlate)
		panier.Transparency = 0.35
		piece("Poignee", Vector3.new(3.4, 0.25, 0.25), CFrame.new(0, 2.6, -1), Color3.fromRGB(220, 40, 40))
	elseif typeKart == "Bolide" or typeKart == "ProDubai" then
		local dore = typeKart == "ProDubai"
		piece("Aileron", Vector3.new(4.2, 0.2, 1), CFrame.new(0, 2.5, 3), NOIR, (not dore) and "Carrosserie" or nil, dore and Enum.Material.Foil or nil).Color = dore and OR or NOIR
		piece("SupportAileron", Vector3.new(0.2, 1.4, 0.4), CFrame.new(-1.3, 1.8, 2.9), NOIR)
		piece("SupportAileron", Vector3.new(0.2, 1.4, 0.4), CFrame.new(1.3, 1.8, 2.9), NOIR)
		piece("Nez", Vector3.new(3, 0.6, 1.6), CFrame.new(0, 0.6, -2.4) * CFrame.Angles(math.rad(-12), 0, 0), Color3.new(1, 1, 1), "Carrosserie")
		if dore then
			for _, cote in ipairs({ -1, 1 }) do
				piece("LiseretOr", Vector3.new(0.1, 0.15, 5.6), CFrame.new(cote * 2.05, 0.35, 0), OR, nil, Enum.Material.Foil)
			end
		end
	end

	-- Le siège (on s'assoit dedans)
	local siege = Instance.new("Seat")
	siege.Name = "Siege"
	siege.Size = Vector3.new(2.4, 0.6, 2.2)
	siege.CFrame = chassis.CFrame * CFrame.new(0, 0.7, 1)
	siege.Material = Enum.Material.Fabric
	siege.CanCollide = false
	siege.Massless = true
	siege.TopSurface = Enum.SurfaceType.Smooth
	siege:SetAttribute("Peinture", "Siege")
	if apercu then
		siege.Anchored = true
		siege.Disabled = true
	else
		local ws = Instance.new("WeldConstraint")
		ws.Part0 = chassis
		ws.Part1 = siege
		ws.Parent = siege
	end
	siege.Parent = modele

	if not apercu then
		-- Garde le kart à plat (il tourne sur lui-même mais ne se retourne pas)
		local attRedresse = Instance.new("Attachment")
		attRedresse.Name = "Redresse"
		attRedresse.CFrame = CFrame.Angles(0, 0, math.rad(90)) -- axe principal vers le haut
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
			a0.Position = Vector3.new(cote - 0.3, -0.38, 2.6)
			a0.Parent = chassis
			local a1 = Instance.new("Attachment")
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
	end

	KartBuilder.Peindre(modele, perso)
	modele:SetAttribute("KartType", typeKart)
	return modele
end

return KartBuilder
