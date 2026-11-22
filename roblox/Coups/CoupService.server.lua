--[[
	NEON BAY : les coups, les étoiles et les Gardiens (script serveur)

	OÙ LE METTRE : ServerScriptService > Script, nommé « CoupService ».

	LA BOUCLE DE JEU
	MALINS
	1. Maintenir le bouton 5 s devant la caisse d'une boutique -> un butin
	   (plus gros si on est musclé) et 1 à 3 étoiles.
	2. Avec des étoiles : son visage apparaît sur les affiches « Recherché »
	   et des étoiles flottent au-dessus de sa tête.
	3. Passer par la cabine de déguisement (plage) -> plus d'étoiles.
	4. Déposer le butin à la planque (marais) -> billets + objet de collection.
	   Butin x2 si un autre Malin est à côté.
	GARDIENS
	- Toucher un Malin qui a des étoiles -> il perd son butin et revient à la
	  plage, le Gardien gagne des billets.
	MANCHES
	- Toutes les 8 minutes, tout le monde change de camp.

	Les billets et la collection sont sauvegardés (même réglage que Muscle Beach :
	Game Settings > Security > « Enable Studio Access to API Services »).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

---------------------------------------------------------------------------
-- Réglages
---------------------------------------------------------------------------
local REGLAGES = {
	FERMETURE_BOUTIQUE = 45,   -- secondes avant qu'une boutique puisse être revisitée
	DISTANCE_ATTRAPER = 6,     -- un Gardien attrape un Malin à cette distance
	PROTECTION = 6,            -- secondes d'invincibilité après une arrestation
	RECOMPENSE_GARDIEN = 50,   -- billets par étoile du Malin attrapé
	DISTANCE_TEMOIN = 60,      -- un joueur à cette distance compte comme témoin
	DISTANCE_DUO = 20,         -- un autre Malin à cette distance double le butin
	DUREE_MANCHE = 480,        -- 8 minutes
	FORCE_BONUS_MAX = 5000,    -- à cette force, le butin vaut 2 fois plus
}

local BUTINS = {
	{ nom = "Bonbon géant", valeur = 100, chance = 40 },
	{ nom = "Donut néon", valeur = 120, chance = 30 },
	{ nom = "Trophée ridicule", valeur = 180, chance = 18 },
	{ nom = "Canard en caoutchouc doré", valeur = 300, chance = 10 },
	{ nom = "Œuf doré", valeur = 500, chance = 2 },
}

---------------------------------------------------------------------------
-- Objets de la carte
---------------------------------------------------------------------------
local neonBay = Workspace:WaitForChild("NeonBay")
local rue = neonBay:WaitForChild("RueDesBoutiques")
local plage = neonBay:WaitForChild("Plage")
local marais = neonBay:WaitForChild("Marais")
local dossierAffiches = rue:WaitForChild("AffichesRecherche")
local cabine = plage:WaitForChild("CabineDeguisement")
local planque = marais:WaitForChild("Planque")
local depot = planque:WaitForChild("Depot")
local departMalins = plage:WaitForChild("DepartMalins")
local texteEcran = plage:WaitForChild("EcranGeant"):WaitForChild("Ecran")
	:WaitForChild("Affichage"):WaitForChild("TexteExploit")

local equipeMalins = Teams:WaitForChild("Malins")
local equipeGardiens = Teams:WaitForChild("Gardiens")

local evenement = ReplicatedStorage:FindFirstChild("CoupEvent")
if not evenement then
	evenement = Instance.new("RemoteEvent")
	evenement.Name = "CoupEvent"
	evenement.Parent = ReplicatedStorage
end

---------------------------------------------------------------------------
-- Données des joueurs
---------------------------------------------------------------------------
local stockage = nil
pcall(function()
	stockage = DataStoreService:GetDataStore("NeonBay_Coups_v1")
end)

local donnees = {}      -- [player] = { Billets, Collection = {nom = nombre} }
local protegeJusqua = {} -- [player] = os.clock()
local miniatures = {}   -- [userId] = image

local function message(player, texte, couleur)
	evenement:FireClient(player, "Message", texte, couleur or "blanc")
end

local function annonce(texte, couleur)
	evenement:FireAllClients("Message", texte, couleur or "cyan")
end

local function exploit(texte)
	texteEcran.Text = "EN DIRECT : " .. texte
end

local function racine(player)
	local perso = player.Character
	return perso and perso:FindFirstChild("HumanoidRootPart")
end

local function estMalin(player)
	return player.Team == equipeMalins
end

local function estGardien(player)
	return player.Team == equipeGardiens
end

local function majBillets(player)
	local d = donnees[player]
	if not d then return end
	local stats = player:FindFirstChild("leaderstats")
	local billets = stats and stats:FindFirstChild("Billets")
	if billets then billets.Value = d.Billets end
	local total = 0
	for _, n in pairs(d.Collection) do total = total + n end
	player:SetAttribute("Collection", total)
end

local function sauvegarder(player)
	local d = donnees[player]
	if not d or not stockage then return end
	pcall(function()
		stockage:SetAsync("joueur_" .. player.UserId, { Billets = d.Billets, Collection = d.Collection })
	end)
end

---------------------------------------------------------------------------
-- Visuels : sac de butin sur le dos, étoiles au-dessus de la tête
---------------------------------------------------------------------------
local function majVisuels(player)
	local perso = player.Character
	if not perso then return end
	local torse = perso:FindFirstChild("UpperTorso") or perso:FindFirstChild("Torso")
	local tete = perso:FindFirstChild("Head")

	-- Sac de butin
	local sac = perso:FindFirstChild("SacDeButin")
	local butin = player:GetAttribute("Butin")
	if butin and not sac and torse then
		sac = Instance.new("Part")
		sac.Name = "SacDeButin"
		sac.Shape = Enum.PartType.Ball
		sac.Size = Vector3.new(2.4, 2.4, 2.4)
		sac.Color = Color3.fromRGB(255, 200, 40)
		sac.Material = Enum.Material.SmoothPlastic
		sac.CanCollide = false
		sac.Massless = true
		sac.CFrame = torse.CFrame * CFrame.new(0, 0.2, 1.6)
		local soudure = Instance.new("WeldConstraint")
		soudure.Part0 = torse
		soudure.Part1 = sac
		soudure.Parent = sac
		sac.Parent = perso
	elseif not butin and sac then
		sac:Destroy()
	end

	-- Étoiles au-dessus de la tête (visibles de loin par les Gardiens)
	local etoiles = player:GetAttribute("Etoiles") or 0
	local panneau = tete and tete:FindFirstChild("Etoiles")
	if etoiles > 0 and tete then
		if not panneau then
			panneau = Instance.new("BillboardGui")
			panneau.Name = "Etoiles"
			panneau.Size = UDim2.fromOffset(150, 45)
			panneau.StudsOffset = Vector3.new(0, 3, 0)
			panneau.AlwaysOnTop = true
			panneau.MaxDistance = 400
			local texte = Instance.new("TextLabel")
			texte.Name = "Texte"
			texte.Size = UDim2.fromScale(1, 1)
			texte.BackgroundTransparency = 1
			texte.TextColor3 = Color3.fromRGB(255, 220, 40)
			texte.TextStrokeTransparency = 0
			texte.TextScaled = true
			texte.Font = Enum.Font.GothamBlack
			texte.Parent = panneau
			panneau.Parent = tete
		end
		panneau.Texte.Text = string.rep("★", etoiles)
	elseif panneau then
		panneau:Destroy()
	end
end

---------------------------------------------------------------------------
-- Affiches « Recherché »
---------------------------------------------------------------------------
local function miniature(player)
	if miniatures[player.UserId] == nil then
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		end)
		miniatures[player.UserId] = ok and image or ""
	end
	return miniatures[player.UserId]
end

local function majAffiches()
	local recherches = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if (p:GetAttribute("Etoiles") or 0) > 0 then
			table.insert(recherches, p)
		end
	end
	table.sort(recherches, function(a, b)
		return (a:GetAttribute("Etoiles") or 0) > (b:GetAttribute("Etoiles") or 0)
	end)

	local affiches = dossierAffiches:GetChildren()
	table.sort(affiches, function(a, b) return a.Name < b.Name end)
	for i, affiche in ipairs(affiches) do
		local panneau = affiche:FindFirstChild("Panneau")
		local gui = panneau and panneau:FindFirstChild("Affichage")
		if gui then
			local p = recherches[i]
			if p then
				gui.Photo.Image = miniature(p)
				gui.Nom.Text = p.DisplayName .. " " .. string.rep("★", p:GetAttribute("Etoiles"))
			else
				gui.Photo.Image = ""
				gui.Nom.Text = "???"
			end
		end
	end
end

local function changerEtoiles(player, etoiles)
	player:SetAttribute("Etoiles", math.clamp(etoiles, 0, 3))
	majVisuels(player)
	majAffiches()
end

---------------------------------------------------------------------------
-- 1. Le coup de la boutique
---------------------------------------------------------------------------
local function tirerButin()
	local total = 0
	for _, b in ipairs(BUTINS) do total = total + b.chance end
	local tirage = math.random() * total
	for _, b in ipairs(BUTINS) do
		tirage = tirage - b.chance
		if tirage <= 0 then return b end
	end
	return BUTINS[1]
end

local function compterTemoins(player)
	local moi = racine(player)
	if not moi then return 0 end
	local gardienProche, autreProche = false, false
	for _, p in ipairs(Players:GetPlayers()) do
		local r = racine(p)
		if p ~= player and r and (r.Position - moi.Position).Magnitude < REGLAGES.DISTANCE_TEMOIN then
			if estGardien(p) then gardienProche = true else autreProche = true end
		end
	end
	local etoiles = 1
	if autreProche then etoiles = etoiles + 1 end
	if gardienProche then etoiles = etoiles + 1 end
	return etoiles
end

local function faireLeCoup(player, boutique, prompt)
	if not estMalin(player) then
		message(player, "Les Gardiens protègent les boutiques !", "bleu")
		return
	end
	if player:GetAttribute("Butin") then
		message(player, "Tu portes déjà un butin : va le cacher à la planque !", "rouge")
		return
	end

	local b = tirerButin()
	local force = math.min(player:GetAttribute("Force") or 0, REGLAGES.FORCE_BONUS_MAX)
	local valeur = math.floor(b.valeur * (1 + force / REGLAGES.FORCE_BONUS_MAX))

	player:SetAttribute("Butin", b.nom)
	player:SetAttribute("ValeurButin", valeur)
	local etoiles = compterTemoins(player)
	changerEtoiles(player, math.max(player:GetAttribute("Etoiles") or 0, etoiles))

	local nomBoutique = boutique:GetAttribute("NomAffiche") or boutique.Name
	message(player, "Tu as pris : " .. b.nom .. " (" .. valeur .. " billets) ! Les témoins t'ont vu !", "or")
	exploit(player.DisplayName .. " a dévalisé " .. nomBoutique .. " !")
	annonce("ALERTE : " .. nomBoutique .. " vient d'être dévalisé !", "rouge")

	-- La boutique ferme un moment
	prompt.Enabled = false
	task.delay(REGLAGES.FERMETURE_BOUTIQUE, function()
		prompt.Enabled = true
	end)
end

for _, boutique in ipairs(rue:GetChildren()) do
	if boutique:GetAttribute("Boutique") then
		local caisse = boutique:FindFirstChild("Caisse")
		local prompt = caisse and caisse:FindFirstChildWhichIsA("ProximityPrompt")
		if prompt then
			boutique:SetAttribute("NomAffiche", prompt.ObjectText)
			prompt.Triggered:Connect(function(player)
				faireLeCoup(player, boutique, prompt)
			end)
		end
	end
end

---------------------------------------------------------------------------
-- 2. La cabine de déguisement
---------------------------------------------------------------------------
local promptCabine = cabine:FindFirstChildWhichIsA("ProximityPrompt", true)
if promptCabine then
	promptCabine.Triggered:Connect(function(player)
		if not estMalin(player) then
			message(player, "Pas besoin de te déguiser, tu es Gardien !", "bleu")
			return
		end
		if (player:GetAttribute("Etoiles") or 0) == 0 then
			message(player, "Personne ne te recherche pour l'instant.", "blanc")
			return
		end
		changerEtoiles(player, 0)
		message(player, "Déguisé ! Les Gardiens ne te reconnaissent plus.", "cyan")
	end)
end

---------------------------------------------------------------------------
-- 3. La planque
---------------------------------------------------------------------------
local promptDepot = depot:FindFirstChildWhichIsA("ProximityPrompt")
if promptDepot then
	promptDepot.Triggered:Connect(function(player)
		local d = donnees[player]
		local butin = player:GetAttribute("Butin")
		if not d or not butin then
			message(player, "Tu n'as pas de butin. Va faire un coup dans la rue des boutiques !", "blanc")
			return
		end
		if (player:GetAttribute("Etoiles") or 0) > 0 then
			message(player, "Tu es encore recherché ! Passe d'abord par la cabine de déguisement.", "rouge")
			return
		end

		local valeur = player:GetAttribute("ValeurButin") or 0
		local duo = false
		local moi = racine(player)
		for _, p in ipairs(Players:GetPlayers()) do
			local r = racine(p)
			if p ~= player and estMalin(p) and r and moi and (r.Position - moi.Position).Magnitude < REGLAGES.DISTANCE_DUO then
				duo = true
			end
		end
		if duo then valeur = valeur * 2 end

		d.Billets = d.Billets + valeur
		d.Collection[butin] = (d.Collection[butin] or 0) + 1
		player:SetAttribute("Butin", nil)
		player:SetAttribute("ValeurButin", nil)
		majVisuels(player)
		majBillets(player)

		message(player, "+" .. valeur .. " billets" .. (duo and " (bonus duo x2 !)" or "") .. " — " .. butin .. " ajouté à ta collection", "or")
		exploit(player.DisplayName .. " a caché un " .. butin .. " à la planque !")
	end)
end

---------------------------------------------------------------------------
-- 4. Les Gardiens attrapent les Malins
---------------------------------------------------------------------------
local function attraper(malin, gardien)
	local etoiles = malin:GetAttribute("Etoiles") or 0
	protegeJusqua[malin] = os.clock() + REGLAGES.PROTECTION

	malin:SetAttribute("Butin", nil)
	malin:SetAttribute("ValeurButin", nil)
	changerEtoiles(malin, 0)

	local perso = malin.Character
	if perso then
		perso:PivotTo(departMalins.CFrame + Vector3.new(math.random(-4, 4), 4, math.random(-4, 4)))
	end

	local dG = donnees[gardien]
	if dG then
		dG.Billets = dG.Billets + REGLAGES.RECOMPENSE_GARDIEN * etoiles
		majBillets(gardien)
	end

	message(malin, "Attrapé par " .. gardien.DisplayName .. " ! Ton butin est perdu.", "rouge")
	message(gardien, "Bravo ! +" .. (REGLAGES.RECOMPENSE_GARDIEN * etoiles) .. " billets", "or")
	exploit(gardien.DisplayName .. " a attrapé " .. malin.DisplayName .. " !")
end

task.spawn(function()
	while true do
		task.wait(0.2)
		local maintenant = os.clock()
		for _, malin in ipairs(Players:GetPlayers()) do
			local rM = racine(malin)
			if estMalin(malin) and rM and (malin:GetAttribute("Etoiles") or 0) > 0
				and (protegeJusqua[malin] or 0) < maintenant then
				for _, gardien in ipairs(Players:GetPlayers()) do
					local rG = racine(gardien)
					if estGardien(gardien) and rG and (rG.Position - rM.Position).Magnitude < REGLAGES.DISTANCE_ATTRAPER then
						attraper(malin, gardien)
						break
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- 5. Les manches : tout le monde change de camp
---------------------------------------------------------------------------
local finManche = os.time() + REGLAGES.DUREE_MANCHE
ReplicatedStorage:SetAttribute("FinManche", finManche)

task.spawn(function()
	while true do
		task.wait(1)
		if os.time() >= finManche then
			for _, p in ipairs(Players:GetPlayers()) do
				p:SetAttribute("Butin", nil)
				p:SetAttribute("ValeurButin", nil)
				p:SetAttribute("Etoiles", 0)
				if estMalin(p) then p.Team = equipeGardiens else p.Team = equipeMalins end
				task.spawn(function() p:LoadCharacter() end)
			end
			majAffiches()
			annonce("NOUVELLE MANCHE : tout le monde change de camp !", "cyan")
			exploit("Nouvelle manche ! Les Malins deviennent Gardiens et inversement.")
			finManche = os.time() + REGLAGES.DUREE_MANCHE
			ReplicatedStorage:SetAttribute("FinManche", finManche)
		end
	end
end)

---------------------------------------------------------------------------
-- Arrivée et départ des joueurs
---------------------------------------------------------------------------
local function joueurArrive(player)
	local d = { Billets = 0, Collection = {} }
	if stockage then
		local ok, resultat = pcall(function()
			return stockage:GetAsync("joueur_" .. player.UserId)
		end)
		if ok and type(resultat) == "table" then
			d.Billets = tonumber(resultat.Billets) or 0
			if type(resultat.Collection) == "table" then d.Collection = resultat.Collection end
		end
	end
	donnees[player] = d

	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end
	local billets = Instance.new("IntValue")
	billets.Name = "Billets"
	billets.Parent = stats

	player:SetAttribute("Etoiles", 0)
	majBillets(player)

	player.CharacterAdded:Connect(function()
		task.wait(1)
		majVisuels(player)
	end)
end

Players.PlayerAdded:Connect(joueurArrive)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(joueurArrive, p)
end

Players.PlayerRemoving:Connect(function(player)
	sauvegarder(player)
	donnees[player] = nil
	protegeJusqua[player] = nil
	task.defer(majAffiches)
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		sauvegarder(p)
	end
end)

task.spawn(function()
	while true do
		task.wait(120)
		for _, p in ipairs(Players:GetPlayers()) do
			sauvegarder(p)
		end
	end
end)
