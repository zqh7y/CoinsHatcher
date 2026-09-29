-- Decorations: rolling hills (with bigger hazy hills behind them so the world
-- feels like it keeps going), lollipop trees, flowers, fence posts and clouds.
-- Uses a fixed seed so the map looks the same every time.
local World = require(script.Parent.World)

local Decor = {}

local rng = Random.new(2024)
local folder

-- Where each area's walls are (walls are in default.project.json).
-- The main area is round; the egg area is a rectangle.
local AREAS = {
	{ Center = World.MAIN_CENTER, Radius = World.MAIN_RADIUS },
	{ Center = World.EGG_CENTER, Radius = World.EGG_RADIUS },
}

local NEAR_HILL_COLORS = {
	Color3.fromRGB(124, 206, 94),
	Color3.fromRGB(108, 196, 84),
	Color3.fromRGB(146, 214, 104),
	Color3.fromRGB(98, 186, 90),
}
local FAR_HILL_COLORS = {
	Color3.fromRGB(120, 185, 120),
	Color3.fromRGB(110, 175, 135),
	Color3.fromRGB(135, 195, 125),
}
local TREE_COLORS = {
	Color3.fromRGB(110, 200, 90),
	Color3.fromRGB(90, 185, 100),
	Color3.fromRGB(255, 170, 205), -- pink blossom
	Color3.fromRGB(255, 205, 120), -- orange
}
local FLOWER_COLORS = {
	Color3.fromRGB(255, 110, 150),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(180, 120, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(110, 190, 255),
}
local CAP_COLORS = {
	Color3.fromRGB(255, 100, 120),
	Color3.fromRGB(255, 190, 60),
	Color3.fromRGB(120, 210, 100),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(190, 120, 255),
}

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function part(props)
	props.Material = props.Material or Enum.Material.SmoothPlastic
	props.Parent = props.Parent or folder
	return World.part(props)
end

-- How far from the area's center its wall is, in direction (dx, dz).
local function wallDistance(area, dx, dz)
	if area.Radius then
		return area.Radius
	end
	local x = if math.abs(dx) > 1e-4 then area.HalfX / math.abs(dx) else math.huge
	local z = if math.abs(dz) > 1e-4 then area.HalfZ / math.abs(dz) else math.huge
	return math.min(x, z)
end

-- Keeps hills out of the other area.
local function clearOfOtherAreas(pos, radius, selfIndex)
	for i, area in ipairs(AREAS) do
		if i ~= selfIndex then
			local keepOut = (area.Radius or math.max(area.HalfX, area.HalfZ) * 1.42) + 20
			if (pos - area.Center).Magnitude - radius < keepOut then
				return false
			end
		end
	end
	return true
end

-- Big balls sunk into the ground look like soft round hills.
local function hillRing(areaIndex, count, minSize, maxSize, gap, colors)
	local area = AREAS[areaIndex]
	for i = 1, count do
		local angle = (i + rng:NextNumber(-0.3, 0.3)) / count * math.pi * 2
		local dx, dz = math.cos(angle), math.sin(angle)
		local size = rng:NextNumber(minSize, maxSize)
		-- a ball sunk by a quarter touches the ground in a circle ~0.43 * size wide
		local dist = wallDistance(area, dx, dz) + size * 0.45 + gap + rng:NextNumber(0, 15)
		local pos = area.Center + Vector3.new(dx * dist, 0, dz * dist)
		if clearOfOtherAreas(pos, size * 0.45, areaIndex) then
			part({
				Name = "Hill",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * size,
				Position = Vector3.new(pos.X, -size * 0.25, pos.Z),
				Color = pick(colors),
			})
		end
	end
end

local function tree(pos)
	local height = rng:NextNumber(5, 9)
	local canopy = rng:NextNumber(6, 9)
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.4, 1.4),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(170, 115, 75),
		CanCollide = false,
	})
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * canopy,
		Position = pos + Vector3.new(0, height + canopy * 0.3, 0),
		Color = pick(TREE_COLORS),
		CanCollide = false,
	})
end

local function flower(pos)
	part({
		Name = "Stem",
		Size = Vector3.new(0.3, 1.4, 0.3),
		Position = pos + Vector3.new(0, 0.7, 0),
		Color = Color3.fromRGB(80, 170, 70),
		CanCollide = false,
		CastShadow = false,
	})
	part({
		Name = "Flower",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.1,
		Position = pos + Vector3.new(0, 1.6, 0),
		Color = pick(FLOWER_COLORS),
		CanCollide = false,
		CastShadow = false,
	})
end

-- A random spot just outside (or inside) an area's wall.
local function spotNearWall(area, minOffset, maxOffset, groundY)
	local angle = rng:NextNumber(0, math.pi * 2)
	local dx, dz = math.cos(angle), math.sin(angle)
	local dist = wallDistance(area, dx, dz) + rng:NextNumber(minOffset, maxOffset)
	return area.Center + Vector3.new(dx * dist, groundY, dz * dist)
end

-- Colorful posts with ball caps along the walls, like a toy fence.
local function fencePosts(area)
	local capIndex = 0
	local function post(x, z)
		capIndex += 1
		local pos = area.Center + Vector3.new(x, 0, z)
		part({
			Name = "Post",
			Size = Vector3.new(2.4, 8, 2.4),
			Position = pos + Vector3.new(0, 4, 0),
			Color = Color3.fromRGB(255, 250, 240),
		})
		part({
			Name = "Cap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3,
			Position = pos + Vector3.new(0, 9, 0),
			Color = CAP_COLORS[capIndex % #CAP_COLORS + 1],
		})
	end

	if area.Radius then
		-- one post between each of the 24 wall pieces
		for i = 0, 23 do
			local angle = (i + 0.5) / 24 * math.pi * 2
			post(math.cos(angle) * area.Radius, math.sin(angle) * area.Radius)
		end
		return
	end

	local step = 12
	for x = -area.HalfX, area.HalfX, step do
		post(x, -area.HalfZ)
		post(x, area.HalfZ)
	end
	for z = -area.HalfZ + step, area.HalfZ - step, step do
		post(-area.HalfX, z)
		post(area.HalfX, z)
	end
end

local function cloud(pos)
	for _ = 1, rng:NextInteger(3, 5) do
		local size = rng:NextNumber(12, 24)
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size,
			Position = pos + Vector3.new(rng:NextNumber(-16, 16), rng:NextNumber(-3, 4), rng:NextNumber(-8, 8)),
			Color = Color3.new(1, 1, 1),
			CanCollide = false,
			CastShadow = false,
		})
	end
end

-- Hatchery decorations -------------------------------------------------------

local PASTELS = {
	Color3.fromRGB(255, 190, 220),
	Color3.fromRGB(200, 180, 255),
	Color3.fromRGB(170, 230, 255),
	Color3.fromRGB(190, 240, 200),
	Color3.fromRGB(255, 235, 160),
}

-- a spot inside the hatchery; angle 90 is the gate side (+Z)
local function hatcherySpot(angleDegrees, dist, y)
	local a = math.rad(angleDegrees)
	return World.EGG_CENTER + Vector3.new(math.cos(a) * dist, y or World.FLOOR_Y, math.sin(a) * dist)
end

-- A candy-striped cylinder standing up.
local function candyPole(base, height, width, colorA, colorB)
	local segments = math.floor(height / 1.2)
	for i = 0, segments - 1 do
		part({
			Name = "Candy",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height / segments, width, width),
			CFrame = CFrame.new(base + Vector3.new(0, (i + 0.5) * height / segments, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if i % 2 == 0 then colorA else colorB,
		})
	end
end

-- A big spotted decoration egg.
local function bigEgg(pos, size, color)
	local tilt = CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.25, 0.25))
	local center = CFrame.new(pos + Vector3.new(0, size * 0.5, 0)) * tilt
	local egg = part({
		Name = "BigEgg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = center,
		Color = color,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(0.85, 1.15, 0.85)
	mesh.Parent = egg

	-- spots on the shell
	local spotColor = color:Lerp(Color3.new(1, 1, 1), 0.6)
	for _ = 1, 6 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1)).Unit
		local onShell = Vector3.new(dir.X * 0.85, dir.Y * 1.15, dir.Z * 0.85) * size * 0.47
		part({
			Name = "Spot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(0.9, 1.4) * size / 6,
			CFrame = center * CFrame.new(onShell),
			Color = spotColor,
			CastShadow = false,
		})
	end
end

local function balloon(anchor, height, color)
	local top = anchor + Vector3.new(rng:NextNumber(-1.2, 1.2), height, rng:NextNumber(-1.2, 1.2))
	local ball = part({
		Name = "Balloon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.4,
		Position = top,
		Color = color,
		CanCollide = false,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.2, 1)
	mesh.Parent = ball

	local bottom = top - Vector3.new(0, 1.4, 0)
	local length = (bottom - anchor).Magnitude
	part({
		Name = "String",
		Size = Vector3.new(0.08, 0.08, length),
		CFrame = CFrame.lookAt((bottom + anchor) / 2, bottom),
		Color = Color3.new(1, 1, 1),
		CanCollide = false,
		CastShadow = false,
	})
end

local function hatchery()
	-- candy gate over the arrival spot with a sign
	for _, x in ipairs({ -6, 6 }) do
		candyPole(World.EGG_CENTER + Vector3.new(x, World.FLOOR_Y, 36), 12, 1.6, Color3.fromRGB(255, 120, 160), Color3.new(1, 1, 1))
		part({
			Name = "GateCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.6,
			Position = World.EGG_CENTER + Vector3.new(x, World.FLOOR_Y + 13, 36),
			Color = Color3.fromRGB(255, 220, 90),
		})
	end
	local beam = part({
		Name = "GateBeam",
		Size = Vector3.new(14, 1.6, 1.6),
		Position = World.EGG_CENTER + Vector3.new(0, World.FLOOR_Y + 11.5, 36),
		Color = Color3.fromRGB(200, 170, 255),
	})
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 60)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	sign.MaxDistance = 150
	sign.Parent = beam
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "🥚 HATCHERY 🥚"
	text.TextColor3 = Color3.fromRGB(255, 200, 230)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(110, 50, 130)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Parent = sign

	-- giant spotted eggs around the edge
	for _, angle in ipairs({ 0, 25, 155, 180, 205, 335 }) do
		bigEgg(hatcherySpot(angle, rng:NextNumber(33, 36)), rng:NextNumber(5, 7.5), pick(PASTELS))
	end

	-- balloon bunches by the gate
	for _, angle in ipairs({ 55, 125 }) do
		local anchor = hatcherySpot(angle, 36)
		part({
			Name = "BalloonWeight",
			Size = Vector3.new(1, 1, 1),
			Position = anchor + Vector3.new(0, 0.5, 0),
			Color = Color3.fromRGB(255, 120, 160),
		})
		for i = 1, 4 do
			balloon(anchor + Vector3.new(0, 1, 0), 8 + i * 1.3, PASTELS[i])
		end
	end

	-- candy lamp posts with a warm glow
	for _, angle in ipairs({ 40, 140, 228, 312 }) do
		local base = hatcherySpot(angle, 37)
		candyPole(base, 8, 0.9, Color3.fromRGB(255, 110, 130), Color3.new(1, 1, 1))
		local bulb = part({
			Name = "LampBulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2,
			Position = base + Vector3.new(0, 9, 0),
			Color = Color3.fromRGB(255, 235, 170),
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 220, 160)
		light.Range = 18
		light.Brightness = 1.2
		light.Parent = bulb
	end

	-- soft sparkles floating in the air
	local air = part({
		Name = "SparkleAir",
		Size = Vector3.new(70, 10, 70),
		Position = World.EGG_CENTER + Vector3.new(0, 9, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Shape = Enum.ParticleEmitterShape.Box
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparkles.Rate = 10
	sparkles.Lifetime = NumberRange.new(3, 5)
	sparkles.Speed = NumberRange.new(0.5, 1.2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 230)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(210, 190, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 250, 220)),
	})
	sparkles.Parent = air
end

function Decor.build()
	folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = workspace

	-- hills: a close ring, a bigger ring behind it, and huge hazy ones far away
	hillRing(1, 18, 45, 90, 14, NEAR_HILL_COLORS)
	hillRing(1, 18, 90, 150, 50, NEAR_HILL_COLORS)
	hillRing(1, 18, 180, 320, 150, FAR_HILL_COLORS)
	hatchery()

	hillRing(2, 20, 40, 90, 10, NEAR_HILL_COLORS)
	hillRing(2, 16, 80, 140, 45, NEAR_HILL_COLORS)
	hillRing(2, 16, 160, 300, 150, FAR_HILL_COLORS)

	for index, area in ipairs(AREAS) do
		fencePosts(area)

		-- trees between the fence and the hills
		for _ = 1, if index == 1 then 30 else 24 do
			tree(spotNearWall(area, 6, 24, 0))
		end

		-- flowers outside the fence, and inside along the edges
		for _ = 1, if index == 1 then 70 else 50 do
			flower(spotNearWall(area, 3, 30, 0))
		end
		-- inside, along the fence
		for _ = 1, if index == 1 then 60 else 30 do
			flower(spotNearWall(area, if index == 1 then -12 else -9, -3, World.FLOOR_Y))
		end

		-- clouds
		for _ = 1, if index == 1 then 18 else 10 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(120, 500)
			cloud(area.Center + Vector3.new(math.cos(angle) * dist, rng:NextNumber(110, 170), math.sin(angle) * dist))
		end
	end
end

return Decor
