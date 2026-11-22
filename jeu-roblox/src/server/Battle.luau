-- Battle de barbiers : tous les joueurs inscrits reproduisent la même coupe,
-- en temps limité, puis le public vote. Précision + votes + vitesse = score.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HairBuilder = require(ReplicatedStorage.Shared.HairBuilder)
local HairGrid = require(ReplicatedStorage.Shared.HairGrid)
local Util = require(ReplicatedStorage.Shared.Util)
local BarberTok = require(script.Parent.BarberTok)
local Data = require(script.Parent.Data)
local Progress = require(script.Parent.Progress)
local Net = require(script.Parent.Net)
local Salons = require(script.Parent.Salons)
local Stats = require(script.Parent.Stats)
local World = require(script.Parent.World)

local P = World.Part
local B = Config.Battle
local GOLD = Color3.fromRGB(255, 200, 70)
local rng = Random.new()

local Battle = {}

local STAGE = Vector3.new(-238, 0, 0)
local CHAIR_Z = { -18, -6, 6, 18 }

local folder = Instance.new("Folder")
folder.Name = "BattleStage"
folder.Parent = Workspace

local stations = {}
local joinPrompt: ProximityPrompt
local screenLabel: TextLabel
local refDummy: Model? = nil

local phase = "idle"
local participants: { any } = {}
local voted: { [Player]: boolean } = {}

local function now()
	return Workspace:GetServerTimeNow()
end

local function setPhase(name: string, duration: number)
	phase = name
	ReplicatedStorage:SetAttribute("BattlePhase", name)
	ReplicatedStorage:SetAttribute("BattleEndsAt", now() + duration)
end

---------------------------------------------------------------------
-- Construction de la scène
---------------------------------------------------------------------
local function build()
	local wood = Color3.fromRGB(40, 30, 46)
	P({ Name = "Stage", Size = Vector3.new(28, 3, 54), Position = STAGE + Vector3.new(0, 1.5, 0), Color = wood, Material = Enum.Material.WoodPlanks, Parent = folder })
	P({ Name = "StageTrim", Size = Vector3.new(0.4, 0.4, 54), Position = STAGE + Vector3.new(14, 3, 0), Color = GOLD, Material = Enum.Material.Neon, Parent = folder })
	for i = 0, 3 do
		P({ Name = "Step", Size = Vector3.new(2, 0.75 * (i + 1), 16), Position = STAGE + Vector3.new(21 - i * 2, 0.375 * (i + 1), 0), Color = wood, Material = Enum.Material.WoodPlanks, Parent = folder })
	end
	-- Écran géant
	local screen = P({ Name = "Screen", Size = Vector3.new(50, 18, 1), CFrame = CFrame.new(STAGE + Vector3.new(-13, 13, 0)) * CFrame.Angles(0, -math.pi / 2, 0), Color = Color3.fromRGB(15, 10, 22), Parent = folder })
	P({ Name = "ScreenFrame", Size = Vector3.new(52, 20, 0.8), CFrame = CFrame.new(STAGE + Vector3.new(-13.4, 13, 0)) * CFrame.Angles(0, -math.pi / 2, 0), Color = GOLD, Material = Enum.Material.Foil, Parent = folder })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = screen
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(120, 70, 10), Color3.fromRGB(40, 20, 50))
	grad.Rotation = 90
	grad.Parent = bg
	screenLabel = Instance.new("TextLabel")
	screenLabel.Size = UDim2.fromScale(0.94, 0.9)
	screenLabel.Position = UDim2.fromScale(0.03, 0.05)
	screenLabel.BackgroundTransparency = 1
	screenLabel.Font = Enum.Font.FredokaOne
	screenLabel.TextScaled = true
	screenLabel.RichText = true
	screenLabel.TextColor3 = Color3.new(1, 1, 1)
	screenLabel.Text = "⚔️ BATTLE DE BARBIERS"
	screenLabel.Parent = bg
	-- Projecteurs
	for _, z in { -24, 24 } do
		local lamp = P({ Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = STAGE + Vector3.new(4, 24, z), Color = Color3.fromRGB(255, 240, 210), Material = Enum.Material.Neon, Parent = folder })
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Bottom
		sl.Range = 40
		sl.Angle = 70
		sl.Brightness = 3
		sl.Color = Color3.fromRGB(255, 230, 190)
		sl.Parent = lamp
		P({ Name = "Truss", Size = Vector3.new(0.8, 24, 0.8), Position = STAGE + Vector3.new(4, 12, z * 1.05), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.DiamondPlate, Parent = folder })
	end
	-- Pupitre d'inscription
	local podium = P({ Name = "JoinPodium", Size = Vector3.new(3, 4, 6), Position = STAGE + Vector3.new(26, 2, 0), Color = GOLD, Material = Enum.Material.Foil, Parent = folder })
	local att = Instance.new("Attachment")
	att.Parent = podium
	joinPrompt = Instance.new("ProximityPrompt")
	joinPrompt.Name = "battlejoin"
	joinPrompt.ActionText = "Rejoindre la Battle"
	joinPrompt.ObjectText = "⚔️ Battle de barbiers"
	joinPrompt.MaxActivationDistance = 14
	joinPrompt.RequiresLineOfSight = false
	joinPrompt.Enabled = false
	joinPrompt.Parent = att

	-- 4 postes
	for i, z in CHAIR_Z do
		local base = CFrame.new(STAGE + Vector3.new(2, 3, z)) * CFrame.Angles(0, -math.pi / 2, 0) -- face au public (+X)
		local model = Instance.new("Model")
		model.Name = "Station" .. i
		P({ Name = "ChairBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.2, 3.2), CFrame = base * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Metal, Parent = model })
		local seat = P({ Name = "Seat", Size = Vector3.new(3, 0.9, 3), CFrame = base * CFrame.new(0, 2.2, 0), Color = Color3.fromRGB(170, 20, 35), Material = Enum.Material.Leather, Parent = model })
		P({ Name = "Back", Size = Vector3.new(3, 3.4, 0.6), CFrame = base * CFrame.new(0, 4.1, 1.4), Color = Color3.fromRGB(170, 20, 35), Material = Enum.Material.Leather, Parent = model })
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromScale(7, 2)
		tag.StudsOffset = Vector3.new(0, 7.5, 0)
		tag.MaxDistance = 120
		tag.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.RichText = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = ""
		label.Parent = tag
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		tag.Parent = seat
		local vatt = Instance.new("Attachment")
		vatt.Position = Vector3.new(0, 2, 0)
		vatt.Parent = seat
		local vote = Instance.new("ProximityPrompt")
		vote.Name = "battlevote"
		vote.ActionText = "Voter 👍"
		vote.ObjectText = "Poste " .. i
		vote.MaxActivationDistance = 40
		vote.RequiresLineOfSight = false
		vote.Enabled = false
		vote:SetAttribute("Station", i)
		vote.Parent = vatt
		model.Parent = folder
		stations[i] = { Seat = seat, Label = label, Vote = vote, Base = base }
	end
end

---------------------------------------------------------------------
-- Déroulement
---------------------------------------------------------------------
local function randomReference()
	local gender = rng:NextNumber() < 0.5 and "F" or "H"
	local styles = {}
	for _, s in Config.Styles do
		if not s.Pass and (s.Gender == "U" or s.Gender == gender) then
			table.insert(styles, s)
		end
	end
	local style = styles[rng:NextInteger(1, #styles)]
	local colors = {}
	for _, c in Config.Colors do
		if c.Tier ~= "neon" then
			table.insert(colors, c)
		end
	end
	return {
		style = style.Id,
		length = rng:NextInteger(1, 3),
		fade = style.Fade and Config.Fades[rng:NextInteger(1, #Config.Fades)].Id or "aucun",
		beard = gender == "H" and Config.Beards[rng:NextInteger(1, #Config.Beards)].Id or "aucune",
		color = colors[rng:NextInteger(1, #colors)].Id,
		acc = "aucun",
		gender = gender,
	},
		gender
end

local function seatNpc(station, look): Model?
	local model = Salons.MakeHumanoid()
	if not model then
		return nil
	end
	model.Name = "BattleClient"
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
	hrp.Anchored = true
	model:PivotTo(station.Seat.CFrame * CFrame.new(0, 2.1, 0))
	model.Parent = folder
	HairBuilder.Apply(model, look)
	local npc = { Model = model, Humanoid = model:FindFirstChildOfClass("Humanoid") }
	Salons.LoadTracks(npc)
	Salons.SetAnim(npc, "sit")
	return model
end

function Battle.Join(player: Player): (boolean, string?)
	if phase ~= "lobby" then
		return false, "Pas de Battle en ce moment"
	end
	if #participants >= B.MaxPlayers then
		return false, "La Battle est complète !"
	end
	for _, p in participants do
		if p.Player == player then
			return false, "Tu es déjà inscrit"
		end
	end
	if Salons.HasSession(player) then
		return false, "Termine ta coupe d'abord"
	end
	table.insert(participants, { Player = player, Name = player.DisplayName })
	Net.Toast(player, "⚔️ Inscrit à la Battle ! Elle commence bientôt.", "success")
	local char = player.Character
	if char then
		char:PivotTo(CFrame.new(STAGE + Vector3.new(10, 6, CHAIR_Z[#participants])))
	end
	return true
end

local function cleanup()
	for _, p in participants do
		if p.Model then
			p.Model:Destroy()
		end
	end
	if refDummy then
		refDummy:Destroy()
		refDummy = nil
	end
	for _, st in stations do
		st.Label.Text = ""
		st.Vote.Enabled = false
	end
	participants = {}
	voted = {}
end

local function runBattle()
	-- 1. Inscriptions
	setPhase("lobby", B.Lobby)
	joinPrompt.Enabled = true
	Net.Announce("⚔️ BATTLE DE BARBIERS dans " .. B.Lobby .. " s ! Va sur la grande scène pour t'inscrire.", GOLD)
	local t0 = os.clock()
	while os.clock() - t0 < B.Lobby and #participants < B.MaxPlayers do
		screenLabel.Text = string.format("⚔️ BATTLE DE BARBIERS\n<font size='60'>Inscriptions : %d/%d  •  %ds</font>", #participants, B.MaxPlayers, math.ceil(B.Lobby - (os.clock() - t0)))
		task.wait(0.5)
	end
	joinPrompt.Enabled = false
	-- Retire ceux qui sont partis
	for i = #participants, 1, -1 do
		if not participants[i].Player.Parent then
			table.remove(participants, i)
		end
	end
	if #participants == 0 then
		cleanup()
		return
	end
	if #participants == 1 then
		table.insert(participants, { Player = nil, Name = "🤖 Robot Barbier", Bot = true })
	end

	-- 2. La coupe
	local reference, gender = randomReference()
	local refText = HairBuilder.Describe(reference)
	ReplicatedStorage:SetAttribute("BattleRef", refText)
	screenLabel.Text = "✂️ REPRODUIS CETTE COUPE :\n<font size='70' color='#FFD25A'>" .. refText .. "</font>"
	-- Mannequin modèle au centre de la scène
	refDummy = Salons.MakeHumanoid()
	if refDummy then
		refDummy.Name = "Reference"
		local hrp = refDummy:FindFirstChild("HumanoidRootPart") :: BasePart
		hrp.Anchored = true
		refDummy:PivotTo(CFrame.new(STAGE + Vector3.new(-7, 6.2, 0)) * CFrame.Angles(0, -math.pi / 2, 0))
		refDummy.Parent = folder
		HairGrid.Apply(refDummy, HairGrid.Target(reference))
		Salons.Burst(hrp.Position + Vector3.new(0, 3, 0), GOLD, 60)
	end

	local battleStart = HairGrid.Encode(HairGrid.Overgrown(reference, "brun", Random.new(rng:NextInteger(1, 1e6))))
	local targetCut = HairGrid.Target(reference)
	local start = now()
	for i, part in participants do
		local station = stations[i]
		local messy = { style = gender == "F" and "lisse" or "afro", length = 3, fade = "aucun", beard = gender == "H" and "pleine" or "aucune", color = "brun", acc = "aucun" }
		-- Même point de départ pour tout le monde : la coupe cible + de la repousse
		part.Before = battleStart
		part.Model = seatNpc(station, messy)
		station.Label.Text = part.Name
		part.Votes = 0
		if part.Bot then
			part.Accuracy = rng:NextNumber(0.55, 0.9)
			part.Time = B.Duration * rng:NextNumber(0.6, 0.95)
			task.delay(part.Time, function()
				if part.Model and part.Model.Parent then
					-- Le robot coupe « presque » bien
					local cut = HairGrid.Clone(targetCut)
					for k = 1, #cut.L do
						cut.L[k] = math.max(0, cut.L[k] + rng:NextNumber(-0.25, 0.25) * (1 - part.Accuracy))
					end
					HairGrid.Apply(part.Model, cut)
				end
			end)
		elseif part.Model then
			local player: Player = part.Player
			local duration = B.Duration + (Stats.HasPass(player, "battlePro") and 15 or 0)
			local char = player.Character
			if char then
				char:PivotTo(station.Base * CFrame.new(-2.8, 3, 0.5) * CFrame.Angles(0, math.pi / 2, 0))
			end
			part.EndsAt = start + duration
			Salons.OpenSession(player, {
				Kind = "battle",
				AllowAll = true,
				Salon = nil,
				Request = reference,
				Start = battleStart,
				TargetModel = part.Model,
				TargetName = "Battle",
				EndsAt = part.EndsAt,
				OnEnd = function(finished, cut)
					part.Final = cut
					part.Accuracy = cut and HairGrid.Score(cut, targetCut) or 0
					if cut and part.Model and part.Model.Parent then
						HairGrid.Apply(part.Model, cut) -- le public voit le résultat
					end
					part.Time = math.min(now() - start, duration)
					part.Done = true
					if finished then
						Net.Toast(player, "✅ Coupe rendue ! Ressemblance " .. math.floor(part.Accuracy * 100) .. "%", "success")
					end
				end,
			})
		end
	end
	setPhase("cut", B.Duration)
	local longest = B.Duration + 15
	while now() - start < longest do
		local allDone = true
		for _, part in participants do
			if not part.Bot and not part.Done then
				if part.Player and part.Player.Parent and now() >= (part.EndsAt or 0) then
					-- Temps écoulé : on demande la coupe au client, puis on la prend telle quelle
					if not part.TimeoutAt then
						part.TimeoutAt = now()
						Salons.RequestFinish(part.Player)
					elseif now() - part.TimeoutAt > 4 then
						Salons.EndSession(part.Player, false)
					end
					allDone = false
				elseif part.Player and part.Player.Parent then
					allDone = false
				end
			end
		end
		if allDone and now() - start > 5 then
			break
		end
		task.wait(0.5)
	end

	-- 3. Vote du public
	setPhase("vote", B.Vote)
	screenLabel.Text = "👍 VOTEZ POUR LA MEILLEURE COUPE !\n<font size='60'>Approche-toi d'un poste et appuie sur E</font>"
	Net.Announce("👍 Votez pour la meilleure coupe de la Battle !", GOLD)
	for i, part in participants do
		if part.Model then
			stations[i].Vote.Enabled = true
		end
	end
	local voteStart = os.clock()
	while os.clock() - voteStart < B.Vote do
		for i, part in participants do
			stations[i].Label.Text = part.Name .. "\n👍 " .. (part.Votes or 0)
		end
		task.wait(0.5)
	end
	for _, st in stations do
		st.Vote.Enabled = false
	end

	-- 4. Résultats
	for _, part in participants do
		local accuracy = part.Accuracy or 0
		local speed = part.Time and math.clamp(1 - part.Time / B.Duration, 0, 1) or 0
		part.Score = math.floor(accuracy * 100 + (part.Votes or 0) * 10 + speed * 10)
	end
	table.sort(participants, function(a, b)
		return a.Score > b.Score
	end)
	local winner = participants[1]
	setPhase("results", 10)
	screenLabel.Text = "🏆 " .. winner.Name .. " GAGNE !\n<font size='60'>" .. winner.Score .. " points</font>"
	Net.Announce("🏆 " .. winner.Name .. " remporte la Battle de barbiers avec " .. winner.Score .. " pts !", GOLD)
	for rank, part in participants do
		local player: Player? = part.Player
		local profile = player and player.Parent and Data.Get(player)
		if player and profile then
			local share = rank == 1 and 1 or (rank == 2 and 0.5 or 0.2)
			local prize = Stats.MinutesOfIncome(player, B.PrizeMinutes, B.PrizeMin) * share
			if Stats.HasPass(player, "battlePro") then
				prize *= 2
			end
			Stats.AddCash(player, prize, false)
			Progress.AddXp(player, Config.Xp.Battle + (rank == 1 and Config.Xp.BattleWin or 0))
			Progress.Task(player, "battle", 1)
			if rank == 1 and part.Final then
				BarberTok.Post(player, part.Before, HairGrid.Encode(part.Final), "🏆 Gagnant de la Battle !")
			end
			if rank == 1 then
				profile.BattleWins += 1
				profile.Trophies += 1
				Net.Notify:FireClient(player, { Type = "celebrate" })
			end
			Stats.MarkDirty(player)
			Net.Notify:FireClient(player, { Type = "battleResult", Rank = rank, Score = part.Score, Prize = math.floor(prize), Count = #participants })
			Net.Toast(player, string.format("⚔️ %de place (%d pts) : +%s", rank, part.Score, Util.Money(prize)), "money")
		end
	end
	for i, part in participants do
		if part.Model then
			local head = part.Model:FindFirstChild("Head") :: BasePart?
			if head and part == winner then
				Salons.Burst(head.Position + Vector3.new(0, 2, 0), GOLD, 80)
			end
		end
		stations[i].Label.Text = (part == winner and "🏆 " or "") .. part.Name .. "\n" .. (part.Score or 0) .. " pts"
	end
	task.wait(10)
	cleanup()
end

function Battle.Init()
	build()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if not prompt:IsDescendantOf(folder) then
			return
		end
		if prompt.Name == "battlejoin" then
			local ok, msg = Battle.Join(player)
			if not ok and msg then
				Net.Toast(player, msg, "error")
			end
		elseif prompt.Name == "battlevote" and phase == "vote" then
			local index = prompt:GetAttribute("Station")
			local part = participants[index]
			if not part or voted[player] then
				return
			end
			if part.Player == player then
				Net.Toast(player, "Tu ne peux pas voter pour toi 😄", "error")
				return
			end
			voted[player] = true
			part.Votes = (part.Votes or 0) + 1
			Net.Toast(player, "👍 Vote enregistré pour " .. part.Name, "success")
		end
	end)
	task.spawn(function()
		ReplicatedStorage:SetAttribute("BattlePhase", "idle")
		while true do
			setPhase("idle", B.Interval)
			local waitStart = os.clock()
			while os.clock() - waitStart < B.Interval do
				screenLabel.Text = "⚔️ BATTLE DE BARBIERS\n<font size='60'>Prochaine battle dans " .. Util.Time(B.Interval - (os.clock() - waitStart)) .. "</font>"
				task.wait(1)
			end
			if #Players:GetPlayers() > 0 then
				local ok, err = pcall(runBattle)
				if not ok then
					warn("[Battle] erreur :", err)
					cleanup()
				end
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	voted[player] = nil
end)

return Battle
