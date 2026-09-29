-- Decorations: rolling hills (with bigger hazy hills behind them so the world
-- feels like it keeps going), lollipop trees, flowers, fence posts and clouds.
-- Uses a fixed seed so the map looks the same every time.
local World = require(script.Parent.World)

local Decor = {}

local rng = Random.new(2024)
local folder

-- Each area's wall half-sizes (walls are in default.project.json)
local AREAS = {
	{ Center = World.MAIN_CENTER, HalfX = 131, HalfZ = 131 },
	{ Center = World.EGG_CENTER, HalfX = 61, HalfZ = 36 },
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
	local x = if math.abs(dx) > 1e-4 then area.HalfX / math.abs(dx) else math.huge
	local z = if math.abs(dz) > 1e-4 then area.HalfZ / math.abs(dz) else math.huge
	return math.min(x, z)
end

-- Keeps hills out of the other area.
local function clearOfOtherAreas(pos, radius, selfIndex)
	for i, area in ipairs(AREAS) do
		if i ~= selfIndex then
			local keepOut = math.max(area.HalfX, area.HalfZ) * 1.42 + 20
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

function Decor.build()
	folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = workspace

	-- hills: a close ring, a bigger ring behind it, and huge hazy ones far away
	hillRing(1, 34, 50, 110, 12, NEAR_HILL_COLORS)
	hillRing(1, 26, 90, 160, 50, NEAR_HILL_COLORS)
	hillRing(1, 22, 180, 340, 180, FAR_HILL_COLORS)
	hillRing(2, 20, 40, 90, 10, NEAR_HILL_COLORS)
	hillRing(2, 16, 80, 140, 45, NEAR_HILL_COLORS)
	hillRing(2, 16, 160, 300, 150, FAR_HILL_COLORS)

	for index, area in ipairs(AREAS) do
		fencePosts(area)

		-- trees between the fence and the hills
		for _ = 1, if index == 1 then 50 else 24 do
			tree(spotNearWall(area, 6, 28, 0))
		end

		-- flowers outside the fence, and inside along the edges
		for _ = 1, if index == 1 then 120 else 50 do
			flower(spotNearWall(area, 3, 30, 0))
		end
		for _ = 1, if index == 1 then 90 else 30 do
			flower(spotNearWall(area, -8, -3, World.FLOOR_Y))
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
