-- Spawns each player's own breakables (coin stacks, coin piles, chests) in the
-- round coin zone. Their health and value scale with that player's rebirths,
-- so the area gets stronger every rebirth. Everyone shares the same map, but
-- the client hides other players' breakables.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Coins = {}

local folder = Instance.new("Folder")
folder.Name = "Coins"
folder.Parent = workspace

local GOLD = Color3.fromRGB(255, 205, 50)
local GOLD_DARK = Color3.fromRGB(235, 150, 30)
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder so it lies flat
local COIN_SIZE = Vector3.new(0.35, 2.4, 2.4)

local function playerFolder(player)
	local f = folder:FindFirstChild(tostring(player.UserId))
	if not f then
		f = Instance.new("Folder")
		f.Name = tostring(player.UserId)
		f.Parent = folder
	end
	return f
end

local function corner(parent, scale)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

-- Builders --------------------------------------------------------------------

local function piece(model, origin, offset, size, color, shape)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = origin * offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.Parent = model
	return p
end

-- One flat coin; y is the height of its bottom.
local function coin(model, origin, x, y, z)
	return piece(model, origin, CFrame.new(x, y + COIN_SIZE.X / 2, z) * FLAT, COIN_SIZE, GOLD, Enum.PartType.Cylinder)
end

-- A stack of coins; the top one gets a star.
local function stack(model, origin, x, z, count)
	local top
	for i = 0, count - 1 do
		top = coin(model, origin, x + math.random(-15, 15) / 100, i * 0.37, z + math.random(-15, 15) / 100)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right -- the flat cylinder's top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = top
	local star = Instance.new("TextLabel")
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.5)
	star.Size = UDim2.fromScale(0.7, 0.7)
	star.BackgroundTransparency = 1
	star.Text = "★"
	star.TextColor3 = GOLD_DARK
	star.TextScaled = true
	star.Font = Enum.Font.FredokaOne
	star.Parent = gui
end

local function chest(model, origin, s, bodyColor, lidColor)
	local function at(x, y, z)
		return CFrame.new(x * s, y * s, z * s)
	end
	piece(model, origin, at(0, 1, 0), Vector3.new(3.6, 2, 2.6) * s, bodyColor)
	piece(model, origin, at(0, 2.45, 0), Vector3.new(3.8, 0.9, 2.8) * s, lidColor)
	for _, x in ipairs({ -1.2, 1.2 }) do
		piece(model, origin, at(x, 1.45, 0), Vector3.new(0.35, 2.95, 2.7) * s, GOLD)
	end
	piece(model, origin, at(0, 1.9, -1.35), Vector3.new(0.7, 0.8, 0.25) * s, GOLD_DARK)
	-- coins spilling out on top
	for _, spot in ipairs({ { -0.8, 0.3 }, { 0.5, -0.4 }, { 0.2, 0.6 } }) do
		piece(
			model,
			origin,
			CFrame.new(spot[1] * s, 2.9 * s + 0.2, spot[2] * s) * CFrame.Angles(math.random() * 0.4, 0, 0) * FLAT,
			COIN_SIZE * math.min(s, 1.3),
			GOLD,
			Enum.PartType.Cylinder
		)
	end
end

-- Each builder draws one kind of breakable (same order as Config.BREAKABLES)
-- around origin and returns its height.
local BUILDERS = {
	function(model, origin) -- Coins: a stack of 4
		stack(model, origin, 0, 0, 4)
		return 1.5
	end,
	function(model, origin) -- Coin Pile: three stacks
		stack(model, origin, -0.95, 0.55, 5)
		stack(model, origin, 0.95, 0.55, 3)
		stack(model, origin, 0, -0.85, 4)
		return 1.9
	end,
	function(model, origin) -- Chest
		chest(model, origin, 1, Color3.fromRGB(170, 105, 60), Color3.fromRGB(135, 80, 45))
		return 3.3
	end,
	function(model, origin) -- Big Chest
		chest(model, origin, 1.6, Color3.fromRGB(150, 95, 225), Color3.fromRGB(115, 70, 190))
		return 5.2
	end,
}

-- How wide each kind is (pets stand around this, and it keeps them apart).
local RADIUS = { 1.4, 2.3, 2.3, 3.6 }

local function makeHealthBar(base, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(110, 22)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 1.3, 0)
	gui.MaxDistance = 70
	gui.Parent = base

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(45, 40, 60)
	back.BorderSizePixel = 0
	back.Parent = gui
	corner(back, 0.5)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 2
	stroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner(fill, 0.5)

	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.Size = UDim2.fromScale(1, 1)
	amount.BackgroundTransparency = 1
	amount.TextColor3 = Color3.new(1, 1, 1)
	amount.TextStrokeTransparency = 0.3
	amount.Font = Enum.Font.FredokaOne
	amount.TextScaled = true
	amount.ZIndex = 2
	amount.Parent = back
end

local function updateHealthBar(model, health)
	local back = model.PrimaryPart.HealthBar.Back
	back.Fill.Size = UDim2.fromScale(health / model:GetAttribute("MaxHealth"), 1)
	back.Amount.Text = Config.formatNumber(health)
end

-- Finds a free spot in the coin zone that doesn't overlap other breakables.
local function findSpot(f, radius)
	local pos
	for _ = 1, 15 do
		pos = World.randomCoinPosition(radius)
		local free = true
		for _, other in ipairs(f:GetChildren()) do
			local gap = (other:GetPivot().Position - pos) * Vector3.new(1, 0, 1)
			if gap.Magnitude < radius + (other:GetAttribute("Radius") or 2) + 0.5 then
				free = false
				break
			end
		end
		if free then
			break
		end
	end
	return pos
end

local function spawnCoin(player)
	local data = PlayerData.get(player)
	if not data or not player.Parent then
		return
	end
	local f = playerFolder(player)
	if #f:GetChildren() >= Config.COINS_PER_PLAYER then
		return
	end

	local kind = Config.rollBreakable()
	local stats = Config.coinStats(data.Rebirths, kind)
	local radius = RADIUS[kind]
	local pos = findSpot(f, radius)
	local origin = CFrame.new(pos.X, World.FLOOR_Y + 0.2, pos.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)

	local model = Instance.new("Model")
	model.Name = Config.BREAKABLES[kind].Name

	-- invisible base: the model's pivot sits on the ground at its center
	local base = piece(model, origin, CFrame.new(0, 0.05, 0), Vector3.new(1, 0.1, 1), GOLD)
	base.Name = "Base"
	base.Transparency = 1
	model.PrimaryPart = base

	local height = BUILDERS[kind](model, origin)
	model:SetAttribute("Health", stats.Health)
	model:SetAttribute("MaxHealth", stats.Health)
	model:SetAttribute("Value", stats.Value)
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Height", height)
	makeHealthBar(base, height)
	updateHealthBar(model, stats.Health)

	if kind == #BUILDERS then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = GOLD
		sparkles.Parent = base
	end

	model.Parent = f
end

local function fill(player)
	for _ = 1, Config.COINS_PER_PLAYER do
		spawnCoin(player)
	end
end

-- Returns the player's breakables that are still alive.
function Coins.get(player)
	local f = folder:FindFirstChild(tostring(player.UserId))
	return if f then f:GetChildren() else {}
end

-- Deals one hit to a breakable. Returns true if it broke.
function Coins.damage(player, model, amount)
	if not model.Parent then
		return true
	end
	local health = math.max(0, model:GetAttribute("Health") - amount)
	-- the client watches this to show damage numbers and shake the breakable
	model:SetAttribute("Health", health)
	if health > 0 then
		updateHealthBar(model, health)
		return false
	end

	local data = PlayerData.get(player)
	PlayerData.addCoins(player, model:GetAttribute("Value") * Config.coinMult(data and data.Upgrades))
	model:Destroy()
	task.delay(Config.COIN_RESPAWN_TIME, spawnCoin, player)
	return true
end

-- Clears and respawns the player's breakables, e.g. after a rebirth.
function Coins.reset(player)
	playerFolder(player):ClearAllChildren()
	fill(player)
end

function Coins.start()
	PlayerData.Changed.Event:Connect(function(player)
		-- first load: spawn their breakables
		if not folder:FindFirstChild(tostring(player.UserId)) then
			fill(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local f = folder:FindFirstChild(tostring(player.UserId))
		if f then
			f:Destroy()
		end
	end)
end

return Coins
