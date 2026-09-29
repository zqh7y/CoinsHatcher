-- Shared UI helpers and the game's look: clean white panels, dark text,
-- bright accent buttons and a modern font. Also bouncy buttons, panels,
-- grids and toasts.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = {}

Ui.FONT = Enum.Font.GothamBold
Ui.FONT_BODY = Enum.Font.GothamMedium
Ui.COLORS = {
	Panel = Color3.new(1, 1, 1),
	Soft = Color3.fromRGB(245, 246, 250), -- cards and rows on a white panel
	Line = Color3.fromRGB(226, 229, 238), -- thin borders and dividers
	Text = Color3.fromRGB(30, 33, 48),
	SubText = Color3.fromRGB(125, 130, 148),
	Accent = Color3.fromRGB(95, 110, 255),
	Accent2 = Color3.fromRGB(175, 95, 255),
	Green = Color3.fromRGB(35, 200, 125),
	Red = Color3.fromRGB(255, 85, 105),
	Gold = Color3.fromRGB(255, 180, 35),
	Gem = Color3.fromRGB(45, 185, 255),
	White = Color3.new(1, 1, 1),
	Disabled = Color3.fromRGB(205, 209, 222), -- maxed / can't afford
}
-- older names still used around the UI
Ui.COLORS.Card = Ui.COLORS.Soft
Ui.COLORS.PanelDark = Ui.COLORS.Disabled
Ui.COLORS.Outline = Ui.COLORS.Line

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
	s.Color = color or Ui.COLORS.Line
	s.Thickness = thickness or 1.5
	s.Parent = parent
	return s
end

-- A soft top-to-bottom gradient (a lighter top makes things look glossy).
function Ui.gradient(parent, top, bottom, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

-- A text label in the game font; props override defaults.
function Ui.label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Ui.FONT
	l.TextScaled = true
	l.TextColor3 = Ui.COLORS.Text
	l.TextStrokeTransparency = 1
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
		to(1.06)
	end)
	button.MouseLeave:Connect(function()
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.92)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.06)
	end)
	return button
end

local function isLight(color)
	return color.R * 0.3 + color.G * 0.59 + color.B * 0.11 > 0.75
end

-- A rounded, glossy accent button. Text is white (or dark on light colors).
function Ui.button(parent, text, color, props)
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.Text = text
	b.Font = Ui.FONT
	b.TextScaled = true
	b.TextColor3 = if isLight(color) then Ui.COLORS.Text else Ui.COLORS.White
	b.AutoButtonColor = true
	for k, v in pairs(props or {}) do
		b[k] = v
	end
	b.Parent = parent
	Ui.corner(b, 10)
	Ui.gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(220, 220, 225))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = b
	return Ui.bounce(b)
end

-- Recolors a Ui.button (keeps the text readable).
function Ui.setButtonColor(button, color)
	button.BackgroundColor3 = color
	button.TextColor3 = if isLight(color) then Ui.COLORS.Text else Ui.COLORS.White
end

-- Panels ----------------------------------------------------------------------

local panels = {}

-- dims the screen behind an open panel; clicking it closes the panel
local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
dim.BackgroundTransparency = 0.55
dim.Text = ""
dim.AutoButtonColor = false
dim.Visible = false
dim.ZIndex = 4
dim.Parent = Ui.gui

-- A white pop-up window with a title and close button. Only one is open at
-- a time. theme = { accent color } for the little bar next to the title.
-- options.Fixed = no dark backdrop and no close button (the game closes it,
-- like the shop when you step off its circle).
-- Returns { Frame, Content, Title, open(), close(), toggle(), isOpen(), OnOpen }.
function Ui.panel(title, _icon, size, theme, options)
	local fixed = options and options.Fixed
	local accent = theme and theme[1] or Ui.COLORS.Accent

	local frame = Instance.new("Frame")
	frame.Name = title
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.52)
	-- fills most of small screens, but never bigger than `size`
	local maxSize = size or UDim2.fromOffset(600, 420)
	frame.Size = UDim2.fromScale(0.92, 0.82)
	frame.BackgroundColor3 = Ui.COLORS.Panel
	frame.Visible = false
	frame.ZIndex = 5
	frame.Active = true -- clicks on the panel stay on the panel (don't reach the backdrop)
	frame.Parent = Ui.gui
	Ui.corner(frame, 20)
	Ui.stroke(frame, Ui.COLORS.Line, 1.5)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(maxSize.X.Offset, maxSize.Y.Offset)
	sizeLimit.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Parent = frame

	-- header: accent bar + title, a thin divider underneath
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(22, 20)
	bar.Size = UDim2.fromOffset(5, 26)
	bar.BackgroundColor3 = accent
	bar.Parent = frame
	Ui.corner(bar, 0.5)

	local titleLabel = Ui.label(frame, {
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -140, 0, 28),
		Position = UDim2.fromOffset(36, 19),
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(0, 64)
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundColor3 = Ui.COLORS.Line
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 14)
	close.Size = UDim2.fromOffset(38, 38)
	close.BackgroundColor3 = Ui.COLORS.Soft
	close.Text = "✕"
	close.Font = Ui.FONT
	close.TextSize = 18
	close.TextColor3 = Ui.COLORS.SubText
	close.Visible = not fixed
	close.Parent = frame
	Ui.corner(close, 0.5)
	Ui.bounce(close)

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(18, 78)
	content.Size = UDim2.new(1, -36, 1, -92)
	content.BackgroundTransparency = 1
	content.Parent = frame

	local panel = { Frame = frame, Content = content, Title = titleLabel, OnOpen = Instance.new("BindableEvent"), Fixed = fixed }

	function panel.isOpen()
		return frame.Visible
	end
	function panel.close()
		frame.Visible = false
		dim.Visible = false
	end
	function panel.open()
		for _, other in ipairs(panels) do
			if other ~= panel then
				other.close()
			end
		end
		dim.Visible = not fixed
		frame.Visible = true
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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

-- tapping the dark backdrop closes the open panel (fixed panels ignore it)
dim.Activated:Connect(function()
	for _, panel in ipairs(panels) do
		if not panel.Fixed then
			panel.close()
		end
	end
end)

-- A scrolling grid inside a panel's content.
function Ui.grid(parent, cellSize, padding)
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.fromScale(1, 1)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = Ui.COLORS.Disabled
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
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 8)
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

-- Toast messages: a white pill with a colored accent bar ------------------------

local toast = Instance.new("Frame")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 92)
toast.Size = UDim2.fromOffset(520, 46)
toast.BackgroundColor3 = Ui.COLORS.Panel
toast.Visible = false
toast.ZIndex = 20
toast.Parent = Ui.gui
Ui.corner(toast, 0.5)
Ui.stroke(toast, Ui.COLORS.Line, 1.5)

local toastBar = Instance.new("Frame")
toastBar.Position = UDim2.fromOffset(16, 13)
toastBar.Size = UDim2.fromOffset(20, 20)
toastBar.ZIndex = 21
toastBar.Parent = toast
Ui.corner(toastBar, 0.5)

local toastText = Ui.label(toast, {
	Position = UDim2.fromOffset(46, 10),
	Size = UDim2.new(1, -62, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 21,
})

local toastScale = Instance.new("UIScale")
toastScale.Parent = toast

local toastId = 0
function Ui.toast(message, color)
	toastId += 1
	local id = toastId
	toastText.Text = message
	toastBar.BackgroundColor3 = color or Ui.COLORS.Accent
	toast.Visible = true
	toastScale.Scale = 0.9
	TweenService:Create(toastScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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
