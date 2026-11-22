-- Salons : construction, clients, stylistes, sessions de coiffure, économie.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HairBuilder = require(ReplicatedStorage.Shared.HairBuilder)
local Util = require(ReplicatedStorage.Shared.Util)
local Data = require(script.Parent.Data)
local Net = require(script.Parent.Net)
local Stats = require(script.Parent.Stats)
local World = require(script.Parent.World)

local P = World.Part
local W, D = World.SalonWidth, World.SalonDepth
local H = 14 -- hauteur des murs
local FLOOR = 1 -- dessus du sol
local CHAIR_X = { -20, -12, -4, 4, 12, 20 }
local CHAIR_Z = 15
local MAX_CHAIRS = #CHAIR_X

local rng = Random.new()

local THEMES = {
	Color3.fromRGB(255, 120, 180),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(90, 225, 170),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(255, 205, 70),
	Color3.fromRGB(255, 90, 100),
	Color3.fromRGB(110, 140, 255),
}

local SKIN = {
	Color3.fromRGB(255, 220, 190),
	Color3.fromRGB(240, 195, 160),
	Color3.fromRGB(205, 150, 110),
	Color3.fromRGB(160, 105, 70),
	Color3.fromRGB(110, 70, 45),
	Color3.fromRGB(80, 52, 36),
}
local CLOTHES = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(40, 40, 50),
	Color3.fromRGB(230, 90, 120),
	Color3.fromRGB(80, 140, 230),
	Color3.fromRGB(120, 200, 140),
	Color3.fromRGB(250, 200, 90),
	Color3.fromRGB(150, 100, 220),
	Color3.fromRGB(240, 130, 70),
}

local ANIM = {
	walk = "rbxassetid://507777826",
	idle = "rbxassetid://507766666",
	sit = "rbxassetid://2506281703",
}

local Salons = {}

type Chair = {
	Index: number,
	Model: Model,
	Seat: Seat,
	Customer: any?,
	Sitter: Player?,
	Reserved: boolean,
}

type Salon = {
	Index: number,
	CFrame: CFrame,
	Theme: Color3,
	Root: Folder,
	Building: Folder,
	ChairsFolder: Folder,
	StaffFolder: Folder,
	CustomersFolder: Folder,
	Owner: Player?,
	Chairs: { [number]: Chair },
	Customers: { any },
	Staff: { any },
	LastSpawn: number,
	PendingCelebrity: number,
	SignLabel: TextLabel?,
}

local salons: { Salon } = {}
local salonOf: { [Player]: Salon } = {}
local sessions: { [Player]: any } = {}
local sitterOf: { [Player]: { salon: Salon, chair: Chair } } = {}
local lastPlayerStyle: { [string]: number } = {}

local root = Instance.new("Folder")
root.Name = "Salons"
root.Parent = Workspace

local function L(salon: Salon, x: number, y: number, z: number): CFrame
	return salon.CFrame * CFrame.new(x, y, z)
end

local function prompt(parent: Instance, kind: string, action: string, object: string, hold: number?): ProximityPrompt
	local att = Instance.new("Attachment")
	att.Name = kind .. "Attachment"
	att.Parent = parent
	local p = Instance.new("ProximityPrompt")
	p.Name = kind
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Default
	p.Enabled = true -- le client masque localement les prompts qui ne le concernent pas
	p:SetAttribute("Kind", kind)
	p.Parent = att
	return p
end

local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, bg: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = bg and 0 or 1
	label.BackgroundColor3 = bg or Color3.new()
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(40, 10, 40)
	stroke.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = label
	return label
end

local function sparkle(parent: Instance, color: Color3, rate: number, size: number?)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(size or 0.35, 0)
	e.LightEmission = 1
	e.Color = ColorSequence.new(color)
	e.Parent = parent
	return e
end

local function burst(position: Vector3, color: Color3, count: number?)
	local p = P({ Name = "Burst", Size = Vector3.new(1, 1, 1), Position = position, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = Workspace })
	local e = sparkle(p, color, 0, 0.6)
	e.Speed = NumberRange.new(6, 12)
	e.Drag = 4
	e:Emit(count or 40)
	task.delay(2, function()
		p:Destroy()
	end)
end
Salons.Burst = burst

---------------------------------------------------------------------
-- Construction du bâtiment (dépend du niveau de déco)
---------------------------------------------------------------------
local DECO_STYLE = {
	{ floor = Enum.Material.WoodPlanks, floorColor = Color3.fromRGB(196, 150, 110), wall = Color3.fromRGB(250, 240, 230), trim = Enum.Material.SmoothPlastic },
	{ floor = "checker", floorColor = Color3.fromRGB(245, 245, 245), wall = Color3.fromRGB(255, 232, 240), trim = Enum.Material.SmoothPlastic },
	{ floor = Enum.Material.Marble, floorColor = Color3.fromRGB(245, 242, 248), wall = Color3.fromRGB(255, 252, 250), trim = Enum.Material.Foil },
	{ floor = Enum.Material.Marble, floorColor = Color3.fromRGB(250, 225, 236), wall = Color3.fromRGB(70, 40, 80), trim = Enum.Material.Foil },
	{ floor = Enum.Material.Marble, floorColor = Color3.fromRGB(40, 34, 48), wall = Color3.fromRGB(28, 26, 48), trim = Enum.Material.Foil },
}
local GOLD = Color3.fromRGB(255, 196, 70)

local function buildBuilding(salon: Salon, level: number)
	salon.Building:ClearAllChildren()
	local f = salon.Building
	local st = DECO_STYLE[math.clamp(level, 1, #DECO_STYLE)]
	local theme = salon.Theme
	local trimColor = st.trim == Enum.Material.Foil and GOLD or theme

	-- Fondations + sol
	P({ Name = "Foundation", Size = Vector3.new(W + 2, 1.2, D + 2), CFrame = L(salon, 0, 0.4, 0), Color = Color3.fromRGB(230, 225, 230), Material = Enum.Material.Concrete, Parent = f })
	if st.floor == "checker" then
		local tw, td = W / 8, D / 8
		for i = 0, 7 do
			for j = 0, 7 do
				local dark = (i + j) % 2 == 0
				P({ Name = "Tile", Size = Vector3.new(tw, 0.2, td), CFrame = L(salon, -W / 2 + tw * (i + 0.5), FLOOR + 0.1, -D / 2 + td * (j + 0.5)), Color = dark and Color3.fromRGB(30, 28, 36) or Color3.fromRGB(250, 248, 252), Reflectance = 0.05, Parent = f })
			end
		end
	else
		P({ Name = "Floor", Size = Vector3.new(W, 0.2, D), CFrame = L(salon, 0, FLOOR + 0.1, 0), Color = st.floorColor, Material = st.floor, Reflectance = level >= 4 and 0.12 or 0, Parent = f })
	end

	local wallMat = level >= 4 and Enum.Material.SmoothPlastic or Enum.Material.Plaster
	local function wall(size: Vector3, cf: CFrame, name: string?)
		return P({ Name = name or "Wall", Size = size, CFrame = cf, Color = st.wall, Material = wallMat, Parent = f })
	end
	local function glass(size: Vector3, cf: CFrame)
		return P({ Name = "Window", Size = size, CFrame = cf, Color = Color3.fromRGB(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.55, Reflectance = 0.2, CastShadow = false, Parent = f })
	end
	local y0 = FLOOR + 0.2

	-- Mur du fond
	wall(Vector3.new(W, H, 1), L(salon, 0, y0 + H / 2, D / 2 - 0.5))
	-- Murs latéraux avec grandes fenêtres
	for _, side in { -1, 1 } do
		local x = side * (W / 2 - 0.5)
		wall(Vector3.new(1, 4, D), L(salon, x, y0 + 2, 0))
		wall(Vector3.new(1, 3, D), L(salon, x, y0 + H - 1.5, 0))
		glass(Vector3.new(0.4, H - 7, D - 2), L(salon, x, y0 + 4 + (H - 7) / 2, 0))
		for _, z in { -D / 2 + 0.5, -D / 6, D / 6, D / 2 - 0.5 } do
			P({ Name = "Post", Size = Vector3.new(1.2, H, 1.2), CFrame = L(salon, x, y0 + H / 2, z), Color = trimColor, Material = st.trim, Parent = f })
		end
	end
	-- Façade : vitrines + porte au centre (12 studs)
	for _, side in { -1, 1 } do
		local x = side * (6 + (W / 2 - 6) / 2)
		local w = W / 2 - 6
		wall(Vector3.new(w, 3, 1), L(salon, x, y0 + 1.5, -D / 2 + 0.5))
		glass(Vector3.new(w, 8, 0.4), L(salon, x, y0 + 7, -D / 2 + 0.5))
		wall(Vector3.new(w, 3, 1), L(salon, x, y0 + H - 1.5, -D / 2 + 0.5))
		P({ Name = "DoorFrame", Size = Vector3.new(1, H, 1.4), CFrame = L(salon, side * 6, y0 + H / 2, -D / 2 + 0.5), Color = trimColor, Material = st.trim, Parent = f })
	end
	wall(Vector3.new(12, 3, 1), L(salon, 0, y0 + H - 1.5, -D / 2 + 0.5))

	-- Toit avec verrière
	local ry = y0 + H + 0.5
	P({ Name = "Roof", Size = Vector3.new(W + 2, 1, 8), CFrame = L(salon, 0, ry, -D / 2 + 3), Color = Color3.fromRGB(70, 62, 80), Parent = f })
	P({ Name = "Roof", Size = Vector3.new(W + 2, 1, 8), CFrame = L(salon, 0, ry, D / 2 - 3), Color = Color3.fromRGB(70, 62, 80), Parent = f })
	P({ Name = "Roof", Size = Vector3.new(8, 1, D - 14), CFrame = L(salon, -W / 2 + 3, ry, 0), Color = Color3.fromRGB(70, 62, 80), Parent = f })
	P({ Name = "Roof", Size = Vector3.new(8, 1, D - 14), CFrame = L(salon, W / 2 - 3, ry, 0), Color = Color3.fromRGB(70, 62, 80), Parent = f })
	glass(Vector3.new(W - 14, 0.4, D - 14), L(salon, 0, ry, 0))

	-- Auvent rayé
	for i = 0, 5 do
		P({ ClassName = "WedgePart", Name = "Awning", Size = Vector3.new(2, 1.6, 4), CFrame = L(salon, -5 + i * 2, y0 + 11.3, -D / 2 - 1.6) * CFrame.Angles(0, math.pi, 0), Color = i % 2 == 0 and theme or Color3.new(1, 1, 1), Parent = f })
	end

	-- Enseigne
	local sign = P({ Name = "Sign", Size = Vector3.new(26, 5, 1), CFrame = L(salon, 0, ry + 3, -D / 2 + 0.5), Color = Color3.fromRGB(30, 22, 40), Parent = f })
	for _, dy in { -2.6, 2.6 } do
		P({ Name = "SignNeon", Size = Vector3.new(26.4, 0.3, 1.2), CFrame = L(salon, 0, ry + 3 + dy, -D / 2 + 0.5), Color = theme, Material = Enum.Material.Neon, CastShadow = false, Parent = f })
	end
	salon.SignLabel = surfaceText(sign, Enum.NormalId.Front, "✂️ SALON LIBRE", theme)
	if level >= 5 then
		sparkle(sign, GOLD, 8, 0.5)
	end

	-- Éclairage intérieur
	for _, x in { -14, 14 } do
		for _, z in { -10, 10 } do
			local panel = P({ Name = "CeilingLight", Size = Vector3.new(8, 0.3, 2.5), CFrame = L(salon, x, y0 + H - 0.3, z), Color = Color3.fromRGB(255, 246, 235), Material = Enum.Material.Neon, CastShadow = false, Parent = f })
			local sl = Instance.new("SurfaceLight")
			sl.Face = Enum.NormalId.Bottom
			sl.Range = 22
			sl.Brightness = 1.4
			sl.Angle = 110
			sl.Color = Color3.fromRGB(255, 240, 225)
			sl.Parent = panel
		end
	end

	-- Miroir « change ton look » (mur gauche)
	local mirror = P({ Name = "LookMirror", Size = Vector3.new(0.3, 9, 6), CFrame = L(salon, -W / 2 + 1.3, y0 + 5.5, -6), Color = Color3.fromRGB(220, 235, 255), Material = Enum.Material.Glass, Reflectance = 0.6, Transparency = 0.05, Parent = f })
	P({ Name = "MirrorFrame", Size = Vector3.new(0.4, 9.8, 6.8), CFrame = L(salon, -W / 2 + 1.15, y0 + 5.5, -6), Color = trimColor, Material = level >= 3 and Enum.Material.Foil or Enum.Material.Neon, Parent = f })
	local mirrorSign = P({ Name = "MirrorSign", Size = Vector3.new(0.2, 1.4, 6), CFrame = L(salon, -W / 2 + 1.3, y0 + 10.9, -6), Transparency = 1, CanCollide = false, Parent = f })
	surfaceText(mirrorSign, Enum.NormalId.Right, "✨ CHANGE TON LOOK", Color3.new(1, 1, 1))
	prompt(mirror, "mirror", "Changer mon look", "Miroir magique", 0.2)

	-- Écran des améliorations (mur droit)
	local board = P({ Name = "UpgradeBoard", Size = Vector3.new(0.5, 6, 9), CFrame = L(salon, W / 2 - 1.3, y0 + 5, -14), Color = Color3.fromRGB(25, 20, 35), Parent = f })
	surfaceText(board, Enum.NormalId.Left, "⬆️ AMÉLIORATIONS\nAgrandis ton salon !", Color3.fromRGB(255, 230, 120))
	prompt(board, "upgrades", "Améliorer", "Mon salon", 0)

	-- Comptoir d'accueil
	P({ Name = "Desk", Size = Vector3.new(8, 3.4, 2.4), CFrame = L(salon, 15, y0 + 1.7, -D / 2 + 7), Color = level >= 3 and Color3.fromRGB(250, 250, 255) or theme, Material = level >= 3 and Enum.Material.Marble or Enum.Material.SmoothPlastic, Parent = f })
	P({ Name = "DeskTop", Size = Vector3.new(8.4, 0.3, 2.8), CFrame = L(salon, 15, y0 + 3.5, -D / 2 + 7), Color = trimColor, Material = st.trim, Parent = f })
	P({ Name = "Register", Size = Vector3.new(1.6, 1.2, 1.2), CFrame = L(salon, 17, y0 + 4.2, -D / 2 + 7), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal, Parent = f })

	-- Plantes
	if level >= 2 then
		for _, pos in { Vector2.new(-W / 2 + 3, -D / 2 + 3), Vector2.new(W / 2 - 3, D / 2 - 6), Vector2.new(-W / 2 + 3, D / 2 - 6), Vector2.new(W / 2 - 3, -D / 2 + 3) } do
			P({ Name = "Pot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = L(salon, pos.X, y0 + 1.2, pos.Y) * CFrame.Angles(0, 0, math.rad(90)), Color = level >= 3 and GOLD or Color3.fromRGB(200, 110, 80), Material = level >= 3 and Enum.Material.Foil or Enum.Material.Slate, Parent = f })
			for i = 1, 3 do
				P({ Name = "Leaf", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = L(salon, pos.X + rng:NextNumber(-0.6, 0.6), y0 + 2.8 + i * 0.9, pos.Y + rng:NextNumber(-0.6, 0.6)), Color = Color3.fromRGB(80, 170, 90), Material = Enum.Material.Grass, Parent = f })
			end
		end
	end
	-- Canapé d'attente
	if level >= 3 then
		local velvet = level >= 5 and Color3.fromRGB(150, 20, 50) or theme
		P({ Name = "Sofa", Size = Vector3.new(10, 1.6, 3.4), CFrame = L(salon, -18, y0 + 0.8, -D / 2 + 6), Color = velvet, Material = Enum.Material.Fabric, Parent = f })
		P({ Name = "Sofa", Size = Vector3.new(10, 3, 1), CFrame = L(salon, -18, y0 + 2.3, -D / 2 + 4.3), Color = velvet, Material = Enum.Material.Fabric, Parent = f })
	end
	-- Néons + lustre
	if level >= 4 then
		for _, z in { -D / 2 + 1.2, D / 2 - 1.2 } do
			P({ Name = "NeonStrip", Size = Vector3.new(W - 3, 0.25, 0.25), CFrame = L(salon, 0, y0 + H - 1, z), Color = theme, Material = Enum.Material.Neon, CastShadow = false, Parent = f })
		end
		for _, x in { -W / 2 + 1.2, W / 2 - 1.2 } do
			P({ Name = "NeonStrip", Size = Vector3.new(0.25, 0.25, D - 3), CFrame = L(salon, x, y0 + H - 1, 0), Color = theme, Material = Enum.Material.Neon, CastShadow = false, Parent = f })
		end
		local center = P({ Name = "Chandelier", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = L(salon, 0, y0 + H - 3.5, 0), Color = Color3.fromRGB(255, 240, 220), Material = Enum.Material.Neon, Parent = f })
		local pl = Instance.new("PointLight")
		pl.Range = 30
		pl.Brightness = 1.5
		pl.Color = Color3.fromRGB(255, 225, 200)
		pl.Shadows = true
		pl.Parent = center
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			P({ Name = "Crystal", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = L(salon, math.cos(a) * 3, y0 + H - 3.2 - (i % 2) * 0.6, math.sin(a) * 3), Color = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.5, Parent = f })
		end
		P({ Name = "Rug", Size = Vector3.new(14, 0.1, 22), CFrame = L(salon, 0, y0 + 0.06, -8), Color = level >= 5 and Color3.fromRGB(160, 20, 45) or theme, Material = Enum.Material.Fabric, Parent = f })
	end
	-- Tapis rouge, colonnes dorées, projecteurs
	if level >= 5 then
		P({ Name = "RedCarpet", Size = Vector3.new(8, 0.15, 12), CFrame = L(salon, 0, 0.9, -D / 2 - 6), Color = Color3.fromRGB(170, 15, 40), Material = Enum.Material.Fabric, Parent = f })
		for _, x in { -8, 8 } do
			P({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(H + 3, 2.4, 2.4), CFrame = L(salon, x, (H + 3) / 2, -D / 2 - 1.8) * CFrame.Angles(0, 0, math.rad(90)), Color = GOLD, Material = Enum.Material.Foil, Parent = f })
			for _, z in { -D / 2 - 3, -D / 2 - 7, -D / 2 - 11 } do
				P({ Name = "Stanchion", Size = Vector3.new(0.4, 3, 0.4), CFrame = L(salon, x / 2, 2.4, z), Color = GOLD, Material = Enum.Material.Foil, Parent = f })
			end
			local beam = P({ Name = "Spotlight", Size = Vector3.new(1.2, 40, 1.2), CFrame = L(salon, x * 1.6, 20, -D / 2 - 4) * CFrame.Angles(0, 0, math.rad(x > 0 and -14 or 14)), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, Transparency = 0.82, CanCollide = false, CastShadow = false, CanQuery = false, Parent = f })
			beam:SetAttribute("Sweep", x > 0 and 1 or -1)
		end
	end
end

---------------------------------------------------------------------
-- Postes de coiffure (fauteuil + miroir lumineux)
---------------------------------------------------------------------
local function buildChair(salon: Salon, i: number): Chair
	local model = Instance.new("Model")
	model.Name = "Chair" .. i
	local x = CHAIR_X[i]
	local y0 = FLOOR + 0.2
	local theme = salon.Theme
	-- Poste au mur : comptoir, miroir, ampoules
	P({ Name = "Counter", Size = Vector3.new(6.4, 3.4, 2.2), CFrame = L(salon, x, y0 + 1.7, D / 2 - 2.1), Color = Color3.fromRGB(250, 248, 252), Material = Enum.Material.Marble, Parent = model })
	P({ Name = "CounterTop", Size = Vector3.new(6.8, 0.3, 2.6), CFrame = L(salon, x, y0 + 3.55, D / 2 - 2.1), Color = Color3.fromRGB(30, 28, 36), Reflectance = 0.15, Parent = model })
	P({ Name = "Mirror", Size = Vector3.new(5, 6.4, 0.3), CFrame = L(salon, x, y0 + 7.4, D / 2 - 1.15), Color = Color3.fromRGB(215, 232, 255), Material = Enum.Material.Glass, Reflectance = 0.55, Transparency = 0.05, Parent = model })
	for k = 0, 13 do
		local px, py
		if k < 5 then
			px, py = -2.6 + k * 1.3, 3.4
		elseif k < 10 then
			px, py = -2.6 + (k - 5) * 1.3, -3.4
		elseif k < 12 then
			px, py = -2.9, -1.2 + (k - 10) * 2.4
		else
			px, py = 2.9, -1.2 + (k - 12) * 2.4
		end
		P({ Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55), CFrame = L(salon, x + px, y0 + 7.4 + py, D / 2 - 1.3), Color = Color3.fromRGB(255, 236, 200), Material = Enum.Material.Neon, CastShadow = false, Parent = model })
	end
	local bulbLight = P({ Name = "StationLight", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = L(salon, x, y0 + 7.4, D / 2 - 2.5), Transparency = 1, CanCollide = false, Parent = model })
	local pl = Instance.new("PointLight")
	pl.Range = 11
	pl.Brightness = 0.9
	pl.Color = Color3.fromRGB(255, 230, 200)
	pl.Parent = bulbLight
	local bottleColors = { theme, Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 220, 120) }
	for k, c in bottleColors do
		P({ Name = "Bottle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 0.6, 0.6), CFrame = L(salon, x - 2.4 + k * 0.8, y0 + 4.3, D / 2 - 1.8) * CFrame.Angles(0, 0, math.rad(90)), Color = c, Material = Enum.Material.Glass, Transparency = 0.15, Parent = model })
	end
	-- Fauteuil hydraulique
	P({ Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.4, 3.4), CFrame = L(salon, x, y0 + 0.15, CHAIR_Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Metal, Reflectance = 0.3, Parent = model })
	P({ Name = "Pole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 0.7, 0.7), CFrame = L(salon, x, y0 + 1.1, CHAIR_Z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Metal, Reflectance = 0.3, Parent = model })
	local leather = Color3.fromRGB(35, 30, 40)
	local seat = P({
		ClassName = "Seat",
		Name = "Seat",
		Size = Vector3.new(3, 0.9, 3),
		CFrame = L(salon, x, y0 + 2.3, CHAIR_Z) * CFrame.Angles(0, math.pi, 0),
		Color = leather,
		Material = Enum.Material.Leather,
		CanTouch = false,
		Parent = model,
	}) :: Seat
	P({ Name = "Back", Size = Vector3.new(3, 3.4, 0.6), CFrame = L(salon, x, y0 + 4.2, CHAIR_Z - 1.4) * CFrame.Angles(math.rad(-8), 0, 0), Color = leather, Material = Enum.Material.Leather, Parent = model })
	P({ Name = "BackTrim", Size = Vector3.new(3.1, 0.3, 0.7), CFrame = L(salon, x, y0 + 5.9, CHAIR_Z - 1.6), Color = theme, Material = Enum.Material.Neon, Parent = model })
	for _, side in { -1, 1 } do
		P({ Name = "Arm", Size = Vector3.new(0.5, 0.4, 2.6), CFrame = L(salon, x + side * 1.6, y0 + 3.4, CHAIR_Z), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Metal, Parent = model })
	end
	model:SetAttribute("Occupied", false)
	model:SetAttribute("Busy", false)
	model:SetAttribute("Index", i)
	prompt(seat, "style", "Coiffer", "Client", 0.15)
	prompt(seat, "sit", "S'asseoir", "Se faire coiffer", 0.3)
	model.Parent = salon.ChairsFolder
	return { Index = i, Model = model, Seat = seat, Customer = nil, Sitter = nil, Reserved = false }
end

local function chairCount(salon: Salon): number
	local owner = salon.Owner
	local profile = owner and Data.Get(owner)
	return profile and math.clamp(profile.Upgrades.chairs, 1, MAX_CHAIRS) or 0
end

local function stylistCount(salon: Salon): number
	local owner = salon.Owner
	local profile = owner and Data.Get(owner)
	if not profile or not owner then
		return 0
	end
	local n = profile.Upgrades.stylists + (Stats.HasPass(owner, "autoStylist") and 2 or 0)
	return math.min(n, MAX_CHAIRS)
end

---------------------------------------------------------------------
-- PNJ
---------------------------------------------------------------------
local function setAnim(npc: any, name: string?)
	if npc.Playing then
		npc.Playing:Stop(0.2)
		npc.Playing = nil
	end
	if name and npc.Tracks and npc.Tracks[name] then
		npc.Tracks[name]:Play(0.2)
		npc.Playing = npc.Tracks[name]
	end
end

local function makeHumanoid(outfit: Color3?, pants: Color3?): Model?
	local desc = Instance.new("HumanoidDescription")
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = outfit or CLOTHES[rng:NextInteger(1, #CLOTHES)]
	local legs = pants or CLOTHES[rng:NextInteger(1, #CLOTHES)]
	desc.LeftLegColor = legs
	desc.RightLegColor = legs
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[Salons] Création PNJ impossible :", model)
		return nil
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.WalkSpeed = 12
		hum.BreakJointsOnDeath = false
	end
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	return model
end

local function loadTracks(npc: any)
	local hum: Humanoid = npc.Humanoid
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	npc.Tracks = {}
	for name, id in ANIM do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Looped = true
			npc.Tracks[name] = track
		end
	end
end

local function walkTo(npc: any, target: Vector3, timeout: number?)
	local hum: Humanoid = npc.Humanoid
	if not hum.Parent then
		return
	end
	setAnim(npc, "walk")
	hum:MoveTo(target)
	local reached = false
	local conn = hum.MoveToFinished:Connect(function()
		reached = true
	end)
	local t0 = os.clock()
	while not reached and os.clock() - t0 < (timeout or 9) and npc.Model.Parent do
		task.wait(0.1)
	end
	conn:Disconnect()
	if not reached and npc.Model.Parent then
		npc.Model:PivotTo(CFrame.new(target + Vector3.new(0, 3, 0)))
	end
	setAnim(npc, "idle")
end

local function makeBillboard(npc: any)
	local head = npc.Model:FindFirstChild("Head")
	local gui = Instance.new("BillboardGui")
	gui.Name = "Request"
	gui.Size = UDim2.fromScale(8, 2.6)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Adornee = head
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = npc.Celebrity and Color3.fromRGB(60, 40, 10) or Color3.fromRGB(28, 20, 40)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0.25, 0)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Thickness = 2
	stroke.Color = (npc.Vip or npc.Celebrity) and GOLD or Color3.fromRGB(255, 140, 200)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.34)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = (npc.Vip or npc.Celebrity) and GOLD or Color3.new(1, 1, 1)
	title.Text = npc.Celebrity and "🌟 CÉLÉBRITÉ (x10)" or (npc.Vip and "⭐ CLIENT VIP (x4)" or "💬 Je voudrais :")
	title.Parent = frame
	local req = Instance.new("TextLabel")
	req.Name = "Wish"
	req.BackgroundTransparency = 1
	req.Position = UDim2.fromScale(0.04, 0.34)
	req.Size = UDim2.fromScale(0.92, 0.38)
	req.Font = Enum.Font.GothamBold
	req.TextScaled = true
	req.TextColor3 = Color3.fromRGB(255, 225, 240)
	req.Text = HairBuilder.Describe(npc.Request)
	req.Parent = frame
	local barBg = Instance.new("Frame")
	barBg.BackgroundColor3 = Color3.fromRGB(60, 50, 70)
	barBg.Position = UDim2.fromScale(0.08, 0.78)
	barBg.Size = UDim2.fromScale(0.84, 0.12)
	barBg.Parent = frame
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(120, 230, 140)
	bar.Size = UDim2.fromScale(1, 1)
	bar.Parent = barBg
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
	gui.Parent = npc.Model
	npc.Bar = bar
	npc.Title = title
end

local function availableOptions(owner: Player, profile: any)
	local styles, colors, accs = {}, {}, {}
	for _, s in Config.Styles do
		if profile.Styles[s.Id] or (s.Pass and Stats.HasPass(owner, s.Pass)) then
			table.insert(styles, s)
		end
	end
	for _, c in Config.Colors do
		if c.Tier == "base" or (c.Tier == "fantasy" and profile.FantasyColors) or (c.Tier == "neon" and Stats.HasPass(owner, "neonColors")) then
			table.insert(colors, c)
		end
	end
	for _, a in Config.Accessories do
		if a.Id ~= "aucun" and (profile.Accs[a.Id] or (a.Pass and Stats.HasPass(owner, a.Pass))) then
			table.insert(accs, a)
		end
	end
	return styles, colors, accs
end

local function weightedPick(list: { any }): any
	local total = 0
	for i in list do
		total += i
	end
	local r = rng:NextNumber() * total
	for i, v in list do
		r -= i
		if r <= 0 then
			return v
		end
	end
	return list[#list]
end

local function makeRequest(owner: Player, profile: any)
	local styles, colors, accs = availableOptions(owner, profile)
	local request = {
		style = weightedPick(styles).Id, -- les coupes les plus chères sortent plus souvent
		length = rng:NextInteger(1, 3),
		color = weightedPick(colors).Id,
		acc = (#accs > 0 and rng:NextNumber() < 0.4) and accs[rng:NextInteger(1, #accs)].Id or "aucun",
	}
	local messy = {
		style = Config.Styles[rng:NextInteger(1, 2)].Id,
		length = rng:NextInteger(1, 3),
		color = Config.Colors[rng:NextInteger(1, 4)].Id,
		acc = "aucun",
	}
	if messy.style == request.style then
		messy.style = request.style == "lisse" and "pixie" or "lisse"
	end
	return request, messy
end

local function freeChair(salon: Salon): Chair?
	local n = chairCount(salon)
	local candidates = {}
	for i = 1, n do
		local c = salon.Chairs[i]
		if c and not c.Customer and not c.Sitter and not c.Reserved then
			table.insert(candidates, c)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

local function updateChairAttrs(chair: Chair)
	local occupied = (chair.Customer ~= nil and chair.Customer.State == "waiting") or chair.Sitter ~= nil
	chair.Model:SetAttribute("Occupied", occupied)
	chair.Model:SetAttribute("Busy", (chair.Customer ~= nil and chair.Customer.State ~= "waiting") or false)
	chair.Model:SetAttribute("Taken", chair.Customer ~= nil or chair.Sitter ~= nil or chair.Reserved)
	chair.Model:SetAttribute("SitterName", chair.Sitter and chair.Sitter.DisplayName or "")
end

local function removeCustomer(salon: Salon, npc: any)
	local i = table.find(salon.Customers, npc)
	if i then
		table.remove(salon.Customers, i)
	end
	if npc.Chair and npc.Chair.Customer == npc then
		npc.Chair.Customer = nil
		npc.Chair.Reserved = false
		updateChairAttrs(npc.Chair)
	end
	npc.Chair = nil
	if npc.Model then
		npc.Model:Destroy()
	end
end

local function leave(salon: Salon, npc: any, happy: boolean)
	if npc.State == "leaving" then
		return
	end
	npc.State = "leaving"
	local chair = npc.Chair
	if chair then
		chair.Customer = nil
		chair.Reserved = false
		updateChairAttrs(chair)
	end
	npc.Chair = nil
	local gui = npc.Model:FindFirstChild("Request")
	if gui then
		gui:Destroy()
	end
	task.spawn(function()
		local hrp = npc.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.Anchored = false
		end
		if happy then
			npc.Humanoid.Jump = true
			task.wait(0.6)
		end
		walkTo(npc, (L(salon, 0, 0, -D / 2 + 3)).Position)
		walkTo(npc, (L(salon, rng:NextNumber(-20, 20), 0, -D / 2 - 14)).Position)
		removeCustomer(salon, npc)
	end)
end

local function spawnCustomer(salon: Salon, special: string?)
	local owner = salon.Owner
	local profile = owner and Data.Get(owner)
	if not owner or not profile then
		return
	end
	local chair = freeChair(salon)
	if not chair then
		return
	end
	chair.Reserved = true
	updateChairAttrs(chair)
	local request, messy = makeRequest(owner, profile)
	local isVip = special == nil and rng:NextNumber() < Config.VipChance * (Stats.HasPass(owner, "vip") and 2 or 1)
	local celebrity = special == "celebrity"
	local model = makeHumanoid(celebrity and Color3.fromRGB(20, 20, 24) or (isVip and Color3.fromRGB(250, 210, 90) or nil))
	if not model or salon.Owner ~= owner then
		chair.Reserved = false
		updateChairAttrs(chair)
		if model then
			model:Destroy()
		end
		return
	end
	model.Name = celebrity and "Celebrity" or "Client"
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local npc = {
		Model = model,
		Humanoid = hum,
		Request = request,
		Look = messy,
		Chair = chair,
		State = "walking",
		Vip = isVip,
		Celebrity = celebrity,
		Patience = Config.CustomerPatience * (celebrity and 3 or 1),
		Waited = 0,
	}
	chair.Customer = npc
	updateChairAttrs(chair)
	table.insert(salon.Customers, npc)
	model:PivotTo(L(salon, rng:NextNumber(-18, 18), 4, -D / 2 - 14) * CFrame.Angles(0, math.pi, 0))
	model.Parent = salon.CustomersFolder
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)
	HairBuilder.Apply(model, messy)
	if isVip or celebrity then
		sparkle(hrp, GOLD, 10, 0.5)
	end
	makeBillboard(npc)
	loadTracks(npc)
	setAnim(npc, "idle")

	task.spawn(function()
		walkTo(npc, L(salon, 0, 0, -D / 2 + 3).Position)
		walkTo(npc, L(salon, CHAIR_X[chair.Index], 0, CHAIR_Z - 3).Position)
		if npc.State ~= "walking" or not model.Parent then
			return
		end
		-- Assis sur le fauteuil (ancré pour la stabilité)
		hrp.Anchored = true
		model:PivotTo(chair.Seat.CFrame * CFrame.new(0, 2.1, 0))
		setAnim(npc, "sit")
		npc.State = "waiting"
		chair.Reserved = false
		updateChairAttrs(chair)
		if celebrity and salon.Owner then
			Net.Announce("🌟 Une CÉLÉBRITÉ est arrivée chez " .. salon.Owner.DisplayName .. " !", GOLD)
		end
	end)
end

---------------------------------------------------------------------
-- Paiement
---------------------------------------------------------------------
local function computePay(owner: Player, profile: any, request: any, score: number, npc: any, byPlayer: boolean): (number, boolean)
	local style = Config.StyleById[request.style]
	local color = Config.ColorById[request.color]
	local base = Config.BasePay * style.Value * color.Value * Config.Lengths[request.length].Mult * (request.acc ~= "aucun" and 1.3 or 1)
	local deco = Config.Upgrades.deco.Mult[math.clamp(profile.Upgrades.deco, 1, #Config.Upgrades.deco.Mult)]
	local perfect = score >= 0.999
	local quality
	if perfect then
		quality = 1 + Config.PerfectTip * (Stats.HasPass(owner, "bigTips") and 2 or 1)
	elseif score >= 0.6 then
		quality = score
	else
		quality = score * 0.5
	end
	local special = npc.Celebrity and Config.CelebrityPay or (npc.Vip and Config.VipPay or 1)
	local streak = byPlayer and (1 + math.min(profile.Streak, Config.StreakMax) * Config.StreakBonus) or 1
	return math.max(1, math.floor(base * deco * quality * special * streak * Stats.Multiplier(owner))), perfect
end

local function payFor(salon: Salon, npc: any, score: number, byPlayer: boolean)
	local owner = salon.Owner
	local profile = owner and Data.Get(owner)
	if not owner or not profile then
		return
	end
	local pay, perfect = computePay(owner, profile, npc.Request, score, npc, byPlayer)
	if byPlayer then
		if perfect then
			profile.Streak += 1
			profile.Perfect += 1
		else
			profile.Streak = 0
		end
	end
	profile.Served += 1
	Stats.AddCash(owner, pay)
	local head = npc.Model:FindFirstChild("Head") :: BasePart?
	if head then
		burst(head.Position + Vector3.new(0, 1.5, 0), perfect and GOLD or Color3.fromRGB(255, 150, 210), perfect and 60 or 25)
	end
	Net.Notify:FireClient(owner, {
		Type = "pay",
		Amount = pay,
		Perfect = perfect,
		Score = score,
		Streak = profile.Streak,
		ByPlayer = byPlayer,
		Position = head and head.Position,
	})
end

---------------------------------------------------------------------
-- Stylistes (automatiques)
---------------------------------------------------------------------
local staffVersion: { [Salon]: number } = {}

local function rebuildStaff(salon: Salon)
	local version = (staffVersion[salon] or 0) + 1
	staffVersion[salon] = version
	for _, s in salon.Staff do
		if s.Model then
			s.Model:Destroy()
		end
	end
	salon.Staff = {}
	local n = stylistCount(salon)
	for i = 1, n do
		local model = makeHumanoid(Color3.fromRGB(30, 28, 36), Color3.fromRGB(30, 28, 36))
		if staffVersion[salon] ~= version then
			if model then
				model:Destroy()
			end
			return -- une reconstruction plus récente a démarré
		end
		if not model then
			continue
		end
		model.Name = "Styliste"
		local home = L(salon, CHAIR_X[i] + 3.3, 4, CHAIR_Z + 1.5) * CFrame.Angles(0, math.pi / 2, 0)
		model:PivotTo(home)
		local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
		hrp.Anchored = true
		model.Parent = salon.StaffFolder
		HairBuilder.Apply(model, { style = ({ "crete", "chignon", "boucle", "pixie", "queue", "tresses" })[i], length = 2, color = ({ "neonrose", "platine", "violet", "noir", "rose", "bleu" })[i], acc = "aucun" })
		-- Tablier aux couleurs du salon
		local torso = model:FindFirstChild("UpperTorso") :: BasePart?
		if torso then
			local apron = P({ Name = "Apron", Size = Vector3.new(torso.Size.X * 0.95, torso.Size.Y * 1.1, 0.1), CFrame = torso.CFrame * CFrame.new(0, -0.1, -torso.Size.Z / 2 - 0.05), Color = salon.Theme, Anchored = false, CanCollide = false, Massless = true, Parent = model })
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = apron
			weld.Parent = apron
		end
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromScale(4, 0.8)
		tag.StudsOffset = Vector3.new(0, 3, 0)
		tag.MaxDistance = 40
		tag.Adornee = model:FindFirstChild("Head")
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 220, 240)
		label.Text = "✂️ Styliste"
		label.Parent = tag
		tag.Parent = model
		local npc = { Model = model, Humanoid = model:FindFirstChildOfClass("Humanoid"), Home = home, Job = nil }
		loadTracks(npc)
		setAnim(npc, "idle")
		table.insert(salon.Staff, npc)
	end
end

local function stylistTick(salon: Salon)
	if not salon.Owner then
		return
	end
	for _, staff in salon.Staff do
		if staff.Job == nil then
			-- Cherche un client qui attend et que personne ne coiffe
			for _, npc in salon.Customers do
				if npc.State == "waiting" and npc.Chair and not npc.Chair.Model:GetAttribute("Busy") then
					staff.Job = npc
					npc.State = "stylist"
					updateChairAttrs(npc.Chair)
					staff.Model:PivotTo(L(salon, CHAIR_X[npc.Chair.Index] + 2.6, 4, CHAIR_Z - 0.5) * CFrame.Angles(0, math.pi / 2, 0))
					local scissors = staff.Model:FindFirstChild("RightHand")
					if scissors then
						sparkle(scissors, Color3.fromRGB(255, 200, 240), 12).Name = "Work"
					end
					task.delay(Config.StylistWorkTime, function()
						if npc.State == "stylist" and salon.Owner and npc.Model.Parent then
							HairBuilder.Apply(npc.Model, npc.Request)
							payFor(salon, npc, Config.StylistScore, false)
							leave(salon, npc, true)
						end
						staff.Job = nil
						if staff.Model.Parent then
							local work = scissors and scissors:FindFirstChild("Work")
							if work then
								work:Destroy()
							end
							staff.Model:PivotTo(staff.Home)
						end
					end)
					break
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Construction / attribution
---------------------------------------------------------------------
local function ensureChairs(salon: Salon)
	local n = chairCount(salon)
	for i = 1, MAX_CHAIRS do
		if i <= n and not salon.Chairs[i] then
			salon.Chairs[i] = buildChair(salon, i)
		elseif i > n and salon.Chairs[i] then
			local c = salon.Chairs[i]
			if c.Customer then
				removeCustomer(salon, c.Customer)
			end
			if c.Sitter then
				Salons.StandUp(c.Sitter)
			end
			c.Model:Destroy()
			salon.Chairs[i] = nil
		end
	end
end

local function refreshSign(salon: Salon)
	if not salon.SignLabel then
		return
	end
	local owner = salon.Owner
	if owner then
		local profile = Data.Get(owner)
		local stars = string.rep("★", profile and profile.Upgrades.deco or 1)
		salon.SignLabel.Text = "✂️ Salon de " .. owner.DisplayName .. "  " .. stars
	else
		salon.SignLabel.Text = "✂️ SALON LIBRE"
	end
end

function Salons.Init()
	for i, cf in World.SalonCFrames() do
		local folder = Instance.new("Folder")
		folder.Name = "Salon" .. i
		local function sub(name)
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = folder
			return f
		end
		local salon: Salon = {
			Index = i,
			CFrame = cf,
			Theme = THEMES[i],
			Root = folder,
			Building = sub("Building"),
			ChairsFolder = sub("Chairs"),
			StaffFolder = sub("Staff"),
			CustomersFolder = sub("Customers"),
			Owner = nil,
			Chairs = {},
			Customers = {},
			Staff = {},
			LastSpawn = 0,
			PendingCelebrity = 0,
			SignLabel = nil,
		}
		folder:SetAttribute("OwnerId", 0)
		folder:SetAttribute("Index", i)
		folder.Parent = root
		buildBuilding(salon, 1)
		salons[i] = salon
	end
	-- Boucle de jeu des salons
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			for _, salon in salons do
				local owner = salon.Owner
				local profile = owner and Data.Get(owner)
				if owner and profile then
					local interval = Config.Upgrades.pub.Interval[math.clamp(profile.Upgrades.pub + 1, 1, #Config.Upgrades.pub.Interval)]
					if Stats.HasPass(owner, "fastClients") then
						interval *= 0.6
					end
					if Stats.RushActive() then
						interval *= 0.5
					end
					if salon.PendingCelebrity > 0 and freeChair(salon) then
						salon.PendingCelebrity -= 1
						salon.LastSpawn = os.clock()
						task.spawn(spawnCustomer, salon, "celebrity")
					elseif os.clock() - salon.LastSpawn >= interval then
						salon.LastSpawn = os.clock()
						task.spawn(spawnCustomer, salon)
					end
					-- Patience
					for _, npc in table.clone(salon.Customers) do
						if npc.State == "waiting" then
							npc.Waited += dt
							local left = 1 - npc.Waited / npc.Patience
							if npc.Bar then
								npc.Bar.Size = UDim2.fromScale(math.max(left, 0), 1)
								npc.Bar.BackgroundColor3 = left > 0.5 and Color3.fromRGB(120, 230, 140) or (left > 0.25 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 80, 90))
							end
							if left <= 0 then
								if npc.Title then
									npc.Title.Text = "😠 Trop long !"
								end
								leave(salon, npc, false)
							end
						end
					end
					stylistTick(salon)
				end
			end
		end
	end)
end

function Salons.Get(player: Player): Salon?
	return salonOf[player]
end

function Salons.HomeCFrame(player: Player): CFrame?
	local salon = salonOf[player]
	if not salon then
		return nil
	end
	return L(salon, 0, 4, -D / 2 + 8) * CFrame.Angles(0, math.pi, 0)
end

function Salons.Rebuild(player: Player, full: boolean?)
	local salon = salonOf[player]
	local profile = Data.Get(player)
	if not salon or not profile then
		return
	end
	if full then
		buildBuilding(salon, profile.Upgrades.deco)
	end
	ensureChairs(salon)
	task.spawn(rebuildStaff, salon)
	refreshSign(salon)
end

function Salons.Assign(player: Player): Salon?
	for _, salon in salons do
		if not salon.Owner then
			salon.Owner = player
			salonOf[player] = salon
			salon.Root:SetAttribute("OwnerId", player.UserId)
			salon.Root:SetAttribute("OwnerName", player.DisplayName)
			salon.LastSpawn = os.clock() - 100
			local s = Stats.Session(player)
			if s then
				s.SalonIndex = salon.Index
			end
			Salons.Rebuild(player, true)
			return salon
		end
	end
	return nil
end

function Salons.Unassign(player: Player)
	local salon = salonOf[player]
	salonOf[player] = nil
	if not salon then
		return
	end
	-- Termine les sessions liées à ce salon
	for stylist, sess in sessions do
		if sess.Salon == salon then
			Salons.EndSession(stylist, false)
		end
	end
	for _, npc in table.clone(salon.Customers) do
		removeCustomer(salon, npc)
	end
	for i, chair in salon.Chairs do
		if chair.Sitter then
			local hum = chair.Sitter.Character and chair.Sitter.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Sit = false
			end
			sitterOf[chair.Sitter] = nil
		end
		chair.Model:Destroy()
		salon.Chairs[i] = nil
	end
	salon.Owner = nil
	rebuildStaff(salon)
	salon.Root:SetAttribute("OwnerId", 0)
	salon.Root:SetAttribute("OwnerName", "")
	buildBuilding(salon, 1)
	refreshSign(salon)
end

function Salons.AddCelebrity(player: Player): boolean
	local salon = salonOf[player]
	if not salon then
		return false
	end
	salon.PendingCelebrity += 1
	return true
end

---------------------------------------------------------------------
-- Sessions de coiffure
---------------------------------------------------------------------
local function canUse(player: Player, kind: string, id: any): boolean
	local profile = Data.Get(player)
	if not profile then
		return false
	end
	if kind == "style" then
		local s = Config.StyleById[id]
		return s ~= nil and (profile.Styles[id] == true or (s.Pass ~= nil and Stats.HasPass(player, s.Pass)))
	elseif kind == "color" then
		local c = Config.ColorById[id]
		if not c then
			return false
		end
		return c.Tier == "base" or (c.Tier == "fantasy" and profile.FantasyColors) or (c.Tier == "neon" and Stats.HasPass(player, "neonColors"))
	elseif kind == "acc" then
		local a = Config.AccById[id]
		return a ~= nil and (profile.Accs[id] == true or (a.Pass ~= nil and Stats.HasPass(player, a.Pass)))
	elseif kind == "length" then
		return id == 1 or id == 2 or id == 3
	end
	return false
end

local function near(player: Player, pos: Vector3, dist: number): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp ~= nil and (hrp.Position - pos).Magnitude <= dist
end

local function startSession(player: Player, sess: any)
	sessions[player] = sess
	Net.Session:FireClient(player, {
		Open = true,
		Kind = sess.Kind,
		Target = sess.TargetModel,
		Request = sess.Request,
		Look = sess.Look,
		Name = sess.TargetName,
	})
end

function Salons.EndSession(player: Player, finished: boolean)
	local sess = sessions[player]
	if not sess then
		return
	end
	sessions[player] = nil
	if sess.Kind == "npc" then
		local npc = sess.Npc
		if npc.State == "styling" then
			if finished then
				payFor(sess.Salon, npc, HairBuilder.Score(npc.Request, sess.Look), true)
				leave(sess.Salon, npc, true)
			else
				npc.State = "waiting"
				if npc.Chair then
					updateChairAttrs(npc.Chair)
				end
			end
		end
	elseif sess.Kind == "player" or sess.Kind == "self" then
		local target: Player = sess.TargetPlayer
		local tProfile = Data.Get(target)
		if finished and tProfile then
			tProfile.Look = table.clone(sess.Look)
			Stats.MarkDirty(target)
			if sess.Kind == "player" then
				Net.Toast(target, "💇 " .. player.DisplayName .. " t'a fait une nouvelle coiffure !", "success")
				-- Petite récompense pour le coiffeur (limitée pour éviter les abus)
				local key = player.UserId .. ":" .. target.UserId
				if os.clock() - (lastPlayerStyle[key] or -1e9) > 120 then
					lastPlayerStyle[key] = os.clock()
					local reward = Stats.MinutesOfIncome(player, 1, 100)
					Stats.AddCash(player, reward)
					Net.Toast(player, "Merci ! +" .. Util.Money(reward) .. " pour avoir coiffé " .. target.DisplayName, "money")
				end
			end
		elseif target.Character then
			if tProfile and tProfile.Look then
				HairBuilder.Apply(target.Character, tProfile.Look)
			else
				-- Pas de coiffure sauvegardée : on remet les cheveux Roblox d'origine
				local char = target.Character
				local old = char:FindFirstChild("CustomHair")
				if old then
					old:Destroy()
				end
				task.spawn(function()
					local hum = char:FindFirstChildOfClass("Humanoid")
					local ok, desc = pcall(function()
						return Players:GetHumanoidDescriptionFromUserId(target.UserId)
					end)
					if ok and desc and hum and hum.Parent then
						pcall(function()
							hum:ApplyDescription(desc)
						end)
					end
				end)
			end
		end
		if sess.Chair then
			sess.Chair.Model:SetAttribute("Busy", false)
		end
	end
	Net.Session:FireClient(player, { Open = false })
end

local function onPrompt(prompt: ProximityPrompt, player: Player)
	local kind = prompt:GetAttribute("Kind")
	local salonFolder = prompt:FindFirstAncestorWhichIsA("Folder")
	while salonFolder and salonFolder.Parent ~= root do
		salonFolder = salonFolder:FindFirstAncestorWhichIsA("Folder")
	end
	if not salonFolder then
		return
	end
	local salon = salons[salonFolder:GetAttribute("Index")]
	if not salon or sessions[player] then
		return
	end
	local parentPart = prompt.Parent and prompt.Parent.Parent
	if not parentPart or not parentPart:IsA("BasePart") or not near(player, parentPart.Position, 14) then
		return
	end

	if kind == "mirror" then
		local profile = Data.Get(player)
		if not profile or not player.Character then
			return
		end
		startSession(player, {
			Kind = "self",
			Salon = salon,
			TargetPlayer = player,
			TargetModel = player.Character,
			TargetName = player.DisplayName,
			Look = HairBuilder.Normalize(profile.Look),
		})
	elseif kind == "upgrades" then
		if salon.Owner == player then
			Net.Notify:FireClient(player, { Type = "open", Panel = "upgrades" })
		end
	elseif kind == "style" then
		if salon.Owner ~= player then
			return
		end
		local chairModel = parentPart.Parent
		local chair = salon.Chairs[chairModel and chairModel:GetAttribute("Index") or 0]
		if not chair or chair.Model:GetAttribute("Busy") then
			return
		end
		if chair.Customer and chair.Customer.State == "waiting" then
			local npc = chair.Customer
			npc.State = "styling"
			updateChairAttrs(chair)
			startSession(player, {
				Kind = "npc",
				Salon = salon,
				Chair = chair,
				Npc = npc,
				TargetModel = npc.Model,
				TargetName = npc.Celebrity and "Célébrité" or (npc.Vip and "Client VIP" or "Client"),
				Request = npc.Request,
				Look = table.clone(npc.Look),
			})
		elseif chair.Sitter and chair.Sitter.Character then
			local target = chair.Sitter
			local tProfile = Data.Get(target)
			chair.Model:SetAttribute("Busy", true)
			startSession(player, {
				Kind = "player",
				Salon = salon,
				Chair = chair,
				TargetPlayer = target,
				TargetModel = target.Character,
				TargetName = target.DisplayName,
				Look = HairBuilder.Normalize(tProfile and tProfile.Look),
			})
			Net.Toast(target, "✂️ " .. player.DisplayName .. " commence ta coiffure…", "info")
		end
	elseif kind == "sit" then
		if salon.Owner == nil or salon.Owner == player or sitterOf[player] then
			return
		end
		local chairModel = parentPart.Parent
		local chair = salon.Chairs[chairModel and chairModel:GetAttribute("Index") or 0]
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not chair or chair.Customer or chair.Sitter or chair.Reserved or not hum then
			return
		end
		chair.Seat:Sit(hum)
		chair.Sitter = player
		sitterOf[player] = { salon = salon, chair = chair }
		updateChairAttrs(chair)
		Net.Toast(salon.Owner, "💺 " .. player.DisplayName .. " attend une coiffure dans ton salon !", "info")
		Net.Toast(player, "Le propriétaire du salon va te coiffer. Saute pour te lever.", "info")
		local conn
		conn = chair.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if chair.Seat.Occupant == nil then
				conn:Disconnect()
				Salons.StandUp(player)
			end
		end)
	end
end

function Salons.StandUp(player: Player)
	local info = sitterOf[player]
	if not info then
		return
	end
	sitterOf[player] = nil
	local chair = info.chair
	if chair.Sitter == player then
		chair.Sitter = nil
	end
	for stylist, sess in sessions do
		if sess.Kind == "player" and sess.TargetPlayer == player then
			Salons.EndSession(stylist, false)
		end
	end
	updateChairAttrs(chair)
end

-- Appelé par le client quand il choisit une option pendant la session.
function Salons.Apply(player: Player, field: string, value: any): (boolean, string?)
	local sess = sessions[player]
	if not sess then
		return false, "Aucune coiffure en cours"
	end
	local kinds = { style = "style", length = "length", color = "color", acc = "acc" }
	local kind = kinds[field]
	if not kind then
		return false
	end
	if not canUse(player, kind, value) then
		return false, "🔒 Pas encore débloqué"
	end
	sess.Look[field] = value
	local model = sess.TargetModel
	if model and model.Parent then
		HairBuilder.Apply(model, sess.Look)
		local head = model:FindFirstChild("Head") :: BasePart?
		if head then
			burst(head.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 180, 230), 12)
		end
	end
	if sess.Kind == "npc" then
		sess.Npc.Look = table.clone(sess.Look)
	end
	return true
end

function Salons.HasSession(player: Player): boolean
	return sessions[player] ~= nil
end

---------------------------------------------------------------------
-- Achats en jeu (argent virtuel)
---------------------------------------------------------------------
function Salons.Buy(player: Player, kind: string, id: string): (boolean, string?)
	local profile = Data.Get(player)
	if not profile then
		return false, "Chargement…"
	end
	if kind == "upgrade" then
		local def = Config.Upgrades[id]
		if not def then
			return false
		end
		local level = profile.Upgrades[id]
		local cost = def.Costs[level + 1]
		if not cost then
			return false, "Niveau maximum atteint !"
		end
		if not Stats.Spend(player, cost) then
			return false, "Pas assez d'argent"
		end
		profile.Upgrades[id] = level + 1
		Salons.Rebuild(player, id == "deco")
		Net.Toast(player, def.Icon .. " " .. def.Name .. " niveau " .. (level + 1) .. " !", "success")
	elseif kind == "style" or kind == "acc" then
		local def = kind == "style" and Config.StyleById[id] or Config.AccById[id]
		local owned = kind == "style" and profile.Styles or profile.Accs
		if not def or def.Pass or owned[id] then
			return false
		end
		if not Stats.Spend(player, def.Cost) then
			return false, "Pas assez d'argent"
		end
		owned[id] = true
		Net.Toast(player, def.Icon .. " " .. def.Name .. " débloqué ! Les clients vont le demander.", "success")
	elseif kind == "fantasy" then
		if profile.FantasyColors then
			return false
		end
		if not Stats.Spend(player, Config.FantasyColorsCost) then
			return false, "Pas assez d'argent"
		end
		profile.FantasyColors = true
		Net.Toast(player, "🎨 Teintures fantaisie débloquées !", "success")
	else
		return false
	end
	Stats.MarkDirty(player)
	return true
end

function Salons.Rebirth(player: Player): (boolean, string?)
	local profile = Data.Get(player)
	if not profile then
		return false
	end
	local cost = Config.RebirthCost(profile.Rebirths)
	if profile.Cash < cost then
		return false, "Il te faut " .. Util.Money(cost)
	end
	if sessions[player] then
		Salons.EndSession(player, false)
	end
	profile.Cash = 0
	profile.Rebirths += 1
	profile.Streak = 0
	profile.Upgrades = { chairs = 1, stylists = 0, deco = 1, pub = 0 }
	local salon = salonOf[player]
	if salon then
		for _, npc in table.clone(salon.Customers) do
			removeCustomer(salon, npc)
		end
	end
	Salons.Rebuild(player, true)
	Stats.MarkDirty(player)
	Net.Announce("🏆 " .. player.DisplayName .. " ouvre sa franchise n°" .. profile.Rebirths .. " !", GOLD)
	return true
end

function Salons.ApplyLook(player: Player)
	local profile = Data.Get(player)
	local char = player.Character
	if profile and profile.Look and char then
		HairBuilder.Apply(char, profile.Look)
	end
end

function Salons.OnPlayerRemoving(player: Player)
	if sessions[player] then
		Salons.EndSession(player, false)
	end
	for stylist, sess in sessions do
		if sess.TargetPlayer == player then
			Salons.EndSession(stylist, false)
		end
	end
	Salons.StandUp(player)
	Salons.Unassign(player)
end

-- Toutes les ProximityPrompts du jeu passent par ici.
local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.PromptTriggered:Connect(function(p, player)
	if p:IsDescendantOf(root) then
		onPrompt(p, player)
	end
end)

return Salons
