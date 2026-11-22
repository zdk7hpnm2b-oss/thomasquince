--[[
	PartieUI  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : PartieUI

	Ce que le joueur voit du mode en ligne « Police contre Fugitifs » :
	  • la barre d'état en haut (attente, prochaine manche, temps restant, fugitifs libres)
	  • l'animation du TIRAGE AU SORT (roulette 🚓 / 🏃, puis ta carte d'équipe)
	  • le fil des arrestations, l'écran « TU ES ARRÊTÉ », l'écran de victoire
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local joueur = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")
local Partie = remotes:WaitForChild("Partie", 30)
if not Partie then
	return
end

local BLEU = Color3.fromRGB(70, 140, 255)
local ORANGE = Color3.fromRGB(255, 150, 40)
local FOND = Color3.fromRGB(15, 15, 20)

local gui = Instance.new("ScreenGui")
gui.Name = "PartieHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = joueur:WaitForChild("PlayerGui")

local function texte(parent: Instance, taille: UDim2, position: UDim2, couleur: Color3, police: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = taille
	t.Position = position
	t.BackgroundTransparency = 1
	t.TextColor3 = couleur
	t.Font = police or Enum.Font.GothamBlack
	t.TextScaled = true
	t.Text = ""
	local c = Instance.new("UIStroke")
	c.Thickness = 2
	c.Color = Color3.fromRGB(10, 10, 14)
	c.Parent = t
	t.Parent = parent
	return t
end

---------------------------------------------------------------------
-- Barre d'état (en haut au centre)
---------------------------------------------------------------------
local barre = Instance.new("Frame")
barre.AnchorPoint = Vector2.new(0.5, 0)
barre.Size = UDim2.new(0, 440, 0, 40)
barre.Position = UDim2.new(0.5, 0, 0, 8)
barre.BackgroundColor3 = FOND
barre.BackgroundTransparency = 0.25
barre.Parent = gui
Instance.new("UICorner", barre).CornerRadius = UDim.new(0, 10)
local texteBarre = texte(barre, UDim2.new(1, -20, 1, -10), UDim2.new(0, 10, 0, 5), Color3.new(1, 1, 1))

local function formatTemps(s: number): string
	return ("%d:%02d"):format(math.floor(s / 60), s % 60)
end

---------------------------------------------------------------------
-- Fil des arrestations (en bas à gauche)
---------------------------------------------------------------------
local fil = Instance.new("Frame")
fil.Size = UDim2.new(0, 380, 0, 140)
fil.Position = UDim2.new(0, 16, 1, -300)
fil.BackgroundTransparency = 1
fil.Parent = gui
local listeFil = Instance.new("UIListLayout")
listeFil.VerticalAlignment = Enum.VerticalAlignment.Bottom
listeFil.Padding = UDim.new(0, 4)
listeFil.Parent = fil

local function ajouterAuFil(message: string, couleur: Color3)
	local l = texte(fil, UDim2.new(1, 0, 0, 26), UDim2.new(), couleur, Enum.Font.GothamBold)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = message
	task.delay(6, function()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.55)
		l:Destroy()
	end)
end

---------------------------------------------------------------------
-- Grand écran central (tirage, arrestation, victoire)
---------------------------------------------------------------------
local carte = Instance.new("Frame")
carte.AnchorPoint = Vector2.new(0.5, 0.5)
carte.Size = UDim2.new(0, 520, 0, 260)
carte.Position = UDim2.fromScale(0.5, 0.45)
carte.BackgroundColor3 = FOND
carte.BackgroundTransparency = 0.1
carte.Visible = false
carte.Parent = gui
Instance.new("UICorner", carte).CornerRadius = UDim.new(0, 18)
local bordCarte = Instance.new("UIStroke")
bordCarte.Thickness = 4
bordCarte.Parent = carte
local echelleCarte = Instance.new("UIScale")
echelleCarte.Parent = carte
local petitTitre = texte(carte, UDim2.new(1, -30, 0, 34), UDim2.new(0, 15, 0, 18), Color3.fromRGB(200, 200, 210), Enum.Font.GothamBold)
local grandTitre = texte(carte, UDim2.new(1, -30, 0, 90), UDim2.new(0, 15, 0, 60), Color3.new(1, 1, 1))
local sousTitre = texte(carte, UDim2.new(1, -40, 0, 60), UDim2.new(0, 20, 0, 170), Color3.fromRGB(230, 230, 235), Enum.Font.GothamMedium)

local function montrerCarte(petit: string, grand: string, sous: string, couleur: Color3, duree: number?)
	petitTitre.Text = petit
	grandTitre.Text = grand
	grandTitre.TextColor3 = couleur
	sousTitre.Text = sous
	bordCarte.Color = couleur
	carte.Visible = true
	echelleCarte.Scale = 0.4
	TweenService:Create(echelleCarte, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if duree then
		local moi = grand
		task.delay(duree, function()
			if grandTitre.Text == moi then
				carte.Visible = false
			end
		end)
	end
end

---------------------------------------------------------------------
-- Messages du serveur
---------------------------------------------------------------------
Partie.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	if info.type == "etat" then
		if info.etat == "attente" then
			texteBarre.Text = ("🎮 MODE LIBRE · En attente de joueurs (%d/%d) pour Police vs Fugitifs"):format(info.joueurs or 1, info.min or 2)
			texteBarre.TextColor3 = Color3.fromRGB(220, 220, 230)
		elseif info.etat == "intermission" then
			texteBarre.Text = ("🚓 POLICE vs FUGITIFS 🏃 · prochaine manche dans %d s"):format(info.temps or 0)
			texteBarre.TextColor3 = Color3.fromRGB(255, 215, 80)
		elseif info.etat == "manche" then
			texteBarre.Text = ("⏱ %s   ·   🏃 %d/%d fugitifs libres"):format(formatTemps(info.temps or 0), info.restants or 0, info.total or 0)
			texteBarre.TextColor3 = if joueur:GetAttribute("Role") == "Police" then BLEU else ORANGE
		end
	elseif info.type == "tirage" then
		-- La roulette : 🚓 / 🏃 qui défilent, puis ton équipe
		task.spawn(function()
			local d = 0.06
			for i = 1, 22 do
				local police = i % 2 == 0
				montrerCarte("TIRAGE AU SORT...", if police then "🚓 POLICE" else "🏃 FUGITIF", "", if police then BLEU else ORANGE)
				echelleCarte.Scale = 1
				task.wait(d)
				d *= 1.12
			end
			if info.equipe == "Police" then
				montrerCarte(("TU ES POLICIER ! (%d policiers contre %d fugitifs)"):format(info.nbPolice or 0, info.nbFugitifs or 0), "🚓 POLICE",
					"Attrape TOUS les fugitifs avant la fin du temps ! Fonce sur leur kart pour les arrêter.", BLEU, 4)
			else
				montrerCarte(("TU ES FUGITIF ! (%d fugitifs contre %d policiers)"):format(info.nbFugitifs or 0, info.nbPolice or 0), "🏃 FUGITIF",
					"Échappe à la police jusqu'à la fin du temps ! Ne te laisse pas coller par un kart de police.", ORANGE, 4)
			end
		end)
	elseif info.type == "info" then
		ajouterAuFil(info.texte or "", Color3.fromRGB(255, 215, 80))
	elseif info.type == "arrestation" then
		ajouterAuFil(("🚔 %s a arrêté %s !"):format(info.policier or "?", info.fugitif or "?"), BLEU)
	elseif info.type == "arrete" then
		montrerCarte("🚨 ARRÊTÉ PAR " .. string.upper(info.par or "LA POLICE") .. " 🚨", "TU ES ARRÊTÉ !",
			"Tu regardes la fin de la manche depuis le garage. Courage à ton équipe !", Color3.fromRGB(255, 70, 70), 4)
	elseif info.type == "fin" then
		local police = info.gagnant == "Police"
		local monRole = joueur:GetAttribute("Role")
		local gagne = (police and monRole == "Police") or (not police and monRole == "Fugitif")
		montrerCarte(
			if gagne then ("🏆 VICTOIRE ! +%d XP"):format(info.xp or 0) else "Dommage... la prochaine sera la bonne !",
			if police then "🚓 LA POLICE GAGNE !" else "🏃 LES FUGITIFS GAGNENT !",
			if police then "Tous les fugitifs ont été arrêtés." else "Au moins un fugitif a échappé à la police !",
			if police then BLEU else ORANGE,
			5.5
		)
	end
end)
