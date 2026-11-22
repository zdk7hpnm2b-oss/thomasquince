-- Tests hors Studio avec Lune (https://lune-org.github.io) : lune run tests/modules.luau .
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local ROOT = process.args[1]

local tags = {}
local services = {
	CollectionService = {
		AddTag = function(_, inst, tag)
			tags[tag] = (tags[tag] or 0) + 1
		end,
		RemoveTag = function(_, inst, tag)
			tags[tag] = (tags[tag] or 0) - 1
		end,
	},
	TweenService = {
		Create = function()
			return { Play = function() end }
		end,
	},
}
local fakeGame = {
	GetService = function(_, name)
		return services[name] or error("service " .. name)
	end,
}

local modules = {}
local function load(path, deps)
	local env = setmetatable({
		game = fakeGame,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		typeof = roblox.typeof or typeof,
		script = { Parent = deps or {} },
		require = function(m)
			return m
		end,
	}, { __index = _G })
	local src = fs.readFile(ROOT .. "/" .. path)
	local fn = luau.load(src, { debugName = path, environment = env })
	return fn()
end

local Config = load("src/shared/Config.luau")
local Util = load("src/shared/Util.luau")
local HairBuilder = load("src/shared/HairBuilder.luau", { Config = Config })

-- Util
local cases = { [0] = "0", [999] = "999", [1000] = "1K", [1500] = "1.5K", [12345] = "12.3K", [100000] = "100K", [2500000] = "2.5M", [1e9] = "1B" }
for n, want in cases do
	local got = Util.Format(n)
	assert(got == want, ("Format(%s) = %s, attendu %s"):format(n, got, want))
end
assert(Util.Time(75) == "1:15" and Util.Time(3725) == "1:02:05")
print("Util OK")

-- Économie
for key, def in Config.Upgrades do
	for i = 2, #def.Costs do
		assert(def.Costs[i] > def.Costs[i - 1], key .. " coûts non croissants")
	end
end
assert(#Config.Upgrades.pub.Interval == #Config.Upgrades.pub.Costs + 1)
assert(#Config.Upgrades.deco.Mult == #Config.Upgrades.deco.Costs)
assert(#Config.PassRewards == Config.PassTiers, "paliers du pass")
for t, r in Config.PassRewards do
	for _, side in { r.Free, r.Gold } do
		assert(side.Kind == "cash" and side.Minutes > 0 or (side.Kind == "color" and Config.ColorById[side.Id] and Config.ColorById[side.Id].Tier == "season"), "récompense palier " .. t)
	end
end
for _, s in Config.Styles do
	assert(Config.StyleById[s.Id] == s)
end
print("Config OK")

-- Toutes les coiffures × longueurs × dégradés × barbes, puis couleurs × accessoires
local function newChar()
	local char = roblox.Instance.new("Model")
	local head = roblox.Instance.new("Part")
	head.Name = "Head"
	head.Size = roblox.Vector3.new(1.2, 1.2, 1.2)
	head.Parent = char
	local hair = roblox.Instance.new("Accessory")
	hair.Name = "CoolHair"
	hair.Parent = char
	return char
end
local count = 0
local function check(look)
	local char = newChar()
	local model = HairBuilder.Apply(char, look)
	assert(model and #model:GetChildren() > 0, "vide : " .. look.style)
	assert(char:FindFirstChild("CoolHair") == nil, "cheveux Roblox non retirés")
	assert(HairBuilder.Score(look, look) == 1, "score")
	HairBuilder.Describe(look)
	count += 1
end
for _, s in Config.Styles do
	assert(s.Gender == "H" or s.Gender == "F" or s.Gender == "U", "genre manquant : " .. s.Id)
	for len = 1, 3 do
		for _, f in Config.Fades do
			for _, b in Config.Beards do
				check({ style = s.Id, length = len, fade = f.Id, beard = b.Id, color = "noir", acc = "aucun" })
			end
		end
	end
	for _, c in Config.Colors do
		for _, a in Config.Accessories do
			check({ style = s.Id, length = 2, fade = "burst", beard = "pleine", color = c.Id, acc = a.Id })
		end
	end
end
-- Réappliquer remplace bien l'ancienne
local char = roblox.Instance.new("Model")
local head = roblox.Instance.new("Part")
head.Name = "Head"
head.Parent = char
HairBuilder.Apply(char, { style = "afro" })
HairBuilder.Apply(char, { style = "royal", length = 3, color = "arcenciel", acc = "couronne" })
local n = 0
for _, c in char:GetChildren() do
	if c.Name == "CustomHair" then
		n += 1
	end
end
assert(n == 1, "plusieurs coiffures")
local norm = HairBuilder.Normalize({ style = "nope", length = 9 })
assert(norm.style == "pixie" and norm.length == 2 and norm.fade == "aucun" and norm.beard == "aucune")
print(("HairBuilder OK : %d combinaisons, tags arc-en-ciel=%d"):format(count, tags.RainbowHair or 0))

-- Interface : construit une fenêtre (valide les noms/types de propriétés)
local Ui = load("src/client/Ui.luau")
local sg = roblox.Instance.new("ScreenGui")
local f = Ui.Frame({ Parent = sg, Size = roblox.UDim2.fromScale(1, 1), AnchorPoint = roblox.Vector2.new(0.5, 0), Visible = false, ZIndex = 20, LayoutOrder = 2, Rotation = 5 })
Ui.Corner(f, 10)
Ui.Stroke(f)
Ui.Gradient(f, roblox.Color3.new(1, 1, 1), roblox.Color3.new())
Ui.Padding(f, 4)
Ui.Label({ Parent = f, Text = "x", NoStroke = true, TextXAlignment = roblox.Enum.TextXAlignment.Left, Font = roblox.Enum.Font.GothamBold, TextColor3 = roblox.Color3.new() })
Ui.Label({ Parent = f, Text = "y" })
Ui.Scroll(f)
print("Ui OK")
