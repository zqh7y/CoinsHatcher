-- Shared UI helpers: the ScreenGui, colors, bouncy buttons, panels and toasts.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.FONT = Enum.Font.FredokaOne
Ui.COLORS = {
	Panel = Color3.fromRGB(110, 90, 190),
	PanelDark = Color3.fromRGB(80, 60, 150),
	Card = Color3.fromRGB(140, 120, 215),
	Green = Color3.fromRGB(90, 200, 100),
	Red = Color3.fromRGB(235, 90, 100),
	Gold = Color3.fromRGB(255, 205, 60),
	White = Color3.new(1, 1, 1),
	Text = Color3.new(1, 1, 1),
	Outline = Color3.fromRGB(45, 30, 80),
}

Ui.gui = Instance.new("ScreenGui")
Ui.gui.Name = "PetSimUI"
Ui.gui.ResetOnSpawn = false
Ui.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Ui.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

function Ui.corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius and radius <= 1 then UDim.new(radius, 0) else UDim.new(0, radius or 12)
	c.Parent = parent
	return c
end

function Ui.stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or Ui.COLORS.Outline
	s.Thickness = thickness or 3
	s.Parent = parent
	return s
end

-- A text label with the friendly font; props override defaults.
function Ui.label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Ui.FONT
	l.TextScaled = true
	l.TextColor3 = Ui.COLORS.Text
	l.TextStrokeTransparency = 0.4
	l.TextStrokeColor3 = Ui.COLORS.Outline
	for k, v in pairs(props or {}) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

-- Makes a button grow a bit on hover and squish when pressed.
function Ui.bounce(button)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function to(value)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		to(1.08)
	end)
	button.MouseLeave:Connect(function()
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.9)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.08)
	end)
	return button
end

-- A rounded, outlined button with text.
function Ui.button(parent, text, color, props)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Ui.FONT
	b.TextScaled = true
	b.TextColor3 = Ui.COLORS.Text
	b.TextStrokeTransparency = 0.4
	b.TextStrokeColor3 = Ui.COLORS.Outline
	b.AutoButtonColor = true
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Parent = parent
	Ui.corner(b, 12)
	Ui.stroke(b, color:Lerp(Color3.new(0, 0, 0), 0.4), 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	return Ui.bounce(b)
end

-- A square icon button: a big emoji with a tiny caption underneath.
function Ui.iconButton(parent, icon, caption, color)
	local b = Instance.new("TextButton")
	b.Name = caption
	b.BackgroundColor3 = color
	b.Text = ""
	b.AutoButtonColor = true
	b.Parent = parent
	Ui.corner(b, 18)
	Ui.stroke(b, color:Lerp(Color3.new(0, 0, 0), 0.4), 4)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	gradient.Rotation = 90
	gradient.Parent = b

	Ui.label(b, {
		Name = "Icon",
		Text = icon,
		Size = UDim2.fromScale(0.8, 0.62),
		Position = UDim2.fromScale(0.1, 0.06),
		TextStrokeTransparency = 1,
	})
	Ui.label(b, {
		Name = "Caption",
		Text = caption,
		Size = UDim2.fromScale(0.9, 0.24),
		Position = UDim2.fromScale(0.05, 0.7),
	})
	return Ui.bounce(b)
end

-- Panels ----------------------------------------------------------------------

local panels = {}

-- A pop-up window with a title and close button. Only one is open at a time.
-- theme = { top color, bottom color } for the gradient (purple by default).
-- Returns { Frame, Content, open(), close(), isOpen(), OnOpen }.
function Ui.panel(title, icon, size, theme)
	local frame = Instance.new("Frame")
	frame.Name = title
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.52)
	-- fills most of small screens, but never bigger than `size`
	local maxSize = size or UDim2.fromOffset(600, 420)
	frame.Size = UDim2.fromScale(0.92, 0.82)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Visible = false
	frame.ZIndex = 5
	frame.Parent = Ui.gui
	Ui.corner(frame, 22)
	Ui.stroke(frame, Color3.new(1, 1, 1), 4)

	local top = theme and theme[1] or Color3.fromRGB(135, 105, 230)
	local bottom = theme and theme[2] or Color3.fromRGB(85, 60, 170)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = frame

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(maxSize.X.Offset, maxSize.Y.Offset)
	sizeLimit.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 58)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.Parent = frame
	Ui.corner(header, 22)
	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new(top:Lerp(Color3.fromRGB(255, 140, 210), 0.45), top:Lerp(Color3.new(0, 0, 0), 0.2))
	headerGradient.Parent = header

	local titleLabel = Ui.label(header, {
		Name = "Title",
		Text = icon .. " " .. title,
		Size = UDim2.new(1, -140, 0, 40),
		Position = UDim2.fromOffset(20, 9),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local close = Ui.button(header, "✖", Ui.COLORS.Red, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 9),
		Size = UDim2.fromOffset(42, 40),
	})

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(14, 68)
	content.Size = UDim2.new(1, -28, 1, -82)
	content.BackgroundTransparency = 1
	content.Parent = frame

	local panel = { Frame = frame, Content = content, Title = titleLabel, OnOpen = Instance.new("BindableEvent") }

	function panel.isOpen()
		return frame.Visible
	end
	function panel.close()
		frame.Visible = false
	end
	function panel.open()
		for _, other in ipairs(panels) do
			if other ~= panel then
				other.close()
			end
		end
		frame.Visible = true
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		panel.OnOpen:Fire()
	end
	function panel.toggle()
		if frame.Visible then
			panel.close()
		else
			panel.open()
		end
	end

	close.Activated:Connect(panel.close)
	table.insert(panels, panel)
	return panel
end

-- A scrolling grid inside a panel's content.
function Ui.grid(parent, cellSize, padding)
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.ScrollBarImageColor3 = Ui.COLORS.White
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = parent

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize
	grid.CellPadding = padding or UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = list

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = list
	return list
end

function Ui.clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Toast messages ----------------------------------------------------------------

local toast = Ui.label(Ui.gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 92),
	Size = UDim2.fromOffset(520, 46),
	BackgroundTransparency = 0.1,
	BackgroundColor3 = Ui.COLORS.PanelDark,
	Visible = false,
	ZIndex = 20,
})
Ui.corner(toast, 16)
Ui.stroke(toast, Ui.COLORS.Outline, 3)
local toastPad = Instance.new("UIPadding")
toastPad.PaddingTop = UDim.new(0, 6)
toastPad.PaddingBottom = UDim.new(0, 6)
toastPad.Parent = toast

local toastId = 0
function Ui.toast(message, color)
	toastId += 1
	local id = toastId
	toast.Text = message
	toast.TextColor3 = color or Ui.COLORS.Text
	toast.Visible = true
	task.delay(3, function()
		if toastId == id then
			toast.Visible = false
		end
	end)
end

-- Chance text: 60% / 2.5% / 0.25%
function Ui.percent(chance)
	if chance >= 10 then
		return string.format("%d%%", math.floor(chance + 0.5))
	elseif chance >= 1 then
		return string.format("%.1f%%", chance)
	end
	return string.format("%.2f%%", chance)
end

return Ui
