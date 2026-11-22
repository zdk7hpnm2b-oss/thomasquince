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
	local neon = type(perso.Neon) == "string" and Config.Neon(perso.Neon)
	if neon and neon.Niveau <= niveau then
		propre.Neon = perso.Neon
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
	local neon = Config.Neon(perso.Neon) or Config.Neons[2]
	local sansNeon = neon.Nom == "Aucun"
	modele:SetAttribute("NeonArcEnCiel", neon.Nom == "Arc-en-ciel")

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
			elseif role == "Neon" then
				p.Color = neon.Couleur
				p.Transparency = sansNeon and 1 or 0
			end
		elseif p:IsA("PointLight") and p.Name == "LumiereNeon" then
			p.Color = neon.Couleur
			p.Enabled = not sansNeon
		elseif p:IsA("TextLabel") and p.Name == "Deco" then
			if perso.Police then
				p.Text = "POLICE"
				p.TextColor3 = Color3.fromRGB(25, 60, 170)
			else
				local autocollant = Config.Autocollant(perso.Autocollant)
				local symbole = autocollant and autocollant.Texte or ""
				p.Text = (symbole ~= "" and (symbole .. " ") or "") .. tostring(perso.Numero)
			end
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
	chassis.Transparency = 1 -- bloc invisible pour la physique ; le look vient des pièces ci-dessous
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

	-- Une pièce arrondie (ellipsoïde) : capot bombé, nez du kart
	local function arrondi(nom: string, taille: Vector3, decalage: CFrame, couleur: Color3, peinture: string?, matiere: Enum.Material?): Part
		local p = piece(nom, taille, decalage, couleur, peinture, matiere)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end

	-------------------------------------------------------------------
	-- LE KART DE DRIFT : coque basse, nez arrondi, capot bombé, colonne de
	-- direction, siège baquet à l'arrière, levier de drift, roues pivotantes
	-------------------------------------------------------------------
	local NOIR_MAT = Color3.fromRGB(28, 28, 32)
	local GRIS_FONCE = Color3.fromRGB(55, 55, 62)

	-- Coque (aux couleurs du joueur)
	piece("Coque", Vector3.new(3.6, 0.5, 5.4), CFrame.new(0, -0.1, -0.1), Color3.new(1, 1, 1), "Carrosserie")
	for _, cote in ipairs({ -1, 1 }) do
		piece("BordCoque", Vector3.new(0.3, 0.45, 5), CFrame.new(cote * 1.7, 0.35, -0.1), Color3.new(1, 1, 1), "Carrosserie")
		piece("Bande", Vector3.new(0.32, 0.05, 5), CFrame.new(cote * 1.7, 0.6, -0.1), Color3.new(1, 1, 1), "Bandes")
		-- Petite lumière bleue sur le côté
		piece("LedCote", Vector3.new(0.06, 0.14, 0.45), CFrame.new(cote * 1.87, 0.2, 0.7), Color3.fromRGB(60, 140, 255), nil, Enum.Material.Neon)
	end
	-- Nez arrondi + capot bombé devant la colonne
	arrondi("Nez", Vector3.new(3.6, 0.75, 1.6), CFrame.new(0, 0.05, -2.8), Color3.new(1, 1, 1), "Carrosserie")
	arrondi("Capot", Vector3.new(1.7, 0.9, 1.9), CFrame.new(0, 0.45, -2.15), Color3.new(1, 1, 1), "Carrosserie")
	-- Plancher antidérapant (où vont les pieds)
	piece("ReposePieds", Vector3.new(3, 0.08, 2.2), CFrame.new(0, 0.2, -0.6), GRIS_FONCE, nil, Enum.Material.DiamondPlate)

	-- Roue avant motrice (cachée sous le nez) + roues arrière pivotantes à jantes blanches
	piece("Roue", Vector3.new(0.7, 1.1, 1.1), CFrame.new(0, -0.05, -2.3), NOIR_MAT, nil, Enum.Material.SmoothPlastic, CYL)
	piece("BarreArriere", Vector3.new(3.2, 0.25, 0.3), CFrame.new(0, 0.25, 2.75), NOIR_MAT, nil, Enum.Material.Metal)
	for _, cote in ipairs({ -1, 1 }) do
		local x = cote * 1.35
		piece("Roue", Vector3.new(0.45, 0.9, 0.9), CFrame.new(x, -0.12, 3.05), NOIR_MAT, nil, Enum.Material.SmoothPlastic, CYL)
		piece("Jante", Vector3.new(0.47, 0.5, 0.5), CFrame.new(x, -0.12, 3.05), Color3.new(1, 1, 1), "Jantes", Enum.Material.SmoothPlastic, CYL)
		piece("Fourche", Vector3.new(0.12, 0.55, 0.12), CFrame.new(x - 0.3, 0.12, 2.95), NOIR_MAT, nil, Enum.Material.Metal)
		piece("Fourche", Vector3.new(0.12, 0.55, 0.12), CFrame.new(x + 0.3, 0.12, 2.95), NOIR_MAT, nil, Enum.Material.Metal)
		piece("TeteFourche", Vector3.new(0.75, 0.15, 0.3), CFrame.new(x, 0.4, 2.85), NOIR_MAT, nil, Enum.Material.Metal)
	end

	-- Colonne de direction + volant
	piece("Colonne", Vector3.new(0.2, 1.75, 0.2), CFrame.new(0, 1.0, -1.45) * CFrame.Angles(math.rad(-18), 0, 0), Color3.fromRGB(40, 40, 46), nil, Enum.Material.Metal)
	piece("BagueColonne", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 1.2, -1.38) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(235, 235, 240), nil, Enum.Material.SmoothPlastic, CYL)
	piece("Volant", Vector3.new(0.14, 1.55, 1.55), CFrame.new(0, 1.85, -1.2) * CFrame.Angles(math.rad(-55), math.rad(90), 0), NOIR_MAT, nil, Enum.Material.SmoothPlastic, CYL)
	piece("MoyeuVolant", Vector3.new(0.18, 0.5, 0.5), CFrame.new(0, 1.86, -1.18) * CFrame.Angles(math.rad(-55), math.rad(90), 0), Color3.fromRGB(70, 70, 78), nil, Enum.Material.Metal, CYL)
	piece("EcranVolant", Vector3.new(0.5, 0.32, 0.08), CFrame.new(0, 1.35, -1.55) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(60, 170, 255), nil, Enum.Material.Neon)

	-- Siège baquet (couleur du siège) : dossier + petits rebords
	piece("Dossier", Vector3.new(2.1, 1.3, 0.3), CFrame.new(0, 1.05, 2.15) * CFrame.Angles(math.rad(-15), 0, 0), Color3.new(1, 1, 1), "Siege", Enum.Material.SmoothPlastic)
	for _, cote in ipairs({ -1, 1 }) do
		piece("RebordSiege", Vector3.new(0.25, 0.5, 1.8), CFrame.new(cote * 1.1, 0.75, 1.25), Color3.new(1, 1, 1), "Siege", Enum.Material.SmoothPlastic)
	end

	-- Levier de drift rouge (côté droit) avec sa poignée noire
	piece("LevierDrift", Vector3.new(0.14, 0.14, 1.9), CFrame.new(1.45, 0.85, 1.35) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(220, 30, 35), nil, Enum.Material.SmoothPlastic)
	piece("PoigneeLevier", Vector3.new(0.22, 0.22, 0.55), CFrame.new(1.45, 1.15, 0.45) * CFrame.Angles(math.rad(-20), 0, 0), NOIR_MAT, nil, Enum.Material.Fabric)

	-- Néons sous le kart (underglow) + la lumière qu'ils projettent sur le sol
	for _, cote in ipairs({ -1, 1 }) do
		piece("Neon", Vector3.new(0.25, 0.12, 5.2), CFrame.new(cote * 1.6, -0.4, -0.1), Color3.new(1, 1, 1), "Neon", Enum.Material.Neon)
		piece("Neon", Vector3.new(3, 0.12, 0.25), CFrame.new(0, -0.4, cote * 2.6), Color3.new(1, 1, 1), "Neon", Enum.Material.Neon)
	end
	local attLumiere = Instance.new("Attachment")
	attLumiere.Name = "SousLeKart"
	attLumiere.Position = Vector3.new(0, -0.7, 0)
	attLumiere.Parent = chassis
	local lumiereNeon = Instance.new("PointLight")
	lumiereNeon.Name = "LumiereNeon"
	lumiereNeon.Range = 11
	lumiereNeon.Brightness = 4
	lumiereNeon.Shadows = false
	lumiereNeon.Parent = attLumiere

	-- Plaque numéro à l'avant + autocollant et numéro sur les côtés
	local plaque = piece("PlaqueNumero", Vector3.new(1.1, 0.45, 0.08), CFrame.new(0, 0.25, -3.62), Color3.fromRGB(245, 245, 245))
	local sgPlaque = Instance.new("SurfaceGui")
	sgPlaque.Face = Enum.NormalId.Front
	sgPlaque.LightInfluence = 0.5
	sgPlaque.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sgPlaque.PixelsPerStud = 60
	sgPlaque.Parent = plaque
	local textePlaque = Instance.new("TextLabel")
	textePlaque.Name = "Deco"
	textePlaque.Size = UDim2.fromScale(1, 1)
	textePlaque.BackgroundTransparency = 1
	textePlaque.TextScaled = true
	textePlaque.Font = Enum.Font.GothamBlack
	textePlaque.TextColor3 = Color3.fromRGB(20, 20, 24)
	textePlaque.Parent = sgPlaque
	for _, cote in ipairs({ -1, 1 }) do
		local flanc = piece("Flanc", Vector3.new(0.05, 0.4, 1.8), CFrame.new(cote * 1.88, 0.3, -0.9), Color3.new(1, 1, 1), nil)
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
		if dore then
			for _, cote in ipairs({ -1, 1 }) do
				piece("LiseretOr", Vector3.new(0.1, 0.15, 5.6), CFrame.new(cote * 2.05, 0.35, 0), OR, nil, Enum.Material.Foil)
			end
		end
	end

	-- Kart de police (mode en ligne) : mât + gyrophare rouge et bleu
	if perso.Police then
		piece("MatGyrophare", Vector3.new(0.2, 1.8, 0.2), CFrame.new(0, 1.3, 2.7), Color3.fromRGB(40, 40, 45), nil, Enum.Material.Metal)
		piece("GyroPolice", Vector3.new(1.1, 0.35, 0.6), CFrame.new(-0.55, 2.25, 2.7), Color3.fromRGB(255, 40, 40), nil, Enum.Material.Neon)
		piece("GyroPolice", Vector3.new(1.1, 0.35, 0.6), CFrame.new(0.55, 2.25, 2.7), Color3.fromRGB(40, 90, 255), nil, Enum.Material.Neon)
		modele:SetAttribute("Police", true)
	end

	-- Le siège (on s'assoit dedans)
	local siege = Instance.new("Seat")
	siege.Name = "Siege"
	siege.Size = Vector3.new(2, 0.45, 1.9)
	siege.CFrame = chassis.CFrame * CFrame.new(0, 0.55, 1.2)
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
