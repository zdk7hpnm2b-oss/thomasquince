--[[
	ManchesServer  (Script)
	À placer dans : ServerScriptService   — nom conseillé : ManchesServer

	LE MODE EN LIGNE « POLICE CONTRE FUGITIFS »
	  1. ATTENTE : en arrivant, on est LIBRE (garage, personnalisation, balade).
	     Les joueurs qui veulent jouer cliquent sur « LANCER UNE PARTIE » (ils sont
	     « prêts »). Il faut au moins Config.Partie.JoueursMin joueurs prêts
	     (s'il en manque, des BOTS DE TEST complètent : Config.Partie.BotsTest)
	  2. PAGE D'ATTENTE : les joueurs ne roulent pas, ils attendent sur une page
	     (caméra qui survole le mall) avec un compte à rebours
	  3. TIRAGE AU SORT : la moitié des participants devient POLICE, l'autre FUGITIFS
	  4. MANCHE : l'entrée du mall se ferme. Les fugitifs partent au SUD, la police
	     au NORD (à l'opposé). Feux 3, 2, 1, PARTEZ pour tout le monde, mais la
	     police reste bloquée quelques secondes de plus (l'avance des fugitifs).
	     Un policier qui colle un fugitif l'ARRÊTE.
	  5. FIN : la police gagne si tous les fugitifs sont arrêtés, sinon les
	     fugitifs gagnent à la fin du temps. XP pour tout le monde, bonus aux gagnants.
	Pendant une manche, la police du mall (ordinateur) se met en pause.
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")
local AjouterXP = ServerStorage:WaitForChild("AjouterXP") :: BindableEvent
local PlacerKart = ServerStorage:WaitForChild("PlacerKart") :: BindableFunction
local RetirerKart = ServerStorage:WaitForChild("RetirerKart") :: BindableFunction
local carte = workspace:WaitForChild("GoldenMall")
local dossierKarts = workspace:WaitForChild("KartsJoueurs")

local P = Config.Partie or {}
local JOUEURS_MIN = P.JoueursMin or 2
local INTERMISSION = P.Intermission or 20
local DUREE = P.DureeManche or 300
local AVANCE = P.AvanceFugitifs or 8
local DISTANCE_ARRESTATION = P.DistanceArrestation or 7
local BOTS_TEST = P.BotsTest or 0
local SOL = 1
local HAUTEUR_ETAGE = SOL + 25

local Partie = Instance.new("RemoteEvent")
Partie.Name = "Partie"
Partie.Parent = remotes

local dossierBots = Instance.new("Folder")
dossierBots.Name = "BotsManche"
dossierBots.Parent = workspace

---------------------------------------------------------------------
-- Les équipes (visibles dans le tableau des joueurs)
---------------------------------------------------------------------
local function equipe(nom: string, couleur: BrickColor, auto: boolean): Team
	local t = Instance.new("Team")
	t.Name = nom
	t.TeamColor = couleur
	t.AutoAssignable = auto
	t.Parent = Teams
	return t
end
local EQUIPE_POLICE = equipe("Police", BrickColor.new("Bright blue"), false)
local EQUIPE_FUGITIFS = equipe("Fugitifs", BrickColor.new("Bright orange"), false)
local EQUIPE_VISITEURS = equipe("Visiteurs", BrickColor.new("Institutional white"), true)

---------------------------------------------------------------------
-- Un participant = un vrai joueur OU un bot de test
---------------------------------------------------------------------
type Participant = {
	nom: string,
	joueur: Player?,
	bot: { [string]: any }?,
	role: string?,
	arrete: boolean,
}

local function present(p: Participant): boolean
	if p.joueur then
		return p.joueur.Parent ~= nil
	end
	return p.bot ~= nil and p.bot.modele.Parent ~= nil
end

local function positionDe(p: Participant): Vector3?
	if p.joueur then
		local racine = p.joueur.Character and p.joueur.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return racine and racine.Position or nil
	end
	return p.bot and p.bot.racine.Position or nil
end

-- Un policier ne peut arrêter qu'au volant de son kart
local function auVolant(p: Participant): boolean
	if p.bot then
		return true
	end
	local j = p.joueur :: Player
	local humanoide = j.Character and j.Character:FindFirstChildOfClass("Humanoid")
	if not humanoide or not humanoide.SeatPart then
		return false
	end
	for _, kart in ipairs(dossierKarts:GetChildren()) do
		if kart:GetAttribute("Proprietaire") == j.UserId and humanoide.SeatPart:IsDescendantOf(kart) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------
-- LES BOTS DE TEST (un personnage dans un kart, piloté par l'ordinateur)
---------------------------------------------------------------------
local NOMS_BOTS = { "Bot Max", "Bot Léa", "Bot Sam", "Bot Inès", "Bot Tom", "Bot Nina" }
local ANIM_ASSIS = "rbxassetid://2506281703"

-- Des points dans les allées du rez-de-chaussée (pour se balader / fuir)
local POINTS_FUITE = {}
for x = -190, 190, 40 do
	table.insert(POINTS_FUITE, Vector3.new(x, SOL + 3, -137))
	table.insert(POINTS_FUITE, Vector3.new(x, SOL + 3, 137))
	if math.abs(x) > 45 then
		table.insert(POINTS_FUITE, Vector3.new(x, SOL + 3, 0))
	end
end
for _, x in ipairs({ -173, -99, 99, 173 }) do
	for _, z in ipairs({ -90, -50, 50, 90 }) do
		table.insert(POINTS_FUITE, Vector3.new(x, SOL + 3, z))
	end
end
for _, z in ipairs({ -100, -60, 60 }) do
	table.insert(POINTS_FUITE, Vector3.new(0, SOL + 3, z))
end

local function souder(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function creerBot(nom: string, role: string, cf: CFrame)
	local police = role == "Police"
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(230, 185, 140)
	description.TorsoColor = if police then Color3.fromRGB(28, 42, 92) else Color3.fromRGB(240, 130, 30)
	description.LeftArmColor = description.TorsoColor
	description.RightArmColor = description.TorsoColor
	description.LeftLegColor = Color3.fromRGB(30, 30, 36)
	description.RightLegColor = Color3.fromRGB(30, 30, 36)
	local ok, modele = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modele then
		return nil
	end
	modele.Name = nom
	local hum = modele:FindFirstChildOfClass("Humanoid") :: Humanoid
	local racine = modele:FindFirstChild("HumanoidRootPart") :: BasePart
	local animate = modele:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HipHeight = 0.7
	hum.WalkSpeed = if police then (P.VitesseBotPolice or 40) else (P.VitesseBotFugitif or 36)
	modele:PivotTo(cf + Vector3.new(0, 2.5, 0))

	-- Le kart sous le bot
	local base = racine.CFrame * CFrame.new(0, -(0.7 + racine.Size.Y / 2) + 0.45, 0.6)
	local function piece(n: string, taille: Vector3, decalage: CFrame, couleur: Color3, matiere: Enum.Material?, forme: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = n
		p.Size = taille
		p.CFrame = base * decalage
		p.Color = couleur
		p.Material = matiere or Enum.Material.SmoothPlastic
		p.Shape = forme or Enum.PartType.Block
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		souder(racine, p)
		p.Parent = modele
		return p
	end
	piece("Chassis", Vector3.new(4, 0.8, 6), CFrame.new(), if police then Color3.fromRGB(240, 242, 248) else Color3.fromRGB(255, 140, 30))
	for _, cote in ipairs({ -1, 1 }) do
		piece("Roue", Vector3.new(0.8, 1.6, 1.6), CFrame.new(cote * 2.2, 0.2, -2.3), Color3.fromRGB(20, 20, 20), nil, Enum.PartType.Cylinder)
		piece("Roue", Vector3.new(0.7, 1.3, 1.3), CFrame.new(cote * 2.1, 0.05, 2.4), Color3.fromRGB(20, 20, 20), nil, Enum.PartType.Cylinder)
	end
	if police then
		piece("BandeBleue", Vector3.new(4.05, 0.3, 5.6), CFrame.new(0, 0.1, 0), Color3.fromRGB(25, 60, 170))
		piece("MatGyrophare", Vector3.new(0.2, 1.8, 0.2), CFrame.new(0, 1.3, 2.7), Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
		piece("Gyrophare", Vector3.new(2.2, 0.35, 0.6), CFrame.new(0, 2.25, 2.7), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	end

	for _, p in ipairs(modele:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Gardes" -- ne bloque pas les karts des joueurs
		end
	end

	-- Repère au-dessus du bot
	local repere = Instance.new("BillboardGui")
	repere.Size = UDim2.new(0, 170, 0, 40)
	repere.StudsOffset = Vector3.new(0, 4, 0)
	repere.AlwaysOnTop = true
	repere.MaxDistance = 220
	repere.Parent = racine
	local etiquette = Instance.new("TextLabel")
	etiquette.Size = UDim2.fromScale(1, 1)
	etiquette.BackgroundTransparency = 1
	etiquette.TextScaled = true
	etiquette.Font = Enum.Font.GothamBlack
	etiquette.Text = (if police then "🤖🚓 " else "🤖🏃 ") .. nom
	etiquette.TextColor3 = if police then Color3.fromRGB(90, 150, 255) else Color3.fromRGB(255, 150, 40)
	local contour = Instance.new("UIStroke")
	contour.Thickness = 2
	contour.Parent = etiquette
	etiquette.Parent = repere

	modele.Parent = dossierBots
	pcall(function()
		racine:SetNetworkOwner(nil)
	end)
	-- Assis au volant
	local animateur = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animateur.Parent = hum
	local anim = Instance.new("Animation")
	anim.AnimationId = ANIM_ASSIS
	pcall(function()
		local piste = animateur:LoadAnimation(anim)
		piste.Looped = true
		piste:Play()
	end)
	return { modele = modele, hum = hum, racine = racine, chemin = nil, indexChemin = 1, prochainCalcul = 0, cible = nil }
end

local parametresVue = RaycastParams.new()
parametresVue.FilterType = Enum.RaycastFilterType.Exclude
parametresVue.RespectCanCollide = true

local function allerVers(bot, destination: Vector3)
	parametresVue.FilterDescendantsInstances = { dossierBots, dossierKarts }
	local depart = bot.racine.Position
	local direct = workspace:Raycast(depart, destination - depart, parametresVue)
	if direct == nil then
		bot.chemin = nil
		bot.hum:MoveTo(destination)
		return
	end
	if bot.chemin == nil or os.clock() > bot.prochainCalcul then
		bot.prochainCalcul = os.clock() + 0.8
		local chemin = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 6 })
		local ok = pcall(function()
			chemin:ComputeAsync(depart, destination)
		end)
		if ok and chemin.Status == Enum.PathStatus.Success then
			local points = {}
			for _, w in ipairs(chemin:GetWaypoints()) do
				table.insert(points, w.Position)
			end
			bot.chemin = points
			bot.indexChemin = math.min(2, #points)
		else
			bot.chemin = nil
			bot.hum:MoveTo(destination)
			return
		end
	end
	local points = bot.chemin
	if points and points[bot.indexChemin] then
		local p = points[bot.indexChemin]
		if Vector3.new(p.X - depart.X, 0, p.Z - depart.Z).Magnitude < 6 and bot.indexChemin < #points then
			bot.indexChemin += 1
		end
		bot.hum:MoveTo(points[bot.indexChemin])
	end
end

-- Le cerveau d'un bot pendant la manche
local function piloterBot(p: Participant, participants: { Participant })
	local bot = p.bot
	if not bot then
		return
	end
	local pointFuite = POINTS_FUITE[math.random(1, #POINTS_FUITE)]
	while present(p) and not p.arrete and workspace:GetAttribute("MancheEnCours") do
		task.wait(0.15)
		local maPosition = bot.racine.Position
		-- Gyrophare qui clignote
		local gyro = bot.modele:FindFirstChild("Gyrophare") :: BasePart?
		if gyro then
			gyro.Color = if math.floor(os.clock() * 5) % 2 == 0 then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(40, 90, 255)
		end
		-- Le participant adverse le plus proche
		local plusProche, distance = nil, math.huge
		for _, autre in ipairs(participants) do
			if autre ~= p and autre.role ~= p.role and present(autre) and not autre.arrete then
				local pos = positionDe(autre)
				if pos then
					local d = (pos - maPosition).Magnitude
					if d < distance then
						plusProche, distance = pos, d
					end
				end
			end
		end
		if p.role == "Police" then
			-- Il fonce sur le fugitif le plus proche
			if plusProche then
				allerVers(bot, plusProche)
			end
		else
			-- Le fugitif fuit le policier proche, sinon il se balade dans le mall
			if plusProche and distance < 70 then
				local fuite = maPosition + (maPosition - plusProche).Unit * 45
				fuite = Vector3.new(math.clamp(fuite.X, -190, 190), maPosition.Y, math.clamp(fuite.Z, -140, 140))
				-- on choisit le point des allées le plus proche de la direction de fuite
				local meilleur, meilleurScore = pointFuite, math.huge
				for _, pt in ipairs(POINTS_FUITE) do
					local score = (pt - fuite).Magnitude - (pt - plusProche).Magnitude * 0.5
					if score < meilleurScore then
						meilleur, meilleurScore = pt, score
					end
				end
				pointFuite = meilleur
			elseif (Vector3.new(pointFuite.X - maPosition.X, 0, pointFuite.Z - maPosition.Z)).Magnitude < 8 then
				pointFuite = POINTS_FUITE[math.random(1, #POINTS_FUITE)]
			end
			allerVers(bot, pointFuite)
		end
	end
end

---------------------------------------------------------------------
-- Outils de la manche
---------------------------------------------------------------------
local function apparitionGarage(): CFrame?
	local garage = carte:FindFirstChild("GarageVIP")
	local apparition = garage and garage:FindFirstChild("ApparitionGarage") :: BasePart?
	return apparition and (apparition.CFrame + Vector3.new(0, 4, 0)) or nil
end

local function fermerEntree(fermee: boolean)
	local barriere = carte:FindFirstChild("BarriereManche", true) :: BasePart?
	if barriere then
		barriere.CanCollide = fermee
		barriere.Transparency = if fermee then 0.35 else 1
		local etiquette = barriere:FindFirstChildWhichIsA("TextLabel", true)
		if etiquette then
			etiquette.TextTransparency = if fermee then 0 else 1
		end
	end
end

local function envoyerATous(info)
	Partie:FireAllClients(info)
end

-- La page d'attente : le joueur ne roule pas (le script PartieUI affiche la page)
local function mettreEnSalle(joueur: Player, enSalle: boolean)
	if (joueur:GetAttribute("EnSalle") == true) == enSalle then
		return
	end
	joueur:SetAttribute("EnSalle", enSalle)
	if enSalle then
		RetirerKart:Invoke(joueur)
	end
end

local function remettreAZero(joueur: Player)
	joueur:SetAttribute("Role", nil)
	joueur:SetAttribute("Arrete", nil)
	joueur.Team = EQUIPE_VISITEURS
end

-- Où faire partir un bot (comme les joueurs : grille de départ ou passerelle)
local placeBot = 0
local function departBot(role: string): CFrame
	placeBot += 1
	local x = ({ -45, 45, -55, 55 })[(placeBot - 1) % 4 + 1]
	if role == "Police" then
		local pos = Vector3.new(x, SOL + 0.6, -135) -- au nord, face au sud
		return CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
	end
	local pos = Vector3.new(x, SOL + 0.6, 135) -- au sud, face au nord
	return CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end

---------------------------------------------------------------------
-- Une manche
---------------------------------------------------------------------
local function jouerManche(participants: { Participant })
	-- 1) Tirage au sort
	for i = #participants, 2, -1 do
		local j = math.random(1, i)
		participants[i], participants[j] = participants[j], participants[i]
	end
	local nombrePolice = math.max(1, math.floor(#participants / 2))
	local police, fugitifs = {}, {}
	for i, p in ipairs(participants) do
		p.role = if i <= nombrePolice then "Police" else "Fugitif"
		p.arrete = false
		table.insert(if p.role == "Police" then police else fugitifs, p)
		if p.joueur then
			p.joueur:SetAttribute("Role", p.role)
			p.joueur:SetAttribute("Arrete", nil)
			p.joueur.Team = if p.role == "Police" then EQUIPE_POLICE else EQUIPE_FUGITIFS
		end
	end
	for _, p in ipairs(participants) do
		if p.joueur then
			Partie:FireClient(p.joueur, { type = "tirage", equipe = p.role, nbPolice = #police, nbFugitifs = #fugitifs })
		end
	end
	task.wait(4) -- le temps de l'animation du tirage

	-- 2) Départ : l'entrée se ferme ; fugitifs au sud, police au nord.
	--    Tout le monde a les feux en même temps (~7 s : survol + 3, 2, 1, PARTEZ),
	--    mais la police reste bloquée AVANCE secondes de plus.
	workspace:SetAttribute("MancheEnCours", true)
	fermerEntree(true)
	local DUREE_DEPART = 7.5
	local debloquePolice = workspace:GetServerTimeNow() + DUREE_DEPART + AVANCE
	local function lancer(p: Participant)
		if p.joueur and p.joueur.Parent then
			mettreEnSalle(p.joueur, false)
			RetirerKart:Invoke(p.joueur)
			local kart = PlacerKart:Invoke(p.joueur, true)
			if kart and p.role == "Police" then
				kart:SetAttribute("BloqueJusqua", debloquePolice)
			end
		elseif not p.joueur then
			p.bot = creerBot(p.nom, p.role :: string, departBot(p.role :: string))
			if p.bot then
				task.delay(if p.role == "Police" then DUREE_DEPART + AVANCE else DUREE_DEPART, function()
					piloterBot(p, participants)
				end)
			end
		end
	end
	for _, p in ipairs(participants) do
		lancer(p)
	end
	task.delay(DUREE_DEPART, function()
		envoyerATous({ type = "info", texte = ("🏃 Les fugitifs ont %d secondes d'avance !"):format(AVANCE) })
	end)
	task.delay(DUREE_DEPART + AVANCE, function()
		envoyerATous({ type = "info", texte = "🚓 La police est lancée !" })
	end)

	-- 3) La manche
	local fin = os.clock() + DUREE + DUREE_DEPART
	local gagnant = nil
	local prochainEnvoi = 0
	while not gagnant do
		task.wait(0.1)
		local maintenant = os.clock()

		-- Arrestations : un policier au volant tout près d'un fugitif libre
		for _, flic in ipairs(police) do
			local posFlic = present(flic) and auVolant(flic) and positionDe(flic)
			if posFlic then
				for _, fugitif in ipairs(fugitifs) do
					local posFugitif = present(fugitif) and not fugitif.arrete and positionDe(fugitif)
					if posFugitif and (posFugitif - posFlic).Magnitude < DISTANCE_ARRESTATION then
						fugitif.arrete = true
						if fugitif.joueur then
							local j = fugitif.joueur
							j:SetAttribute("Arrete", true)
							RetirerKart:Invoke(j)
							local cf = apparitionGarage()
							if cf then
								task.delay(0.15, function()
									if j.Character then
										j.Character:PivotTo(cf)
									end
								end)
							end
							Partie:FireClient(j, { type = "arrete", par = flic.nom })
						elseif fugitif.bot then
							fugitif.bot.modele:Destroy()
						end
						if flic.joueur then
							AjouterXP:Fire(flic.joueur, P.XPArrestation or 100)
						end
						envoyerATous({ type = "arrestation", policier = flic.nom, fugitif = fugitif.nom })
					end
				end
			end
		end

		local restants, policeEnJeu = 0, 0
		for _, f in ipairs(fugitifs) do
			if present(f) and not f.arrete then
				restants += 1
			end
		end
		for _, f in ipairs(police) do
			if present(f) then
				policeEnJeu += 1
			end
		end

		if restants == 0 then
			gagnant = "Police"
		elseif policeEnJeu == 0 or maintenant >= fin then
			gagnant = "Fugitifs"
		elseif maintenant >= prochainEnvoi then
			prochainEnvoi = maintenant + 1
			envoyerATous({ type = "etat", etat = "manche", temps = math.max(0, math.ceil(fin - maintenant)), restants = restants, total = #fugitifs })
		end
	end

	-- 4) Fin de la manche : résultats et XP
	envoyerATous({ type = "fin", gagnant = gagnant, xp = P.XPVictoire or 300 })
	for _, p in ipairs(participants) do
		if p.joueur and p.joueur.Parent then
			AjouterXP:Fire(p.joueur, P.XPParticipation or 50)
			if p.role == (if gagnant == "Police" then "Police" else "Fugitif") then
				AjouterXP:Fire(p.joueur, P.XPVictoire or 300)
			end
		end
	end
	task.wait(6)

	-- 5) Retour au garage pour tout le monde
	workspace:SetAttribute("MancheEnCours", false)
	fermerEntree(false)
	dossierBots:ClearAllChildren()
	for _, p in ipairs(participants) do
		if p.joueur and p.joueur.Parent then
			local j = p.joueur
			RetirerKart:Invoke(j)
			remettreAZero(j)
			j:SetAttribute("EnSalle", nil)
			j:SetAttribute("Pret", false) -- pour rejouer, on reclique sur « LANCER UNE PARTIE »
			task.spawn(function()
				j:LoadCharacter() -- réapparition au garage
			end)
		end
	end
end

---------------------------------------------------------------------
-- La boucle de la partie : attente → intermission → manche → ...
---------------------------------------------------------------------
Players.PlayerAdded:Connect(function(joueur)
	joueur.Team = EQUIPE_VISITEURS
end)
for _, joueur in ipairs(Players:GetPlayers()) do
	joueur.Team = EQUIPE_VISITEURS
end
workspace:SetAttribute("MancheEnCours", false)

-- Le bouton « LANCER UNE PARTIE » (côté joueur) : on devient « prêt » ou non
Partie.OnServerEvent:Connect(function(joueur: Player, info)
	if type(info) ~= "table" or joueur:GetAttribute("Role") ~= nil then
		return -- (pendant sa manche, le joueur ne peut rien changer)
	end
	if info.type == "pret" then
		joueur:SetAttribute("Pret", info.valeur == true)
	elseif info.type == "garage" then
		-- Bouton « GARAGE VIP » du menu : retour au garage
		RetirerKart:Invoke(joueur)
		local cf = nil
		local garage = carte:FindFirstChild("GarageVIP")
		local apparition = garage and garage:FindFirstChild("ApparitionGarage") :: BasePart?
		if apparition then
			cf = apparition.CFrame + Vector3.new(0, 4, 0)
		end
		task.delay(0.2, function()
			if cf and joueur.Character then
				joueur.Character:PivotTo(cf)
			end
		end)
	end
end)

local function joueursPrets(): { Player }
	local liste = {}
	for _, j in ipairs(Players:GetPlayers()) do
		if j:GetAttribute("Pret") and j.Character then
			table.insert(liste, j)
		end
	end
	return liste
end

-- Combien de bots faut-il pour compléter ?
local function botsNecessaires(): number
	local n = #joueursPrets()
	if n == 0 or n >= JOUEURS_MIN then
		return 0
	end
	return math.min(BOTS_TEST, JOUEURS_MIN - n)
end

local function assezDeMonde(): boolean
	local n = #joueursPrets()
	return n > 0 and n + botsNecessaires() >= JOUEURS_MIN
end

task.spawn(function()
	while true do
		-- Attente de joueurs
		while not assezDeMonde() do
			for _, j in ipairs(Players:GetPlayers()) do
				mettreEnSalle(j, false)
			end
			envoyerATous({ type = "etat", etat = "attente", joueurs = #joueursPrets(), min = JOUEURS_MIN })
			task.wait(1)
		end
		-- Page d'attente : plus personne ne roule, compte à rebours avant le tirage
		local annule = false
		for t = INTERMISSION, 1, -1 do
			if not assezDeMonde() then
				annule = true
				break
			end
			for _, j in ipairs(Players:GetPlayers()) do
				-- seuls les joueurs « prêts » vont sur la page d'attente
				mettreEnSalle(j, j:GetAttribute("Pret") == true)
			end
			envoyerATous({ type = "etat", etat = "intermission", temps = t, bots = botsNecessaires() })
			task.wait(1)
		end
		if annule then
			for _, j in ipairs(Players:GetPlayers()) do
				mettreEnSalle(j, false) -- pas assez de monde : retour au mode libre
			end
		end
		if not annule then
			local participants: { Participant } = {}
			for _, j in ipairs(joueursPrets()) do
				if j.Character then
					table.insert(participants, { nom = j.DisplayName, joueur = j, bot = nil, role = nil, arrete = false })
					mettreEnSalle(j, true)
				end
			end
			for k = 1, botsNecessaires() do
				table.insert(participants, { nom = NOMS_BOTS[(k - 1) % #NOMS_BOTS + 1], joueur = nil, bot = nil, role = nil, arrete = false })
			end
			if #participants >= JOUEURS_MIN then
				local ok, erreur = pcall(jouerManche, participants)
				if not ok then
					warn("[Manches] " .. tostring(erreur))
					workspace:SetAttribute("MancheEnCours", false)
					fermerEntree(false)
					dossierBots:ClearAllChildren()
					for _, j in ipairs(Players:GetPlayers()) do
						remettreAZero(j)
						mettreEnSalle(j, false)
					end
				end
			end
		end
	end
end)

print(("[Golden Mall] Mode en ligne « Police contre Fugitifs » prêt (bots de test : %d)."):format(BOTS_TEST))
