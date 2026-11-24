--[[
	ModesServer  (Script)
	À placer dans : ServerScriptService   — nom conseillé : ModesServer

	  ⏱ COURSE CHRONO : 3 tours du mall en passant par les portes lumineuses,
	    meilleur tour enregistré (classement mondial des meilleurs tours).
	  🏆 CLASSEMENT DE LA SEMAINE (Drift Battle) : chaque semaine repart à zéro.
	    Le top 10 de la semaine passée reçoit des pièces à sa prochaine connexion.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")
local TYPE = Config.TypeDePlace()
local C = Config.Chrono or {}
local SOL = 1

---------------------------------------------------------------------
-- Les données (classements)
---------------------------------------------------------------------
local function store(nom: string): OrderedDataStore?
	local ok, s = pcall(function()
		return DataStoreService:GetOrderedDataStore(nom)
	end)
	return if ok then s else nil
end
local function semaine(): number
	return os.time() // 604800
end
local function storeSemaine(n: number): OrderedDataStore?
	return store("DriftBattle_Semaine_" .. n)
end
local storeChrono = store("Chrono_MeilleurTour_v1") -- (en millisecondes : plus petit = mieux)
local paiements = (function()
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore("Recompenses_Semaine_v1")
	end)
	return if ok then s else nil
end)()

local nomsCache: { [number]: string } = {}
local function nomDe(id: number): string
	if nomsCache[id] then
		return nomsCache[id]
	end
	local j = Players:GetPlayerByUserId(id)
	local nom = if j then j.DisplayName else nil
	if not nom then
		local ok, n = pcall(function()
			return Players:GetNameFromUserIdAsync(id)
		end)
		nom = if ok then n else ("Joueur " .. id)
	end
	nomsCache[id] = nom :: string
	return nom :: string
end

-- Le Drift Battle signale chaque score de fin de défi (ManchesServer)
local ScoreBattleSemaine = Instance.new("BindableEvent")
ScoreBattleSemaine.Name = "ScoreBattleSemaine"
ScoreBattleSemaine.Parent = ServerStorage
ScoreBattleSemaine.Event:Connect(function(joueur: Player, score: number)
	local s = storeSemaine(semaine())
	if not s or type(score) ~= "number" or score <= 0 then
		return
	end
	pcall(function()
		s:UpdateAsync(tostring(joueur.UserId), function(ancien)
			return math.max(tonumber(ancien) or 0, math.floor(score))
		end)
	end)
end)

-- Récompenses du top 10 de la semaine passée (versées à la connexion suivante)
local RECOMPENSES = C.RecompensesSemaine or { 5000, 3000, 2000, 1000, 1000, 1000, 1000, 1000, 1000, 1000 }
Players.PlayerAdded:Connect(function(joueur: Player)
	task.wait(6) -- (le temps que le profil soit chargé)
	local passee = semaine() - 1
	local s = storeSemaine(passee)
	if not s or not paiements or not joueur.Parent then
		return
	end
	local ok, page = pcall(function()
		return s:GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not ok then
		return
	end
	for rang, entree in ipairs(page) do
		if tonumber(entree.key) == joueur.UserId then
			local dejaPaye = false
			pcall(function()
				paiements:UpdateAsync("u_" .. joueur.UserId, function(ancien)
					if ancien == passee then
						dejaPaye = true
						return nil
					end
					return passee
				end)
			end)
			if not dejaPaye then
				local gain = RECOMPENSES[rang] or 0
				local donner = ServerStorage:FindFirstChild("AjouterPieces") :: BindableEvent?
				if donner and gain > 0 then
					donner:Fire(joueur, gain, ("🏆 %de DE LA SEMAINE ! +%d 💰"):format(rang, gain))
				end
			end
			break
		end
	end
end)

-- Le client demande les classements (page 🏆 du menu)
local Classements = Instance.new("RemoteFunction")
Classements.Name = "Classements"
Classements.Parent = remotes
local cache: { [string]: { temps: number, top: { any } } } = {}
local function top10(nom: string, s: OrderedDataStore?, croissant: boolean): { any }
	local c = cache[nom]
	if c and os.clock() - c.temps < 30 then
		return c.top
	end
	local liste = {}
	if s then
		pcall(function()
			for rang, entree in ipairs(s:GetSortedAsync(croissant, 10):GetCurrentPage()) do
				table.insert(liste, { rang = rang, nom = nomDe(tonumber(entree.key) or 0), score = entree.value, id = tonumber(entree.key) })
			end
		end)
	end
	cache[nom] = { temps = os.clock(), top = liste }
	return liste
end
Classements.OnServerInvoke = function(joueur: Player)
	local n = semaine()
	local s = storeSemaine(n)
	local monScore, monTour = 0, nil
	pcall(function()
		if s then
			monScore = s:GetAsync(tostring(joueur.UserId)) or 0
		end
		if storeChrono then
			monTour = storeChrono:GetAsync(tostring(joueur.UserId))
		end
	end)
	return {
		semaine = { top = top10("semaine" .. n, s, false), monScore = monScore, finDans = (n + 1) * 604800 - os.time(), recompenses = RECOMPENSES },
		chrono = { top = top10("chrono", storeChrono, true), monTour = monTour },
	}
end

---------------------------------------------------------------------
-- ⏱ LA COURSE CHRONO
---------------------------------------------------------------------
if TYPE == "Lobby" then
	return -- (au lobby, on ne roule pas : la course se lance dans la place Entraînement)
end

-- Les portes lumineuses, dans l'ordre (tour du mall par les allées)
local PORTES = C.Portes or {
	Vector3.new(60, 0, 137), Vector3.new(160, 0, 137), Vector3.new(173, 0, 40), Vector3.new(173, 0, -60),
	Vector3.new(120, 0, -137), Vector3.new(0, 0, -137), Vector3.new(-120, 0, -137), Vector3.new(-173, 0, -60),
	Vector3.new(-173, 0, 40), Vector3.new(-160, 0, 137), Vector3.new(-40, 0, 137),
}
local dossierPortes = Instance.new("Folder")
dossierPortes.Name = "ChronoPortes"
dossierPortes.Parent = workspace
local OR = Color3.fromRGB(255, 200, 60)
for i, pos in ipairs(PORTES) do
	local suivante = PORTES[i % #PORTES + 1]
	local sens = Vector3.new(suivante.X - pos.X, 0, suivante.Z - pos.Z).Unit
	local cf = CFrame.lookAt(pos + Vector3.new(0, SOL, 0), pos + Vector3.new(0, SOL, 0) + sens)
	local porte = Instance.new("Model")
	porte.Name = "Porte" .. i
	porte:SetAttribute("Ordre", i)
	local function piece(nom: string, taille: Vector3, decalage: CFrame)
		local p = Instance.new("Part")
		p.Name = nom
		p.Size = taille
		p.CFrame = cf * decalage
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = OR
		p.Transparency = 1 -- (le client les montre seulement pendant une course)
		p.CastShadow = false
		p.Parent = porte
		return p
	end
	-- Une arche : deux piliers + une barre en haut (assez large pour passer en drift)
	piece("Pilier", Vector3.new(1, 12, 1), CFrame.new(-11, 6, 0))
	piece("Pilier", Vector3.new(1, 12, 1), CFrame.new(11, 6, 0))
	piece("Barre", Vector3.new(23, 1, 1), CFrame.new(0, 12, 0))
	porte.PrimaryPart = porte:FindFirstChild("Barre") :: BasePart
	porte.Parent = dossierPortes
end

local Chrono = Instance.new("RemoteEvent")
Chrono.Name = "Chrono"
Chrono.Parent = remotes
local PlacerKart = ServerStorage:WaitForChild("PlacerKart") :: BindableFunction
local RetirerKart = ServerStorage:WaitForChild("RetirerKart") :: BindableFunction
local AjouterXP = ServerStorage:WaitForChild("AjouterXP") :: BindableEvent
local TOURS = C.Tours or 3
local DUREE_MAX = C.DureeMax or 240
local TOUR_MIN = C.TourMinimum or 14 -- (un tour plus rapide que ça = triche)

local enCourse: { [Player]: { debut: number, tours: number, meilleur: number? } } = {}

local function finCourse(joueur: Player, abandon: boolean)
	local c = enCourse[joueur]
	if not c then
		return
	end
	enCourse[joueur] = nil
	if joueur.Parent then
		joueur:SetAttribute("Role", nil)
		RetirerKart:Invoke(joueur)
		local garage = workspace:FindFirstChild("GoldenMall") and workspace.GoldenMall:FindFirstChild("GarageVIP")
		local apparition = garage and garage:FindFirstChild("ApparitionGarage") :: BasePart?
		task.delay(0.2, function()
			if apparition and joueur.Character then
				joueur.Character:PivotTo(apparition.CFrame + Vector3.new(0, 4, 0))
			end
		end)
		if not abandon then
			AjouterXP:Fire(joueur, 100 + c.tours * 40)
		end
		Chrono:FireClient(joueur, { type = "fin", meilleur = c.meilleur, abandon = abandon })
	end
end

Chrono.OnServerEvent:Connect(function(joueur: Player, action: any, valeur: any)
	if action == "lancer" then
		if enCourse[joueur] or joueur:GetAttribute("Role") ~= nil or joueur:GetAttribute("EnSalle") then
			return
		end
		joueur:SetAttribute("Pret", false)
		joueur:SetAttribute("Role", "Chrono")
		RetirerKart:Invoke(joueur)
		PlacerKart:Invoke(joueur, true, true) -- (directement sur la ligne : 3, 2, 1)
		enCourse[joueur] = { debut = os.clock(), tours = 0, meilleur = nil }
		local record = nil
		pcall(function()
			if storeChrono then
				record = storeChrono:GetAsync(tostring(joueur.UserId))
			end
		end)
		Chrono:FireClient(joueur, { type = "debut", tours = TOURS, portes = #PORTES, record = record })
		task.delay(DUREE_MAX, function()
			if enCourse[joueur] then
				finCourse(joueur, true)
			end
		end)
	elseif action == "tour" and type(valeur) == "number" then
		local c = enCourse[joueur]
		if not c or valeur ~= valeur or valeur < TOUR_MIN then
			return -- (temps impossible : ignoré)
		end
		c.tours += 1
		local ms = math.floor(valeur * 1000)
		if not c.meilleur or ms < c.meilleur then
			c.meilleur = ms
		end
		if storeChrono then
			pcall(function()
				storeChrono:UpdateAsync(tostring(joueur.UserId), function(ancien)
					local a = tonumber(ancien)
					return if a and a <= ms then nil else ms
				end)
			end)
		end
		if c.tours >= TOURS then
			finCourse(joueur, false)
		end
	elseif action == "quitter" then
		finCourse(joueur, true)
	end
end)
Players.PlayerRemoving:Connect(function(joueur)
	enCourse[joueur] = nil
end)

print("[Golden Mall] Course chrono et classement de la semaine prêts.")
