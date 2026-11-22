--[[
	PNJServer  (Script)
	À placer dans : ServerScriptService   — nom conseillé : PNJServer

	Met du MONDE dans le mall : un vendeur à la caisse de chaque boutique,
	des clients qui font leurs courses, des gens assis sur les bancs.
	Le script MallDriftServer prépare des emplacements invisibles « PostePNJ »
	(rôle : vendeur, client ou assis) ; ce script y place des personnages.

	Les personnages sont immobiles (ancrés) et ne bloquent pas les karts.
	Réglages : KartConfig > Config.PNJ (nombre maximum, chance d'avoir un client).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
ReplicatedStorage:WaitForChild("MallDriftRemotes") -- = la carte est construite
local carte = workspace:WaitForChild("GoldenMall")

local REGLAGES = Config.PNJ or { Max = 220, ChanceClient = 0.75 }
local random = Random.new(7)

local dossier = Instance.new("Folder")
dossier.Name = "PNJ"
dossier.Parent = workspace

local ANIM_REPOS = "rbxassetid://507766388"
local ANIM_ASSIS = "rbxassetid://2506281703"

local PEAUX = {
	Color3.fromRGB(255, 224, 189), Color3.fromRGB(241, 194, 150), Color3.fromRGB(224, 172, 125),
	Color3.fromRGB(198, 134, 90), Color3.fromRGB(141, 85, 55), Color3.fromRGB(95, 60, 40),
}
local HAUTS = {
	Color3.fromRGB(240, 240, 240), Color3.fromRGB(30, 30, 35), Color3.fromRGB(200, 50, 60), Color3.fromRGB(50, 90, 170),
	Color3.fromRGB(70, 140, 80), Color3.fromRGB(240, 190, 60), Color3.fromRGB(150, 90, 170), Color3.fromRGB(240, 140, 170),
	Color3.fromRGB(130, 130, 135), Color3.fromRGB(100, 70, 50),
}
local BAS = {
	Color3.fromRGB(40, 55, 95), Color3.fromRGB(30, 30, 35), Color3.fromRGB(110, 110, 115), Color3.fromRGB(190, 170, 130),
	Color3.fromRGB(70, 60, 50), Color3.fromRGB(240, 240, 240),
}
local CHEVEUX = {
	Color3.fromRGB(25, 20, 15), Color3.fromRGB(60, 40, 25), Color3.fromRGB(110, 70, 40),
	Color3.fromRGB(200, 160, 90), Color3.fromRGB(150, 50, 30), Color3.fromRGB(180, 180, 180),
}

local function auHasard(liste)
	return liste[random:NextInteger(1, #liste)]
end

local function souder(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function ajouterCheveux(modele: Model, tete: BasePart)
	local couleur = auHasard(CHEVEUX)
	local style = random:NextInteger(1, 3)
	local function meche(taille: Vector3, decalage: CFrame)
		local p = Instance.new("Part")
		p.Name = "Cheveux"
		p.Size = taille
		p.CFrame = tete.CFrame * decalage
		p.Color = couleur
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		souder(tete, p)
		p.Parent = modele
	end
	meche(Vector3.new(1.25, 0.4, 1.3), CFrame.new(0, 0.55, 0.05)) -- dessus
	if style >= 2 then
		meche(Vector3.new(1.25, 0.9, 0.3), CFrame.new(0, 0.2, 0.6)) -- arrière
	end
	if style == 3 then
		meche(Vector3.new(1.25, 1.6, 0.35), CFrame.new(0, -0.2, 0.62)) -- cheveux longs
	end
end

local function creerPersonne(poste: BasePart): Model?
	local role = poste:GetAttribute("Role") or "client"
	local description = Instance.new("HumanoidDescription")
	local peau = auHasard(PEAUX)
	local haut = if role == "vendeur" then (poste:GetAttribute("Couleur") or auHasard(HAUTS)) else auHasard(HAUTS)
	description.HeadColor = peau
	description.LeftArmColor = peau
	description.RightArmColor = peau
	description.TorsoColor = haut
	description.LeftLegColor = auHasard(BAS)
	description.RightLegColor = description.LeftLegColor
	description.HeightScale = random:NextNumber(0.92, 1.05)
	local ok, modele = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modele then
		return nil
	end
	modele.Name = if role == "vendeur" then "Vendeur" else "Client"
	local hum = modele:FindFirstChildOfClass("Humanoid") :: Humanoid
	local racine = modele:FindFirstChild("HumanoidRootPart") :: BasePart
	local tete = modele:FindFirstChild("Head") :: BasePart?
	local animate = modele:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	if tete then
		ajouterCheveux(modele, tete)
	end

	-- Position : debout sur le poste, ou assis sur le siège
	local hauteurRacine = hum.HipHeight + racine.Size.Y / 2
	if role == "assis" then
		hauteurRacine = (poste:GetAttribute("HauteurSiege") or 2.6) + 1.1
	end
	modele:PivotTo(poste.CFrame + Vector3.new(0, hauteurRacine, 0))

	-- Personnages immobiles et « fantômes » pour les karts
	for _, p in ipairs(modele:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	racine.Anchored = true
	modele.Parent = dossier

	-- Animation : repos (il respire, bouge un peu) ou assis
	local animateur = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animateur.Parent = hum
	local anim = Instance.new("Animation")
	anim.AnimationId = if role == "assis" then ANIM_ASSIS else ANIM_REPOS
	pcall(function()
		local piste = animateur:LoadAnimation(anim)
		piste.Looped = true
		piste:Play()
		piste:AdjustSpeed(random:NextNumber(0.85, 1.15))
	end)
	return modele
end

-- On récupère tous les emplacements : d'abord les vendeurs, puis les clients
-- mélangés au hasard (pour qu'il y ait du monde aux deux étages)
local vendeurs, clients = {}, {}
for _, d in ipairs(carte:GetDescendants()) do
	if d:IsA("BasePart") and d.Name == "PostePNJ" then
		table.insert(if d:GetAttribute("Role") == "vendeur" then vendeurs else clients, d)
	end
end
for i = #clients, 2, -1 do
	local j = random:NextInteger(1, i)
	clients[i], clients[j] = clients[j], clients[i]
end
local postes = vendeurs
for _, c in ipairs(clients) do
	table.insert(postes, c)
end

local nombre = 0
for _, poste in ipairs(postes) do
	if nombre >= REGLAGES.Max then
		break
	end
	local role = poste:GetAttribute("Role")
	if role == "vendeur" or random:NextNumber() < REGLAGES.ChanceClient then
		if creerPersonne(poste) then
			nombre += 1
		end
		task.wait() -- on étale la création pour ne pas faire ramer le serveur
	end
end

print(("[Golden Mall] %d personnes dans le mall."):format(nombre))
