-- Client entry point: the coin counter, the icon buttons on the left, and
-- keeping the world in sync with our data. Each menu lives in its own module.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local State = require(script.State)
local Ui = require(script.Ui)
local Inventory = require(script.Inventory)
local Index = require(script.Index)
local Rebirth = require(script.Rebirth)
local Hatch = require(script.Hatch)
require(script.Shop)
require(script.EggPreview)
require(script.Breakables)

local player = Players.LocalPlayer

-- Coin + rebirth counter (top left) -------------------------------------------

local hud = Instance.new("Frame")
hud.Position = UDim2.fromOffset(12, 60)
hud.Size = UDim2.fromOffset(200, 100)
hud.BackgroundTransparency = 1
hud.Parent = Ui.gui

local function counter(icon, color, y)
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(200, 44)
	box.Position = UDim2.fromOffset(0, y)
	box.BackgroundColor3 = color
	box.Parent = hud
	Ui.corner(box, 0.5)
	Ui.stroke(box, color:Lerp(Color3.new(0, 0, 0), 0.4), 3)
	Ui.label(box, { Text = icon, Size = UDim2.fromOffset(40, 36), Position = UDim2.fromOffset(6, 4) })
	local value = Ui.label(box, {
		Text = "0",
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -60, 0, 32),
		Position = UDim2.fromOffset(50, 6),
	})
	local scale = Instance.new("UIScale")
	scale.Parent = box
	return value, scale
end

local coinText, coinScale = counter("💰", Color3.fromRGB(255, 190, 50), 0)
local rebirthText = counter("⭐", Color3.fromRGB(170, 100, 230), 52)

task.spawn(function()
	local stats = player:WaitForChild("leaderstats")
	local coins = stats:WaitForChild("Coins")
	local rebirths = stats:WaitForChild("Rebirths")
	local function updateCoins()
		coinText.Text = Config.formatNumber(coins.Value)
		coinScale.Scale = 1.12
		TweenService:Create(coinScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	local function updateRebirths()
		rebirthText.Text = ("Rebirth %d/%d"):format(rebirths.Value, Config.MAX_REBIRTHS)
	end
	coins.Changed:Connect(updateCoins)
	rebirths.Changed:Connect(updateRebirths)
	updateCoins()
	updateRebirths()
end)

-- Icon buttons (left side) ------------------------------------------------------

local side = Instance.new("Frame")
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 12, 0.55, 0)
side.Size = UDim2.fromOffset(170, 260)
side.BackgroundTransparency = 1
side.Parent = Ui.gui

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(78, 78)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = side

local buttons = {
	{ "🏠", "Home", Color3.fromRGB(90, 190, 100), function()
		remotes.Teleport:FireServer("Main")
	end },
	{ "🥚", "Eggs", Color3.fromRGB(255, 170, 60), function()
		remotes.Teleport:FireServer("Eggs")
	end },
	{ "🐾", "Pets", Color3.fromRGB(80, 160, 240), Inventory.toggle },
	{ "📖", "Index", Color3.fromRGB(240, 110, 150), Index.toggle },
	{ "⭐", "Rebirth", Color3.fromRGB(170, 100, 230), Rebirth.toggle },
	{ "🛹", "Board", Color3.fromRGB(80, 200, 210), function()
		remotes.ToggleHoverboard:FireServer()
	end },
}
local boardButton
for order, def in ipairs(buttons) do
	local button = Ui.iconButton(side, def[1], def[2], def[3])
	button.LayoutOrder = order
	button.Activated:Connect(def[4])
	if def[2] == "Board" then
		boardButton = button
		button.Visible = false -- shows up once you buy the hoverboard
	end
end

remotes.Notify.OnClientEvent:Connect(Ui.toast)
remotes.Hatched.OnClientEvent:Connect(Hatch.play)

-- World: match this player's rebirth ----------------------------------------------

local function updateWorld()
	local data = State.Data
	if not data then
		return
	end

	-- recolor the main area for our rebirth level
	local mainArea = workspace:FindFirstChild("MainArea")
	local floor = mainArea and mainArea:FindFirstChild("Floor")
	if floor then
		floor.Color = Config.areaColor(data.Rebirths)
	end
	local coinZone = mainArea and mainArea:FindFirstChild("CoinZone")
	if coinZone then
		coinZone.Color = Config.areaColor(data.Rebirths):Lerp(Color3.new(1, 1, 1), 0.35)
	end

	-- show a lock on eggs we haven't unlocked yet
	local eggArea = workspace:FindFirstChild("EggArea")
	local eggs = eggArea and eggArea:FindFirstChild("Eggs")
	if eggs then
		for _, egg in ipairs(eggs:GetChildren()) do
			local lock = egg:FindFirstChild("Lock", true)
			local required = egg:GetAttribute("RequiredRebirths")
			if lock and required then
				lock.Visible = data.Rebirths < required
			end
		end
	end

	boardButton.Visible = (data.Upgrades.Hoverboard or 0) > 0
end

State.Changed.Event:Connect(updateWorld)
remotes.DataChanged.OnClientEvent:Connect(State.set)
task.spawn(function()
	local initial = remotes.GetData:InvokeServer()
	if initial and not State.Data then
		State.set(initial)
	end
end)

-- eggs are built by the server and may replicate after we start
task.spawn(function()
	workspace:WaitForChild("EggArea"):WaitForChild("Eggs").DescendantAdded:Connect(updateWorld)
	updateWorld()
end)
