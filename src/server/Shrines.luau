-- Egg platforms: every egg in the hatchery stands on a round platform in its
-- theme's color (Config.EGGS[i].Theme), with one themed prop placed on each
-- side behind the egg (mirrored, so it stays neat and tidy).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local World = require(script.Parent.World)

local Shrines = {}

local BALL = Enum.PartType.Ball
local CYL = Enum.PartType.Cylinder
local UP = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder up
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 70)

-- Everything for one platform is built relative to `space`: a CFrame at the
-- egg's floor center where -Z points AWAY from the walkway (the back).
-- spot(x, out, y): x = sideways, out = how far back, y = height.
local function builder(model, space)
	local b = {}

	function b.spot(x, out, y)
		return space * CFrame.new(x, y or 0, -out)
	end

	function b.part(props)
		props.Material = props.Material or Enum.Material.SmoothPlastic
		props.CanCollide = props.CanCollide or false
		props.Parent = props.Parent or model
		return World.part(props)
	end

	function b.ball(x, out, y, size, color, material)
		return b.part({ Shape = BALL, Size = Vector3.one * size, CFrame = b.spot(x, out, y), Color = color, Material = material })
	end

	-- a squashed/stretched ball (SpecialMesh)
	function b.blob(x, out, y, size, scale, color, material)
		local p = b.part({ Size = Vector3.one * size, CFrame = b.spot(x, out, y), Color = color, Material = material })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = scale
		mesh.Parent = p
		return p
	end

	function b.column(x, out, bottom, height, width, color, material)
		return b.part({
			Shape = CYL,
			Size = Vector3.new(height, width, width),
			CFrame = b.spot(x, out, bottom + height / 2) * UP,
			Color = color,
			Material = material,
		})
	end

	return b
end

-- One prop per theme, built at (x, out) standing on the platform (y = 0.5).
local Y = 0.5
local PROPS = {}

PROPS.Meadow = function(b, x, out)
	b.blob(x, out, Y + 1.2, 3.2, Vector3.new(1, 0.8, 1), Color3.fromRGB(120, 200, 90))
	for k, color in ipairs({ WHITE, Color3.fromRGB(255, 215, 70), Color3.fromRGB(255, 140, 170) }) do
		local a = k * 2.1
		b.ball(x + math.cos(a) * 0.8, out + math.sin(a) * 0.8, Y + 2.5, 0.8, color)
	end
end

PROPS.Forest = function(b, x, out)
	b.column(x, out, Y, 2, 0.8, Color3.fromRGB(130, 90, 60))
	for k, size in ipairs({ 4, 3.2, 2.2 }) do
		b.blob(x, out, Y + 1.6 + k * 1.3, size, Vector3.new(1, 0.7, 1), Color3.fromRGB(70, 150, 80):Lerp(Color3.fromRGB(120, 200, 100), k / 4))
	end
end

PROPS.Ocean = function(b, x, out)
	local color = Color3.fromRGB(255, 125, 150)
	for k, h in ipairs({ 3.4, 2.4, 2.8 }) do
		local dx = (k - 2) * 0.9
		b.column(x + dx, out + (k % 2) * 0.5, Y, h, 0.55, color)
		b.ball(x + dx, out + (k % 2) * 0.5, Y + h, 0.9, color:Lerp(WHITE, 0.3))
	end
end

PROPS.Lava = function(b, x, out)
	b.blob(x, out, Y + 1, 3.2, Vector3.new(1, 0.7, 0.9), Color3.fromRGB(70, 45, 45))
	b.blob(x, out, Y + 2.2, 1.8, Vector3.new(1, 0.6, 1), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
end

PROPS.Candy = function(b, x, out)
	b.column(x, out, Y, 4, 0.3, WHITE)
	for k, width in ipairs({ 2.6, 1.9, 1.2 }) do
		b.part({
			Shape = CYL,
			Size = Vector3.new(0.3 + k * 0.02, width, width),
			CFrame = b.spot(x, out, Y + 5) * CFrame.Angles(0, math.rad(90), 0),
			Color = if k % 2 == 1 then Color3.fromRGB(255, 120, 190) else WHITE,
		})
	end
end

PROPS.Snow = function(b, x, out)
	b.ball(x, out, Y + 1, 2.2, WHITE)
	b.ball(x, out, Y + 2.6, 1.6, WHITE)
	b.ball(x, out, Y + 3.8, 1.1, WHITE)
	b.part({ Size = Vector3.new(0.2, 0.2, 0.6), CFrame = b.spot(x, out - 0.6, Y + 3.8), Color = Color3.fromRGB(255, 140, 40) })
end

PROPS.Jungle = function(b, x, out)
	for k = 0, 3 do
		b.part({ Shape = CYL, Size = Vector3.new(1.4, 0.7, 0.7), CFrame = b.spot(x + k * 0.15, out, Y + 0.7 + k * 1.3) * UP, Color = Color3.fromRGB(150, 110, 70) })
	end
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		b.blob(x + 0.6 + math.cos(a) * 1.3, out + math.sin(a) * 1.3, Y + 5.4, 2.4, Vector3.new(1, 0.25, 0.5), Color3.fromRGB(70, 170, 80))
	end
end

PROPS.Desert = function(b, x, out)
	local green = Color3.fromRGB(90, 170, 90)
	b.column(x, out, Y, 4, 1.2, green)
	b.ball(x, out, Y + 4, 1.2, green)
	for _, side in ipairs({ -1, 1 }) do
		b.column(x + side * 1.1, out, Y + 1.6 + (side + 1) * 0.3, 1.6, 0.7, green)
	end
end

PROPS.Space = function(b, x, out)
	b.column(x, out, Y, 3, 0.3, Color3.fromRGB(200, 200, 220))
	b.ball(x, out, Y + 4, 2.2, Color3.fromRGB(150, 110, 255))
	b.part({
		Shape = CYL,
		Size = Vector3.new(0.12, 3.6, 3.6),
		CFrame = b.spot(x, out, Y + 4) * CFrame.Angles(0, 0, math.rad(70)),
		Color = Color3.fromRGB(255, 230, 140),
		Material = Enum.Material.Neon,
	})
end

PROPS.Magic = function(b, x, out)
	local color = Color3.fromRGB(190, 130, 255)
	for k, h in ipairs({ 3.2, 2.2, 2.6 }) do
		b.part({
			Size = Vector3.new(0.8, h, 0.8),
			CFrame = b.spot(x + (k - 2) * 0.7, out, Y + h / 2) * CFrame.Angles(0, math.rad(45), math.rad((k - 2) * 15)),
			Color = color:Lerp(WHITE, k * 0.1),
			Material = Enum.Material.Neon,
		})
	end
end

PROPS.Mythic = function(b, x, out)
	b.column(x, out, Y, 4.5, 1, Color3.fromRGB(255, 250, 235))
	b.part({ Size = Vector3.new(1.6, 0.5, 1.6), CFrame = b.spot(x, out, Y + 4.7), Color = GOLD })
	b.ball(x, out, Y + 5.5, 1, GOLD, Enum.Material.Neon)
end

PROPS.Party = function(b, x, out)
	local colors = { Color3.fromRGB(255, 90, 130), Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 190, 255) }
	for k = 1, 3 do
		local dx = (k - 2) * 0.9
		local h = 5 + (k % 2) * 0.8
		b.column(x + dx * 0.3, out, Y, h, 0.08, WHITE)
		b.blob(x + dx, out, Y + h + 0.9, 1.6, Vector3.new(0.9, 1.15, 0.9), colors[k])
	end
	b.part({ Size = Vector3.one * 1.4, CFrame = b.spot(x, out, Y + 0.7), Color = Color3.fromRGB(150, 110, 255) })
	b.part({ Size = Vector3.new(1.5, 1.5, 0.3), CFrame = b.spot(x, out, Y + 0.7), Color = WHITE })
end

-- Platform colors per theme
local PAD = {
	Meadow = Color3.fromRGB(190, 235, 170),
	Forest = Color3.fromRGB(150, 205, 140),
	Ocean = Color3.fromRGB(170, 220, 240),
	Lava = Color3.fromRGB(120, 80, 75),
	Candy = Color3.fromRGB(255, 200, 225),
	Snow = Color3.fromRGB(235, 245, 255),
	Jungle = Color3.fromRGB(120, 190, 110),
	Desert = Color3.fromRGB(245, 225, 175),
	Space = Color3.fromRGB(80, 70, 140),
	Magic = Color3.fromRGB(205, 180, 255),
	Mythic = Color3.fromRGB(255, 235, 170),
	Party = Color3.fromRGB(255, 220, 150),
}

-- Builds the platform for egg `eggIndex` into its model. `outward` points
-- away from the walkway (the platform's back).
function Shrines.build(model, eggIndex, floorPosition, outward)
	local egg = Config.EGGS[eggIndex]
	local space = CFrame.lookAt(floorPosition, floorPosition + outward.Unit)
	local b = builder(model, space)
	local big = egg.Release
	local radius = if big then 8 else 7

	-- two-tone round platform: a white base with a gold edge, the theme color on top
	b.part({ Name = "Platform", Shape = CYL, Size = Vector3.new(0.3, radius * 2 + 1, radius * 2 + 1), CFrame = b.spot(0, 0, 0.15) * UP, Color = WHITE, CanCollide = true })
	b.part({ Name = "PlatformEdge", Shape = CYL, Size = Vector3.new(0.12, radius * 2 + 0.4, radius * 2 + 0.4), CFrame = b.spot(0, 0, 0.36) * UP, Color = GOLD })
	b.part({
		Name = "Pad",
		Shape = CYL,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = b.spot(0, 0, 0.4) * UP,
		Color = PAD[egg.Theme] or egg.Color:Lerp(WHITE, 0.6),
		CanCollide = true,
	})

	-- the theme prop, mirrored on both sides behind the egg
	local prop = PROPS[egg.Theme]
	if prop then
		local side = if big then 5.8 else 4.8
		prop(b, -side, radius - 2.8)
		prop(b, side, radius - 2.8)
	end
end

return Shrines
