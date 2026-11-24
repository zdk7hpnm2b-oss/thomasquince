--[[
	Cadeaux  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : Cadeaux

	Ce qui fait revenir les joueurs (comme dans les gros jeux Roblox) :
	  🎁 CADEAU GRATUIT : des cadeaux selon le temps de jeu (3, 10, 20, 35, 60 min)
	  📅 SÉRIE DU JOUR  : 1 cadeau par jour, de plus en plus gros jusqu'au jour 7
	  👥 INVITER DES AMIS : invitation Roblox (bonus quand vous jouez ensemble)
	  🔔 M'AVERTIR : notifications Roblox quand il y a du nouveau
	  👪 GROUPE : bonus unique si on rejoint le groupe (si Config.Cadeaux.GroupeId est réglé)
	Les cartes s'affichent à droite du menu. Une pastille rouge « ! » = cadeau prêt.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")
local Cadeaux = remotes:WaitForChild("Cadeaux") :: RemoteFunction

local joueur = Players.LocalPlayer
local hud = joueur:WaitForChild("PlayerGui"):WaitForChild("PartieHUD")
local menu = hud:WaitForChild("Menu") :: Frame

local POLICE = Font.fromEnum(Enum.Font.FredokaOne)
local ROUGE = Color3.fromRGB(225, 30, 45)
local VERT = Color3.fromRGB(50, 170, 90)

local function coins(o: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end

local function texte(parent: Instance, taille: UDim2, position: UDim2, couleur: Color3, police: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = taille
	t.Position = position
	t.BackgroundTransparency = 1
	t.TextColor3 = couleur
	t.Font = police or Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 24
	t.Parent = parent
	return t
end

---------------------------------------------------------------------
-- Les cartes à droite du menu
---------------------------------------------------------------------
-- (rangées dans la colonne de droite du menu, entre « EN DIRECT » et l'offre exclusive)
local colonne = Instance.new("Frame")
colonne.Name = "Cadeaux"
colonne.LayoutOrder = 3
colonne.Size = UDim2.new(1, 0, 0, 0)
colonne.AutomaticSize = Enum.AutomaticSize.Y
colonne.BackgroundTransparency = 1
colonne.ZIndex = 22
colonne.Parent = menu:WaitForChild("ColonneDroite")
local dispo = Instance.new("UIListLayout")
dispo.Padding = UDim.new(0, 8)
dispo.SortOrder = Enum.SortOrder.LayoutOrder
dispo.Parent = colonne

local function carte(ordre: number, icone: string, titre: string, couleur: Color3?): (TextButton, TextLabel, Frame)
	local b = Instance.new("TextButton")
	b.LayoutOrder = ordre
	b.Size = UDim2.new(1, 0, 0, 60)
	b.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	b.BackgroundTransparency = 0.05
	b.AutoButtonColor = false
	b.Text = ""
	b.ZIndex = 23
	b.Parent = colonne
	coins(b, 4)
	local bord = Instance.new("UIStroke")
	bord.Color = Color3.fromRGB(60, 60, 70)
	bord.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bord.Parent = b
	local fondIcone = Instance.new("Frame")
	fondIcone.Size = UDim2.fromOffset(44, 44)
	fondIcone.Position = UDim2.new(0, 8, 0.5, -22)
	fondIcone.BackgroundColor3 = Color3.new(1, 1, 1)
	local teinte = couleur or Color3.fromRGB(120, 120, 140)
	local degradeIcone = Instance.new("UIGradient") -- pastille colorée, style bonbon
	degradeIcone.Color = ColorSequence.new(teinte:Lerp(Color3.new(1, 1, 1), 0.35), teinte:Lerp(Color3.new(0, 0, 0), 0.15))
	degradeIcone.Rotation = 90
	degradeIcone.Parent = fondIcone
	local contourIcone = Instance.new("UIStroke")
	contourIcone.Color = Color3.new(1, 1, 1)
	contourIcone.Transparency = 0.55
	contourIcone.Thickness = 2
	contourIcone.Parent = fondIcone
	fondIcone.ZIndex = 24
	fondIcone.Parent = b
	coins(fondIcone, 4)
	local i = texte(fondIcone, UDim2.new(1, -10, 1, -10), UDim2.new(0, 5, 0, 5), Color3.new(1, 1, 1))
	i.TextXAlignment = Enum.TextXAlignment.Center
	i.Text = icone
	i.ZIndex = 25
	local image = Config.ImageIcone(icone)
	if image then
		i.Visible = false
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(1, -14, 1, -14)
		img.Position = UDim2.fromOffset(7, 7)
		img.BackgroundTransparency = 1
		img.Image = image
		img.ZIndex = 25
		img.Parent = fondIcone
	end
	local t = texte(b, UDim2.new(1, -70, 0, 22), UDim2.new(0, 62, 0, 9), Color3.new(1, 1, 1))
	t.FontFace = POLICE
	t.Text = titre
	local sous = texte(b, UDim2.new(1, -70, 0, 16), UDim2.new(0, 62, 0, 34), Color3.fromRGB(190, 190, 200), Enum.Font.GothamMedium)
	-- Pastille rouge « ! »
	local pastille = Instance.new("Frame")
	pastille.AnchorPoint = Vector2.new(0.5, 0.5)
	pastille.Size = UDim2.fromOffset(16, 16)
	pastille.Position = UDim2.new(1, -4, 0, 4)
	pastille.BackgroundColor3 = Color3.fromRGB(240, 40, 50)
	pastille.Visible = false
	pastille.ZIndex = 26
	pastille.Parent = b
	coins(pastille, 8)
	local e = Instance.new("UIScale")
	e.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(e, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(38, 38, 46) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(e, TweenInfo.new(0.12), { Scale = 1 }):Play()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(20, 20, 24) }):Play()
	end)
	-- La pastille « respire »
	task.spawn(function()
		while b.Parent do
			if pastille.Visible then
				TweenService:Create(pastille, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.fromOffset(20, 20) }):Play()
				task.wait(0.5)
				TweenService:Create(pastille, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { Size = UDim2.fromOffset(16, 16) }):Play()
			end
			task.wait(0.5)
		end
	end)
	return b, sous, pastille
end

local carteCadeau, sousCadeau, pastilleCadeau = carte(1, "🎁", "Cadeau gratuit", Color3.fromRGB(170, 70, 255))
local carteSerie, sousSerie, pastilleSerie = carte(2, "📅", "Série du jour", Color3.fromRGB(0, 200, 170))
local carteAmis, sousAmis = carte(3, "👥", "Inviter des amis", Color3.fromRGB(50, 140, 255))
sousAmis.Text = ("+%d pièces chacun"):format(Config.Cadeaux.BonusAmi or 150)
local carteNotif, sousNotif = carte(4, "🔔", "M'avertir", Color3.fromRGB(255, 190, 0))
sousNotif.Text = "Ne rate aucune mise à jour"
local carteGroupe, sousGroupe, pastilleGroupe = carte(5, "👪", "Rejoins le groupe", Color3.fromRGB(40, 210, 100))
sousGroupe.Text = ("+%d 💰 une seule fois"):format(Config.Cadeaux.BonusGroupe or 500)
carteGroupe.Visible = false

---------------------------------------------------------------------
-- Le panneau qui détaille les cadeaux
---------------------------------------------------------------------
local panneau = Instance.new("Frame")
panneau.Name = "PageCadeaux"
panneau.AnchorPoint = Vector2.new(0.5, 0.5)
panneau.Size = UDim2.fromScale(1, 1) -- page entière
panneau.Position = UDim2.fromScale(0.5, 0.5)
panneau.BackgroundColor3 = Color3.new(1, 1, 1)
panneau.BackgroundTransparency = 0.03
panneau.Visible = false
panneau.ZIndex = 40
panneau.Parent = menu
local degradePage = Instance.new("UIGradient")
degradePage.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 14)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(16, 14, 20)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 12, 20)),
})
degradePage.Rotation = 25
degradePage.Parent = panneau
local margesPage = Instance.new("UIPadding")
margesPage.PaddingLeft = UDim.new(0.12, 0)
margesPage.PaddingRight = UDim.new(0.12, 0)
margesPage.PaddingTop = UDim.new(0, 40)
margesPage.PaddingBottom = UDim.new(0, 30)
margesPage.Parent = panneau
local lisere = Instance.new("Frame")
lisere.Size = UDim2.new(0, 140, 0, 5)
lisere.Position = UDim2.new(0, 20, 0, 62)
lisere.BackgroundColor3 = ROUGE
lisere.BorderSizePixel = 0
lisere.ZIndex = 41
lisere.Parent = panneau
local titrePanneau = texte(panneau, UDim2.new(1, -220, 0, 50), UDim2.new(0, 20, 0, 6), Color3.new(1, 1, 1))
titrePanneau.FontFace = POLICE
titrePanneau.ZIndex = 41
local fermer = Instance.new("TextButton")
fermer.AnchorPoint = Vector2.new(1, 0)
fermer.Size = UDim2.fromOffset(150, 46)
fermer.Position = UDim2.new(1, -10, 0, 8)
fermer.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
fermer.TextColor3 = Color3.new(1, 1, 1)
fermer.Font = Enum.Font.FredokaOne
fermer.TextSize = 20
fermer.Text = "← RETOUR"
fermer.ZIndex = 42
fermer.Parent = panneau
coins(fermer, 6)
fermer.Activated:Connect(function()
	panneau.Visible = false
end)
local liste = Instance.new("Frame")
liste.Size = UDim2.new(1, -40, 1, -110)
liste.Position = UDim2.new(0, 20, 0, 96)
liste.BackgroundTransparency = 1
liste.ZIndex = 41
liste.Parent = panneau
local dispoListe = Instance.new("UIGridLayout")
dispoListe.CellPadding = UDim2.fromOffset(8, 8)
dispoListe.SortOrder = Enum.SortOrder.LayoutOrder
dispoListe.Parent = liste

local etat: any = nil
local vue = "" -- "temps" ou "serie"

local function formatTemps(s: number): string
	return ("%d:%02d"):format(s // 60, s % 60)
end

local function remplir()
	for _, e in ipairs(liste:GetChildren()) do
		if e:IsA("GuiObject") then
			e:Destroy()
		end
	end
	if not etat then
		return
	end
	if vue == "temps" then
		titrePanneau.Text = "CADEAUX"
		dispoListe.CellSize = UDim2.new(1, 0, 0, 70)
		for i, c in ipairs(etat.temps or {}) do
			local b = Instance.new("TextButton")
			b.LayoutOrder = i
			b.BackgroundColor3 = if c.pret then VERT elseif c.pris then Color3.fromRGB(30, 30, 36) else Color3.fromRGB(26, 26, 32)
			b.AutoButtonColor = c.pret
			b.Text = ""
			b.ZIndex = 42
			b.Parent = liste
			coins(b, 4)
			local t = texte(b, UDim2.new(0.6, 0, 0, 24), UDim2.new(0, 14, 0, 8), Color3.new(1, 1, 1))
			t.FontFace = POLICE
			t.Text = c.texte
			t.ZIndex = 43
			local s = texte(b, UDim2.new(0.6, 0, 0, 16), UDim2.new(0, 14, 0, 34), Color3.fromRGB(200, 200, 210), Enum.Font.GothamMedium)
			s.Text = ("Après %d min de jeu"):format(c.minutes)
			s.ZIndex = 43
			local d = texte(b, UDim2.new(0.35, 0, 0, 26), UDim2.new(0.62, 0, 0, 16), Color3.new(1, 1, 1))
			d.TextXAlignment = Enum.TextXAlignment.Right
			d.Text = if c.pris then "✔ PRIS" elseif c.pret then "RÉCUPÉRER" else "⏳ " .. formatTemps(c.reste)
			d.ZIndex = 43
			if c.pret then
				b.Activated:Connect(function()
					etat = Cadeaux:InvokeServer("temps", i)
					remplir()
				end)
			end
		end
	else
		titrePanneau.Text = ("SÉRIE · JOUR %d"):format(etat.serieJour or 1)
		dispoListe.CellSize = UDim2.new(0.25, -6, 0, 170)
		for i, c in ipairs(Config.Cadeaux.Serie or {}) do
			local aujourdhui = i == etat.serieJour
			local passe = i < (etat.serieJour or 1) or (aujourdhui and not etat.seriePrete)
			local b = Instance.new("TextButton")
			b.LayoutOrder = i
			b.BackgroundColor3 = if aujourdhui and etat.seriePrete then ROUGE elseif passe then VERT else Color3.fromRGB(28, 28, 34)
			b.AutoButtonColor = aujourdhui and etat.seriePrete
			b.Text = ""
			b.ZIndex = 42
			b.Parent = liste
			coins(b, 4)
			local j = texte(b, UDim2.new(1, -10, 0, 20), UDim2.new(0, 5, 0, 8), Color3.new(1, 1, 1))
			j.TextXAlignment = Enum.TextXAlignment.Center
			j.FontFace = POLICE
			j.Text = "JOUR " .. i
			j.ZIndex = 43
			local ic = texte(b, UDim2.new(1, -10, 0, 34), UDim2.new(0, 5, 0, 32), Color3.new(1, 1, 1))
			ic.TextXAlignment = Enum.TextXAlignment.Center
			ic.Text = if passe then "✔" elseif c.Tours then "🎡" else "💰"
			ic.ZIndex = 43
			local t = texte(b, UDim2.new(1, -10, 0, 36), UDim2.new(0, 5, 0, 74), Color3.fromRGB(230, 230, 235), Enum.Font.FredokaOne)
			t.TextXAlignment = Enum.TextXAlignment.Center
			t.TextWrapped = true
			t.Text = Config.TexteCadeau(c)
			t.ZIndex = 43
			if aujourdhui and etat.seriePrete then
				b.Activated:Connect(function()
					etat = Cadeaux:InvokeServer("serie")
					remplir()
				end)
			end
		end
	end
end

local function ouvrir(v: string)
	vue = v
	-- Une seule page à la fois : on ferme le magasin, la roue, l'aperçu
	for _, nom in ipairs({ "Magasin", "RoueDuJour", "Apercu" }) do
		local autre = menu:FindFirstChild(nom)
		if autre and autre:IsA("GuiObject") then
			autre.Visible = false
		end
	end
	panneau.Visible = true
	-- La page arrive en glissant depuis la droite
	panneau.Position = UDim2.fromScale(1.5, 0.5)
	TweenService:Create(panneau, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	lisere.Size = UDim2.new(0, 0, 0, 5)
	TweenService:Create(lisere, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0, 140, 0, 5) }):Play()
	task.spawn(function()
		etat = Cadeaux:InvokeServer("etat")
		remplir()
	end)
	remplir()
end
carteCadeau.Activated:Connect(function()
	ouvrir("temps")
end)
carteSerie.Activated:Connect(function()
	ouvrir("serie")
end)
carteAmis.Activated:Connect(function()
	pcall(function()
		SocialService:PromptGameInvite(joueur)
	end)
end)
carteNotif.Activated:Connect(function()
	local ok = pcall(function()
		local ens = game:GetService("ExperienceNotificationService")
		if ens:CanPromptOptInAsync() then
			ens:PromptOptIn()
		end
	end)
	sousNotif.Text = if ok then "✔ Merci ! Tu seras averti" else "Pas disponible ici"
end)
carteGroupe.Activated:Connect(function()
	if (Config.Cadeaux.GroupeId or 0) ~= 0 then
		pcall(function()
			game:GetService("GroupService"):PromptJoinAsync(Config.Cadeaux.GroupeId)
		end)
		task.wait(1)
		etat = Cadeaux:InvokeServer("groupe")
	end
end)

---------------------------------------------------------------------
-- Mise à jour toutes les secondes (compte à rebours, pastilles)
---------------------------------------------------------------------
task.spawn(function()
	local depuis = 0
	while true do
		if menu.Visible then
			depuis += 1
			if not etat or depuis >= 15 then
				depuis = 0
				local ok, r = pcall(function()
					return Cadeaux:InvokeServer("etat")
				end)
				if ok and r then
					etat = r
				end
			elseif etat then
				for _, c in ipairs(etat.temps or {}) do
					if c.reste > 0 then
						c.reste -= 1
						if c.reste == 0 and not c.pris then
							c.pret = true
						end
					end
				end
			end
			if etat then
				local prochain = nil
				local pret = false
				for _, c in ipairs(etat.temps or {}) do
					if c.pret then
						pret = true
					elseif not c.pris and not prochain then
						prochain = c
					end
				end
				pastilleCadeau.Visible = pret
				sousCadeau.Text = if pret then "Prêt à récupérer !" elseif prochain then ("Prochain dans %s"):format(formatTemps(prochain.reste)) else "Tout récupéré, bravo !"
				pastilleSerie.Visible = etat.seriePrete == true
				sousSerie.Text = if etat.seriePrete then ("Jour %d · cadeau prêt !"):format(etat.serieJour or 1) else ("Jour %d · reviens demain"):format(etat.serieJour or 1)
				carteGroupe.Visible = etat.groupe == true
				pastilleGroupe.Visible = etat.groupe == true
				if panneau.Visible and vue == "temps" then
					remplir()
				end
			end
		end
		task.wait(1)
	end
end)
