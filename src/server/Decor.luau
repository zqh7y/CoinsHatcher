-- Decorations: rolling hills (with bigger hazy hills behind them so the world
-- feels like it keeps going), lollipop trees, flowers, fence posts and clouds.
-- Uses a fixed seed so the map looks the same every time.
local CollectionService = game:GetService("CollectionService")

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
	Color3.fromRGB(100, 200, 80),
	Color3.fromRGB(80, 185, 90),
	Color3.fromRGB(120, 210, 70),
	Color3.fromRGB(255, 170, 205), -- pink blossom
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

-- A chunky cartoon tree like in pet simulator games: a thick trunk and a big
-- bubbly crown of overlapping leaf balls.
local function tree(pos)
	local height = rng:NextNumber(6, 9)
	local leaf = pick(TREE_COLORS)
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 2, 2),
		CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 95, 60),
		CanCollide = false,
	})
	local crown = pos + Vector3.new(0, height + 2, 0)
	local size = rng:NextNumber(7, 9)
	for _, offset in ipairs({ Vector3.new(0, 1.2, 0), Vector3.new(-2.4, -0.6, 0.8), Vector3.new(2.3, -0.4, -0.6), Vector3.new(0.4, -0.8, 2.4) }) do
		part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * rng:NextNumber(0.75, 1),
			Position = crown + offset,
			Color = leaf:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.12)),
			CanCollide = false,
		})
	end
end

-- Textured grass: darker/lighter patches and little grass tufts on the main
-- area floor. Tagged "FloorPatch" with a Shade (-1..1) so the client can tint
-- them to match the floor color of each rebirth.
local function floorPatch(pos, size, shade)
	local patch = part({
		Name = "GrassPatch",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, size, size * rng:NextNumber(0.6, 1)),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 200, 85),
		CastShadow = false,
		CanCollide = false,
	})
	patch:SetAttribute("Shade", shade)
	CollectionService:AddTag(patch, "FloorPatch")
end

local function grassTuft(pos)
	for k = -1, 1 do
		local blade = part({
			Name = "GrassTuft",
			Size = Vector3.new(0.3, rng:NextNumber(0.9, 1.4), 0.3),
			CFrame = CFrame.new(pos + Vector3.new(k * 0.25, 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(k * 20)),
			Color = Color3.fromRGB(90, 170, 70),
			CastShadow = false,
			CanCollide = false,
		})
		blade:SetAttribute("Shade", -0.25)
		CollectionService:AddTag(blade, "FloorPatch")
	end
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
		-- one post between each of the 24 wall pieces, with party bunting
		-- (a rope with little diamond flags) strung between them
		local posts = {}
		for i = 0, 23 do
			local angle = (i + 0.5) / 24 * math.pi * 2
			local x, z = math.cos(angle) * area.Radius, math.sin(angle) * area.Radius
			post(x, z)
			table.insert(posts, area.Center + Vector3.new(x, 7.4, z))
		end
		for i, from in ipairs(posts) do
			local to = posts[i % #posts + 1]
			local dir = (to - from).Unit
			part({
				Name = "Rope",
				Size = Vector3.new(0.1, 0.1, (to - from).Magnitude),
				CFrame = CFrame.lookAt((from + to) / 2, to),
				Color = Color3.new(1, 1, 1),
				CanCollide = false,
				CastShadow = false,
			})
			for f = 1, 3 do
				local pos = from:Lerp(to, f / 4) - Vector3.new(0, 0.55, 0)
				part({
					Name = "Flag",
					Size = Vector3.new(0.1, 0.85, 0.85),
					CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(math.rad(45), 0, 0),
					Color = CAP_COLORS[(i + f) % #CAP_COLORS + 1],
					CanCollide = false,
					CastShadow = false,
				})
			end
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

-- Detail pieces ---------------------------------------------------------------

local PASTELS = {
	Color3.fromRGB(255, 190, 220),
	Color3.fromRGB(200, 180, 255),
	Color3.fromRGB(170, 230, 255),
	Color3.fromRGB(190, 240, 200),
	Color3.fromRGB(255, 235, 160),
}

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

-- An arch of two candy poles and a beam with a sign on top (spans along X).
local function gate(base, text, poleColor, beamColor)
	for _, x in ipairs({ -6, 6 }) do
		candyPole(base + Vector3.new(x, 0, 0), 12, 1.6, poleColor, Color3.new(1, 1, 1))
		part({
			Name = "GateCap",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 2.6,
			Position = base + Vector3.new(x, 13, 0),
			Color = Color3.fromRGB(255, 220, 90),
		})
	end
	local beam = part({
		Name = "GateBeam",
		Size = Vector3.new(14, 1.6, 1.6),
		Position = base + Vector3.new(0, 11.5, 0),
		Color = beamColor,
	})
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 60)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	sign.MaxDistance = 150
	sign.Parent = beam
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 235, 200)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(110, 50, 130)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = sign
end

-- A candy lamp post with a warm glowing bulb.
local function lamp(base)
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

local BUSH_COLORS = { Color3.fromRGB(90, 180, 80), Color3.fromRGB(110, 200, 95), Color3.fromRGB(75, 160, 90) }

-- A round bush of a few green balls, sometimes with berries.
local function bush(base)
	local size = rng:NextNumber(2.5, 4)
	for _ = 1, 3 do
		part({
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * rng:NextNumber(0.8, 1.1),
			Position = base + Vector3.new(rng:NextNumber(-1.2, 1.2), size * 0.3, rng:NextNumber(-1.2, 1.2)),
			Color = pick(BUSH_COLORS),
			CanCollide = false,
		})
	end
	if rng:NextNumber() < 0.5 then
		for _ = 1, 4 do
			part({
				Name = "Berry",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.45,
				Position = base + Vector3.new(rng:NextNumber(-1.4, 1.4), size * rng:NextNumber(0.4, 0.7), rng:NextNumber(-1.4, 1.4)),
				Color = Color3.fromRGB(255, 80, 110),
				CanCollide = false,
				CastShadow = false,
			})
		end
	end
end

-- A smooth grey rock.
local function rock(base, size)
	local r = part({
		Name = "Rock",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		CFrame = CFrame.new(base + Vector3.new(0, size * 0.15, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
		Color = Color3.fromRGB(160, 160, 175):Lerp(Color3.fromRGB(200, 195, 210), rng:NextNumber()),
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1.2, 0.6, 1)
	mesh.Parent = r
end

local CAP_SHROOM = { Color3.fromRGB(255, 90, 100), Color3.fromRGB(255, 140, 200), Color3.fromRGB(170, 120, 255) }

-- A cute mushroom with a spotted cap.
local function mushroom(base, scale)
	part({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 0.8, 0.8) * scale,
		CFrame = CFrame.new(base + Vector3.new(0, 0.8 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 245, 225),
		CanCollide = false,
	})
	local capColor = pick(CAP_SHROOM)
	local cap = part({
		Name = "Cap",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.4 * scale,
		Position = base + Vector3.new(0, 1.7 * scale, 0),
		Color = capColor,
		CanCollide = false,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.55, 1)
	mesh.Parent = cap
	for i = 1, 4 do
		local a = i * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		part({
			Name = "CapSpot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.4 * scale,
			Position = base + Vector3.new(math.cos(a) * 0.6 * scale, 2.2 * scale, math.sin(a) * 0.6 * scale),
			Color = Color3.new(1, 1, 1),
			CanCollide = false,
			CastShadow = false,
		})
	end
end

-- Round stepping stones from one point to another.
local function stonePath(from, to)
	local dist = (to - from).Magnitude
	local count = math.floor(dist / 3)
	local side = (to - from).Unit:Cross(Vector3.yAxis)
	for i = 0, count do
		local pos = from:Lerp(to, i / count) + side * (if i % 2 == 0 then 0.7 else -0.7)
		part({
			Name = "Stone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 2.4, 2.4),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(235, 225, 210),
			CastShadow = false,
		})
	end
end

-- A wooden bench facing `facing`.
local function bench(base, facing)
	local cf = CFrame.lookAt(base, Vector3.new(facing.X, base.Y, facing.Z))
	local wood = Color3.fromRGB(200, 140, 90)
	part({ Name = "Seat", Size = Vector3.new(5, 0.4, 1.6), CFrame = cf * CFrame.new(0, 1.4, 0), Color = wood })
	part({ Name = "Back", Size = Vector3.new(5, 1.4, 0.3), CFrame = cf * CFrame.new(0, 2.4, 0.7), Color = wood })
	for _, x in ipairs({ -2, 2 }) do
		part({ Name = "Leg", Size = Vector3.new(0.4, 1.2, 1.4), CFrame = cf * CFrame.new(x, 0.6, 0), Color = Color3.fromRGB(120, 90, 70) })
	end
end

-- A fountain with a stone basin, water and a spray of droplets.
local function fountain(base)
	local stone = Color3.fromRGB(235, 230, 245)
	local water = Color3.fromRGB(120, 200, 255)
	local function disc(name, height, width, y, color, transparency)
		return part({
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, width, width),
			CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Transparency = transparency or 0,
		})
	end
	disc("Basin", 1.2, 13, 0.6, stone)
	disc("Water", 0.2, 11.4, 1.15, water, 0.25)
	disc("Pillar", 4, 1.8, 3, stone)
	disc("Bowl", 0.7, 5.5, 5.2, stone)
	disc("BowlWater", 0.2, 4.6, 5.5, water, 0.25)
	local spout = part({
		Name = "Spout",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.4,
		Position = base + Vector3.new(0, 6.2, 0),
		Color = Color3.fromRGB(255, 190, 220),
	})
	local spray = Instance.new("ParticleEmitter")
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Rate = 45
	spray.Lifetime = NumberRange.new(0.8, 1.1)
	spray.Speed = NumberRange.new(9, 11)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Size = NumberSequence.new(0.35)
	spray.Transparency = NumberSequence.new(0.2, 0.8)
	spray.Color = ColorSequence.new(Color3.fromRGB(170, 225, 255))
	spray.LightEmission = 0.4
	spray.Parent = spout
end

-- A windmill; its blades are spun by the client (tag "Spin").
local function windmill(base, lookAt)
	local facing = CFrame.lookAt(base, Vector3.new(lookAt.X, base.Y, lookAt.Z))
	part({ Name = "Tower", Size = Vector3.new(5, 16, 5), CFrame = facing * CFrame.new(0, 8, 0), Color = Color3.fromRGB(255, 245, 230) })
	part({
		Name = "Roof",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 6.5,
		CFrame = facing * CFrame.new(0, 16, 0),
		Color = Color3.fromRGB(255, 110, 130),
	})
	part({ Name = "Door", Size = Vector3.new(1.8, 3, 0.2), CFrame = facing * CFrame.new(0, 1.5, -2.55), Color = Color3.fromRGB(170, 110, 70) })

	local blades = Instance.new("Model")
	blades.Name = "WindmillBlades"
	local hubCFrame = facing * CFrame.new(0, 13, -3)
	local hub = part({
		Name = "Hub",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.6,
		CFrame = hubCFrame,
		Color = Color3.fromRGB(255, 210, 80),
		Parent = blades,
	})
	for k = 0, 3 do
		part({
			Name = "Blade",
			Size = Vector3.new(1.6, 8, 0.2),
			CFrame = hubCFrame * CFrame.Angles(0, 0, k * math.pi / 2) * CFrame.new(0, 4.6, 0),
			Color = if k % 2 == 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(180, 220, 255),
			Parent = blades,
		})
	end
	blades.PrimaryPart = hub
	blades:SetAttribute("SpinSpeed", 0.8)
	blades.Parent = folder
	CollectionService:AddTag(blades, "Spin")
end

-- The incremental upgrades board. The client draws the buttons on the part
-- named "UpgradeBoard" (in MainArea) with a SurfaceGui.
local function upgradeBoard(base)
	local facing = CFrame.lookAt(base, Vector3.new(World.MAIN_CENTER.X, base.Y, World.MAIN_CENTER.Z))
	local frame = Color3.fromRGB(255, 190, 90)
	local screen = part({
		Name = "UpgradeBoard",
		Size = Vector3.new(22, 14, 0.6),
		CFrame = facing * CFrame.new(0, 9.5, 0),
		Color = Color3.fromRGB(40, 70, 80),
		Parent = workspace:WaitForChild("MainArea"),
	})
	-- cute frame, legs and a striped roof
	for _, x in ipairs({ -11.6, 11.6 }) do
		part({ Name = "BoardLeg", Size = Vector3.new(1.2, 17.5, 1.2), CFrame = facing * CFrame.new(x, 8.75, 0), Color = frame })
	end
	for _, y in ipairs({ 2.2, 16.8 }) do
		part({ Name = "BoardFrame", Size = Vector3.new(24.4, 0.8, 1), CFrame = facing * CFrame.new(0, y, 0), Color = frame })
	end
	for i = 0, 5 do
		part({
			Name = "BoardRoof",
			Size = Vector3.new(26 / 6, 0.6, 3.4),
			CFrame = facing * CFrame.new(-13 + 26 / 6 * (i + 0.5), 17.7, 0.4) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(90, 200, 150) else Color3.new(1, 1, 1),
		})
	end
	return screen
end

-- Main area details --------------------------------------------------------------

local SHOP_ANGLE, FOUNTAIN_ANGLE, SPAWN_ANGLE, BOARD_ANGLE = 180, 0, 90, 270

local function mainSpot(angleDegrees, dist, y)
	local a = math.rad(angleDegrees)
	return World.MAIN_CENTER + Vector3.new(math.cos(a) * dist, y or World.FLOOR_Y, math.sin(a) * dist)
end

-- is this angle clear of the spawn, shop and fountain?
local function clearAngle(angle, margin)
	for _, taken in ipairs({ SHOP_ANGLE, FOUNTAIN_ANGLE, SPAWN_ANGLE, BOARD_ANGLE }) do
		local diff = math.abs((angle - taken + 180) % 360 - 180)
		if diff < margin then
			return false
		end
	end
	return true
end

local function mainArea()
	local zoneRadius = World.COIN_ZONE / 2

	-- gold trim around the round coin zone
	local pieces = 32
	for i = 0, pieces - 1 do
		local a = (i + 0.5) / pieces * math.pi * 2
		local pos = mainSpot(math.deg(a), zoneRadius + 0.4, World.FLOOR_Y + 0.45)
		part({
			Name = "ZoneTrim",
			Size = Vector3.new(0.9, 0.5, 2 * math.pi * (zoneRadius + 0.4) / pieces + 0.2),
			CFrame = CFrame.lookAt(pos, World.MAIN_CENTER + Vector3.new(0, pos.Y, 0)) * CFrame.Angles(0, math.rad(90), 0),
			Color = if i % 2 == 0 then Color3.fromRGB(255, 205, 60) else Color3.fromRGB(255, 245, 210),
		})
	end

	-- glowing gem posts around the coin zone
	for k = 0, 7 do
		local angle = 22.5 + k * 45
		local base = mainSpot(angle, zoneRadius + 3)
		part({
			Name = "GemPost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 1, 1),
			CFrame = CFrame.new(base + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 250, 240),
		})
		local gem = part({
			Name = "Gem",
			Size = Vector3.one * 1.1,
			CFrame = CFrame.new(base + Vector3.new(0, 3, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Color = PASTELS[k % #PASTELS + 1],
			Material = Enum.Material.Neon,
			CastShadow = false,
		})
		local light = Instance.new("PointLight")
		light.Color = gem.Color
		light.Range = 8
		light.Brightness = 0.8
		light.Parent = gem
	end

	-- gate behind the spawn, benches and stone paths
	gate(World.MAIN_CENTER + World.MAIN_SPAWN + Vector3.new(0, World.FLOOR_Y, 7), "🐾 PET PARK 🐾", Color3.fromRGB(110, 190, 255), Color3.fromRGB(255, 190, 90))
	for _, x in ipairs({ -10, 10 }) do
		bench(World.MAIN_CENTER + Vector3.new(x, World.FLOOR_Y, 42), World.MAIN_CENTER)
	end
	stonePath(mainSpot(SPAWN_ANGLE, 34), mainSpot(SPAWN_ANGLE, zoneRadius + 2))
	stonePath(mainSpot(SHOP_ANGLE, zoneRadius + 2), mainSpot(SHOP_ANGLE, 32))
	stonePath(mainSpot(FOUNTAIN_ANGLE, zoneRadius + 2), mainSpot(FOUNTAIN_ANGLE, 30))

	fountain(mainSpot(FOUNTAIN_ANGLE, 38))
	upgradeBoard(mainSpot(BOARD_ANGLE, 43))
	stonePath(mainSpot(BOARD_ANGLE, zoneRadius + 2), mainSpot(BOARD_ANGLE, 38))

	for _, angle in ipairs({ 45, 135, 225, 315 }) do
		lamp(mainSpot(angle, 46))
	end

	-- bushes, mushrooms and rocks along the fence inside
	for _ = 1, 22 do
		local angle = rng:NextNumber(0, 360)
		if clearAngle(angle, 16) then
			bush(mainSpot(angle, rng:NextNumber(46.5, 48.5)))
		end
	end
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, 360)
		if clearAngle(angle, 16) then
			mushroom(mainSpot(angle, rng:NextNumber(40, 44)), rng:NextNumber(0.7, 1.2))
		end
	end
end

-- Outside both fences: bushes, rocks, mushrooms and a windmill on the hills.
local function outside(area, index)
	for _ = 1, 30 do
		bush(spotNearWall(area, 3, 26, 0))
	end
	for _ = 1, 24 do
		rock(spotNearWall(area, 4, 30, 0), rng:NextNumber(1.5, 4))
	end
	for _ = 1, 16 do
		mushroom(spotNearWall(area, 3, 22, 0), rng:NextNumber(0.9, 2))
	end
	local angle = if index == 1 then math.rad(215) else math.rad(330)
	local dist = area.Radius + 32
	windmill(area.Center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist), area.Center)
end

-- Hatchery decorations -------------------------------------------------------


-- a spot inside the hatchery; angle 90 is the gate side (+Z)
local function hatcherySpot(angleDegrees, dist, y)
	local a = math.rad(angleDegrees)
	return World.EGG_CENTER + Vector3.new(math.cos(a) * dist, y or World.FLOOR_Y, math.sin(a) * dist)
end

-- The hatchery's centerpiece: a giant glowing crystal egg floating over a
-- tiered pedestal, with little eggs orbiting it.
local function crystalEgg(base)
	local function tier(height, width, y, color, material)
		part({
			Name = "CenterTier",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, width, width),
			CFrame = CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = color,
			Material = material,
		})
	end
	tier(1, 11, 0.5, Color3.fromRGB(215, 195, 255))
	tier(0.3, 11.6, 1.05, Color3.fromRGB(255, 160, 215), Enum.Material.Neon)
	tier(1, 8, 1.6, Color3.fromRGB(255, 250, 245))
	tier(0.8, 5, 2.5, Color3.fromRGB(255, 225, 240))

	local center = base + Vector3.new(0, 8.5, 0)
	local shell = part({
		Name = "CrystalEgg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 7,
		Position = center,
		Color = Color3.fromRGB(255, 195, 235),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
		CastShadow = false,
	})
	local core = part({
		Name = "CrystalCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3.4,
		Position = center,
		Color = Color3.fromRGB(255, 150, 215),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	for _, p in ipairs({ shell, core }) do
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(0.85, 1.15, 0.85)
		mesh.Parent = p
		CollectionService:AddTag(p, "Bob") -- the client floats them
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 180, 230)
	light.Range = 22
	light.Brightness = 1.5
	light.Parent = core
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 220, 245)
	sparkles.Parent = core

	-- mini eggs orbiting around it (spun by the client)
	local orbit = Instance.new("Model")
	orbit.Name = "EggOrbit"
	local hubCFrame = CFrame.new(center) * CFrame.Angles(-math.pi / 2, 0, 0) -- local Z points up
	local hub = part({ Name = "Hub", Size = Vector3.one * 0.2, CFrame = hubCFrame, Transparency = 1, CanCollide = false, Parent = orbit })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local mini = part({
			Name = "MiniEgg",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 1.4,
			CFrame = hubCFrame * CFrame.new(math.cos(a) * 5.5, math.sin(a) * 5.5, math.sin(a * 2) * 0.6),
			Color = PASTELS[(i - 1) % #PASTELS + 1],
			CanCollide = false,
			Parent = orbit,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(0.85, 1.15, 0.85)
		mesh.Parent = mini
	end
	orbit.PrimaryPart = hub
	orbit:SetAttribute("SpinSpeed", 0.5)
	orbit.Parent = folder
	CollectionService:AddTag(orbit, "Spin")
end

local function hatchery()
	-- candy gate over the arrival spot with a sign
	gate(World.EGG_CENTER + Vector3.new(0, World.FLOOR_Y, 47), "🥚 HATCHERY 🥚", Color3.fromRGB(255, 120, 160), Color3.fromRGB(200, 170, 255))

	-- the crystal egg in the middle, and a path to it from the gate
	crystalEgg(World.EGG_CENTER + Vector3.new(0, World.FLOOR_Y, 0))
	stonePath(World.EGG_CENTER + Vector3.new(0, World.FLOOR_Y, 45), World.EGG_CENTER + Vector3.new(0, World.FLOOR_Y, 13))

	-- neat round hedges evenly spaced along the fence (gate kept clear)
	for angle = 0, 345, 15 do
		if math.abs(angle - 90) > 20 then
			local base = hatcherySpot(angle, 48.5)
			part({
				Name = "Hedge",
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 3.6,
				Position = base + Vector3.new(0, 1.6, 0),
				Color = Color3.fromRGB(100, 185, 95),
				CanCollide = false,
			})
		end
	end

	-- lamps between the shrines, just outside the walkway
	for _, angle in ipairs({ 45, 135, 225, 315 }) do
		lamp(hatcherySpot(angle, 44))
	end

	-- a few soft sparkles floating in the air
	local air = part({
		Name = "SparkleAir",
		Size = Vector3.new(90, 10, 90),
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
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(3, 5)
	sparkles.Speed = NumberRange.new(0.5, 1.2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 230)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(210, 190, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 250, 220)),
	})
	sparkles.Parent = air
end

local function texturedGrass()
	local zoneRadius = World.COIN_ZONE / 2
	for _ = 1, 45 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(zoneRadius + 3, World.MAIN_RADIUS - 5)
		floorPatch(World.MAIN_CENTER + Vector3.new(math.cos(a) * d, World.FLOOR_Y, math.sin(a) * d), rng:NextNumber(3, 8), if rng:NextNumber() < 0.6 then -0.12 else 0.12)
	end
	for _ = 1, 70 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(zoneRadius + 2, World.MAIN_RADIUS - 3)
		grassTuft(World.MAIN_CENTER + Vector3.new(math.cos(a) * d, World.FLOOR_Y, math.sin(a) * d))
	end
	-- a few on the ground outside the fences too (fixed green)
	for _, area in ipairs(AREAS) do
		for _ = 1, 40 do
			local spot = spotNearWall(area, 3, 30, 0)
			for k = -1, 1 do
				part({
					Name = "GrassTuft",
					Size = Vector3.new(0.3, rng:NextNumber(0.9, 1.4), 0.3),
					CFrame = CFrame.new(spot + Vector3.new(k * 0.25, 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(k * 20)),
					Color = Color3.fromRGB(75, 165, 60),
					CastShadow = false,
					CanCollide = false,
				})
			end
		end
	end
end

function Decor.build()
	folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = workspace

	-- hills: a close ring, a bigger ring behind it, and huge hazy ones far away
	hillRing(1, 18, 45, 90, 14, NEAR_HILL_COLORS)
	hillRing(1, 18, 90, 150, 50, NEAR_HILL_COLORS)
	hillRing(1, 18, 180, 320, 150, FAR_HILL_COLORS)
	mainArea()
	texturedGrass()
	hatchery()

	hillRing(2, 20, 40, 90, 10, NEAR_HILL_COLORS)
	hillRing(2, 16, 80, 140, 45, NEAR_HILL_COLORS)
	hillRing(2, 16, 160, 300, 150, FAR_HILL_COLORS)

	for index, area in ipairs(AREAS) do
		fencePosts(area)
		outside(area, index)

		-- trees between the fence and the hills
		for _ = 1, if index == 1 then 30 else 24 do
			tree(spotNearWall(area, 6, 24, 0))
		end

		-- flowers outside the fence, and inside along the edges
		for _ = 1, if index == 1 then 70 else 50 do
			flower(spotNearWall(area, 3, 30, 0))
		end
		-- inside, along the fence
		if index == 1 then
			for _ = 1, 60 do
				flower(spotNearWall(area, -12, -3, World.FLOOR_Y))
			end
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
