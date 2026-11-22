--[[
	ManchesServer  (Script)
	À placer dans : ServerScriptService   — nom conseillé : ManchesServer

	LE MODE EN LIGNE « POLICE CONTRE FUGITIFS »
	  1. ATTENTE : il faut au moins Config.Partie.JoueursMin joueurs
	  2. INTERMISSION : compte à rebours avant la manche
	  3. TIRAGE AU SORT : la moitié des joueurs devient POLICE, l'autre FUGITIFS
	  4. MANCHE : l'entrée du mall se ferme. Les fugitifs partent de la ligne de
	     départ ; la police part du 1er étage quelques secondes plus tard.
	     Un policier qui colle un fugitif l'ARRÊTE (le fugitif va au garage).
	  5. FIN : la police gagne si tous les fugitifs sont arrêtés, sinon les
	     fugitifs gagnent à la fin du temps. XP pour tout le monde, bonus aux gagnants.
	Pendant une manche, la police du mall (ordinateur) se met en pause.
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")
local AjouterXP = ServerStorage:WaitForChild("AjouterXP") :: BindableEvent
local PlacerKart = ServerStorage:WaitForChild("PlacerKart") :: BindableFunction
local RetirerKart = ServerStorage:WaitForChild("RetirerKart") :: BindableFunction
local carte = workspace:WaitForChild("GoldenMall")
local dossierKarts = workspace:WaitForChild("KartsJoueurs")

local P = Config.Partie or {
	JoueursMin = 2, Intermission = 20, DureeManche = 300, AvanceFugitifs = 8,
	DistanceArrestation = 7, XPVictoire = 300, XPParticipation = 50, XPArrestation = 100,
}

-- Le canal pour prévenir les joueurs (état de la partie, tirage, arrestations, fin)
local Partie = Instance.new("RemoteEvent")
Partie.Name = "Partie"
Partie.Parent = remotes

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
-- Outils
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

-- Position d'un joueur (son kart s'il conduit, sinon son personnage)
local function positionDe(joueur: Player): Vector3?
	local racine = joueur.Character and joueur.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return racine and racine.Position or nil
end

-- Le policier est-il au volant de son kart ?
local function auVolant(joueur: Player): boolean
	local humanoide = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	if not humanoide or not humanoide.SeatPart then
		return false
	end
	for _, kart in ipairs(dossierKarts:GetChildren()) do
		if kart:GetAttribute("Proprietaire") == joueur.UserId and humanoide.SeatPart:IsDescendantOf(kart) then
			return true
		end
	end
	return false
end

local function remettreAZero(joueur: Player)
	joueur:SetAttribute("Role", nil)
	joueur:SetAttribute("Arrete", nil)
	joueur.Team = EQUIPE_VISITEURS
end

---------------------------------------------------------------------
-- Une manche
---------------------------------------------------------------------
local function jouerManche(participants: { Player })
	-- 1) Tirage au sort
	for i = #participants, 2, -1 do
		local j = math.random(1, i)
		participants[i], participants[j] = participants[j], participants[i]
	end
	local nombrePolice = math.max(1, math.floor(#participants / 2))
	local police, fugitifs = {}, {}
	for i, joueur in ipairs(participants) do
		if i <= nombrePolice then
			table.insert(police, joueur)
			joueur:SetAttribute("Role", "Police")
			joueur.Team = EQUIPE_POLICE
		else
			table.insert(fugitifs, joueur)
			joueur:SetAttribute("Role", "Fugitif")
			joueur.Team = EQUIPE_FUGITIFS
		end
		joueur:SetAttribute("Arrete", nil)
	end
	for _, joueur in ipairs(participants) do
		Partie:FireClient(joueur, {
			type = "tirage",
			equipe = joueur:GetAttribute("Role"),
			nbPolice = #police,
			nbFugitifs = #fugitifs,
		})
	end
	task.wait(4) -- le temps de l'animation du tirage

	-- 2) Départ : l'entrée se ferme, les fugitifs partent, puis la police
	workspace:SetAttribute("MancheEnCours", true)
	fermerEntree(true)
	for _, joueur in ipairs(fugitifs) do
		if joueur.Parent then
			RetirerKart:Invoke(joueur)
			PlacerKart:Invoke(joueur, true)
		end
	end
	envoyerATous({ type = "info", texte = ("🏃 Les fugitifs ont %d secondes d'avance !"):format(P.AvanceFugitifs) })
	task.wait(P.AvanceFugitifs)
	for _, joueur in ipairs(police) do
		if joueur.Parent then
			RetirerKart:Invoke(joueur)
			PlacerKart:Invoke(joueur, true)
		end
	end
	envoyerATous({ type = "info", texte = "🚓 La police est lancée !" })

	-- 3) La manche
	local fin = os.clock() + P.DureeManche + 7 -- (+ le temps du départ de la police)
	local gagnant = nil
	local prochainEnvoi = 0
	while not gagnant do
		task.wait(0.1)
		local maintenant = os.clock()

		-- Qui est encore là ?
		local policeEnJeu, fugitifsLibres = {}, {}
		for _, j in ipairs(police) do
			if j.Parent then
				table.insert(policeEnJeu, j)
			end
		end
		for _, j in ipairs(fugitifs) do
			if j.Parent and not j:GetAttribute("Arrete") then
				table.insert(fugitifsLibres, j)
			end
		end

		-- Arrestations : un policier au volant tout près d'un fugitif
		for _, flic in ipairs(policeEnJeu) do
			local posFlic = auVolant(flic) and positionDe(flic)
			if posFlic then
				for _, fugitif in ipairs(fugitifsLibres) do
					local posFugitif = positionDe(fugitif)
					if posFugitif and not fugitif:GetAttribute("Arrete") and (posFugitif - posFlic).Magnitude < P.DistanceArrestation then
						fugitif:SetAttribute("Arrete", true)
						RetirerKart:Invoke(fugitif)
						local cf = apparitionGarage()
						if cf and fugitif.Character then
							task.delay(0.15, function()
								if fugitif.Character then
									fugitif.Character:PivotTo(cf)
								end
							end)
						end
						AjouterXP:Fire(flic, P.XPArrestation)
						envoyerATous({ type = "arrestation", policier = flic.DisplayName, fugitif = fugitif.DisplayName })
						Partie:FireClient(fugitif, { type = "arrete", par = flic.DisplayName })
					end
				end
			end
		end

		-- Recompter après les arrestations
		local restants = 0
		for _, j in ipairs(fugitifs) do
			if j.Parent and not j:GetAttribute("Arrete") then
				restants += 1
			end
		end

		if restants == 0 then
			gagnant = "Police"
		elseif #policeEnJeu == 0 then
			gagnant = "Fugitifs"
		elseif maintenant >= fin then
			gagnant = "Fugitifs"
		elseif maintenant >= prochainEnvoi then
			prochainEnvoi = maintenant + 1
			envoyerATous({ type = "etat", etat = "manche", temps = math.max(0, math.ceil(fin - maintenant)), restants = restants, total = #fugitifs })
		end
	end

	-- 4) Fin de la manche : résultats et XP
	envoyerATous({ type = "fin", gagnant = gagnant, xp = P.XPVictoire })
	for _, joueur in ipairs(participants) do
		if joueur.Parent then
			AjouterXP:Fire(joueur, P.XPParticipation)
			if joueur:GetAttribute("Role") == (if gagnant == "Police" then "Police" else "Fugitif") then
				AjouterXP:Fire(joueur, P.XPVictoire)
			end
		end
	end
	task.wait(6)

	-- 5) Retour au garage pour tout le monde
	workspace:SetAttribute("MancheEnCours", false)
	fermerEntree(false)
	for _, joueur in ipairs(participants) do
		if joueur.Parent then
			RetirerKart:Invoke(joueur)
			remettreAZero(joueur)
			task.spawn(function()
				joueur:LoadCharacter() -- réapparition au garage
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

task.spawn(function()
	while true do
		-- Attente de joueurs
		while #Players:GetPlayers() < P.JoueursMin do
			envoyerATous({ type = "etat", etat = "attente", joueurs = #Players:GetPlayers(), min = P.JoueursMin })
			task.wait(2)
		end
		-- Intermission (on peut rouler librement en attendant)
		local annule = false
		for t = P.Intermission, 1, -1 do
			if #Players:GetPlayers() < P.JoueursMin then
				annule = true
				break
			end
			envoyerATous({ type = "etat", etat = "intermission", temps = t })
			task.wait(1)
		end
		if not annule then
			local participants = {}
			for _, j in ipairs(Players:GetPlayers()) do
				if j.Character then
					table.insert(participants, j)
				end
			end
			if #participants >= P.JoueursMin then
				-- Tout le monde quitte son kart libre avant le tirage
				for _, j in ipairs(participants) do
					RetirerKart:Invoke(j)
				end
				local ok, erreur = pcall(jouerManche, participants)
				if not ok then
					warn("[Manches] " .. tostring(erreur))
					workspace:SetAttribute("MancheEnCours", false)
					fermerEntree(false)
					for _, j in ipairs(Players:GetPlayers()) do
						remettreAZero(j)
					end
				end
			end
		end
	end
end)

print("[Golden Mall] Mode en ligne « Police contre Fugitifs » prêt.")
