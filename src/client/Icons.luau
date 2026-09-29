-- Clean, modern icons drawn with UI shapes (no emojis or image assets).
-- Each function draws into `parent` (which should be square) using `color`
-- plus a slightly lighter version of it for a glossy gradient.
local Icons = {}

local function shade(frame, color)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BorderSizePixel = 0
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.12))
	g.Rotation = 90
	g.Parent = frame
end

-- A shape at (x, y) center with size (w, h), all as fractions of the parent.
local function shape(parent, color, x, y, w, h, round, rotation)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = rotation or 0
	shade(f, color)
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = if round == true then UDim.new(0.5, 0) else UDim.new(round, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

function Icons.paw(parent, color)
	shape(parent, color, 0.5, 0.64, 0.46, 0.4, true)
	shape(parent, color, 0.22, 0.4, 0.18, 0.22, true)
	shape(parent, color, 0.4, 0.22, 0.18, 0.22, true)
	shape(parent, color, 0.6, 0.22, 0.18, 0.22, true)
	shape(parent, color, 0.78, 0.4, 0.18, 0.22, true)
end

function Icons.book(parent, color)
	shape(parent, color, 0.3, 0.5, 0.36, 0.68, 0.18, -4)
	shape(parent, color, 0.7, 0.5, 0.36, 0.68, 0.18, 4)
	shape(parent, Color3.new(1, 1, 1), 0.5, 0.5, 0.05, 0.66, 0.3)
end

function Icons.rebirth(parent, color)
	-- a ring with a gap, and an arrow head at the gap
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.52)
	ring.Size = UDim2.fromScale(0.66, 0.66)
	ring.BackgroundTransparency = 1
	ring.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Color = color
	stroke.Parent = ring
	local gap = Instance.new("UIGradient")
	gap.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0),
		NumberSequenceKeypoint.new(0.81, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gap.Rotation = -30
	gap.Parent = stroke
	shape(parent, color, 0.78, 0.26, 0.2, 0.2, 0.15, 45)
end

function Icons.gift(parent, color)
	shape(parent, color, 0.5, 0.64, 0.66, 0.46, 0.12)
	shape(parent, color, 0.5, 0.38, 0.76, 0.16, 0.2)
	shape(parent, Color3.new(1, 1, 1), 0.5, 0.58, 0.1, 0.6, 0.2)
	shape(parent, color, 0.38, 0.22, 0.22, 0.16, true, -25)
	shape(parent, color, 0.62, 0.22, 0.22, 0.16, true, 25)
end

function Icons.egg(parent, color)
	shape(parent, color, 0.5, 0.52, 0.56, 0.76, true)
	shape(parent, Color3.new(1, 1, 1), 0.38, 0.36, 0.12, 0.18, true, 20).BackgroundTransparency = 0.3
end

function Icons.home(parent, color)
	shape(parent, color, 0.5, 0.62, 0.56, 0.44, 0.1)
	shape(parent, color, 0.5, 0.4, 0.52, 0.52, 0.12, 45)
	shape(parent, Color3.new(1, 1, 1), 0.5, 0.7, 0.16, 0.26, 0.2)
end

function Icons.coin(parent, color)
	shape(parent, color, 0.5, 0.5, 0.84, 0.84, true)
	local inner = shape(parent, color:Lerp(Color3.new(1, 1, 1), 0.35), 0.5, 0.5, 0.56, 0.56, true)
	inner.ZIndex = 2
end

-- a little tree: a trunk with three round crowns (for the upgrade tree)
function Icons.tree(parent, color)
	shape(parent, Color3.fromRGB(150, 100, 60), 0.5, 0.78, 0.16, 0.36, 0.3)
	shape(parent, color, 0.3, 0.46, 0.4, 0.4, true)
	shape(parent, color, 0.7, 0.46, 0.4, 0.4, true)
	shape(parent, color, 0.5, 0.3, 0.46, 0.46, true)
end

function Icons.gem(parent, color)
	shape(parent, color, 0.5, 0.52, 0.62, 0.62, 0.12, 45)
	local shine = shape(parent, Color3.new(1, 1, 1), 0.42, 0.4, 0.16, 0.16, 0.2, 45)
	shine.BackgroundTransparency = 0.35
end

return Icons
