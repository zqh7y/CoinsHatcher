-- Builds a pet model: a cute cube with a face, feet, ears, tail and extras.
-- Used by the server for real pets and by the client for previews (index,
-- egg popup, hatch animation). Looks are set in Config.PET_LOOKS.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PetModel = {}

PetModel.SIZE = 2.2

-- How high the body's center sits above the ground (feet underneath).
function PetModel.lift(petName: string): number
	local info = Config.PETS[petName]
	return (PetModel.SIZE / 2 + 0.3) * (if info then info.Scale else 1)
end

local BALL = Enum.PartType.Ball
local BLACK = Color3.fromRGB(35, 30, 40)
local WHITE = Color3.new(1, 1, 1)

-- options:
--   Anchored = true  -> anchor every part (for previews; no welds needed)
--   Silhouette = true -> all black (for undiscovered pets in the index)
function PetModel.build(petName: string, options)
	options = options or {}
	local info = Config.PETS[petName]
	local look = info.Look
	local extras = look.Extras or {}
	local s = info.Scale
	local color = info.BodyColor
	local darker = color:Lerp(Color3.new(0, 0, 0), 0.15)
	local lighter = color:Lerp(WHITE, 0.4)

	local model = Instance.new("Model")
	model.Name = petName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.one * PetModel.SIZE * s
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Parent = model
	model.PrimaryPart = body

	-- Adds a part at offset (x, y, z) from the body's center, scaled for huge
	-- pets. -Z is the front (face), +Z is the back, +Y is up.
	local function add(x, y, z, size, partColor, shape, rotation)
		local p = Instance.new("Part")
		p.Shape = shape or Enum.PartType.Block
		p.Size = size * s
		p.Color = partColor
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CFrame = body.CFrame * CFrame.new(x * s, y * s, z * s) * (rotation or CFrame.identity)
		if options.Anchored then
			p.Anchored = true
		else
			p.Anchored = false
			p.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = p
			weld.Parent = p
		end
		p.Parent = model
		return p
	end
	local function both(fn)
		fn(1)
		fn(-1)
	end

	-- face: shiny eyes, pink cheeks and a little mouth
	both(function(side)
		add(side * 0.45, 0.2, -1.05, Vector3.one * 0.5, BLACK, BALL)
		add(side * 0.45 + 0.1, 0.32, -1.25, Vector3.one * 0.16, WHITE, BALL)
		add(side * 0.78, -0.18, -1.11, Vector3.new(0.38, 0.2, 0.05), Color3.fromRGB(255, 150, 175))
	end)
	add(0, -0.3, -1.11, Vector3.new(0.35, 0.09, 0.05), BLACK)

	-- ears
	if look.Ears == "pointy" then
		both(function(side)
			add(side * 0.6, 1.35, -0.2, Vector3.new(0.55, 0.8, 0.3), darker, nil, CFrame.Angles(0, 0, side * -0.35))
		end)
	elseif look.Ears == "round" then
		both(function(side)
			add(side * 0.7, 1.15, -0.1, Vector3.one * 0.75, darker, BALL)
		end)
	elseif look.Ears == "long" then
		both(function(side)
			add(side * 0.45, 1.85, 0, Vector3.new(0.45, 1.6, 0.3), darker, nil, CFrame.Angles(0, 0, side * -0.15))
		end)
	elseif look.Ears == "floppy" then
		both(function(side)
			add(side * 1.25, 0.45, -0.1, Vector3.new(0.3, 1, 0.7), darker, nil, CFrame.Angles(0, 0, side * 0.25))
		end)
	end

	-- tail
	if look.Tail == "short" then
		add(0, 0.3, 1.25, Vector3.one * 0.6, darker, BALL)
	elseif look.Tail == "long" then
		add(0, 0.45, 1.65, Vector3.new(0.35, 0.35, 1.5), darker, nil, CFrame.Angles(0.5, 0, 0))
	elseif look.Tail == "fluffy" then
		add(0, 0.4, 1.45, Vector3.one * 1.1, lighter, BALL)
	elseif look.Tail == "fin" then
		add(0, 0, 1.5, Vector3.new(0.2, 1.4, 0.9), darker)
	end

	-- extras
	for _, extra in ipairs(extras) do
		if extra == "wings" then
			both(function(side)
				add(side * 1.55, 0.35, 0.15, Vector3.new(1.1, 0.18, 1), lighter, nil, CFrame.Angles(0, 0, side * 0.45))
			end)
		elseif extra == "beak" then
			add(0, -0.2, -1.25, Vector3.new(0.5, 0.35, 0.4), Color3.fromRGB(255, 170, 40))
		elseif extra == "horns" then
			both(function(side)
				add(side * 0.55, 1.4, -0.3, Vector3.new(0.3, 0.8, 0.3), Color3.fromRGB(255, 245, 215), nil, CFrame.Angles(0, 0, side * -0.3))
			end)
		elseif extra == "antlers" then
			local brown = Color3.fromRGB(150, 100, 60)
			both(function(side)
				add(side * 0.55, 1.6, 0, Vector3.new(0.22, 1.2, 0.22), brown, nil, CFrame.Angles(0, 0, side * -0.35))
				add(side * 0.95, 1.85, 0, Vector3.new(0.2, 0.6, 0.2), brown, nil, CFrame.Angles(0, 0, side * 0.6))
			end)
		elseif extra == "shell" then
			local green = Color3.fromRGB(70, 150, 80)
			add(0, 1.3, 0.1, Vector3.new(2.5, 0.5, 2.5), green)
			add(0, 1.7, 0.1, Vector3.new(1.7, 0.4, 1.7), green:Lerp(WHITE, 0.2))
		elseif extra == "claws" then
			both(function(side)
				add(side * 1.5, -0.2, -0.7, Vector3.one * 0.9, darker, BALL)
			end)
		elseif extra == "topfin" then
			add(0, 1.45, 0.3, Vector3.new(0.2, 0.9, 1), color, nil, CFrame.Angles(-0.35, 0, 0))
		elseif extra == "fire" then
			local fire = Instance.new("Fire")
			fire.Size = 3 * s
			fire.Heat = 2
			fire.Color = Color3.fromRGB(255, 140, 40)
			fire.SecondaryColor = Color3.fromRGB(255, 230, 90)
			fire.Parent = body
		end
	end

	-- feet
	if not table.find(extras, "nofeet") then
		for _, x in ipairs({ -0.6, 0.6 }) do
			for _, z in ipairs({ -0.6, 0.6 }) do
				add(x, -1.25, z, Vector3.new(0.6, 0.3, 0.6), darker)
			end
		end
	end

	if info.Rarity == "Legendary" or info.Rarity == "Huge" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = info.Color
		sparkles.Parent = body
	end

	if options.Silhouette then
		for _, obj in ipairs(model:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Color = Color3.fromRGB(25, 20, 35)
			elseif obj:IsA("Fire") or obj:IsA("Sparkles") then
				obj:Destroy()
			end
		end
	end

	return model
end

return PetModel
