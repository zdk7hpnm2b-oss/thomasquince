-- Génère la carte : terrain, éclairage cinématique, boulevard, fontaine, arbres.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local World = {}

World.SalonWidth = 56
World.SalonDepth = 50
World.SalonCount = 8

local rng = Random.new(42)

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = Workspace

function World.Part(props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	if props.Shape then
		(p :: any).Shape = props.Shape
	end
	if props.Size then
		p.Size = props.Size
	end
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" and k ~= "Shape" and k ~= "Size" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent or map
	return p
end
local P = World.Part

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

---------------------------------------------------------------------
-- Éclairage
---------------------------------------------------------------------
local function setupLighting()
	for _, c in Lighting:GetChildren() do
		if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
			c:Destroy()
		end
	end
	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.32
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(214, 190, 230)
	atmo.Decay = Color3.fromRGB(120, 92, 150)
	atmo.Glare = 0.35
	atmo.Haze = 1.4
	atmo.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 4000
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 28
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.07
	rays.Spread = 0.65
	rays.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.18
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.TintColor = Color3.fromRGB(255, 246, 250)
	cc.Parent = Lighting

	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.12
	dof.FocusDistance = 50
	dof.InFocusRadius = 90
	dof.NearIntensity = 0
	dof.Parent = Lighting

	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.45
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 240, 250)
	clouds.Parent = Workspace.Terrain
end

---------------------------------------------------------------------
-- Terrain
---------------------------------------------------------------------
local function setupTerrain()
	local t = Workspace.Terrain
	t.WaterColor = Color3.fromRGB(60, 170, 200)
	t.WaterReflectance = 0.6
	t.WaterTransparency = 0.6
	t.WaterWaveSize = 0.12
	t.WaterWaveSpeed = 8
	pcall(function()
		t:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(110, 170, 80))
		t:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(95, 160, 75))
	end)

	t:FillBlock(CFrame.new(0, -8, 0), Vector3.new(900, 16, 900), Enum.Material.Grass)
	-- Collines tout autour
	for i = 1, 46 do
		local a = (i / 46) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local r = rng:NextNumber(330, 400)
		local size = rng:NextNumber(45, 95)
		t:FillBall(Vector3.new(math.cos(a) * r, -size * 0.35, math.sin(a) * r), size, i % 3 == 0 and Enum.Material.Rock or Enum.Material.LeafyGrass)
	end
	-- Lac derrière les salons nord
	t:FillBlock(CFrame.new(0, -4, 175), Vector3.new(160, 8, 70), Enum.Material.Air)
	t:FillBlock(CFrame.new(0, -5, 175), Vector3.new(160, 6, 70), Enum.Material.Water)
	t:FillBlock(CFrame.new(0, -9, 175), Vector3.new(170, 2, 80), Enum.Material.Sand)
end

---------------------------------------------------------------------
-- Décor
---------------------------------------------------------------------
local BLOSSOM = {
	Color3.fromRGB(255, 183, 213),
	Color3.fromRGB(255, 205, 225),
	Color3.fromRGB(245, 160, 200),
}
local GREEN = {
	Color3.fromRGB(96, 168, 82),
	Color3.fromRGB(78, 150, 70),
	Color3.fromRGB(120, 185, 90),
}

function World.Tree(pos: Vector3, blossom: boolean?, parent: Instance?)
	local model = Instance.new("Model")
	model.Name = "Tree"
	local h = rng:NextNumber(9, 14)
	P({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, 1.6, 1.6),
		CFrame = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(105, 72, 52),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local palette = blossom and BLOSSOM or GREEN
	for i = 1, 4 do
		local d = rng:NextNumber(6, 9)
		P({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(d, d, d),
			Position = pos + Vector3.new(rng:NextNumber(-2.5, 2.5), h + rng:NextNumber(-1, 2.5), rng:NextNumber(-2.5, 2.5)),
			Color = palette[rng:NextInteger(1, #palette)],
			Material = Enum.Material.Grass,
			CastShadow = true,
			Parent = model,
		})
	end
	if blossom then
		local petals = Instance.new("ParticleEmitter")
		petals.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		petals.Rate = 1.5
		petals.Lifetime = NumberRange.new(4, 7)
		petals.Speed = NumberRange.new(0.5, 1.5)
		petals.Acceleration = Vector3.new(0.6, -1.2, 0.3)
		petals.Size = NumberSequence.new(0.25)
		petals.Color = ColorSequence.new(Color3.fromRGB(255, 190, 220))
		petals.SpreadAngle = Vector2.new(180, 180)
		petals.Rotation = NumberRange.new(0, 360)
		petals.RotSpeed = NumberRange.new(-90, 90)
		petals.Parent = model:FindFirstChild("Leaves")
	end
	model.Parent = parent or map
	return model
end

local lamps: { PointLight } = {}

local function lampPost(pos: Vector3)
	P({ Name = "LampPole", Size = Vector3.new(0.6, 12, 0.6), Position = pos + Vector3.new(0, 6, 0), Color = Color3.fromRGB(40, 36, 50), Material = Enum.Material.Metal })
	P({ Name = "LampBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 1.6, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(40, 36, 50), Material = Enum.Material.Metal })
	local bulb = P({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Position = pos + Vector3.new(0, 12.4, 0), Color = Color3.fromRGB(255, 225, 180), Material = Enum.Material.Neon, CastShadow = false })
	table.insert(lamps, light(bulb, Color3.fromRGB(255, 205, 150), 26, 1.6))
end

local function bench(cf: CFrame)
	local wood = Color3.fromRGB(150, 98, 62)
	P({ Name = "Bench", Size = Vector3.new(7, 0.4, 2), CFrame = cf * CFrame.new(0, 1.8, 0), Color = wood, Material = Enum.Material.Wood })
	P({ Name = "Bench", Size = Vector3.new(7, 1.6, 0.3), CFrame = cf * CFrame.new(0, 2.8, 0.9) * CFrame.Angles(math.rad(-10), 0, 0), Color = wood, Material = Enum.Material.Wood })
	for _, x in { -3, 3 } do
		P({ Name = "Bench", Size = Vector3.new(0.3, 1.8, 1.8), CFrame = cf * CFrame.new(x, 0.9, 0), Color = Color3.fromRGB(40, 36, 50), Material = Enum.Material.Metal })
	end
end

local function flowerBed(pos: Vector3, w: number, d: number)
	P({ Name = "Bed", Size = Vector3.new(w, 1, d), Position = pos + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(235, 228, 220), Material = Enum.Material.Concrete })
	P({ Name = "Soil", Size = Vector3.new(w - 0.6, 0.2, d - 0.6), Position = pos + Vector3.new(0, 1.05, 0), Color = Color3.fromRGB(80, 56, 40), Material = Enum.Material.Ground })
	local colors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 220, 90), Color3.fromRGB(180, 120, 255), Color3.fromRGB(255, 255, 255) }
	for _ = 1, math.floor(w * d / 3) do
		P({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Position = pos + Vector3.new(rng:NextNumber(-w / 2 + 0.8, w / 2 - 0.8), 1.4, rng:NextNumber(-d / 2 + 0.8, d / 2 - 0.8)), Color = colors[rng:NextInteger(1, #colors)], CastShadow = false })
	end
end

local function fountain(pos: Vector3)
	local marble = Color3.fromRGB(240, 236, 245)
	P({ Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 22, 22), CFrame = CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = marble, Material = Enum.Material.Marble })
	P({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 20, 20), CFrame = CFrame.new(pos + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 200, 235), Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.3, CanCollide = false })
	P({ Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 2.4, 2.4), CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = marble, Material = Enum.Material.Marble })
	P({ Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 9, 9), CFrame = CFrame.new(pos + Vector3.new(0, 8.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = marble, Material = Enum.Material.Marble })
	local top = P({ Name = "FountainTop", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Position = pos + Vector3.new(0, 9.6, 0), Color = Color3.fromRGB(255, 150, 210), Material = Enum.Material.Neon })
	light(top, Color3.fromRGB(255, 160, 220), 22, 1.2)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Rate = 60
	spray.Lifetime = NumberRange.new(1.2, 1.6)
	spray.Speed = NumberRange.new(14, 18)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	spray.Color = ColorSequence.new(Color3.fromRGB(170, 230, 255))
	spray.LightEmission = 0.6
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = top
end

local function boulevard()
	local length = 440
	-- Route
	P({ Name = "Road", Size = Vector3.new(length, 0.4, 20), Position = Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(52, 50, 60), Material = Enum.Material.Asphalt })
	for x = -length / 2 + 6, length / 2 - 6, 12 do
		if math.abs(x) > 16 then
			P({ Name = "Line", Size = Vector3.new(5, 0.05, 0.4), Position = Vector3.new(x, 0.42, 0), Color = Color3.fromRGB(250, 240, 220), CastShadow = false, CanCollide = false })
		end
	end
	-- Trottoirs en pavés roses
	for _, z in { -14, 14 } do
		P({ Name = "Sidewalk", Size = Vector3.new(length, 0.8, 8), Position = Vector3.new(0, 0.4, z), Color = Color3.fromRGB(232, 205, 210), Material = Enum.Material.Pavement })
		P({ Name = "Curb", Size = Vector3.new(length, 0.9, 0.6), Position = Vector3.new(0, 0.45, z - math.sign(z) * 3.9), Color = Color3.fromRGB(250, 245, 245), Material = Enum.Material.Concrete })
		for x = -length / 2 + 15, length / 2 - 15, 30 do
			lampPost(Vector3.new(x, 0.8, z + math.sign(z) * 2.5))
		end
	end
	-- Place centrale
	P({ Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 44, 44), CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(245, 225, 232), Material = Enum.Material.Pavement })
	fountain(Vector3.new(0, 0.5, 0))
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + math.pi / 6
		bench(CFrame.new(math.cos(a) * 17, 0.5, math.sin(a) * 17) * CFrame.Angles(0, -a - math.pi / 2, 0))
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.Position = Vector3.new(-30, 0.6, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = map

	-- Arbres et massifs
	for x = -200, 200, 45 do
		for _, z in { -110, 110 } do
			World.Tree(Vector3.new(x + rng:NextNumber(-6, 6), 0, z + rng:NextNumber(-8, 8)), rng:NextNumber() < 0.6)
		end
	end
	for i = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(240, 310)
		World.Tree(Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber() < 0.5)
	end
	flowerBed(Vector3.new(215, 0, 0), 10, 30) -- (côté ouest : la scène de Battle)
end

---------------------------------------------------------------------
-- Cycle jour / nuit (10 min jour, 4 min nuit)
---------------------------------------------------------------------
local function dayNight()
	task.spawn(function()
		local t = 9
		while true do
			local dt = task.wait(0.5)
			local isDay = t > 6.5 and t < 18.5
			t += dt * (isDay and (12 / 600) or (12 / 240))
			if t >= 24 then
				t -= 24
			end
			Lighting.ClockTime = t
			local night = not (t > 6 and t < 18.7)
			for _, l in lamps do
				l.Enabled = night
			end
		end
	end)
end

-- Position (CFrame) de chaque salon, façade tournée vers le boulevard.
function World.SalonCFrames(): { CFrame }
	local list = {}
	local xs = { -150, -75, 75, 150 }
	local zFront = 22
	for _, side in { -1, 1 } do
		for _, x in xs do
			local center = Vector3.new(x, 0, side * (zFront + World.SalonDepth / 2))
			table.insert(list, CFrame.lookAt(center, Vector3.new(x, 0, 0)))
		end
	end
	return list
end

function World.Build()
	setupLighting()
	setupTerrain()
	boulevard()
	dayNight()
end

World.Map = map

return World
