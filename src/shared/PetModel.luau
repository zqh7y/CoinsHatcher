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
	local material = Enum.Material.SmoothPlastic
	if info.Mutation == "Shiny" then
		color = color:Lerp(WHITE, 0.25)
		material = Enum.Material.Foil
	elseif info.Mutation == "Galaxy" then
		color = Color3.fromRGB(70, 35, 140)
		material = Enum.Material.Neon
	end
	local darker = color:Lerp(Color3.new(0, 0, 0), 0.15)
	local lighter = color:Lerp(WHITE, 0.4)
	if info.Mutation == "Galaxy" then
		lighter = Color3.fromRGB(150, 110, 255)
	end

	-- body-colored parts get the mutation's look; rainbow pets get a new
	-- color for every part
	local rainbowHue = 0
	local function paint(partColor)
		if partColor ~= color and partColor ~= darker and partColor ~= lighter then
			return partColor, Enum.Material.SmoothPlastic -- face, beak, horns...
		end
		if info.Mutation == "Rainbow" then
			rainbowHue = (rainbowHue + 0.13) % 1
			return Color3.fromHSV(rainbowHue, 0.5, 1), Enum.Material.SmoothPlastic
		end
		return partColor, if material == Enum.Material.Neon and partColor ~= color then Enum.Material.SmoothPlastic else material
	end

	local model = Instance.new("Model")
	model.Name = petName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.one * PetModel.SIZE * s
	body.Color, body.Material = paint(color)
	-- a little gloss, like shiny plastic toys
	body.Reflectance = if body.Material == Enum.Material.SmoothPlastic then 0.08 else 0
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
		p.Color, p.Material = paint(partColor)
		p.Reflectance = if p.Material == Enum.Material.SmoothPlastic then 0.06 else 0
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
		elseif extra == "halo" then
			local halo = add(0, 2.1, 0, Vector3.new(0.12, 1.5, 1.5), Color3.fromRGB(255, 235, 120), Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(90)))
			halo.Material = Enum.Material.Neon
			add(0, 2.1, 0, Vector3.new(0.14, 1, 1), Color3.fromRGB(255, 250, 225), Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(90)))
		elseif extra == "partyhat" then
			-- a striped cone hat (stacked shrinking discs) with a pom-pom
			local hatColors = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(255, 220, 70), Color3.fromRGB(90, 190, 255) }
			for k = 0, 4 do
				local w = 1 - k * 0.18
				add(0.25, 1.25 + k * 0.22, -0.15, Vector3.new(0.22, w, w), hatColors[k % 3 + 1], Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(90)))
			end
			add(0.25, 2.4, -0.15, Vector3.one * 0.38, WHITE, BALL)
		elseif extra == "bowtie" then
			both(function(side)
				add(side * 0.3, -0.75, -1.12, Vector3.new(0.45, 0.4, 0.1), Color3.fromRGB(230, 40, 90), nil, CFrame.Angles(0, 0, side * 0.3))
			end)
			add(0, -0.75, -1.15, Vector3.new(0.2, 0.2, 0.1), Color3.fromRGB(255, 120, 160))
		elseif extra == "giftbox" then
			-- a present: gold ribbon bands all around the box and a big bow on top
			local ribbon = Color3.fromRGB(255, 210, 70)
			add(0, -0.72, 0, Vector3.new(2.3, 0.4, 2.3), ribbon) -- around the bottom (under the face)
			add(0, 0, 0, Vector3.new(2.3, 2.3, 0.5), ribbon) -- over the top and down the sides
			both(function(side)
				add(side * 0.45, 1.45, 0, Vector3.new(0.9, 0.6, 0.35), ribbon, nil, CFrame.Angles(0, 0, side * -0.5))
			end)
			add(0, 1.35, 0, Vector3.one * 0.5, ribbon:Lerp(WHITE, 0.2), BALL)
		elseif extra == "balloon" then
			add(1.3, 1.1, 0.4, Vector3.new(0.06, 2.2, 0.06), WHITE)
			add(1.3, 2.8, 0.4, Vector3.new(1.2, 1.4, 1.2), Color3.fromRGB(255, 80, 120), BALL)
		end
	end

	-- mythical pets wear a golden crown
	if info.Rarity == "Mythical" then
		local gold = Color3.fromRGB(255, 205, 60)
		add(0, 1.25, 0, Vector3.new(1.3, 0.3, 1.3), gold)
		for k = 0, 3 do
			local a = k * math.pi / 2 + math.pi / 4
			add(math.cos(a) * 0.5, 1.55, math.sin(a) * 0.5, Vector3.new(0.3, 0.45, 0.3), gold, nil, CFrame.Angles(0, -a, 0))
		end
		local gem = add(0, 1.3, -0.66, Vector3.new(0.3, 0.3, 0.1), Color3.fromRGB(255, 70, 120))
		gem.Material = Enum.Material.Neon
	end

	-- feet
	if not table.find(extras, "nofeet") then
		for _, x in ipairs({ -0.6, 0.6 }) do
			for _, z in ipairs({ -0.6, 0.6 }) do
				add(x, -1.25, z, Vector3.new(0.6, 0.3, 0.6), darker)
			end
		end
	end

	if info.Rarity == "Legendary" or info.Rarity == "Mythical" or info.Rarity == "Huge" or info.Mutation then
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
