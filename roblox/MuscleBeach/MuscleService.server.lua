--[[
	MUSCLE BEACH : script serveur

	OÙ LE METTRE : ServerScriptService > Script (pas LocalScript), nommé « MuscleService ».

	CE QU'IL FAIT
	- Chaque appui sur un appareil de Muscle Beach = 1 répétition = de la force en plus.
	- Les appareils plus durs demandent un minimum de force mais rapportent plus.
	- L'avatar (R15) s'élargit avec la force.
	- La force est affichée dans le classement (leaderstats) et sauvegardée.
	- Après quelques jours sans entraînement, les muscles fondent un peu
	  (jamais en dessous de la moitié du record).
	- La force est aussi mise en attribut « Force » sur le joueur :
	  les futurs scripts (butin, barrages) pourront la lire avec player:GetAttribute("Force").

	SAUVEGARDE : pour qu'elle marche dans Studio, active
	Game Settings > Security > « Enable Studio Access to API Services ».
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

---------------------------------------------------------------------------
-- Réglages (modifie-les librement)
---------------------------------------------------------------------------
local REGLAGES = {
	FORCE_TAILLE_MAX = 5000, -- force à laquelle l'avatar atteint sa largeur maximale
	LARGEUR_MAX = 1.8,       -- largeur maximale de l'avatar (1 = normal)
	DELAI_REPETITION = 0.35, -- secondes minimum entre deux répétitions
	JOURS_AVANT_FONTE = 3,   -- jours sans entraînement avant que les muscles fondent
	FONTE_PAR_JOUR = 0.02,   -- 2 % de force perdue par jour après ce délai
	PLANCHER_FONTE = 0.5,    -- on ne descend jamais sous 50 % du record
	SAUVEGARDE_AUTO = 120,   -- sauvegarde automatique toutes les 2 minutes
	MULTIPLICATEUR = 1,      -- pour un futur Game Pass « Force x2 »
}

---------------------------------------------------------------------------
-- Communication avec l'écran du joueur
---------------------------------------------------------------------------
local evenement = ReplicatedStorage:FindFirstChild("MuscleEvent")
if not evenement then
	evenement = Instance.new("RemoteEvent")
	evenement.Name = "MuscleEvent"
	evenement.Parent = ReplicatedStorage
end

---------------------------------------------------------------------------
-- Sauvegarde
---------------------------------------------------------------------------
local stockage = nil
local okStockage = pcall(function()
	stockage = DataStoreService:GetDataStore("NeonBay_Muscle_v1")
end)
if not okStockage then
	warn("[MuscleBeach] Sauvegarde indisponible (active l'accès aux API dans Game Settings).")
end

local donnees = {}        -- [player] = { Force, Record, DernierEntrainement }
local derniereRep = {}    -- [player] = os.clock() de la dernière répétition

local function charger(player)
	local d = { Force = 0, Record = 0, DernierEntrainement = os.time() }
	if stockage then
		local ok, resultat = pcall(function()
			return stockage:GetAsync("joueur_" .. player.UserId)
		end)
		if ok and type(resultat) == "table" then
			d.Force = tonumber(resultat.Force) or 0
			d.Record = tonumber(resultat.Record) or d.Force
			d.DernierEntrainement = tonumber(resultat.DernierEntrainement) or os.time()
		elseif not ok then
			warn("[MuscleBeach] Chargement impossible pour " .. player.Name)
		end
	end
	return d
end

local function sauvegarder(player)
	local d = donnees[player]
	if not d or not stockage then return end
	pcall(function()
		stockage:SetAsync("joueur_" .. player.UserId, {
			Force = d.Force,
			Record = d.Record,
			DernierEntrainement = d.DernierEntrainement,
		})
	end)
end

-- Les muscles fondent doucement après plusieurs jours d'absence
local function appliquerFonte(d)
	local jours = (os.time() - d.DernierEntrainement) / 86400
	if jours <= REGLAGES.JOURS_AVANT_FONTE or d.Force <= 0 then
		return 0
	end
	local perte = math.min((jours - REGLAGES.JOURS_AVANT_FONTE) * REGLAGES.FONTE_PAR_JOUR, 1)
	local avant = d.Force
	local plancher = math.floor(d.Record * REGLAGES.PLANCHER_FONTE)
	d.Force = math.max(math.floor(d.Force * (1 - perte)), math.min(plancher, avant))
	return avant - d.Force
end

---------------------------------------------------------------------------
-- Muscles visibles (avatars R15)
---------------------------------------------------------------------------
local function appliquerMuscles(player)
	local d = donnees[player]
	local personnage = player.Character
	if not d or not personnage then return end
	local humanoid = personnage:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then return end

	local ratio = math.clamp(d.Force / REGLAGES.FORCE_TAILLE_MAX, 0, 1)
	local largeur = 1 + ratio * (REGLAGES.LARGEUR_MAX - 1)

	for _, nom in ipairs({ "BodyWidthScale", "BodyDepthScale" }) do
		local valeur = humanoid:FindFirstChild(nom)
		if valeur then
			-- On garde la morphologie choisie par le joueur comme base
			local base = valeur:GetAttribute("Base")
			if not base then
				base = valeur.Value
				valeur:SetAttribute("Base", base)
			end
			valeur.Value = base * largeur
		end
	end
end

local function mettreAJourAffichage(player)
	local d = donnees[player]
	if not d then return end
	player:SetAttribute("Force", d.Force)
	local stats = player:FindFirstChild("leaderstats")
	local force = stats and stats:FindFirstChild("Force")
	if force then force.Value = d.Force end
end

---------------------------------------------------------------------------
-- Entraînement
---------------------------------------------------------------------------
local function entrainer(player, appareil)
	local d = donnees[player]
	if not d then return end

	local maintenant = os.clock()
	if derniereRep[player] and maintenant - derniereRep[player] < REGLAGES.DELAI_REPETITION then
		return
	end
	derniereRep[player] = maintenant

	local requise = appareil:GetAttribute("ForceRequise") or 0
	if d.Force < requise then
		evenement:FireClient(player, "TropLourd", requise)
		return
	end

	local gain = math.floor((appareil:GetAttribute("Gain") or 1) * REGLAGES.MULTIPLICATEUR)
	d.Force = d.Force + gain
	d.Record = math.max(d.Record, d.Force)
	d.DernierEntrainement = os.time()

	mettreAJourAffichage(player)
	appliquerMuscles(player)
	evenement:FireClient(player, "Gain", gain, d.Force)
end

local appareilsBranches = {}
local function brancherAppareil(appareil)
	if appareilsBranches[appareil] or not appareil:IsA("Model") then return end
	if appareil:GetAttribute("Gain") == nil then return end
	local prompt = appareil:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then return end
	appareilsBranches[appareil] = true
	prompt.Triggered:Connect(function(player)
		entrainer(player, appareil)
	end)
end

task.spawn(function()
	local neonBay = Workspace:WaitForChild("NeonBay", 30)
	local plage = neonBay and neonBay:WaitForChild("Plage", 10)
	local muscleBeach = plage and plage:WaitForChild("MuscleBeach", 10)
	if not muscleBeach then
		warn("[MuscleBeach] Dossier Workspace > NeonBay > Plage > MuscleBeach introuvable. Lance d'abord NeonBay_Carte.lua.")
		return
	end
	for _, appareil in ipairs(muscleBeach:GetChildren()) do
		brancherAppareil(appareil)
	end
	muscleBeach.ChildAdded:Connect(brancherAppareil)
end)

---------------------------------------------------------------------------
-- Arrivée et départ des joueurs
---------------------------------------------------------------------------
local function joueurArrive(player)
	local d = charger(player)
	local perte = appliquerFonte(d)
	donnees[player] = d

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	local force = Instance.new("IntValue")
	force.Name = "Force"
	force.Value = d.Force
	force.Parent = stats

	mettreAJourAffichage(player)

	player.CharacterAdded:Connect(function(personnage)
		local humanoid = personnage:WaitForChild("Humanoid", 10)
		if humanoid then
			humanoid:WaitForChild("BodyWidthScale", 5)
			task.wait(0.5) -- laisse l'apparence du joueur se charger
			appliquerMuscles(player)
		end
	end)
	if player.Character then
		appliquerMuscles(player)
	end

	task.delay(3, function()
		if player.Parent then
			evenement:FireClient(player, "Init", d.Force, perte)
		end
	end)
end

Players.PlayerAdded:Connect(joueurArrive)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(joueurArrive, player)
end

Players.PlayerRemoving:Connect(function(player)
	sauvegarder(player)
	donnees[player] = nil
	derniereRep[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		sauvegarder(player)
	end
end)

task.spawn(function()
	while true do
		task.wait(REGLAGES.SAUVEGARDE_AUTO)
		for _, player in ipairs(Players:GetPlayers()) do
			sauvegarder(player)
		end
	end
end)
