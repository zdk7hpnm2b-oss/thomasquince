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
-- possessions : { Couleurs = { [nom] = true }, Premium = { [nom] = true } } (ce que le joueur a acheté)
function KartBuilder.Nettoyer(perso: any, niveau: number, possessions: any?): { [string]: any }
	local achats = type(possessions) == "table" and possessions or {}
	local couleursAchetees = type(achats.Couleurs) == "table" and achats.Couleurs or {}
	local premiumAchetees = type(achats.Premium) == "table" and achats.Premium or {}
	local defaut = Config.PersoParDefaut
	local propre = table.clone(defaut)
	if type(perso) ~= "table" then
		return propre
	end

	local function couleurOk(nom)
		local c = type(nom) == "string" and Config.Couleur(nom)
		return c and c.Niveau <= niveau and ((c.Prix or 0) == 0 or couleursAchetees[c.Nom] == true)
	end

	local kartsAchetes = type(achats.Karts) == "table" and achats.Karts or {}
	local kart = Config.Karts[perso.Kart]
	if kart and kart.Niveau <= niveau and (not kart.Exclusif or kartsAchetes[perso.Kart] == true) then
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
	-- Peinture premium (achetée en Robux) : elle remplace la couleur de la carrosserie
	if type(perso.Premium) == "string" and Config.PeinturePremium(perso.Premium) and premiumAchetees[perso.Premium] == true then
		propre.Premium = perso.Premium
	end
	-- Traînée (achetée en Robux, ou gagnée à la roue)
	local traineesAchetees = type(achats.Trainees) == "table" and achats.Trainees or {}
	if type(perso.Trainee) == "string" and Config.Trainee(perso.Trainee) and (perso.Trainee == "Aucune" or traineesAchetees[perso.Trainee] == true) then
		propre.Trainee = perso.Trainee
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
	local premium = type(perso.Premium) == "string" and Config.PeinturePremium(perso.Premium) or nil
	-- Arc-en-ciel animé : peinture premium « Arc-en-ciel » / « Licorne pastel », ou le kart exclusif Galaxie
	local kartGalaxie = perso.Kart == "Galaxie" and not perso.Police
	modele:SetAttribute("CarrosserieArcEnCiel", (premium ~= nil and premium.ArcEnCiel == true) or (kartGalaxie and premium == nil))
	modele:SetAttribute("ArcEnCielPastel", premium ~= nil and premium.Pastel == true)
	local neon = Config.Neon(perso.Neon) or Config.Neons[2]
	local sansNeon = neon.Nom == "Aucun"
	modele:SetAttribute("NeonArcEnCiel", neon.Nom == "Arc-en-ciel")

	for _, p in ipairs(modele:GetDescendants()) do
		if p:IsA("BasePart") then
			local role = p:GetAttribute("Peinture")
			if role == "Carrosserie" then
				if premium then
					p.Color = premium.Couleur
					p.Material = premium.Materiau
					p.Reflectance = premium.Reflet
				else
					p.Color = couleur(perso.Carrosserie)
					p.Material = finition.Materiau
					p.Reflectance = finition.Reflet
				end
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
	-- Écran digital sur le volant : vitesse, régime, état de la piste (mis à jour par le pilote)
	local ecran = piece("EcranVolant", Vector3.new(0.78, 0.46, 0.08), CFrame.new(0, 1.36, -1.58) * CFrame.Angles(math.rad(-35), 0, 0), Color3.fromRGB(12, 14, 18), nil, Enum.Material.Glass)
	piece("CadreEcran", Vector3.new(0.86, 0.54, 0.06), CFrame.new(0, 1.36, -1.6) * CFrame.Angles(math.rad(-35), 0, 0), NOIR_MAT, nil, Enum.Material.SmoothPlastic)
	local tableau = Instance.new("SurfaceGui")
	tableau.Name = "Tableau"
	tableau.Face = Enum.NormalId.Back -- tourné vers le pilote
	tableau.LightInfluence = 0
	tableau.Brightness = 1.4
	tableau.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	tableau.PixelsPerStud = 260
	tableau.Parent = ecran
	local fondEcran = Instance.new("Frame")
	fondEcran.Size = UDim2.fromScale(1, 1)
	fondEcran.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
	fondEcran.Parent = tableau
	local function ligne(nom: string, taille: UDim2, position: UDim2, couleur: Color3, texte: string, alignement: Enum.TextXAlignment?): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = nom
		l.Size = taille
		l.Position = position
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Code
		l.TextScaled = true
		l.TextColor3 = couleur
		l.TextXAlignment = alignement or Enum.TextXAlignment.Left
		l.Text = texte
		l.Parent = fondEcran
		return l
	end
	ligne("Marque", UDim2.new(0.6, 0, 0.13, 0), UDim2.new(0.05, 0, 0.05, 0), Color3.fromRGB(90, 200, 255), "GOLDEN MALL DRIFT")
	ligne("Piste", UDim2.new(0.32, 0, 0.13, 0), UDim2.new(0.63, 0, 0.05, 0), Color3.fromRGB(255, 200, 60), "SEC", Enum.TextXAlignment.Right)
	ligne("Vitesse", UDim2.new(0.45, 0, 0.46, 0), UDim2.new(0.05, 0, 0.22, 0), Color3.new(1, 1, 1), "000")
	ligne("Unite", UDim2.new(0.3, 0, 0.12, 0), UDim2.new(0.05, 0, 0.68, 0), Color3.fromRGB(150, 150, 160), "KM/H")
	ligne("Regime", UDim2.new(0.45, 0, 0.2, 0), UDim2.new(0.5, 0, 0.26, 0), Color3.fromRGB(230, 230, 235), "1500 TR/MIN", Enum.TextXAlignment.Right)
	ligne("Etat", UDim2.new(0.45, 0, 0.14, 0), UDim2.new(0.5, 0, 0.52, 0), Color3.fromRGB(120, 255, 140), "", Enum.TextXAlignment.Right)
	local barre = Instance.new("Frame")
	barre.Name = "BarreRegime"
	barre.Size = UDim2.new(0.9, 0, 0.08, 0)
	barre.Position = UDim2.new(0.05, 0, 0.86, 0)
	barre.BackgroundColor3 = Color3.fromRGB(35, 38, 45)
	barre.BorderSizePixel = 0
	barre.Parent = fondEcran
	local remplissage = Instance.new("Frame")
	remplissage.Name = "Remplissage"
	remplissage.Size = UDim2.fromScale(0, 1)
	remplissage.BackgroundColor3 = Color3.fromRGB(90, 200, 255)
	remplissage.BorderSizePixel = 0
	remplissage.Parent = barre

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

	-- ✨ KART EXCLUSIF « Licorne Galaxie » : ailes néon, corne dorée, grand aileron,
	-- étoile qui brille, paillettes et traînée arc-en-ciel
	if typeKart == "Galaxie" then
		for _, cote in ipairs({ -1, 1 }) do
			for i, decal in ipairs({ 0, 0.55, 1.1 }) do
				local aile = piece("AileGalaxie", Vector3.new(0.08, 0.35, 2.4 - decal), CFrame.new(cote * (1.95 + decal * 0.5), 0.55 + decal * 0.45, 0.6 + decal * 0.3) * CFrame.Angles(math.rad(-12), 0, math.rad(cote * -(35 + i * 8))), Color3.fromRGB(255, 140, 230), nil, Enum.Material.Neon)
				aile.Transparency = 0.15
				aile:SetAttribute("ArcEnCiel", true)
			end
		end
		local corne = arrondi("CorneLicorne", Vector3.new(0.32, 1.5, 0.32), CFrame.new(0, 1.05, -2.55) * CFrame.Angles(math.rad(-30), 0, 0), OR, nil, Enum.Material.Foil)
		corne.Reflectance = 0.4
		for _, cote in ipairs({ -1, 1 }) do
			piece("SupportAileron", Vector3.new(0.18, 1.6, 0.35), CFrame.new(cote * 1.2, 1.7, 3.05), Color3.fromRGB(250, 250, 255), nil, Enum.Material.SmoothPlastic)
		end
		local aileron = piece("AileronGalaxie", Vector3.new(4.4, 0.18, 1.1), CFrame.new(0, 2.55, 3.15) * CFrame.Angles(math.rad(8), 0, 0), Color3.fromRGB(150, 90, 255), nil, Enum.Material.Neon)
		aileron:SetAttribute("ArcEnCiel", true)
		local etoile = arrondi("EtoileGalaxie", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 2.95, 3.15), Color3.fromRGB(255, 240, 150), nil, Enum.Material.Neon)
		local lumiereEtoile = Instance.new("PointLight")
		lumiereEtoile.Color = Color3.fromRGB(255, 160, 240)
		lumiereEtoile.Range = 10
		lumiereEtoile.Brightness = 2
		lumiereEtoile.Parent = etoile
		local paillettes = Instance.new("ParticleEmitter")
		paillettes.Name = "PaillettesGalaxie"
		paillettes.LightEmission = 1
		paillettes.LightInfluence = 0
		paillettes.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 220)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 220, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 140)),
		})
		paillettes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		paillettes.Lifetime = NumberRange.new(0.6, 1.2)
		paillettes.Speed = NumberRange.new(1, 3)
		paillettes.SpreadAngle = Vector2.new(180, 180)
		paillettes.RotSpeed = NumberRange.new(-180, 180)
		paillettes.Rate = 25
		paillettes.Parent = etoile
		if not apercu then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(-1.6, 0.4, 3.2)
			a0.Parent = chassis
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(1.6, 0.4, 3.2)
			a1.Parent = chassis
			local trainee = Instance.new("Trail")
			trainee.Name = "TraineeArcEnCiel"
			trainee.Attachment0 = a0
			trainee.Attachment1 = a1
			trainee.LightEmission = 0.8
			trainee.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
			})
			trainee.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
			trainee.Lifetime = 0.7
			trainee.MinLength = 0.2
			trainee.FaceCamera = true
			trainee.Parent = chassis
		end
	end

	-- 🌈 TRAÎNÉE achetée : un ruban de couleur derrière le kart + des particules
	local trainee = (not perso.Police) and Config.Trainee(perso.Trainee or "Aucune") or nil
	-- (aussi sur le kart du garage : en tournant sur le plateau, il dessine un cercle de couleur)
	if trainee and trainee.Couleurs then
		local t0 = Instance.new("Attachment")
		t0.Position = Vector3.new(0, 0.1, 3.1)
		t0.Parent = chassis
		local t1 = Instance.new("Attachment")
		t1.Position = Vector3.new(0, 1.3, 3.1)
		t1.Parent = chassis
		local ruban = Instance.new("Trail")
		ruban.Name = "TraineeAchetee"
		ruban.Attachment0 = t0
		ruban.Attachment1 = t1
		ruban.Color = trainee.Couleurs
		ruban.LightEmission = 1
		ruban.LightInfluence = 0
		ruban.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		ruban.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
		ruban.Lifetime = 0.9
		ruban.MinLength = 0.1
		ruban.FaceCamera = true
		ruban.Parent = chassis
		if trainee.Particules then
			local emetteur = Instance.new("ParticleEmitter")
			emetteur.Name = "ParticulesTrainee"
			emetteur.LightEmission = 1
			emetteur.LightInfluence = 0
			emetteur.Color = trainee.Couleurs
			emetteur.Lifetime = NumberRange.new(0.5, 1)
			emetteur.Speed = NumberRange.new(1, 4)
			emetteur.SpreadAngle = Vector2.new(60, 60)
			emetteur.Rate = 30
			emetteur.EmissionDirection = Enum.NormalId.Back
			emetteur.RotSpeed = NumberRange.new(-120, 120)
			if trainee.Particules == "Feu" then
				emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
				emetteur.Acceleration = Vector3.new(0, 6, 0)
				emetteur.Rate = 60
			elseif trainee.Particules == "Eclair" then
				emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
				emetteur.Speed = NumberRange.new(6, 12)
				emetteur.Lifetime = NumberRange.new(0.15, 0.3)
				emetteur.Rate = 80
			else
				emetteur.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
			end
			local att = Instance.new("Attachment")
			att.Position = Vector3.new(0, 0.6, 3.2)
			att.Parent = chassis
			emetteur.Parent = att
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

			-- Étincelles du drift (la couleur change avec le niveau : bleu, orange, violet)
			local etincelles = Instance.new("ParticleEmitter")
			etincelles.Name = "Etincelles"
			etincelles.LightEmission = 1
			etincelles.LightInfluence = 0
			etincelles.Color = ColorSequence.new(Color3.fromRGB(90, 170, 255))
			etincelles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
			etincelles.Lifetime = NumberRange.new(0.15, 0.35)
			etincelles.Speed = NumberRange.new(10, 20)
			etincelles.SpreadAngle = Vector2.new(35, 35)
			etincelles.Acceleration = Vector3.new(0, -40, 0)
			etincelles.EmissionDirection = Enum.NormalId.Back
			etincelles.Drag = 3
			etincelles.Rate = 90
			etincelles.Enabled = false
			etincelles.Parent = attEffet
		end

		-- Flamme et lumière du BOOST (derrière le kart)
		local attBoost = Instance.new("Attachment")
		attBoost.Name = "Echappement"
		attBoost.Position = Vector3.new(0, 0.3, 3.3)
		attBoost.Parent = chassis
		local flamme = Instance.new("ParticleEmitter")
		flamme.Name = "FlammeBoost"
		flamme.LightEmission = 1
		flamme.LightInfluence = 0
		flamme.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 220, 255)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 160, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 20)),
		})
		flamme.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
		flamme.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		flamme.Lifetime = NumberRange.new(0.12, 0.25)
		flamme.Speed = NumberRange.new(14, 20)
		flamme.SpreadAngle = Vector2.new(8, 8)
		flamme.EmissionDirection = Enum.NormalId.Back
		flamme.Rate = 140
		flamme.Enabled = false
		flamme.Parent = attBoost
		local lumiereBoost = Instance.new("PointLight")
		lumiereBoost.Name = "LumiereBoost"
		lumiereBoost.Color = Color3.fromRGB(255, 150, 50)
		lumiereBoost.Range = 14
		lumiereBoost.Brightness = 3
		lumiereBoost.Enabled = false
		lumiereBoost.Parent = attBoost

		-- Phares : éclairent la piste devant le kart (surtout la nuit)
		local attPhares = Instance.new("Attachment")
		attPhares.Name = "Phares"
		attPhares.Position = Vector3.new(0, 0.4, -3.4)
		attPhares.Parent = chassis
		local phare = Instance.new("SpotLight")
		phare.Name = "Phare"
		phare.Face = Enum.NormalId.Front
		phare.Angle = 55
		phare.Range = 40
		phare.Brightness = 2
		phare.Color = Color3.fromRGB(235, 245, 255)
		phare.Parent = attPhares
	end

	KartBuilder.Peindre(modele, perso)
	modele:SetAttribute("KartType", typeKart)
	return modele
end

return KartBuilder
