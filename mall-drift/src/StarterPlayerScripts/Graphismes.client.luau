--[[
	Graphismes  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : Graphismes

	Adapte les graphismes à l'appareil, pour que le jeu reste FLUIDE partout
	(la majorité des joueurs Roblox sont sur téléphone : un jeu qui rame, ils partent) :
	  • PC / console / graphismes élevés : rendu complet (ombres, profondeur de champ,
	    rayons du soleil, flou de vitesse)
	  • Téléphone / graphismes bas : mode LÉGER (pas d'ombres des lampes, pas de flou,
	    moins de particules) — l'image reste belle, mais tourne bien mieux
	Ça se réajuste tout seul si le joueur change ses réglages graphiques Roblox.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local joueur = Players.LocalPlayer
local reglagesRoblox = UserSettings():GetService("UserGameSettings")

local function modeLeger(): boolean
	local telephone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local niveau = reglagesRoblox.SavedQualityLevel.Value -- 0 = automatique, 1 à 10 sinon
	if niveau == 0 then
		return telephone
	end
	return niveau <= 4
end

local debitsParticules: { [ParticleEmitter]: number } = {}

local function appliquer()
	local leger = modeLeger()
	joueur:SetAttribute("GraphismesLegers", leger)
	for _, nom in ipairs({ "ProfondeurMallDrift", "RayonsMallDrift" }) do
		local e = Lighting:FindFirstChild(nom)
		if e and e:IsA("PostEffect") then
			e.Enabled = not leger
		end
	end
	local halo = Lighting:FindFirstChild("HaloMallDrift")
	if halo and halo:IsA("BloomEffect") then
		halo.Size = if leger then 14 else 28
	end
	local carte = workspace:FindFirstChild("GoldenMall")
	if not carte then
		return
	end
	for _, d in ipairs(carte:GetDescendants()) do
		if d:IsA("SpotLight") or d:IsA("PointLight") then
			if leger then
				d.Shadows = false
			end
		elseif d:IsA("SurfaceLight") then
			d.Enabled = not leger -- (les halos colorés des enseignes)
		elseif d:IsA("ParticleEmitter") then
			if not debitsParticules[d] then
				debitsParticules[d] = d.Rate
			end
			d.Rate = if leger then debitsParticules[d] * 0.5 else debitsParticules[d]
		end
	end
end

task.spawn(function()
	workspace:WaitForChild("GoldenMall", 30)
	task.wait(2) -- (le temps que la carte soit construite)
	appliquer()
end)
reglagesRoblox:GetPropertyChangedSignal("SavedQualityLevel"):Connect(appliquer)

---------------------------------------------------------------------
-- ✨ ENSEIGNES NÉON ANIMÉES (chez chaque joueur : fluide, sans charger le serveur)
--   1 enseigne sur 3 « respire », 1 sur 3 change doucement de couleur,
--   quelques-unes grésillent comme un vieux néon, et les vitrines lumineuses pulsent
---------------------------------------------------------------------
task.spawn(function()
	local carte = workspace:WaitForChild("GoldenMall", 30)
	if not carte then
		return
	end
	task.wait(3) -- (le temps que la carte soit construite)
	local enseignes: { { texte: TextLabel, mode: number, phase: number, couleur: Color3 } } = {}
	local fonds: { { part: BasePart, phase: number, base: number } } = {}
	local ballons: { { part: BasePart, phase: number, cf: CFrame } } = {}
	local hasard = Random.new(7)
	for _, d in ipairs(carte:GetDescendants()) do
		if d:IsA("TextLabel") and d.Parent and d.Parent:IsA("SurfaceGui") then
			local support = d.Parent.Parent
			if support and support:IsA("BasePart") and (support.Name == "Enseigne" or support.Name == "EnseigneExterieure") then
				local tirage = hasard:NextInteger(1, 10)
				local mode = if tirage <= 4 then 1 elseif tirage <= 8 then 2 else 3 -- 1 respire, 2 couleur, 3 grésille
				table.insert(enseignes, { texte = d, mode = mode, phase = hasard:NextNumber(0, 6), couleur = d.TextColor3 })
			end
		elseif d:IsA("BasePart") and d.Name == "FondLumineux" then
			table.insert(fonds, { part = d, phase = hasard:NextNumber(0, 6), base = d.Transparency })
		elseif d:IsA("BasePart") and d.Name == "Ballon" then
			table.insert(ballons, { part = d, phase = hasard:NextNumber(0, 6), cf = d.CFrame })
		end
	end
	while true do
		local leger = joueur:GetAttribute("GraphismesLegers") == true
		local t = os.clock()
		for _, e in ipairs(enseignes) do
			if e.mode == 1 then
				e.texte.TextTransparency = 0.25 * (0.5 + 0.5 * math.sin(t * 2 + e.phase))
			elseif e.mode == 2 then
				local h, sat, v = e.couleur:ToHSV()
				e.texte.TextColor3 = Color3.fromHSV((h + 0.08 * math.sin(t * 0.6 + e.phase)) % 1, math.max(sat, 0.5), math.max(v, 0.9))
			else
				-- Vieux néon qui grésille : il s'éteint brièvement de temps en temps
				local coupure = math.sin(t * 13 + e.phase) > 0.93 or math.sin(t * 7.3 + e.phase * 2) > 0.97
				e.texte.TextTransparency = if coupure then 0.85 else 0
			end
		end
		for _, f in ipairs(fonds) do
			f.part.Transparency = math.clamp(f.base + 0.15 * math.sin(t * 1.5 + f.phase), 0, 0.9)
		end
		-- Les ballons flottent et se balancent doucement
		for _, b in ipairs(ballons) do
			b.part.CFrame = b.cf * CFrame.new(0, 0.35 * math.sin(t * 1.3 + b.phase), 0) * CFrame.Angles(0.06 * math.sin(t * 0.9 + b.phase), 0, 0.06 * math.cos(t * 1.1 + b.phase))
		end
		task.wait(if leger then 0.15 else 0.05) -- (moins souvent sur téléphone)
	end
end)
