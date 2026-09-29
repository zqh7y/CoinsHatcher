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

-- Fires (player, position, kind) whenever one of the player's breakables breaks.
Coins.Broken = Instance.new("BindableEvent")

local folder = Instance.new("Folder")
folder.Name = "Coins"
folder.Parent = workspace

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
-- Everything is built in the look of the player's area (Config.areaTheme):
-- the coins, the chests, a patch of the area's ground under each breakable
-- and a decoration on the chest lids.

local function piece(model, origin, offset, size, color, shape, shiny)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = origin * offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	-- coins are shiny, like polished coins
	p.Reflectance = if shiny then 0.3 else 0.05
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- One flat coin; y is the height of its bottom.
local function coin(model, origin, x, y, z, theme)
	return piece(model, origin, CFrame.new(x, y + COIN_SIZE.X / 2, z) * FLAT, COIN_SIZE, theme.Coin, Enum.PartType.Cylinder, true)
end

-- A stack of coins; the top one gets a star.
local function stack(model, origin, x, z, count, theme)
	local top
	for i = 0, count - 1 do
		top = coin(model, origin, x + math.random(-15, 15) / 100, i * 0.37, z + math.random(-15, 15) / 100, theme)
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
	star.TextColor3 = theme.CoinDark
	star.TextScaled = true
	star.Font = Enum.Font.FredokaOne
	star.Parent = gui
end

-- A patch of the area's ground under a breakable.
local function groundPatch(model, origin, radius, theme)
	local patch = piece(model, origin, CFrame.new(0, 0.04, 0) * FLAT, Vector3.new(0.08, radius * 2 + 1, radius * 2 + 1), theme.Ground, Enum.PartType.Cylinder)
	patch.Name = "Ground"
end

-- A little decoration on a chest lid, in the area's style. (x, y, z) is the
-- middle of the lid's top; s is the chest's size.
local DECOR = {
	grass = function(model, at, s)
		for k = -1, 1 do
			piece(model, at, CFrame.new(k * 0.35 * s, 0.25 * s, 0) * CFrame.Angles(0, 0, k * 0.4), Vector3.new(0.18, 0.6, 0.18) * s, Color3.fromRGB(90, 180, 70))
		end
	end,
	cactus = function(model, at, s)
		local green = Color3.fromRGB(90, 170, 90)
		piece(model, at, CFrame.new(0, 0.45 * s, 0), Vector3.new(0.4, 0.9, 0.4) * s, green)
		piece(model, at, CFrame.new(0.3 * s, 0.55 * s, 0), Vector3.new(0.25, 0.35, 0.25) * s, green)
	end,
	snow = function(model, at, s)
		piece(model, at, CFrame.new(0, 0.08 * s, 0), Vector3.new(3.9, 0.22, 2.9) * s, Color3.new(1, 1, 1))
		for _, x in ipairs({ -1, 0.8 }) do
			piece(model, at, CFrame.new(x * s, 0.3 * s, 0.4 * s), Vector3.one * 0.5 * s, Color3.new(1, 1, 1), Enum.PartType.Ball)
		end
	end,
	sprinkles = function(model, at, s)
		local colors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 70), Color3.fromRGB(110, 210, 120), Color3.fromRGB(90, 170, 255), Color3.new(1, 1, 1) }
		for k = 1, 8 do
			local x, z = (k % 4 - 1.5) * 0.7, (if k > 4 then 0.4 else -0.4)
			piece(model, at, CFrame.new(x * s, 0.06, z * s) * CFrame.Angles(0, k, 0), Vector3.new(0.12, 0.12, 0.4) * s, colors[k % #colors + 1])
		end
	end,
	shell = function(model, at, s)
		local shell = piece(model, at, CFrame.new(0, 0.25 * s, 0), Vector3.new(1, 0.5, 0.9) * s, Color3.fromRGB(255, 190, 170))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = shell
	end,
	leaf = function(model, at, s)
		piece(model, at, CFrame.new(0, 0.1 * s, 0) * CFrame.Angles(0, 0.5, 0), Vector3.new(1.6, 0.1, 0.7) * s, Color3.fromRGB(80, 170, 70))
	end,
	flame = function(model, at, s)
		local flame = piece(model, at, CFrame.new(0, 0.35 * s, 0), Vector3.new(0.6, 0.8, 0.6) * s, Color3.fromRGB(255, 150, 40), Enum.PartType.Ball)
		flame.Material = Enum.Material.Neon
	end,
	crystal = function(model, at, s)
		local c = piece(model, at, CFrame.new(0, 0.45 * s, 0) * CFrame.Angles(0, math.rad(45), math.rad(12)), Vector3.new(0.45, 0.9, 0.45) * s, Color3.fromRGB(210, 150, 255))
		c.Material = Enum.Material.Neon
	end,
	flower = function(model, at, s)
		piece(model, at, CFrame.new(0, 0.25 * s, 0), Vector3.one * 0.55 * s, Color3.fromRGB(255, 170, 210), Enum.PartType.Ball)
		piece(model, at, CFrame.new(0, 0.3 * s, -0.2 * s), Vector3.one * 0.25 * s, Color3.fromRGB(255, 225, 90), Enum.PartType.Ball)
	end,
	star = function(model, at, s)
		local star = piece(model, at, CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Vector3.one * 0.5 * s, Color3.fromRGB(140, 235, 255))
		star.Material = Enum.Material.Neon
	end,
	crown = function(model, at, s)
		local gold = Color3.fromRGB(255, 210, 60)
		piece(model, at, CFrame.new(0, 0.12 * s, 0), Vector3.new(1, 0.24, 0.8) * s, gold, nil, true)
		for k = -1, 1 do
			piece(model, at, CFrame.new(k * 0.35 * s, 0.38 * s, 0), Vector3.new(0.2, 0.3, 0.2) * s, gold, nil, true)
		end
	end,
}

local function chest(model, origin, s, theme, big)
	local function at(x, y, z)
		return CFrame.new(x * s, y * s, z * s)
	end
	local body = if big then theme.Lid else theme.Body
	local lid = if big then theme.Lid:Lerp(Color3.new(0, 0, 0), 0.2) else theme.Lid
	piece(model, origin, at(0, 1, 0), Vector3.new(3.6, 2, 2.6) * s, body)
	piece(model, origin, at(0, 2.45, 0), Vector3.new(3.8, 0.9, 2.8) * s, lid)
	for _, x in ipairs({ -1.2, 1.2 }) do
		piece(model, origin, at(x, 1.45, 0), Vector3.new(0.35, 2.95, 2.7) * s, theme.Band, nil, true)
	end
	piece(model, origin, at(0, 1.9, -1.35), Vector3.new(0.7, 0.8, 0.25) * s, theme.CoinDark, nil, true)
	-- coins spilling out on top
	for _, spot in ipairs({ { -0.8, 0.3 }, { 0.5, -0.4 }, { 0.2, 0.6 } }) do
		piece(
			model,
			origin,
			CFrame.new(spot[1] * s, 2.9 * s + 0.2, spot[2] * s) * CFrame.Angles(math.random() * 0.4, 0, 0) * FLAT,
			COIN_SIZE * math.min(s, 1.3),
			theme.Coin,
			Enum.PartType.Cylinder,
			true
		)
	end
	-- the area's decoration on the lid
	local decor = DECOR[theme.Decor]
	if decor then
		decor(model, origin * at(0, 2.9, 0.2), s)
	end
end

-- Each builder draws one kind of breakable (same order as Config.BREAKABLES)
-- around origin and returns its height.
local BUILDERS = {
	function(model, origin, theme) -- Coins: a stack of 4
		stack(model, origin, 0, 0, 4, theme)
		return 1.5
	end,
	function(model, origin, theme) -- Coin Pile: three stacks
		stack(model, origin, -0.95, 0.55, 5, theme)
		stack(model, origin, 0.95, 0.55, 3, theme)
		stack(model, origin, 0, -0.85, 4, theme)
		return 1.9
	end,
	function(model, origin, theme) -- Chest
		chest(model, origin, 1, theme, false)
		return 3.3
	end,
	function(model, origin, theme) -- Big Chest
		chest(model, origin, 1.6, theme, true)
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
	if #f:GetChildren() >= Config.breakableCount(data) then
		return
	end

	local kind = Config.rollBreakable(data)
	local stats = Config.coinStats(data.Rebirths, kind)
	local radius = RADIUS[kind]
	local pos = findSpot(f, radius)
	local origin = CFrame.new(pos.X, World.FLOOR_Y + 0.2, pos.Z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)

	local model = Instance.new("Model")
	model.Name = Config.BREAKABLES[kind].Name

	-- invisible base: the model's pivot sits on the ground at its center
	local theme = Config.areaTheme(data.Rebirths)
	local base = piece(model, origin, CFrame.new(0, 0.05, 0), Vector3.new(1, 0.1, 1), theme.Coin)
	base.Name = "Base"
	base.Transparency = 1
	model.PrimaryPart = base

	groundPatch(model, origin, radius, theme)
	local height = BUILDERS[kind](model, origin, theme)
	model:SetAttribute("Health", stats.Health)
	model:SetAttribute("MaxHealth", stats.Health)
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Value", stats.Value) -- base value; upgrades apply when it breaks
	model:SetAttribute("Radius", radius)
	model:SetAttribute("Height", height)

	-- some breakables carry diamonds: a glowing gem floats above them
	local breakable = Config.BREAKABLES[kind]
	if math.random() < Config.diamondChance(data, kind) then
		model:SetAttribute("Diamonds", Config.breakableDiamonds(kind))
		local gem = piece(
			model,
			origin,
			CFrame.new(0, height + 0.9, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Vector3.one * 0.9,
			Color3.fromRGB(110, 220, 255)
		)
		gem.Name = "Diamond"
		gem.Material = Enum.Material.Neon
		gem.CastShadow = false
	end

	-- the health bar goes above the gem if there is one
	makeHealthBar(base, if model:GetAttribute("Diamonds") then height + 1.4 else height)
	updateHealthBar(model, stats.Health)

	if kind == #BUILDERS then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = theme.Coin
		sparkles.Parent = base
	end

	model.Parent = f
end

local function fill(player)
	local data = PlayerData.get(player)
	for _ = 1, Config.breakableCount(data) do
		spawnCoin(player)
	end
end

-- Spawns extra breakables right away (after buying "More Stuff").
Coins.fill = fill

-- Returns the player's breakables that are still alive.
function Coins.get(player)
	local f = folder:FindFirstChild(tostring(player.UserId))
	return if f then f:GetChildren() else {}
end

-- Deals one hit to a breakable. Returns true if it broke.
function Coins.damage(player, model, amount, crit)
	if not model.Parent then
		return true
	end
	local health = math.max(0, model:GetAttribute("Health") - amount)
	-- the client watches these to show damage numbers and shake the breakable
	model:SetAttribute("Crit", crit == true)
	model:SetAttribute("Health", health)
	if health > 0 then
		updateHealthBar(model, health)
		return false
	end

	local data = PlayerData.get(player)
	PlayerData.addCoins(player, Config.breakablePayout(data, model:GetAttribute("Kind") or 1, model:GetAttribute("Value")))
	local diamonds = model:GetAttribute("Diamonds")
	if diamonds then
		PlayerData.addDiamonds(player, diamonds)
	end
	Coins.Broken:Fire(player, model:GetPivot().Position, model:GetAttribute("Kind") or 1)
	model:Destroy()
	task.delay(Config.respawnTime(data), spawnCoin, player)
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
