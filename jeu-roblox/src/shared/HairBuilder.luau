-- Construit une coiffure 3D (en pièces) sur la tête d'un personnage.
-- Utilisé par le serveur (clients PNJ, joueurs) et par le client (aperçus).

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)

local HairBuilder = {}

local DEFAULT_LOOK = { style = "lisse", length = 2, color = "brun", acc = "aucun" }

local function darken(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

type Ctx = {
	model: Model,
	head: BasePart,
	s: number, -- échelle de la tête
	color: Color3,
	material: Enum.Material,
	rainbow: boolean,
}

local function addPart(ctx: Ctx, kind: string, size: Vector3, offset: CFrame, color: Color3?, material: Enum.Material?, noRainbow: boolean?): BasePart
	local s = ctx.s
	local p = Instance.new("Part")
	p.Name = "Hair"
	p.Size = size * s
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Anchored = false
	p.Color = color or ctx.color
	p.Material = material or ctx.material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if kind == "ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif kind == "ball" then
		p.Shape = Enum.PartType.Ball
	elseif kind == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif kind == "wedge" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = p
	end
	local pos = offset.Position * s
	p.CFrame = ctx.head.CFrame * (CFrame.new(pos) * offset.Rotation)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ctx.head
	weld.Part1 = p
	weld.Parent = p
	p.Parent = ctx.model
	if ctx.rainbow and not noRainbow and color == nil then
		CollectionService:AddTag(p, "RainbowHair")
	end
	return p
end

local function E(ctx, size, x, y, z, rx, ry, rz)
	return addPart(ctx, "ellipsoid", size, CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0)))
end

local function B(ctx, d, x, y, z)
	return addPart(ctx, "ball", Vector3.new(d, d, d), CFrame.new(x, y, z))
end

-- Le dessus du crâne (présent dans presque toutes les coupes)
local function cap(ctx, tight: boolean?)
	if tight then
		E(ctx, Vector3.new(1.27, 0.72, 1.3), 0, 0.3, 0.06)
	else
		E(ctx, Vector3.new(1.34, 0.8, 1.38), 0, 0.32, 0.07)
	end
end

local function fringe(ctx, length: number)
	E(ctx, Vector3.new(1.12, 0.32 + 0.06 * length, 0.42), 0, 0.42, -0.5, -18, 0, 0)
end

local Styles = {}

function Styles.pixie(ctx, length)
	cap(ctx, true)
	E(ctx, Vector3.new(1.05, 0.28, 0.45), 0.12, 0.45, -0.48, -15, 0, -8)
	if length >= 2 then
		E(ctx, Vector3.new(1.2, 0.5, 0.5), 0, 0.05, 0.5)
	end
	if length >= 3 then
		E(ctx, Vector3.new(0.3, 0.6, 0.6), 0.6, 0.0, 0.0)
		E(ctx, Vector3.new(0.3, 0.6, 0.6), -0.6, 0.0, 0.0)
	end
end

function Styles.lisse(ctx, length)
	cap(ctx)
	fringe(ctx, length)
	local L = ({ 0.9, 1.7, 2.6 })[length]
	E(ctx, Vector3.new(1.32, L, 0.55), 0, 0.42 - L / 2, 0.42)
	E(ctx, Vector3.new(0.34, L * 0.92, 0.95), 0.6, 0.4 - L / 2 * 0.92, 0.08)
	E(ctx, Vector3.new(0.34, L * 0.92, 0.95), -0.6, 0.4 - L / 2 * 0.92, 0.08)
end

function Styles.queue(ctx, length)
	cap(ctx, true)
	fringe(ctx, 1)
	B(ctx, 0.38, 0, 0.3, 0.68)
	local n = ({ 2, 4, 6 })[length]
	for i = 1, n do
		local t = i / n
		local w = 0.62 - 0.25 * t
		E(ctx, Vector3.new(w, 0.62, w * 0.9), 0, 0.22 - i * 0.4, 0.82 + 0.06 * math.sin(i))
	end
end

function Styles.boucle(ctx, length)
	cap(ctx)
	local rows = length
	for row = 0, rows do
		local count = 10
		local r = 0.64 + row * 0.03
		for i = 0, count - 1 do
			local a = (i / count) * math.pi * 2
			local x, z = math.sin(a) * r, math.cos(a) * r
			if z > -0.35 or row == 0 then -- ne pas cacher le visage
				B(ctx, 0.46, x, 0.42 - row * 0.4, z + 0.05)
			end
		end
	end
	for i = 0, 5 do
		local a = (i / 6) * math.pi * 2
		B(ctx, 0.45, math.sin(a) * 0.32, 0.72, math.cos(a) * 0.32 + 0.05)
	end
end

function Styles.chignon(ctx, length)
	cap(ctx, true)
	fringe(ctx, 1)
	local d = 0.6 + 0.12 * length
	B(ctx, d, 0, 0.72 + 0.05 * length, 0.42)
	addPart(ctx, "cylinder", Vector3.new(0.14, d * 0.85, d * 0.85), CFrame.new(0, 0.6, 0.4) * CFrame.Angles(0, 0, math.rad(90)), darken(ctx.color, 0.7))
	if length == 3 then
		E(ctx, Vector3.new(0.22, 0.9, 0.22), 0.55, -0.1, -0.15, 0, 0, 8)
		E(ctx, Vector3.new(0.22, 0.9, 0.22), -0.55, -0.1, -0.15, 0, 0, -8)
	end
end

function Styles.couettes(ctx, length)
	cap(ctx)
	fringe(ctx, 1)
	local n = ({ 2, 3, 5 })[length]
	for _, side in { 1, -1 } do
		B(ctx, 0.3, side * 0.68, 0.32, 0.12)
		for i = 1, n do
			local d = 0.5 - i * 0.03
			B(ctx, d, side * (0.78 + i * 0.07), 0.3 - i * 0.36, 0.18)
		end
	end
end

function Styles.tresses(ctx, length)
	cap(ctx)
	fringe(ctx, 1)
	local n = ({ 3, 5, 8 })[length]
	for _, side in { 1, -1 } do
		for i = 1, n do
			local wiggle = (i % 2 == 0) and 0.06 or -0.06
			B(ctx, 0.34, side * 0.48 + wiggle, 0.15 - i * 0.26, 0.48 + i * 0.02)
		end
		B(ctx, 0.2, side * 0.48, 0.15 - (n + 1) * 0.26, 0.5 + n * 0.02)
	end
end

function Styles.afro(ctx, length)
	local d = 1.75 + 0.3 * length
	E(ctx, Vector3.new(d, d * 0.9, d), 0, 0.45, 0.18)
	for i = 0, 13 do
		local a = (i / 14) * math.pi * 2
		local b = (i % 2 == 0) and 0.2 or 0.55
		B(ctx, 0.55, math.sin(a) * d * 0.45, 0.45 + b * d * 0.35, math.cos(a) * d * 0.45 + 0.18)
	end
end

function Styles.crete(ctx, length)
	E(ctx, Vector3.new(1.25, 0.66, 1.28), 0, 0.28, 0.06):SetAttribute("Shaved", true)
	local h = 0.45 + 0.28 * length
	for i = 0, 5 do
		local z = -0.5 + i * 0.22
		addPart(ctx, "wedge", Vector3.new(0.22, h * (1 - math.abs(i - 2.5) * 0.08), 0.42), CFrame.new(0, 0.6 + h / 2, z) * CFrame.Angles(math.rad(-20), 0, 0))
	end
end

function Styles.sirene(ctx, length)
	cap(ctx)
	fringe(ctx, length)
	local n = ({ 4, 6, 9 })[length]
	for col = -1, 1 do
		for i = 1, n do
			local wave = math.sin(i * 1.1 + col) * 0.12
			B(ctx, 0.5, col * 0.42 + wave, 0.35 - i * 0.32, 0.5 + math.abs(col) * -0.08)
		end
	end
	for _, side in { 1, -1 } do
		for i = 1, math.max(2, n - 3) do
			B(ctx, 0.38, side * (0.62 + math.sin(i) * 0.06), 0.2 - i * 0.3, -0.05)
		end
	end
end

function Styles.royal(ctx, length)
	cap(ctx)
	fringe(ctx, 1)
	E(ctx, Vector3.new(1.05, 0.7, 1.05), 0, 0.85, 0.15)
	E(ctx, Vector3.new(0.8, 0.6, 0.8), 0, 1.25, 0.15)
	E(ctx, Vector3.new(0.5, 0.45, 0.5), 0, 1.55, 0.15)
	local L = ({ 0.8, 1.5, 2.3 })[length]
	E(ctx, Vector3.new(1.2, L, 0.5), 0, 0.35 - L / 2, 0.45)
	local glow = addPart(ctx, "ball", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 1.8, 0.15), Color3.fromRGB(255, 240, 180), Enum.Material.Neon)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(0.6, 1.2)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new(0.25, 0)
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150))
	sparkle.Parent = glow
end

local Accessories = {}

function Accessories.noeud(ctx)
	local c = Color3.fromRGB(255, 70, 120)
	addPart(ctx, "ellipsoid", Vector3.new(0.18, 0.36, 0.48), CFrame.new(0.5, 0.72, -0.05) * CFrame.Angles(0, 0, math.rad(35)) * CFrame.new(0, 0, 0.22), c, Enum.Material.SmoothPlastic)
	addPart(ctx, "ellipsoid", Vector3.new(0.18, 0.36, 0.48), CFrame.new(0.5, 0.72, -0.05) * CFrame.Angles(0, 0, math.rad(35)) * CFrame.new(0, 0, -0.22), c, Enum.Material.SmoothPlastic)
	addPart(ctx, "ball", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0.5, 0.72, -0.05), darken(c, 0.8), Enum.Material.SmoothPlastic)
end

function Accessories.barrette(ctx)
	addPart(ctx, "block", Vector3.new(0.12, 0.1, 0.55), CFrame.new(0.62, 0.45, -0.25) * CFrame.Angles(math.rad(20), 0, math.rad(-20)), Color3.fromRGB(120, 230, 255), Enum.Material.Neon)
end

function Accessories.fleur(ctx)
	local center = CFrame.new(-0.62, 0.5, -0.12) * CFrame.Angles(0, math.rad(90), 0)
	for i = 0, 4 do
		local a = math.rad(i * 72)
		addPart(ctx, "ellipsoid", Vector3.new(0.22, 0.32, 0.1), center * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.16, 0), Color3.fromRGB(255, 190, 220), Enum.Material.SmoothPlastic)
	end
	addPart(ctx, "ball", Vector3.new(0.14, 0.14, 0.14), center * CFrame.new(0, 0, -0.04), Color3.fromRGB(255, 220, 80), Enum.Material.Neon)
end

function Accessories.couronne(ctx)
	local gold = Color3.fromRGB(255, 200, 60)
	local y = 0.78
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		local cf = CFrame.new(math.sin(a) * 0.42, y, math.cos(a) * 0.42 + 0.05) * CFrame.Angles(0, a, 0)
		addPart(ctx, "block", Vector3.new(0.2, 0.18, 0.06), cf, gold, Enum.Material.Foil)
		addPart(ctx, "wedge", Vector3.new(0.06, 0.2, 0.12), cf * CFrame.new(0, 0.18, 0), gold, Enum.Material.Foil)
	end
	addPart(ctx, "ball", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0, y + 0.05, -0.4), Color3.fromRGB(255, 40, 90), Enum.Material.Neon)
end

function HairBuilder.Normalize(look: any): Config.Look
	look = typeof(look) == "table" and look or {}
	return {
		style = Config.StyleById[look.style] and look.style or DEFAULT_LOOK.style,
		length = (look.length == 1 or look.length == 2 or look.length == 3) and look.length or DEFAULT_LOOK.length,
		color = Config.ColorById[look.color] and look.color or DEFAULT_LOOK.color,
		acc = Config.AccById[look.acc] and look.acc or DEFAULT_LOOK.acc,
	}
end

-- Retire les cheveux Roblox (accessoires) et l'ancienne coiffure custom.
function HairBuilder.Clear(character: Model)
	local old = character:FindFirstChild("CustomHair")
	if old then
		old:Destroy()
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
end

function HairBuilder.Apply(character: Model, look: any): Model?
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	look = HairBuilder.Normalize(look)
	HairBuilder.Clear(character)

	local colorDef = Config.ColorById[look.color]
	local model = Instance.new("Model")
	model.Name = "CustomHair"
	local ctx: Ctx = {
		model = model,
		head = head,
		s = head.Size.Y,
		color = colorDef.Color,
		material = colorDef.Material or Enum.Material.SmoothPlastic,
		rainbow = colorDef.Rainbow == true,
	}
	local builder = Styles[look.style] or Styles.lisse
	builder(ctx, look.length)
	-- Crâne rasé de la crête : couleur plus sombre
	for _, p in model:GetChildren() do
		if p:GetAttribute("Shaved") then
			p.Color = darken(ctx.color, 0.55)
			p.Material = Enum.Material.SmoothPlastic
			CollectionService:RemoveTag(p, "RainbowHair")
		end
	end
	local acc = Accessories[look.acc]
	if acc then
		acc(ctx)
	end
	if colorDef.Tier == "neon" and colorDef.Material == Enum.Material.Neon then
		local light = Instance.new("PointLight")
		light.Color = colorDef.Color
		light.Range = 6
		light.Brightness = 0.8
		light.Parent = model:FindFirstChildWhichIsA("BasePart")
	end
	model:SetAttribute("Style", look.style)
	model:SetAttribute("Length", look.length)
	model:SetAttribute("Color", look.color)
	model:SetAttribute("Acc", look.acc)
	model.Parent = character
	return model
end

-- Score (0..1) entre une demande et une coiffure réalisée
function HairBuilder.Score(request: Config.Look, look: Config.Look): number
	local points = 0 -- sur 100 (entiers : pas d'erreur d'arrondi)
	if request.style == look.style then
		points += 40
	end
	if request.length == look.length then
		points += 20
	end
	if request.color == look.color then
		points += 30
	end
	if request.acc == look.acc then
		points += 10
	end
	return points / 100
end

function HairBuilder.Describe(look: Config.Look): string
	local style = Config.StyleById[look.style]
	local length = Config.Lengths[look.length]
	local color = Config.ColorById[look.color]
	local acc = Config.AccById[look.acc]
	local parts = { style.Icon .. " " .. style.Name, length.Name, "🎨 " .. color.Name }
	if look.acc ~= "aucun" then
		table.insert(parts, acc.Icon .. " " .. acc.Name)
	end
	return table.concat(parts, " • ")
end

return HairBuilder
