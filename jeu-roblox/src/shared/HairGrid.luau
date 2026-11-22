-- Cheveux « coupables » : des centaines de mèches posées sur le crâne et la mâchoire.
-- Chaque mèche a une longueur (0 = rasé) et une couleur. On coupe à la souris / au doigt.
-- Le même module sert au serveur (modèles, score) et au client (atelier en temps réel).

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)

local HairGrid = {}

---------------------------------------------------------------------
-- Disposition des mèches (identique partout : générée de façon déterministe)
---------------------------------------------------------------------
-- Repère de la tête : +Y haut, -Z devant (visage), +X droite.
-- Ces rayons (en fraction de Head.Size.Y) se règlent si les mèches flottent ou rentrent dans la tête.
HairGrid.Scalp = { X = 0.5, Y = 0.5, Z = 0.52, YOffset = 0.06 }
HairGrid.MaxLength = 2.0 -- longueur max d'une mèche (en fraction de taille de tête)
HairGrid.Shaved = 0.03 -- en dessous : mèche invisible (peau)

export type Tuft = { Dir: Vector3, Beard: boolean, Index: number }

local tufts: { Tuft } = {}

local function addTuft(dir: Vector3, beard: boolean)
	table.insert(tufts, { Dir = dir.Unit, Beard = beard, Index = #tufts + 1 })
end

do
	-- Cuir chevelu : anneaux du sommet (phi = 0) jusque sous les oreilles / la nuque
	local step = math.rad(10)
	for ring = 0, 13 do
		local phi = ring * step
		local count = ring == 0 and 1 or math.max(6, math.floor(2 * math.pi * math.sin(phi) / 0.18))
		for i = 0, count - 1 do
			local theta = (i + (ring % 2) * 0.5) / count * math.pi * 2
			local dir = Vector3.new(math.sin(phi) * math.sin(theta), math.cos(phi), math.sin(phi) * math.cos(theta))
			-- pas de mèches sur le visage, ni sous les oreilles devant
			local face = dir.Z < -0.42 and dir.Y < 0.42
			local belowEarsFront = dir.Y < -0.05 and dir.Z < 0.2
			if not face and not belowEarsFront then
				addTuft(dir, false)
			end
		end
	end
	HairGrid.ScalpCount = #tufts
	-- Barbe : bas du visage (joues, menton, moustache)
	for row = 0, 5 do
		local y = 0.02 - row * 0.11
		for col = -7, 7 do
			local a = math.rad(col * 13)
			local dir = Vector3.new(math.sin(a), y, -math.cos(a) * 0.95)
			local mouth = math.abs(dir.X) < 0.2 and y < -0.12 and y > -0.24
			local upperCheek = y > -0.05 and math.abs(col) < 4
			if not mouth and not upperCheek then
				addTuft(dir, true)
			end
		end
	end
	HairGrid.Count = #tufts
end

HairGrid.Tufts = tufts

---------------------------------------------------------------------
-- Encodage compact (64 niveaux par mèche, caractères sûrs pour DataStore / réseau)
---------------------------------------------------------------------
local ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_"
local DECODE = {}
for i = 1, 64 do
	DECODE[string.byte(ALPHABET, i)] = i - 1
end

-- Échelle en racine carrée : très précise pour les cheveux courts (dégradés)
local function q(length: number): number
	return math.clamp(math.floor(math.sqrt(math.max(length, 0) / HairGrid.MaxLength) * 63 + 0.5), 0, 63)
end

export type Cut = { L: { number }, C: { number }, T: string } -- longueurs, couleurs (index Config.Colors), texture

function HairGrid.Encode(cut: Cut): { L: string, C: string, T: string }
	local l, c = table.create(#tufts), table.create(#tufts)
	for i = 1, #tufts do
		local li = q(cut.L[i] or 0) + 1
		local ci = math.clamp(cut.C[i] or 1, 1, 64)
		l[i] = string.sub(ALPHABET, li, li)
		c[i] = string.sub(ALPHABET, ci, ci)
	end
	return { L = table.concat(l), C = table.concat(c), T = cut.T }
end

function HairGrid.Decode(data: any): Cut?
	if typeof(data) ~= "table" or typeof(data.L) ~= "string" or typeof(data.C) ~= "string" then
		return nil
	end
	if #data.L ~= #tufts or #data.C ~= #tufts then
		return nil
	end
	local cut = { L = table.create(#tufts), C = table.create(#tufts), T = Config.TextureById[data.T] and data.T or "lisse" }
	for i = 1, #tufts do
		local l = DECODE[string.byte(data.L, i)]
		local c = DECODE[string.byte(data.C, i)]
		if l == nil or c == nil then
			return nil
		end
		cut.L[i] = (l / 63) ^ 2 * HairGrid.MaxLength
		cut.C[i] = math.clamp(c + 1, 1, #Config.Colors) -- encodé en (index - 1)
	end
	return cut
end

function HairGrid.Clone(cut: Cut): Cut
	return { L = table.clone(cut.L), C = table.clone(cut.C), T = cut.T }
end

---------------------------------------------------------------------
-- Coupe cible (calculée à partir de la demande du client)
---------------------------------------------------------------------
local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

-- Longueur demandée pour une mèche du cuir chevelu
local function scalpTarget(style, look, dir: Vector3): number
	local mult = Config.Lengths[look.length].Mult
	local y = dir.Y
	local front = dir.Z < -0.3 and y > 0.2
	local side = math.abs(dir.X)
	local top, frontL, sideL, back = style.Top * mult, style.Front * mult, style.Side * mult, style.Back * mult
	local len
	if style.Mohawk then
		len = side < 0.22 and top or HairGrid.Shaved
	elseif front then
		len = frontL
	elseif y > 0.55 then
		len = top
	else
		-- côtés / arrière selon l'orientation
		local backness = math.clamp((dir.Z + 0.3) / 1.0, 0, 1)
		local low = lerp(sideL, back, backness)
		len = lerp(low, top, (y - 0.05) / 0.5)
	end
	-- Dégradé
	local fade = Config.FadeById[look.fade]
	if style.Fade and fade and fade.Id ~= "aucun" and not front then
		local from, to, bottom = fade.From, fade.To, fade.Bottom
		local t = math.clamp((from - y) / (from - to), 0, 1) -- 0 au début du dégradé, 1 en bas
		if fade.Burst then
			t *= math.clamp(side * 1.4, 0, 1) -- seulement autour de l'oreille
		end
		len = lerp(len, bottom, t)
	end
	return math.clamp(len, 0, HairGrid.MaxLength)
end

local function beardTarget(beardId: string, dir: Vector3): number
	local y, x = dir.Y, math.abs(dir.X)
	if beardId == "aucune" then
		return 0
	elseif beardId == "trois" then
		return 0.06
	elseif beardId == "bouc" then
		local chin = x < 0.3 and y < -0.2
		local stache = x < 0.3 and y > -0.15 and y < -0.02
		return (chin or stache) and 0.18 or 0
	elseif beardId == "collier" then
		local jaw = y < -0.32 or x > 0.75
		return jaw and 0.12 or 0
	elseif beardId == "pleine" then
		return 0.26
	end
	return 0
end

function HairGrid.Target(look: any): Cut
	local style = Config.StyleById[look.style] or Config.Styles[1]
	local color = Config.ColorById[look.color] or Config.Colors[1]
	local cut = { L = table.create(#tufts), C = table.create(#tufts), T = style.Texture or "lisse" }
	for i, tuft in tufts do
		cut.L[i] = tuft.Beard and beardTarget(look.beard or "aucune", tuft.Dir) or scalpTarget(style, look, tuft.Dir)
		cut.C[i] = color.Order
	end
	return cut
end

-- Cheveux « trop longs » à l'arrivée : la cible + de la repousse irrégulière.
function HairGrid.Overgrown(look: any, naturalColor: string, rng: Random): Cut
	local target = HairGrid.Target(look)
	local colorIndex = (Config.ColorById[naturalColor] or Config.Colors[2]).Order
	local beardGrowth = (look.beard and look.beard ~= "aucune") and 0.18 or (rng:NextNumber() < 0.5 and 0.2 or 0)
	local isMan = look.gender == "H"
	for i, tuft in tufts do
		if tuft.Beard then
			target.L[i] = isMan and math.min(target.L[i] + beardGrowth + rng:NextNumber(0, 0.08), 0.45) or 0
		else
			target.L[i] = math.min(HairGrid.MaxLength, target.L[i] + rng:NextNumber(0.25, 0.5))
		end
		target.C[i] = colorIndex
	end
	return target
end

---------------------------------------------------------------------
-- Score : ressemblance mèche par mèche (0..1)
---------------------------------------------------------------------
function HairGrid.Score(cut: Cut, target: Cut): number
	local lengthScore, n = 0, 0
	local colorHits, colorN = 0, 0
	for i = 1, #tufts do
		local t, c = target.L[i], cut.L[i]
		local tolerance = 0.06 + 0.15 * t
		-- parfait si l'écart est sous la demi-tolérance, puis baisse jusqu'à 2x la tolérance
		local s = math.clamp(1 - math.max(0, math.abs(c - t) - tolerance * 0.5) / (tolerance * 1.5), 0, 1)
		-- les zones de peau visibles comptent autant que les cheveux
		lengthScore += s
		n += 1
		if t > HairGrid.Shaved and not tufts[i].Beard then
			colorN += 1
			if cut.C[i] == target.C[i] then
				colorHits += 1
			end
		end
	end
	local lengths = n > 0 and lengthScore / n or 0
	local colors = colorN > 0 and colorHits / colorN or 1
	local texture = cut.T == target.T and 1 or 0
	return math.clamp(lengths * 0.8 + colors * 0.15 + texture * 0.05, 0, 1)
end

---------------------------------------------------------------------
-- Rendu
---------------------------------------------------------------------
local function tuftCFrame(head: BasePart, tuft: Tuft, len: number, texture: string): (CFrame, Vector3, Enum.PartType?)
	local s = head.Size.Y
	local sc = HairGrid.Scalp
	local d = tuft.Dir
	local base = Vector3.new(d.X * sc.X, d.Y * sc.Y + sc.YOffset, d.Z * sc.Z) * s
	if tuft.Beard then
		base = Vector3.new(d.X * 0.47, d.Y * 0.55 - 0.05, d.Z * 0.5) * s
	end
	local L = len * s * 0.5
	local width = (tuft.Beard and 0.11 or 0.15) * s
	local dir = d
	if texture == "boucle" then
		-- boucles / afro : boules qui gonflent avec la longueur
		local size = math.max(width, L * 0.9)
		return head.CFrame * CFrame.new(base + dir * (L * 0.5)), Vector3.new(size, size, size), Enum.PartType.Ball
	end
	if not tuft.Beard and L > 0.25 * s and texture ~= "twists" then
		-- les cheveux longs retombent vers le bas
		local droop = math.clamp((L / s - 0.25) * 1.6, 0, 1.4)
		dir = (d + Vector3.new(0, -droop, 0) + (d.Y > 0.6 and Vector3.new(0, 0, droop * 0.4) or Vector3.zero)).Unit
	end
	local thick = texture == "locs" and width * 1.1 or width
	local center = base + dir * (L * 0.5)
	local cf = CFrame.lookAt(center, center + dir)
	return head.CFrame * cf, Vector3.new(thick * (texture == "lisse" and 1.3 or 1), thick, math.max(L, 0.02)), nil
end

local function styleTuft(part: BasePart, len: number, colorIndex: number)
	local colorDef = Config.Colors[colorIndex] or Config.Colors[2]
	part.Color = colorDef.Color
	part.Material = colorDef.Material or Enum.Material.SmoothPlastic
	if len < HairGrid.Shaved then
		part.Transparency = 1
	elseif len < 0.09 then
		part.Transparency = 0.45 -- poils très courts : on devine la peau (effet dégradé)
	else
		part.Transparency = 0
	end
	if colorDef.Rainbow then
		CollectionService:AddTag(part, "RainbowHair")
	else
		CollectionService:RemoveTag(part, "RainbowHair")
	end
end

function HairGrid.UpdateTuft(model: Model, head: BasePart, cut: Cut, i: number)
	local part = model:FindFirstChild(tostring(i)) :: BasePart?
	if not part then
		return
	end
	local cf, size, shape = tuftCFrame(head, tufts[i], cut.L[i], cut.T)
	if shape and part.Shape ~= shape then
		part.Shape = shape
	elseif not shape and part.Shape ~= Enum.PartType.Block then
		part.Shape = Enum.PartType.Block
	end
	part.Size = size
	local weld = part:FindFirstChildOfClass("WeldConstraint")
	if weld then
		weld.Enabled = false
	end
	part.CFrame = cf
	if weld then
		weld.Enabled = true
	end
	styleTuft(part, cut.L[i], cut.C[i])
end

-- Construit un modèle de mèches sur une tête, sans toucher au reste du personnage.
function HairGrid.Build(head: BasePart, cut: Cut, name: string, parent: Instance, anchored: boolean?): Model
	local model = Instance.new("Model")
	model.Name = name
	for i, tuft in tufts do
		local p = Instance.new("Part")
		p.Name = tostring(i)
		p.CanCollide = false
		p.CanQuery = true -- l'atelier vise les mèches au rayon
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.Anchored = anchored == true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local cf, size, shape = tuftCFrame(head, tuft, cut.L[i], cut.T)
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = cf
		styleTuft(p, cut.L[i], cut.C[i])
		if not anchored then
			local w = Instance.new("WeldConstraint")
			w.Part0 = head
			w.Part1 = p
			w.Parent = p
		end
		p.Parent = model
	end
	model:SetAttribute("Texture", cut.T)
	model.Parent = parent
	return model
end

-- Remplace la coiffure d'un personnage par cette coupe (retire les cheveux Roblox).
function HairGrid.Apply(character: Model, cut: Cut, anchored: boolean?): Model?
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	for _, name in { "CustomHair", "CutHair" } do
		local old = character:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	for _, acc in character:GetChildren() do
		if acc:IsA("Accessory") then
			local ok, t = pcall(function()
				return acc.AccessoryType
			end)
			if (ok and t == Enum.AccessoryType.Hair) or acc.Name:lower():find("hair") then
				acc:Destroy()
			end
		end
	end
	return HairGrid.Build(head, cut, "CutHair", character, anchored)
end

-- Met à jour toutes les mèches (après annuler / pousser / texture)
function HairGrid.UpdateAll(model: Model, head: BasePart, cut: Cut)
	for i = 1, #tufts do
		HairGrid.UpdateTuft(model, head, cut, i)
	end
end

-- Index des mèches touchées par un pinceau (position en espace monde).
function HairGrid.TuftsNear(head: BasePart, worldPos: Vector3, radius: number): { number }
	local localPos = head.CFrame:PointToObjectSpace(worldPos)
	local dir = localPos.Magnitude > 0 and localPos.Unit or Vector3.yAxis
	local cosR = math.cos(radius)
	local list = {}
	for i, tuft in tufts do
		if tuft.Dir:Dot(dir) >= cosR then
			table.insert(list, i)
		end
	end
	return list
end

return HairGrid
