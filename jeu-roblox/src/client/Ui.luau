-- Petite bibliothèque d'interface : composants arrondis, dégradés, animations.

local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.Colors = {
	Bg = Color3.fromRGB(28, 20, 44),
	Bg2 = Color3.fromRGB(44, 32, 68),
	Card = Color3.fromRGB(56, 40, 86),
	Pink = Color3.fromRGB(255, 105, 180),
	Pink2 = Color3.fromRGB(255, 160, 210),
	Gold = Color3.fromRGB(255, 200, 70),
	Green = Color3.fromRGB(90, 220, 130),
	Red = Color3.fromRGB(255, 85, 100),
	Blue = Color3.fromRGB(90, 170, 255),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(200, 185, 220),
}

function Ui.Corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 14)
	c.Parent = parent
	return c
end

function Ui.Stroke(parent: Instance, color: Color3?, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(255, 140, 210)
	s.Thickness = thickness or 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Ui.Gradient(parent: Instance, a: Color3, b: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

function Ui.Padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Ui.Frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Ui.Colors.Bg
	for k, v in props do
		if k ~= "Parent" then
			(f :: any)[k] = v
		end
	end
	f.Parent = props.Parent
	return f
end

function Ui.Label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = Ui.Colors.Text
	l.TextScaled = true
	l.RichText = true
	for k, v in props do
		if k ~= "Parent" then
			(l :: any)[k] = v
		end
	end
	if not props.NoStroke then
		local s = Instance.new("UIStroke")
		s.Thickness = 1.5
		s.Color = Color3.fromRGB(30, 10, 40)
		s.Transparency = 0.2
		s.Parent = l
	end
	l.Parent = props.Parent
	return l
end

-- Bouton avec effet de survol / clic
function Ui.Button(props: { [string]: any }, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Font = Enum.Font.FredokaOne
	b.TextScaled = true
	b.TextColor3 = Ui.Colors.Text
	b.BackgroundColor3 = Ui.Colors.Pink
	b.RichText = true
	for k, v in props do
		if k ~= "Parent" and k ~= "Radius" and k ~= "NoStroke" then
			(b :: any)[k] = v
		end
	end
	Ui.Corner(b, props.Radius or 12)
	local ts = Instance.new("UIStroke")
	ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	ts.Thickness = 1.5
	ts.Color = Color3.fromRGB(30, 10, 40)
	ts.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = props.Parent
	return b
end

function Ui.Tween(obj: Instance, time: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

function Ui.Pop(obj: GuiObject)
	local scale = obj:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = obj
	scale.Scale = 0.6
	Ui.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Fenêtre modale avec titre et bouton fermer. Renvoie (fenêtre, contenu).
function Ui.Window(parent: Instance, title: string, accent: Color3?): (Frame, Frame)
	local win = Ui.Frame({
		Name = title,
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.72),
		BackgroundColor3 = Ui.Colors.Bg,
		Visible = false,
		ZIndex = 20,
	})
	Ui.Corner(win, 22)
	Ui.Stroke(win, accent or Ui.Colors.Pink, 3)
	Ui.Gradient(win, Color3.fromRGB(60, 36, 92), Color3.fromRGB(24, 16, 38), 90)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(820, 600)
	limit.MinSize = Vector2.new(300, 260)
	limit.Parent = win
	local header = Ui.Frame({ Parent = win, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = accent or Ui.Colors.Pink, ZIndex = 21 })
	Ui.Corner(header, 22)
	Ui.Gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200), 90)
	Ui.Frame({ Parent = header, Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = accent or Ui.Colors.Pink, ZIndex = 21 })
	Ui.Label({ Parent = header, Text = title, Size = UDim2.new(1, -80, 0, 40), Position = UDim2.fromOffset(20, 8), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 })
	Ui.Button({ Parent = header, Text = "✕", Size = UDim2.fromOffset(42, 42), Position = UDim2.new(1, -50, 0, 7), BackgroundColor3 = Ui.Colors.Red, ZIndex = 23 }, function()
		win.Visible = false
	end)
	local content = Ui.Frame({ Parent = win, Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 68), Size = UDim2.new(1, -32, 1, -84), ZIndex = 21 })
	return win, content
end

function Ui.Scroll(parent: Instance, padding: number?): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = UDim2.fromScale(1, 1)
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = Ui.Colors.Pink2
	s.ZIndex = 21
	s.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, padding or 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = s
	return s
end

return Ui
