--[[
	Modes  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : Modes

	  ⏱ COURSE CHRONO : chrono en haut de l'écran, portes lumineuses à passer
	    dans l'ordre (la prochaine brille en vert, une flèche la montre), 3 tours.
	  🏆 PAGE CLASSEMENT (menu) : top 10 de la semaine au Drift Battle (avec les
	    récompenses) et top 10 des meilleurs tours chrono.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local remotes = ReplicatedStorage:WaitForChild("MallDriftRemotes")

local joueur = Players.LocalPlayer
local hudPartie = joueur:WaitForChild("PlayerGui"):WaitForChild("PartieHUD")
local menu = hudPartie:WaitForChild("Menu") :: Frame
local POLICE = Font.fromEnum(Enum.Font.FredokaOne)
local ROUGE = Color3.fromRGB(225, 30, 45)
local VERT = Color3.fromRGB(70, 230, 120)
local OR = Color3.fromRGB(255, 200, 60)
local C = Config.Chrono or {}

local function coins(o: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end
local function texte(parent: Instance, taille: UDim2, position: UDim2, couleur: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = taille
	t.Position = position
	t.BackgroundTransparency = 1
	t.TextColor3 = couleur
	t.FontFace = POLICE
	t.TextScaled = true
	t.Text = ""
	local contour = Instance.new("UIStroke")
	contour.Thickness = 2
	contour.Color = Color3.fromRGB(10, 10, 14)
	contour.Parent = t
	t.Parent = parent
	return t
end
local function formatTemps(secondes: number): string
	secondes = math.max(secondes, 0)
	return ("%d:%05.2f"):format(secondes // 60, secondes % 60)
end

---------------------------------------------------------------------
-- ⏱ LA COURSE CHRONO
--   • départ lancé, chrono en direct, portes dans l'ordre (la prochaine en vert)
--   • ÉCART à chaque porte par rapport à ton meilleur tour (-0.42 vert / +0.31 rouge)
--   • FANTÔME : un kart transparent rejoue ton meilleur tour
--   • FLÈCHE au bord de l'écran quand la prochaine porte n'est pas visible
--   • MÉDAILLES 🥇🥈🥉 et écran de résultats à la fin
---------------------------------------------------------------------
local KartBuilder = require(ReplicatedStorage:WaitForChild("KartBuilder"))
local camera = workspace.CurrentCamera

local gui = Instance.new("ScreenGui")
gui.Name = "ChronoHUD"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
gui.Enabled = false
gui.Parent = joueur.PlayerGui

local panneau = Instance.new("Frame")
panneau.AnchorPoint = Vector2.new(0.5, 0)
panneau.Size = UDim2.new(0, 420, 0, 78)
panneau.Position = UDim2.new(0.5, 0, 0, 54)
panneau.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
panneau.BackgroundTransparency = 0.15
panneau.Parent = gui
coins(panneau, 10)
local lisere = Instance.new("Frame")
lisere.Size = UDim2.new(1, 0, 0, 4)
lisere.BackgroundColor3 = OR
lisere.BorderSizePixel = 0
lisere.Parent = panneau
local texteTour = texte(panneau, UDim2.new(0.25, 0, 0, 26), UDim2.new(0, 12, 0, 12), Color3.new(1, 1, 1))
local textePorte = texte(panneau, UDim2.new(0.25, 0, 0, 18), UDim2.new(0, 12, 0, 44), Color3.fromRGB(170, 230, 180))
local texteTemps = texte(panneau, UDim2.new(0.42, 0, 0, 44), UDim2.new(0.29, 0, 0, 8), OR)
local texteEcart = texte(panneau, UDim2.new(0.42, 0, 0, 20), UDim2.new(0.29, 0, 0, 52), Color3.new(1, 1, 1))
local texteMeilleur = texte(panneau, UDim2.new(0.27, 0, 0, 20), UDim2.new(0.72, -12, 0, 14), Color3.fromRGB(200, 200, 210))
local texteRecord = texte(panneau, UDim2.new(0.27, 0, 0, 16), UDim2.new(0.72, -12, 0, 40), Color3.fromRGB(160, 160, 175))
-- (juste sous le panneau du chrono : ne croise ni les chiffres du départ, ni les messages de drift)
local grandTexte = texte(gui, UDim2.new(0.6, 0, 0, 48), UDim2.new(0.2, 0, 0, 140), VERT)
grandTexte.TextTransparency = 1

local function montrerGrand(t: string, couleur: Color3, duree: number)
	grandTexte.Text = t
	grandTexte.TextColor3 = couleur
	grandTexte.TextTransparency = 0
	local e = grandTexte:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	e.Parent = grandTexte
	e.Scale = 0.5
	TweenService:Create(e, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duree, function()
		if grandTexte.Text == t then
			TweenService:Create(grandTexte, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

-- Flèche au bord de l'écran (prochaine porte hors de vue)
local flecheBord = texte(gui, UDim2.fromOffset(56, 56), UDim2.new(), VERT)
flecheBord.AnchorPoint = Vector2.new(0.5, 0.5)
flecheBord.Text = "➤"
flecheBord.Visible = false

-- Les portes (construites par le serveur, invisibles hors course)
local function portesDansLOrdre(): { Model }
	local dossier = workspace:FindFirstChild("ChronoPortes")
	local liste = {}
	if dossier then
		for _, p in ipairs(dossier:GetChildren()) do
			if p:IsA("Model") then
				table.insert(liste, p)
			end
		end
	end
	table.sort(liste, function(a, b)
		return (a:GetAttribute("Ordre") or 0) < (b:GetAttribute("Ordre") or 0)
	end)
	return liste
end
local flecheMonde = Instance.new("BillboardGui")
flecheMonde.Size = UDim2.fromOffset(80, 80)
flecheMonde.StudsOffset = Vector3.new(0, 6, 0)
flecheMonde.AlwaysOnTop = true
flecheMonde.Enabled = false
flecheMonde.Parent = gui
local texteFlecheMonde = texte(flecheMonde, UDim2.fromScale(1, 1), UDim2.new(), VERT)
texteFlecheMonde.Text = "▼"

local function colorerPortes(portes: { Model }, prochaine: number?)
	for i, porte in ipairs(portes) do
		for _, p in ipairs(porte:GetChildren()) do
			if p:IsA("BasePart") then
				if not prochaine then
					p.Transparency = 1
				elseif i == prochaine then
					p.Transparency = 0.05
					p.Color = VERT
				elseif i == prochaine % #portes + 1 then
					p.Transparency = 0.45 -- (la suivante, pour anticiper la trajectoire)
					p.Color = OR
				else
					p.Transparency = 0.85
					p.Color = OR
				end
			end
		end
	end
	local cible = prochaine and portes[prochaine]
	flecheMonde.Adornee = if cible then cible.PrimaryPart else nil
	flecheMonde.Enabled = cible ~= nil
end

-- Le fantôme : un kart transparent qui rejoue ton meilleur tour
local fantome: Model? = nil
local function creerFantome()
	if fantome then
		return
	end
	local perso = table.clone(Config.PersoParDefaut)
	perso.Carrosserie = "Blanc"
	perso.Neon = "Cyan"
	local m = KartBuilder.Construire(perso, CFrame.new(0, -100, 0), true)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			d.Material = Enum.Material.ForceField
			d.Color = Color3.fromRGB(120, 220, 255)
			d.Transparency = if d.Transparency >= 1 then 1 else 0.35
		elseif d:IsA("SurfaceGui") or d:IsA("Light") then
			d:Destroy()
		end
	end
	m.Name = "FantomeChrono"
	m.Parent = workspace
	fantome = m
end
local function retirerFantome()
	if fantome then
		fantome:Destroy()
		fantome = nil
	end
end

type Point = { t: number, cf: CFrame }
type Course = {
	depart: number, debutTour: number, tour: number, porte: number, tours: number, portes: { Model },
	meilleur: number?, record: number?, temps: { number },
	splits: { number }, meilleursSplits: { number }?,
	trace: { Point }, meilleureTrace: { Point }?, prochainEchantillon: number,
	departCF: CFrame?, replace: boolean,
}
local course: Course? = nil
local Chrono = remotes:WaitForChild("Chrono", 15) :: RemoteEvent?

local function chassisDuKart(): BasePart?
	local h = joueur.Character and joueur.Character:FindFirstChildOfClass("Humanoid")
	local siege = h and h.SeatPart
	return siege and siege.Parent and siege.Parent:FindFirstChild("Chassis") :: BasePart?
end

-- Position du fantôme à l'instant t du tour (interpolation entre deux points enregistrés)
local function cfFantome(trace: { Point }, t: number): CFrame?
	if #trace < 2 or t > trace[#trace].t then
		return nil
	end
	local bas, haut = 1, #trace
	while haut - bas > 1 do
		local milieu = (bas + haut) // 2
		if trace[milieu].t <= t then
			bas = milieu
		else
			haut = milieu
		end
	end
	local a, b = trace[bas], trace[haut]
	local alpha = if b.t > a.t then (t - a.t) / (b.t - a.t) else 0
	return a.cf:Lerp(b.cf, math.clamp(alpha, 0, 1))
end

-- L'écran de résultats
local resultats = Instance.new("Frame")
resultats.AnchorPoint = Vector2.new(0.5, 0.5)
resultats.Size = UDim2.new(0, 420, 0, 330)
resultats.Position = UDim2.fromScale(0.5, 0.5)
resultats.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
resultats.BackgroundTransparency = 0.05
resultats.Visible = false
resultats.Parent = gui
coins(resultats, 12)
local bordResultats = Instance.new("UIStroke")
bordResultats.Color = OR
bordResultats.Thickness = 3
bordResultats.Parent = resultats
local titreResultats = texte(resultats, UDim2.new(1, -40, 0, 44), UDim2.new(0, 20, 0, 14), OR)
local medailleResultats = texte(resultats, UDim2.new(1, -40, 0, 70), UDim2.new(0, 20, 0, 60), Color3.new(1, 1, 1))
local lignesResultats = texte(resultats, UDim2.new(1, -40, 0, 120), UDim2.new(0, 20, 0, 136), Color3.fromRGB(220, 220, 230))
lignesResultats.TextYAlignment = Enum.TextYAlignment.Top
lignesResultats.TextScaled = false
lignesResultats.TextSize = 22
local piedResultats = texte(resultats, UDim2.new(1, -40, 0, 26), UDim2.new(0, 20, 1, -44), Color3.fromRGB(170, 170, 185))

local function montrerResultats(c: Course?, meilleur: number?, nomMedaille: string?)
	local medaille = nil
	for _, m in ipairs(C.Medailles or {}) do
		if m.Nom == nomMedaille then
			medaille = m
		end
	end
	titreResultats.Text = "🏁 COURSE TERMINÉE"
	medailleResultats.Text = if medaille then ("%s MÉDAILLE %s  +%d 💰"):format(medaille.Icone, medaille.Nom, medaille.Pieces) else "Pas de médaille… réessaie !"
	medailleResultats.TextColor3 = if medaille and medaille.Nom == "OR" then OR elseif medaille and medaille.Nom == "ARGENT" then Color3.fromRGB(215, 220, 230) elseif medaille then Color3.fromRGB(220, 140, 70) else Color3.fromRGB(200, 200, 210)
	local lignes = {}
	for i, t in ipairs(c and c.temps or {}) do
		table.insert(lignes, ("Tour %d : %s%s"):format(i, formatTemps(t), if meilleur and math.abs(t - meilleur) < 0.01 then "  ⭐" else ""))
	end
	lignesResultats.Text = table.concat(lignes, "\n")
	local seuils = {}
	for _, m in ipairs(C.Medailles or {}) do
		table.insert(seuils, ("%s %s"):format(m.Icone, formatTemps(m.Temps)))
	end
	piedResultats.Text = "Objectifs : " .. table.concat(seuils, "  ")
	resultats.Visible = true
	local e = resultats:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	e.Parent = resultats
	e.Scale = 0.5
	TweenService:Create(e, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(5, function()
		resultats.Visible = false
		if not course then
			gui.Enabled = false
		end
	end)
end

local function arreterCourse()
	local c = course
	course = nil
	colorerPortes(if c then c.portes else portesDansLOrdre(), nil)
	flecheBord.Visible = false
	retirerFantome()
	return c
end

if Chrono then
	-- (le fantôme et les meilleurs écarts restent d'une course à l'autre pendant la session)
	local fantomeSession: { Point }? = nil
	local splitsSession: { number }? = nil

	Chrono.OnClientEvent:Connect(function(info)
		if type(info) ~= "table" then
			return
		end
		if info.type == "debut" then
			local portes = portesDansLOrdre()
			local depart = os.clock() + 3.2 -- (après le 3, 2, 1)
			course = {
				depart = depart, debutTour = depart, tour = 1, porte = 1, tours = info.tours or 3, portes = portes,
				meilleur = nil, record = if type(info.record) == "number" then info.record / 1000 else nil, temps = {},
				splits = {}, meilleursSplits = splitsSession,
				trace = {}, meilleureTrace = fantomeSession, prochainEchantillon = 0,
				departCF = if typeof(info.depart) == "CFrame" then info.depart else nil, replace = false,
			}
			colorerPortes(portes, 1)
			gui.Enabled = true
			resultats.Visible = false
			texteEcart.Text = ""
			texteRecord.Text = if course.record then ("Record : %s"):format(formatTemps(course.record)) else "Pas encore de record"
			texteMeilleur.Text = "Meilleur : —"
			panneau.Visible = false
			-- Départ lancé : on place aussi le kart de notre côté (on en a le contrôle)
			task.delay(1.3, function()
				local c = course
				local ch = chassisDuKart()
				if c and c.departCF and ch and ch.Parent then
					local modele = ch.Parent :: Model
					modele:PivotTo(c.departCF)
					ch.AssemblyLinearVelocity = Vector3.zero
					c.replace = true
				end
			end)
		elseif info.type == "fin" then
			local c = arreterCourse()
			if info.abandon then
				gui.Enabled = false
				return
			end
			local meilleur = if type(info.meilleur) == "number" then info.meilleur / 1000 else (c and c.meilleur)
			montrerResultats(c, meilleur, info.medaille)
		end
	end)

	local horsDuKart = 0
	RunService.RenderStepped:Connect(function(dt)
		local c = course
		if not c then
			return
		end
		local maintenant = os.clock()
		local porteCible = c.portes[c.porte]
		-- Flèche au bord de l'écran si la prochaine porte est hors de vue
		if porteCible and porteCible.PrimaryPart then
			local p, visible = camera:WorldToViewportPoint(porteCible.PrimaryPart.Position)
			local taille = camera.ViewportSize
			if visible and p.X > 0 and p.X < taille.X and p.Y > 0 and p.Y < taille.Y then
				flecheBord.Visible = false
			else
				local centre = taille / 2
				local dir = Vector2.new(p.X, p.Y) - centre
				if not visible then
					dir = -dir -- (derrière la caméra)
				end
				if dir.Magnitude < 1 then
					dir = Vector2.new(0, -1)
				end
				dir = dir.Unit
				local bord = math.min((taille.X / 2 - 60) / math.max(math.abs(dir.X), 0.001), (taille.Y / 2 - 60) / math.max(math.abs(dir.Y), 0.001))
				flecheBord.Position = UDim2.fromOffset(centre.X + dir.X * bord, centre.Y + dir.Y * bord)
				flecheBord.Rotation = math.deg(math.atan2(dir.Y, dir.X))
				flecheBord.Visible = true
			end
		end
		-- Pendant le 3, 2, 1 : le panneau est caché (les feux de départ sont à cet endroit)
		panneau.Visible = maintenant >= c.depart
		if maintenant < c.depart then
			texteTemps.Text = "PRÊT ?"
			texteTour.Text = ("TOUR 1/%d"):format(c.tours)
			textePorte.Text = ("PORTE 1/%d"):format(#c.portes)
			return
		end
		local tTour = maintenant - c.debutTour
		texteTemps.Text = formatTemps(tTour)
		texteTour.Text = ("TOUR %d/%d"):format(math.min(c.tour, c.tours), c.tours)
		textePorte.Text = ("PORTE %d/%d"):format(c.porte, #c.portes)
		local ch = chassisDuKart()
		if not ch then
			horsDuKart += dt
			if horsDuKart > 3 and Chrono then
				Chrono:FireServer("quitter") -- (descendu du kart : la course s'arrête)
				arreterCourse()
				gui.Enabled = false
			end
			return
		end
		horsDuKart = 0
		-- Enregistrement de la trajectoire (pour le fantôme du prochain tour)
		if maintenant >= c.prochainEchantillon then
			c.prochainEchantillon = maintenant + 0.05
			table.insert(c.trace, { t = tTour, cf = ch.CFrame })
		end
		-- Le fantôme rejoue le meilleur tour
		local trace = c.meilleureTrace
		if trace then
			local cfF = cfFantome(trace, tTour)
			if cfF then
				creerFantome()
				if fantome then
					fantome:PivotTo(cfF)
				end
			elseif fantome then
				fantome:PivotTo(CFrame.new(0, -100, 0)) -- (fantôme arrivé : il disparaît)
			end
		end
		if not porteCible or not porteCible.PrimaryPart then
			return
		end
		local cible = porteCible.PrimaryPart.Position
		local ecart = Vector3.new(ch.Position.X - cible.X, 0, ch.Position.Z - cible.Z).Magnitude
		if ecart < (C.DistancePorte or 13) then
			-- Écart avec le meilleur tour à cette porte
			c.splits[c.porte] = tTour
			local ref = c.meilleursSplits and c.meilleursSplits[c.porte]
			if ref then
				local d = tTour - ref
				texteEcart.Text = ("%s%.2f"):format(if d < 0 then "-" else "+", math.abs(d))
				texteEcart.TextColor3 = if d < 0 then VERT else Color3.fromRGB(255, 90, 90)
			end
			c.porte += 1
			if c.porte > #c.portes then
				-- Tour terminé !
				local temps = tTour
				table.insert(c.temps, temps)
				local estMeilleur = not c.meilleur or temps < (c.meilleur :: number)
				if estMeilleur then
					c.meilleur = temps
					c.meilleursSplits = c.splits
					c.meilleureTrace = c.trace
					fantomeSession = c.trace
					splitsSession = c.splits
					texteMeilleur.Text = ("Meilleur : %s"):format(formatTemps(temps))
				end
				local estRecord = not c.record or temps < (c.record :: number)
				if estRecord then
					c.record = temps
					texteRecord.Text = ("Record : %s"):format(formatTemps(temps))
				end
				montrerGrand(("TOUR %d · %s%s"):format(c.tour, formatTemps(temps), if estRecord then "  🏆 RECORD !" elseif estMeilleur then "  ⭐" else ""), if estRecord then OR else VERT, 1.8)
				if Chrono then
					Chrono:FireServer("tour", temps)
				end
				c.tour += 1
				c.porte = 1
				c.splits = {}
				c.trace = {}
				c.debutTour = maintenant
				retirerFantome() -- (il repartira avec le nouveau tour)
			end
			colorerPortes(c.portes, if c.tour <= c.tours then c.porte else nil)
		end
	end)

	-- Arrivée dans la place Entraînement en ayant choisi « CHRONO » au lobby
	task.spawn(function()
		local donnees = TeleportService:GetLocalPlayerTeleportData()
		if type(donnees) == "table" and donnees.chrono then
			local perso = joueur.Character or joueur.CharacterAdded:Wait()
			perso:WaitForChild("HumanoidRootPart", 10)
			task.wait(3)
			Chrono:FireServer("lancer")
		end
	end)
end

---------------------------------------------------------------------
-- 🏆 LA PAGE CLASSEMENT (dans le menu)
---------------------------------------------------------------------
local Classements = remotes:WaitForChild("Classements", 15) :: RemoteFunction?

local page = Instance.new("Frame")
page.Name = "PageClassement"
page.AnchorPoint = Vector2.new(0.5, 0.5)
page.Size = UDim2.fromScale(1, 1)
page.Position = UDim2.fromScale(0.5, 0.5)
page.BackgroundColor3 = Color3.new(1, 1, 1)
page.BackgroundTransparency = 0.03
page.Visible = false
page.ZIndex = 40
page.Parent = menu
local degrade = Instance.new("UIGradient")
degrade.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 14)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(18, 15, 10)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 55, 10)),
})
degrade.Rotation = 25
degrade.Parent = page
local marges = Instance.new("UIPadding")
marges.PaddingLeft = UDim.new(0.12, 0)
marges.PaddingRight = UDim.new(0.12, 0)
marges.PaddingTop = UDim.new(0, 40)
marges.PaddingBottom = UDim.new(0, 30)
marges.Parent = page
local titre = texte(page, UDim2.new(1, -220, 0, 50), UDim2.new(0, 20, 0, 6), Color3.new(1, 1, 1))
titre.Text = "CLASSEMENT"
titre.TextXAlignment = Enum.TextXAlignment.Left
titre.ZIndex = 41
local barreTitre = Instance.new("Frame")
barreTitre.Size = UDim2.new(0, 140, 0, 5)
barreTitre.Position = UDim2.new(0, 20, 0, 62)
barreTitre.BackgroundColor3 = OR
barreTitre.BorderSizePixel = 0
barreTitre.ZIndex = 41
barreTitre.Parent = page
local retour = Instance.new("TextButton")
retour.AnchorPoint = Vector2.new(1, 0)
retour.Size = UDim2.fromOffset(150, 46)
retour.Position = UDim2.new(1, -10, 0, 8)
retour.BackgroundColor3 = Color3.fromRGB(34, 34, 42)
retour.TextColor3 = Color3.new(1, 1, 1)
retour.FontFace = POLICE
retour.TextSize = 20
retour.Text = "← RETOUR"
retour.ZIndex = 42
retour.Parent = page
coins(retour, 6)
retour.Activated:Connect(function()
	page.Visible = false
end)

-- Onglets
local onglets = {}
local ongletActif = "semaine"
for i, def in ipairs({ { "semaine", "SEMAINE · DRIFT BATTLE" }, { "chrono", "CHRONO · MEILLEUR TOUR" } }) do
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.5, -6, 0, 44)
	b.Position = UDim2.new((i - 1) * 0.5, if i == 2 then 6 else 0, 0, 84)
	b.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.FontFace = POLICE
	b.TextScaled = true
	b.Text = def[2]
	b.ZIndex = 42
	b.Parent = page
	coins(b, 6)
	local marge = Instance.new("UIPadding")
	marge.PaddingTop = UDim.new(0, 10)
	marge.PaddingBottom = UDim.new(0, 10)
	marge.Parent = b
	onglets[def[1]] = b
end
local info = texte(page, UDim2.new(1, -40, 0, 22), UDim2.new(0, 20, 0, 138), Color3.fromRGB(255, 220, 120))
info.ZIndex = 41
local liste = Instance.new("Frame")
liste.Size = UDim2.new(1, -40, 1, -230)
liste.Position = UDim2.new(0, 20, 0, 170)
liste.BackgroundTransparency = 1
liste.ZIndex = 41
liste.Parent = page
local dispo = Instance.new("UIListLayout")
dispo.Padding = UDim.new(0, 6)
dispo.SortOrder = Enum.SortOrder.LayoutOrder
dispo.Parent = liste
local monResultat = texte(page, UDim2.new(1, -40, 0, 26), UDim2.new(0, 20, 1, -50), Color3.new(1, 1, 1))
monResultat.ZIndex = 41

local donnees: any = nil
local COULEURS_RANG = { Color3.fromRGB(255, 205, 50), Color3.fromRGB(210, 215, 225), Color3.fromRGB(220, 140, 70) }

local function remplir()
	for _, e in ipairs(liste:GetChildren()) do
		if e:IsA("GuiObject") then
			e:Destroy()
		end
	end
	for nom, b in pairs(onglets) do
		b.BackgroundColor3 = if nom == ongletActif then ROUGE else Color3.fromRGB(34, 34, 40)
	end
	if not donnees then
		info.Text = "Chargement…"
		return
	end
	local bloc = donnees[ongletActif] or {}
	local top = bloc.top or {}
	if ongletActif == "semaine" then
		local reste = bloc.finDans or 0
		local r = bloc.recompenses or {}
		info.Text = ("🏆 1er %s 💰 · 2e %s · 3e %s · 4e à 10e %s  —  fin dans %dj %dh"):format(r[1] or 0, r[2] or 0, r[3] or 0, r[4] or 0, reste // 86400, (reste % 86400) // 3600)
		monResultat.Text = ("Ton meilleur score de la semaine : %d pts"):format(bloc.monScore or 0)
	else
		info.Text = "Les meilleurs tours de tous les joueurs"
		monResultat.Text = if type(bloc.monTour) == "number" then ("Ton meilleur tour : %s"):format(formatTemps(bloc.monTour / 1000)) else "Fais une course CHRONO pour entrer dans le classement !"
	end
	if #top == 0 then
		local vide = texte(liste, UDim2.new(1, 0, 0, 40), UDim2.new(), Color3.fromRGB(190, 190, 200))
		vide.Text = "Personne pour l'instant… sois le premier !"
		vide.ZIndex = 42
		return
	end
	for _, ligne in ipairs(top) do
		local f = Instance.new("Frame")
		f.LayoutOrder = ligne.rang
		f.Size = UDim2.new(1, 0, 0, 40)
		f.BackgroundColor3 = if ligne.id == joueur.UserId then Color3.fromRGB(80, 30, 40) else Color3.fromRGB(26, 26, 32)
		f.ZIndex = 42
		f.Parent = liste
		coins(f, 6)
		local rang = texte(f, UDim2.new(0, 50, 1, -10), UDim2.fromOffset(10, 5), COULEURS_RANG[ligne.rang] or Color3.new(1, 1, 1))
		rang.Text = "#" .. ligne.rang
		rang.ZIndex = 43
		local nom = texte(f, UDim2.new(0.6, 0, 1, -12), UDim2.new(0, 70, 0, 6), Color3.new(1, 1, 1))
		nom.Text = tostring(ligne.nom)
		nom.TextXAlignment = Enum.TextXAlignment.Left
		nom.ZIndex = 43
		local score = texte(f, UDim2.new(0.3, -20, 1, -12), UDim2.new(0.7, 10, 0, 6), OR)
		score.Text = if ongletActif == "chrono" then formatTemps((tonumber(ligne.score) or 0) / 1000) else ("%d pts"):format(tonumber(ligne.score) or 0)
		score.TextXAlignment = Enum.TextXAlignment.Right
		score.ZIndex = 43
	end
end
for nom, b in pairs(onglets) do
	b.Activated:Connect(function()
		ongletActif = nom
		remplir()
	end)
end

local function ouvrirPage()
	-- Une seule page à la fois
	for _, autre in ipairs({ "Magasin", "RoueDuJour", "Apercu", "PageCadeaux" }) do
		local p = menu:FindFirstChild(autre)
		if p and p:IsA("GuiObject") then
			p.Visible = false
		end
	end
	page.Visible = true
	page.Position = UDim2.fromScale(1.5, 0.5)
	TweenService:Create(page, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	remplir()
	task.spawn(function()
		if Classements then
			local ok, r = pcall(function()
				return Classements:InvokeServer()
			end)
			if ok and type(r) == "table" then
				donnees = r
				remplir()
			end
		end
	end)
end
joueur:GetAttributeChangedSignal("OuvrirClassement"):Connect(function()
	if joueur:GetAttribute("OuvrirClassement") then
		joueur:SetAttribute("OuvrirClassement", false)
		ouvrirPage()
	end
end)
menu:GetPropertyChangedSignal("Visible"):Connect(function()
	if not menu.Visible then
		page.Visible = false
	end
end)
