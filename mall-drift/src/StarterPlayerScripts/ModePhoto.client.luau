--[[
	ModePhoto  (LocalScript)
	À placer dans : StarterPlayer > StarterPlayerScripts   — nom conseillé : ModePhoto

	📸 MODE PHOTO (touche P) : pour faire de belles images et vidéos (TikTok !)
	  • toute l'interface disparaît (image propre)
	  • la caméra tourne autour de ton kart : souris (clic droit maintenu) ou Q / E,
	    molette ou I / L pour zoomer, T / G pour monter / descendre
	  • O : la caméra tourne toute seule (plan cinéma)
	  • P : on revient au jeu
	(Roblox ne permet pas de ralentir vraiment le temps : pas de vrai ralenti.)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local joueur = Players.LocalPlayer
local camera = workspace.CurrentCamera
local K = Enum.KeyCode

local actif = false
local etatsInterfaces: { [ScreenGui]: boolean } = {}
local typeCameraAvant = Enum.CameraType.Custom
local angleH, angleV, distance = 0, math.rad(18), 16
local autoRotation = false

-- Petite aide en bas de l'écran (seule chose visible en mode photo)
local aide = Instance.new("ScreenGui")
aide.Name = "AideModePhoto"
aide.ResetOnSpawn = false
aide.DisplayOrder = 200
aide.Enabled = false
aide.Parent = joueur:WaitForChild("PlayerGui")
local texteAide = Instance.new("TextLabel")
texteAide.AnchorPoint = Vector2.new(0.5, 1)
texteAide.Size = UDim2.new(0, 620, 0, 26)
texteAide.Position = UDim2.new(0.5, 0, 1, -10)
texteAide.BackgroundTransparency = 1
texteAide.TextColor3 = Color3.new(1, 1, 1)
texteAide.TextTransparency = 0.3
texteAide.Font = Enum.Font.FredokaOne
texteAide.TextScaled = true
texteAide.Text = "📸 MODE PHOTO · Q/E ou clic droit : tourner · I/L ou molette : zoom · T/G : hauteur · O : auto · P : quitter"
texteAide.Parent = aide
local contour = Instance.new("UIStroke")
contour.Thickness = 2
contour.Parent = texteAide

local function cible(): Vector3?
	local perso = joueur.Character
	local h = perso and perso:FindFirstChildOfClass("Humanoid")
	local siege = h and h.SeatPart
	local chassis = siege and siege.Parent and siege.Parent:FindFirstChild("Chassis") :: BasePart?
	if chassis then
		return chassis.Position
	end
	local racine = perso and perso:FindFirstChild("HumanoidRootPart") :: BasePart?
	return racine and racine.Position or nil
end

local function activer(oui: boolean)
	if oui == actif then
		return
	end
	actif = oui
	if oui then
		-- On cache toute l'interface (on retient ce qui était affiché)
		etatsInterfaces = {}
		for _, g in ipairs(joueur.PlayerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= aide then
				etatsInterfaces[g] = g.Enabled
				g.Enabled = false
			end
		end
		aide.Enabled = true
		typeCameraAvant = camera.CameraType
		local look = camera.CFrame.LookVector
		angleH = math.atan2(-look.X, -look.Z)
		RunService:BindToRenderStep("ModePhoto", Enum.RenderPriority.Camera.Value + 20, function(dt)
			local c = cible()
			if not c then
				return
			end
			if autoRotation then
				angleH += dt * 0.35
			end
			if UserInputService:IsKeyDown(K.Q) then
				angleH += dt * 1.6
			end
			if UserInputService:IsKeyDown(K.E) then
				angleH -= dt * 1.6
			end
			if UserInputService:IsKeyDown(K.I) then
				distance = math.max(distance - dt * 18, 4)
			end
			if UserInputService:IsKeyDown(K.L) then
				distance = math.min(distance + dt * 18, 60)
			end
			if UserInputService:IsKeyDown(K.T) then
				angleV = math.min(angleV + dt * 0.8, math.rad(80))
			end
			if UserInputService:IsKeyDown(K.G) then
				angleV = math.max(angleV - dt * 0.8, math.rad(-5))
			end
			local decalage = Vector3.new(math.sin(angleH) * math.cos(angleV), math.sin(angleV), math.cos(angleH) * math.cos(angleV)) * distance
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(c + Vector3.new(0, 1.5, 0) + decalage, c + Vector3.new(0, 1.5, 0))
		end)
	else
		RunService:UnbindFromRenderStep("ModePhoto")
		for g, etait in pairs(etatsInterfaces) do
			if g.Parent then
				g.Enabled = etait
			end
		end
		etatsInterfaces = {}
		aide.Enabled = false
		camera.CameraType = typeCameraAvant
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

UserInputService.InputBegan:Connect(function(entree, traite)
	if traite or UserInputService:GetFocusedTextBox() then
		return
	end
	if entree.KeyCode == K.P then
		activer(not actif)
	elseif actif and entree.KeyCode == K.O then
		autoRotation = not autoRotation
	elseif actif and entree.UserInputType == Enum.UserInputType.MouseButton2 then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)
UserInputService.InputEnded:Connect(function(entree)
	if actif and entree.UserInputType == Enum.UserInputType.MouseButton2 then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end)
UserInputService.InputChanged:Connect(function(entree)
	if not actif then
		return
	end
	if entree.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		angleH -= entree.Delta.X * 0.008
		angleV = math.clamp(angleV + entree.Delta.Y * 0.006, math.rad(-5), math.rad(80))
	elseif entree.UserInputType == Enum.UserInputType.MouseWheel then
		distance = math.clamp(distance - entree.Position.Z * 2, 4, 60)
	end
end)
-- Si le personnage réapparaît, on sort proprement du mode photo
joueur.CharacterAdded:Connect(function()
	activer(false)
end)
