-- Builds the two areas: the main area (coins) and the egg area (hatching).
-- Swap these for your own builds later; just keep the part names the same.
local World = {}

World.MAIN_CENTER = Vector3.new(0, 0, 0)
World.MAIN_SIZE = 240 -- coins spawn inside this square
World.EGG_CENTER = Vector3.new(0, 0, 1000)
World.FLOOR_Y = 1 -- top of both floors

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

function World.build()
	local main = Instance.new("Folder")
	main.Name = "MainArea"
	main.Parent = workspace

	part({
		Name = "Floor",
		Size = Vector3.new(World.MAIN_SIZE + 20, 1, World.MAIN_SIZE + 20),
		Position = World.MAIN_CENTER + Vector3.new(0, World.FLOOR_Y - 0.5, 0),
		Color = Color3.fromRGB(106, 176, 76), -- the client recolors this by rebirth
		Material = Enum.Material.Grass,
		Parent = main,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = World.MAIN_CENTER + Vector3.new(0, World.FLOOR_Y + 0.5, 0)
	spawn.Duration = 0
	spawn.Parent = main

	local eggs = Instance.new("Folder")
	eggs.Name = "EggArea"
	eggs.Parent = workspace

	part({
		Name = "Floor",
		Size = Vector3.new(120, 1, 70),
		Position = World.EGG_CENTER + Vector3.new(0, World.FLOOR_Y - 0.5, 0),
		Color = Color3.fromRGB(230, 220, 200),
		Material = Enum.Material.Sand,
		Parent = eggs,
	})
end

-- Where a player lands when they teleport to an area.
function World.spawnCFrame(area: string): CFrame
	local center = if area == "Eggs" then World.EGG_CENTER + Vector3.new(0, 0, 20) else World.MAIN_CENTER
	return CFrame.new(center + Vector3.new(0, World.FLOOR_Y + 3, 0))
end

function World.isInMainArea(position: Vector3): boolean
	local offset = position - World.MAIN_CENTER
	local half = World.MAIN_SIZE / 2 + 10
	return math.abs(offset.X) <= half and math.abs(offset.Z) <= half and offset.Y < 50
end

function World.randomCoinPosition(): Vector3
	local half = World.MAIN_SIZE / 2
	local x, z
	repeat
		x = math.random(-half, half)
		z = math.random(-half, half)
	until math.abs(x) > 12 or math.abs(z) > 12 -- keep the spawn pad clear
	return World.MAIN_CENTER + Vector3.new(x, World.FLOOR_Y, z)
end

return World
