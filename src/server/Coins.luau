-- Spawns each player's own coins in the main area. Coin health and value
-- scale with that player's rebirths, so the area gets stronger every rebirth.
-- Everyone shares the same map, but the client hides other players' coins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local World = require(script.Parent.World)

local Coins = {}

local folder = Instance.new("Folder")
folder.Name = "Coins"
folder.Parent = workspace

local SIZE_WEIGHTS = { 70, 25, 5 } -- small, medium, big

-- Toy coins: small = gold star, medium = pink heart, big = blue diamond
local STYLES = {
	{ Color = Color3.fromRGB(255, 210, 50), Rim = Color3.fromRGB(240, 140, 20), Symbol = "★" },
	{ Color = Color3.fromRGB(255, 130, 195), Rim = Color3.fromRGB(215, 70, 150), Symbol = "♥" },
	{ Color = Color3.fromRGB(100, 215, 255), Rim = Color3.fromRGB(40, 140, 235), Symbol = "◆" },
}

local function rollSize()
	local roll = math.random(1, 100)
	if roll <= SIZE_WEIGHTS[1] then
		return 1
	elseif roll <= SIZE_WEIGHTS[1] + SIZE_WEIGHTS[2] then
		return 2
	end
	return 3
end

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

local function makeHealthBar(coin, diameter)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromScale(diameter, 0.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, diameter / 2 + 1.5, 0)
	gui.MaxDistance = 80
	gui.Parent = coin

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	back.BorderSizePixel = 0
	back.Parent = gui
	corner(back, 0.5)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner(fill, 0.5)
end

-- A round rim and a symbol on both faces of the coin.
local function makeFace(coin, face, style)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = coin

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.78, 0.78)
	ring.BackgroundTransparency = 1
	ring.Parent = gui
	corner(ring, 0.5)

	local stroke = Instance.new("UIStroke")
	stroke.Color = style.Rim
	stroke.Thickness = 10
	stroke.Parent = ring

	local symbol = Instance.new("TextLabel")
	symbol.Size = UDim2.fromScale(1, 1)
	symbol.BackgroundTransparency = 1
	symbol.Text = style.Symbol
	symbol.TextColor3 = style.Rim
	symbol.TextScaled = true
	symbol.Font = Enum.Font.FredokaOne
	symbol.Parent = ring
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

	local size = rollSize()
	local style = STYLES[size]
	local stats = Config.coinStats(data.Rebirths, size)
	local diameter = 2 + size * 1.2
	local thickness = diameter * 0.25

	-- a chunky coin standing on its edge (the client makes it spin and bob)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(thickness, diameter, diameter)
	coin.CFrame = CFrame.new(World.randomCoinPosition() + Vector3.new(0, diameter / 2 + 0.4, 0))
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)
	coin.Color = style.Color
	coin.Material = Enum.Material.SmoothPlastic
	coin.Anchored = true
	coin.CanCollide = false
	coin:SetAttribute("Health", stats.Health)
	coin:SetAttribute("MaxHealth", stats.Health)
	coin:SetAttribute("Value", stats.Value)
	makeFace(coin, Enum.NormalId.Right, style)
	makeFace(coin, Enum.NormalId.Left, style)
	makeHealthBar(coin, diameter)
	coin.Parent = f
end

local function fill(player)
	for _ = 1, Config.COINS_PER_PLAYER do
		spawnCoin(player)
	end
end

-- Returns the player's coins that are still alive.
function Coins.get(player)
	local f = folder:FindFirstChild(tostring(player.UserId))
	return if f then f:GetChildren() else {}
end

-- Deals damage to a coin. Returns true if the coin broke.
function Coins.damage(player, coin, amount)
	if not coin.Parent then
		return true
	end
	local health = coin:GetAttribute("Health") - amount
	if health > 0 then
		coin:SetAttribute("Health", health)
		local fillBar = coin.HealthBar.Back.Fill
		fillBar.Size = UDim2.fromScale(health / coin:GetAttribute("MaxHealth"), 1)
		return false
	end

	PlayerData.addCoins(player, coin:GetAttribute("Value"))
	coin:Destroy()
	task.delay(Config.COIN_RESPAWN_TIME, spawnCoin, player)
	return true
end

-- Clears and respawns the player's coins, e.g. after a rebirth.
function Coins.reset(player)
	playerFolder(player):ClearAllChildren()
	fill(player)
end

function Coins.start()
	PlayerData.Changed.Event:Connect(function(player)
		-- first load: spawn their coins
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
