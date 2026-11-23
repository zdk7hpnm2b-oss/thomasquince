--[[
	MatchmakingServer  (Script)
	À placer dans : ServerScriptService   — nom conseillé : MatchmakingServer

	LE MATCHMAKING ENTRE LES PLACES DE L'EXPÉRIENCE
	  • Dans le LOBBY (place de départ, publique) :
	      - 🏁 Entraînement : on part tout de suite vers la place Entraînement
	      - 🔥 Drift Battle : on part tout de suite vers la place Drift Battle
	      - 🌐 Police contre Fugitifs : on entre dans une FILE D'ATTENTE. Dès qu'il y
	        a assez de joueurs (ou avec les bots de test), le matchmaking crée un
	        serveur privé et y envoie le groupe (jusqu'à 20 joueurs) ENSEMBLE.
	  • Dans les PLACES DE JEU : le bouton « Retour au lobby ».
	Rien ne se passe en mode « ToutEnUn » (KartConfig > Config.Places pas rempli).
	Les téléportations ne marchent que dans le jeu publié (pas dans Studio).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")

local TYPE = Config.TypeDePlace()
local P = Config.Partie or {}
local JOUEURS_MIN = P.JoueursMin or 2
local MAX_PAR_PARTIE = 20
local ATTENTE_BOTS = 8 -- seul dans la file avec les bots de test : départ au bout de 8 s

local Voyage = Instance.new("RemoteEvent")
Voyage.Name = "Voyage"
Voyage.Parent = remotes

if TYPE == "ToutEnUn" then
	return -- tout se joue dans cette place : pas de téléportation
end

---------------------------------------------------------------------
-- Téléporter des joueurs vers une place
---------------------------------------------------------------------
local function teleporter(joueurs: { Player }, placeId: number, donnees: { [string]: any }, codeServeurPrive: string?): boolean
	if placeId == 0 or #joueurs == 0 then
		return false
	end
	local options = Instance.new("TeleportOptions")
	if codeServeurPrive then
		options.ReservedServerAccessCode = codeServeurPrive
	end
	options:SetTeleportData(donnees)
	local ok, erreur = pcall(function()
		TeleportService:TeleportAsync(placeId, joueurs, options)
	end)
	if not ok then
		warn("[Matchmaking] Téléportation impossible : " .. tostring(erreur))
		for _, j in ipairs(joueurs) do
			Voyage:FireClient(j, { type = "erreur", texte = "Impossible de rejoindre la partie. Réessaie !" })
		end
	end
	return ok
end

TeleportService.TeleportInitFailed:Connect(function(joueur: Player)
	joueur:SetAttribute("Pret", false)
	Voyage:FireClient(joueur, { type = "erreur", texte = "Le voyage a échoué. Réessaie !" })
end)

---------------------------------------------------------------------
-- Dans une PLACE DE JEU : retour au lobby
---------------------------------------------------------------------
if TYPE ~= "Lobby" then
	Voyage.OnServerEvent:Connect(function(joueur: Player, info)
		if type(info) ~= "table" then
			return
		end
		if info.mode == "Lobby" then
			Voyage:FireClient(joueur, { type = "depart", texte = "Retour au lobby…" })
			teleporter({ joueur }, Config.Places.Lobby, { ouvrirMenu = true })
		elseif (info.mode == "Entrainement" or info.mode == "DriftBattle") and info.mode ~= TYPE then
			-- Le menu d'accueil marche aussi ici : on part directement vers l'autre mode
			Voyage:FireClient(joueur, { type = "depart", texte = if info.mode == "Entrainement" then "Direction l'entraînement…" else "Direction le Drift Battle…" })
			teleporter({ joueur }, Config.Places[info.mode] or 0, { mode = info.mode })
		elseif info.mode == "PoliceFugitifs" then
			-- La file d'attente est au lobby : on y va, et on entre dans la file tout seul
			Voyage:FireClient(joueur, { type = "depart", texte = "Recherche d'une partie en ligne…" })
			teleporter({ joueur }, Config.Places.Lobby, { fileAuto = true })
		end
	end)
	print(("[Matchmaking] Place de jeu « %s » : retour au lobby prêt."):format(TYPE))
	return
end

---------------------------------------------------------------------
-- Dans le LOBBY : départs directs + file d'attente Police contre Fugitifs
---------------------------------------------------------------------
local file: { Player } = {}
local entreeDansLaFile: { [Player]: number } = {}

local function retirerDeLaFile(joueur: Player)
	for i, j in ipairs(file) do
		if j == joueur then
			table.remove(file, i)
			break
		end
	end
	entreeDansLaFile[joueur] = nil
	joueur:SetAttribute("Pret", false)
end

Voyage.OnServerEvent:Connect(function(joueur: Player, info)
	if type(info) ~= "table" then
		return
	end
	if info.mode == "Entrainement" or info.mode == "DriftBattle" then
		retirerDeLaFile(joueur)
		Voyage:FireClient(joueur, { type = "depart", texte = if info.mode == "Entrainement" then "Direction l'entraînement…" else "Direction le Drift Battle…" })
		teleporter({ joueur }, Config.Places[info.mode], { mode = info.mode })
	elseif info.mode == "PoliceFugitifs" then
		if joueur:GetAttribute("Pret") then
			retirerDeLaFile(joueur) -- (recliquer = quitter la file)
		else
			table.insert(file, joueur)
			entreeDansLaFile[joueur] = os.clock()
			joueur:SetAttribute("Pret", true)
		end
	end
end)

Players.PlayerRemoving:Connect(retirerDeLaFile)

task.spawn(function()
	while true do
		task.wait(1)
		-- On retire les joueurs partis
		for i = #file, 1, -1 do
			if not file[i].Parent then
				table.remove(file, i)
			end
		end
		-- Assez de monde ? (ou un joueur seul depuis 8 s, avec les bots de test)
		local plusAncien = file[1] and entreeDansLaFile[file[1]] or os.clock()
		-- (bots de test seulement dans Studio : en ligne, que des vraies personnes)
		local avecBots = game:GetService("RunService"):IsStudio() and (P.BotsTest or 0) > 0 and #file >= 1 and os.clock() - plusAncien >= ATTENTE_BOTS
		if #file >= JOUEURS_MIN or avecBots then
			local groupe = {}
			for i = 1, math.min(#file, MAX_PAR_PARTIE) do
				table.insert(groupe, file[i])
			end
			for _, j in ipairs(groupe) do
				retirerDeLaFile(j)
				Voyage:FireClient(j, { type = "depart", texte = ("🚓 Partie trouvée ! %d joueur%s, c'est parti…"):format(#groupe, if #groupe > 1 then "s" else "") })
			end
			local ok, code = pcall(function()
				return TeleportService:ReserveServer(Config.Places.PoliceFugitifs)
			end)
			if ok and code then
				teleporter(groupe, Config.Places.PoliceFugitifs, { mode = "PoliceFugitifs", attendus = #groupe }, code)
			else
				warn("[Matchmaking] Impossible de créer le serveur privé : " .. tostring(code))
				for _, j in ipairs(groupe) do
					Voyage:FireClient(j, { type = "erreur", texte = "Impossible de créer la partie. Réessaie !" })
				end
			end
		end
		Voyage:FireAllClients({ type = "file", n = #file, min = JOUEURS_MIN })
	end
end)

print("[Matchmaking] Lobby prêt : Entraînement, Drift Battle, file Police contre Fugitifs.")
