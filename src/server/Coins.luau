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

local function makeHealthBar(coin)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromScale(4, 0.5)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 80
	gui.Parent = coin

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
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
	local stats = Config.coinStats(data.Rebirths, size)
	local diameter = 1.5 + size * 1.5
	local height = 0.4 + size * 0.3

	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(height, diameter, diameter)
	-- cylinders point along X; tip it over so it lies flat on the ground
	coin.CFrame = CFrame.new(World.randomCoinPosition() + Vector3.new(0, height / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	coin.Color = Color3.fromRGB(255, 200, 40)
	coin.Material = Enum.Material.Metal
	coin.Anchored = true
	coin.CanCollide = false
	coin:SetAttribute("Health", stats.Health)
	coin:SetAttribute("MaxHealth", stats.Health)
	coin:SetAttribute("Value", stats.Value)
	makeHealthBar(coin)
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
		local fillBar = coin.HealthBar.Frame.Fill
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
