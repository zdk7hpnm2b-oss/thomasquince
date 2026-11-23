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
