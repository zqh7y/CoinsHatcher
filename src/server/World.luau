-- Builds the two areas: the main area (coins) and the egg area (hatching).
-- Swap these for your own builds later; just keep the part names the same.
local World = {}

World.MAIN_CENTER = Vector3.new(0, 0, 0)
World.MAIN_RADIUS = 51 -- the round main area's wall (floor is 104 wide)
World.COIN_ZONE = 50 -- coins spawn in this square in the middle
World.MAIN_SPAWN = Vector3.new(0, 0, 38) -- spawn pad, between the coins and the wall
World.EGG_CENTER = Vector3.new(0, 0, 1000)
World.FLOOR_Y = 1 -- top of both floors

local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

World.part = part

local function folder(name)
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

-- The map lives in default.project.json so you can see and edit it in Studio.
-- This only builds the pieces that are missing, as a fallback.
function World.build()
	local main = folder("MainArea")
	if not main:FindFirstChild("Floor") then
		part({
			Name = "Floor",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, World.MAIN_RADIUS * 2 + 2, World.MAIN_RADIUS * 2 + 2),
			CFrame = CFrame.new(World.MAIN_CENTER + Vector3.new(0, World.FLOOR_Y - 0.5, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 210, 90), -- the client recolors this by rebirth
			Material = Enum.Material.SmoothPlastic,
			Parent = main,
		})
	end
	if not main:FindFirstChild("Spawn") then
		part({
			ClassName = "SpawnLocation",
			Name = "Spawn",
			Size = Vector3.new(8, 1, 8),
			Position = World.MAIN_CENTER + World.MAIN_SPAWN + Vector3.new(0, World.FLOOR_Y + 0.5, 0),
			Duration = 0,
			Parent = main,
		})
	end

	local eggs = folder("EggArea")
	if not eggs:FindFirstChild("Floor") then
		part({
			Name = "Floor",
			Size = Vector3.new(120, 1, 70),
			Position = World.EGG_CENTER + Vector3.new(0, World.FLOOR_Y - 0.5, 0),
			Color = Color3.fromRGB(235, 220, 255),
			Material = Enum.Material.SmoothPlastic,
			Parent = eggs,
		})
	end
end

-- Where a player lands when they teleport to an area.
function World.spawnCFrame(area: string): CFrame
	local center = if area == "Eggs"
		then World.EGG_CENTER + Vector3.new(0, 0, 20)
		else World.MAIN_CENTER + World.MAIN_SPAWN
	return CFrame.new(center + Vector3.new(0, World.FLOOR_Y + 3, 0))
end

function World.isInMainArea(position: Vector3): boolean
	local offset = position - World.MAIN_CENTER
	local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
	return flat <= World.MAIN_RADIUS + 5 and offset.Y < 50
end

function World.randomCoinPosition(): Vector3
	local half = World.COIN_ZONE / 2 - 3 -- keep big coins inside the zone
	local x = math.random(-half, half)
	local z = math.random(-half, half)
	return World.MAIN_CENTER + Vector3.new(x, World.FLOOR_Y, z)
end

return World
