-- Decorated eggs: a glossy egg-shaped shell with a pattern (spots, bands,
-- stripes, cracks, sprinkles or stars) and a painted shine highlight, styled
-- per egg theme. Used for the eggs in the hatchery, the egg popup and the
-- hatch animation, so they all look the same.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local EggModel = {}

local WHITE = Color3.new(1, 1, 1)
local UP = CFrame.Angles(0, 0, math.rad(90)) -- stands a cylinder up
EggModel.SHAPE = Vector3.new(0.85, 1.15, 0.85) -- egg-shaped sphere mesh scale

-- Pattern + accent color per theme. Neon = the pattern glows.
local STYLES = {
	Meadow = { Pattern = "spots", Accent = Color3.fromRGB(255, 180, 110), Accent2 = Color3.fromRGB(150, 215, 120) },
	Forest = { Pattern = "spots", Accent = Color3.fromRGB(55, 110, 45), Accent2 = Color3.fromRGB(150, 200, 90) },
	Ocean = { Pattern = "bands", Accent = WHITE },
	Lava = { Pattern = "cracks", Accent = Color3.fromRGB(255, 130, 30), Neon = true, Shell = Color3.fromRGB(70, 40, 40) },
	Candy = { Pattern = "sprinkles" },
	Snow = { Pattern = "spots", Accent = Color3.fromRGB(140, 200, 255), Accent2 = WHITE },
	Jungle = { Pattern = "stripes", Accent = Color3.fromRGB(35, 85, 40) },
	Desert = { Pattern = "bands", Accent = Color3.fromRGB(190, 130, 70) },
	Space = { Pattern = "stars", Accent = Color3.fromRGB(255, 240, 150), Neon = true, Shell = Color3.fromRGB(55, 40, 110) },
	Magic = { Pattern = "bands", Accent = Color3.fromRGB(255, 190, 255), Neon = true },
	Mythic = { Pattern = "bands", Accent = Color3.fromRGB(255, 215, 80), Gem = true },
	Party = { Pattern = "sprinkles", Gem = true, Shell = Color3.fromRGB(255, 205, 70), Band = Color3.fromRGB(255, 90, 150) },
	Exclusive = { Pattern = "stars", Accent = Color3.fromRGB(120, 240, 255), Neon = true, Gem = true, Shell = Color3.fromRGB(60, 25, 110), Band = Color3.fromRGB(255, 110, 220) },
}

-- An egg's settings: a number is an egg in Config.EGGS, "Exclusive" is the
-- token shop's Exclusive Egg.
local function eggInfo(eggIndex)
	return if eggIndex == "Exclusive" then Config.EXCLUSIVE_EGG else Config.EGGS[eggIndex]
end

local SPRINKLES = {
	Color3.fromRGB(255, 90, 110),
	Color3.fromRGB(255, 220, 70),
	Color3.fromRGB(110, 210, 120),
	Color3.fromRGB(90, 170, 255),
	WHITE,
}

-- The shell color for an egg (some themes use a darker shell).
function EggModel.shellColor(eggIndex)
	local egg = eggInfo(eggIndex)
	local style = STYLES[egg.Theme] or {}
	return style.Shell or egg.Color
end

-- Adds the pattern and highlight around `shell` (a Ball part sized like an
-- egg, with EggModel.SHAPE mesh). Parts go into `parent`, all anchored.
function EggModel.decorate(shell, eggIndex, parent)
	local egg = eggInfo(eggIndex)
	local style = STYLES[egg.Theme] or { Pattern = "spots", Accent = WHITE }
	local rng = Random.new(if typeof(eggIndex) == "number" then eggIndex * 31 else 777)
	local size = shell.Size.X
	local k = size / 6 -- everything below is designed for a 6-stud egg
	local a, c = size / 2 * EggModel.SHAPE.X, size / 2 * EggModel.SHAPE.Y -- egg radii (side, up)
	local center = shell.CFrame

	local function add(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = if style.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		for key, value in pairs(props) do
			p[key] = value
		end
		p.Parent = parent
		return p
	end

	-- A point on the egg's surface in direction `dir`, and the outward normal there.
	local function surface(dir)
		dir = dir.Unit
		local t = 1 / math.sqrt((dir.X / a) ^ 2 + (dir.Y / c) ^ 2 + (dir.Z / a) ^ 2)
		local point = dir * t
		local normal = Vector3.new(point.X / a ^ 2, point.Y / c ^ 2, point.Z / a ^ 2).Unit
		return point, normal
	end

	-- A flat-ish blob lying on the surface (spots, stripes, sprinkles...).
	local function onSurface(dir, partSize, color, shape, scale, spin)
		local point, normal = surface(dir)
		local cf = center * CFrame.lookAt(point - normal * 0.05 * k, point + normal) * CFrame.Angles(0, 0, spin or 0)
		-- balls are always perfectly round, so stretched shapes use a block
		-- with a sphere mesh instead
		local p = add({ Shape = if scale then Enum.PartType.Block else (shape or Enum.PartType.Ball), Size = partSize, CFrame = cf, Color = color })
		if scale then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = scale
			mesh.Parent = p
		end
		return p
	end

	local function randomDir(minY, maxY)
		local angle = rng:NextNumber(0, math.pi * 2)
		return Vector3.new(math.cos(angle), rng:NextNumber(minY or -0.7, maxY or 0.9), math.sin(angle))
	end

	local pattern = style.Pattern
	if pattern == "spots" then
		for i = 1, 11 do
			local s = rng:NextNumber(0.8, 1.4) * k
			onSurface(randomDir(), Vector3.one * s, if i % 3 == 0 and style.Accent2 then style.Accent2 else style.Accent, nil, Vector3.new(1, 1, 0.3))
		end
	elseif pattern == "bands" then
		for _, h in ipairs({ -1.2, 0, 1.2 }) do
			local y = h * k
			local width = 2 * a * math.sqrt(math.max(0, 1 - (y / c) ^ 2)) + 0.15 * k
			add({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new((if h == 0 then 0.6 else 0.35) * k, width, width),
				CFrame = center * CFrame.new(0, y, 0) * UP,
				Color = style.Accent,
			})
		end
	elseif pattern == "stripes" then
		for i = 1, 9 do
			local dir = Vector3.new(math.cos(i / 9 * math.pi * 2), rng:NextNumber(-0.4, 0.5), math.sin(i / 9 * math.pi * 2))
			onSurface(dir, Vector3.new(0.5, 2.4, 0.5) * k, style.Accent, nil, Vector3.new(1, 1, 0.4), rng:NextNumber(-0.4, 0.4))
		end
	elseif pattern == "cracks" then
		for _ = 1, 10 do
			onSurface(randomDir(), Vector3.new(0.18, 1.6, 0.18) * k, style.Accent, Enum.PartType.Block, nil, rng:NextNumber(0, math.pi))
		end
	elseif pattern == "sprinkles" then
		for i = 1, 26 do
			onSurface(randomDir(), Vector3.new(0.22, 0.6, 0.22) * k, SPRINKLES[i % #SPRINKLES + 1], Enum.PartType.Block, nil, rng:NextNumber(0, math.pi))
		end
	elseif pattern == "stars" then
		for _ = 1, 12 do
			local s = rng:NextNumber(0.3, 0.55) * k
			onSurface(randomDir(), Vector3.new(s, s, 0.1 * k), style.Accent, Enum.PartType.Block, nil, math.rad(45))
		end
	end

	-- a ribbon around the middle (the Release egg's gift wrap)
	if style.Band then
		local width = 2 * a + 0.15 * k
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5 * k, width, width),
			CFrame = center * UP,
			Color = style.Band,
			Material = Enum.Material.SmoothPlastic,
		})
	end

	if style.Gem then
		local top = center * CFrame.new(0, c + 0.3 * k, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45))
		add({ Size = Vector3.one * 0.9 * k, CFrame = top, Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Neon })
	end

	-- painted shine: a soft white highlight near the top, and a small one
	-- under it
	local highlight = onSurface(Vector3.new(-0.45, 0.8, -0.5), Vector3.new(1.1, 1.6, 0.2) * k, WHITE, nil, Vector3.new(1, 1, 0.3), 0.4)
	highlight.Material = Enum.Material.SmoothPlastic
	highlight.Transparency = 0.35
	local dot = onSurface(Vector3.new(-0.62, 0.25, -0.62), Vector3.new(0.45, 0.45, 0.15) * k, WHITE, nil, Vector3.new(1, 1, 0.3))
	dot.Material = Enum.Material.SmoothPlastic
	dot.Transparency = 0.45

	-- a soft glowing aura around the egg in its color
	local aura = add({
		Name = "Aura",
		Shape = Enum.PartType.Block,
		Size = shell.Size * 1.12,
		CFrame = center,
		Color = egg.Color,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
	})
	local auraMesh = Instance.new("SpecialMesh")
	auraMesh.MeshType = Enum.MeshType.Sphere
	auraMesh.Scale = EggModel.SHAPE
	auraMesh.Parent = aura
end

-- A complete decorated egg (for previews): a Model whose PrimaryPart is the shell.
function EggModel.build(eggIndex, size)
	local model = Instance.new("Model")
	model.Name = eggInfo(eggIndex).Name

	local shell = Instance.new("Part")
	shell.Name = "Egg"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.one * (size or 6)
	shell.Color = EggModel.shellColor(eggIndex)
	shell.Material = Enum.Material.SmoothPlastic
	shell.Reflectance = 0.2
	shell.Anchored = true
	shell.CanCollide = false
	shell.CFrame = CFrame.new()
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = EggModel.SHAPE
	mesh.Parent = shell
	shell.Parent = model
	model.PrimaryPart = shell

	EggModel.decorate(shell, eggIndex, model)
	return model
end

return EggModel
