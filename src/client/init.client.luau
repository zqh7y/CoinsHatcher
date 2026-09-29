-- Client entry point: the coin counter, the icon buttons on the left, and
-- keeping the world in sync with our data. Each menu lives in its own module.
local CollectionService = game:GetService("CollectionService")
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
local Gifts = require(script.Gifts)
local Fx = require(script.Fx)
require(script.AreaUpgrades)
require(script.Shop)
require(script.EggPreview)
require(script.Breakables)
require(script.Boosts)
require(script.EggArea)
require(script.WorldFx)

local player = Players.LocalPlayer
local EGG_CENTER = Vector3.new(0, 0, 1000) -- same as World.EGG_CENTER on the server

-- Coin + rebirth counter (top left) -------------------------------------------

local hud = Instance.new("Frame")
hud.Position = UDim2.fromOffset(12, 60)
hud.Size = UDim2.fromOffset(200, 150)
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
	return value, box
end

-- A number that rolls up (or down) to its new value instead of jumping.
local function rollingNumber(label, getValue)
	local shown = Instance.new("NumberValue")
	shown.Value = getValue()
	label.Text = Config.formatNumber(shown.Value)
	shown.Changed:Connect(function(v)
		label.Text = Config.formatNumber(v)
	end)
	return function()
		TweenService:Create(shown, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Value = getValue() }):Play()
	end
end

local coinText, coinBox = counter("💰", Color3.fromRGB(255, 190, 50), 0)
local diamondText, diamondBox = counter("💎", Color3.fromRGB(70, 190, 240), 52)
local rebirthText = counter("⭐", Color3.fromRGB(170, 100, 230), 104)
Fx.targets.Coins = coinBox
Fx.targets.Diamonds = diamondBox

task.spawn(function()
	local stats = player:WaitForChild("leaderstats")
	local rebirths = stats:WaitForChild("Rebirths")
	local rollCoins = rollingNumber(coinText, function()
		return player:GetAttribute("Coins") or 0
	end)
	local rollDiamonds = rollingNumber(diamondText, function()
		return player:GetAttribute("Diamonds") or 0
	end)
	player:GetAttributeChangedSignal("Coins"):Connect(rollCoins)
	player:GetAttributeChangedSignal("Diamonds"):Connect(rollDiamonds)

	local function updateRebirths()
		rebirthText.Text = ("Rebirth %d/%d"):format(rebirths.Value, Config.MAX_REBIRTHS)
	end
	rebirths.Changed:Connect(updateRebirths)
	updateRebirths()
end)

-- Combo counter (top middle): shows while you keep breaking things -------------

local combo = Ui.label(Ui.gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(260, 46),
	TextColor3 = Color3.fromRGB(255, 170, 60),
	TextStrokeTransparency = 0,
	Visible = false,
})
local comboNext = Ui.label(combo, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 0),
	Size = UDim2.fromOffset(260, 20),
	TextColor3 = Color3.fromRGB(255, 235, 200),
})
local comboScale = Instance.new("UIScale")
comboScale.Parent = combo

player:GetAttributeChangedSignal("Combo"):Connect(function()
	local count = player:GetAttribute("Combo") or 0
	combo.Visible = count >= 3
	if count < 3 then
		return
	end
	combo.Text = "🔥 Combo x" .. count
	-- hotter colors as the combo grows
	combo.TextColor3 = Color3.fromRGB(255, 200, 80):Lerp(Color3.fromRGB(255, 60, 60), math.min(count / 100, 1))
	local toNext = Config.COMBO_STEP - count % Config.COMBO_STEP
	comboNext.Text = ("%d more for a free boost!"):format(toNext)
	comboScale.Scale = 1.25
	TweenService:Create(comboScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end)

-- Icon buttons (left side) ------------------------------------------------------

local side = Instance.new("Frame")
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 12, 0.6, 0)
side.Size = UDim2.fromOffset(170, 260)
side.BackgroundTransparency = 1
side.Parent = Ui.gui

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(78, 78)
grid.CellPadding = UDim2.fromOffset(10, 10)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = side

local buttons = {
	-- one teleport button: goes to the eggs from home, and home from the eggs
	{ "🥚", "Eggs", Color3.fromRGB(255, 170, 60), function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local atEggs = root and (root.Position - EGG_CENTER).Magnitude < 150
		remotes.Teleport:FireServer(if atEggs then "Main" else "Eggs")
	end },
	{ "🐾", "Pets", Color3.fromRGB(80, 160, 240), Inventory.toggle },
	{ "📖", "Index", Color3.fromRGB(240, 110, 150), Index.toggle },
	{ "⭐", "Rebirth", Color3.fromRGB(170, 100, 230), Rebirth.toggle },
	{ "🎁", "Gifts", Color3.fromRGB(255, 120, 120), Gifts.toggle },
	{ "🛹", "Board", Color3.fromRGB(80, 200, 210), function()
		remotes.ToggleHoverboard:FireServer()
	end },
}
local boardButton, teleportButton
for order, def in ipairs(buttons) do
	local button = Ui.iconButton(side, def[1], def[2], def[3])
	button.LayoutOrder = order
	button.Activated:Connect(def[4])
	if def[2] == "Eggs" then
		teleportButton = button
	elseif def[2] == "Board" then
		boardButton = button
		button.Visible = false -- shows up once you buy the hoverboard
	elseif def[2] == "Gifts" then
		Gifts.attach(button)
	end
end

-- the teleport button shows where it will take you
task.spawn(function()
	while true do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local atEggs = root and (root.Position - EGG_CENTER).Magnitude < 150
		teleportButton.Icon.Text = if atEggs then "🏠" else "🥚"
		teleportButton.Caption.Text = if atEggs then "Home" else "Eggs"
		teleportButton.BackgroundColor3 = if atEggs then Color3.fromRGB(90, 190, 100) else Color3.fromRGB(255, 170, 60)
		task.wait(0.4)
	end
end)

-- server messages; `celebrate` adds confetti (e.g. a new pet discovered)
remotes.Notify.OnClientEvent:Connect(function(message, color, celebrate)
	Ui.toast(message, color)
	if celebrate then
		Fx.confetti(45)
	end
end)
remotes.Hatched.OnClientEvent:Connect(Hatch.play)

-- Server-wide shout-outs for rare hatches, so everyone can see the flex
local banner = Ui.label(Ui.gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 146),
	Size = UDim2.fromOffset(640, 44),
	BackgroundTransparency = 0.15,
	BackgroundColor3 = Color3.fromRGB(60, 30, 110),
	Visible = false,
	ZIndex = 25,
})
Ui.corner(banner, 16)
Ui.stroke(banner, Ui.COLORS.Gold, 3)
local bannerId = 0
remotes.Announce.OnClientEvent:Connect(function(playerName, petName)
	local info = Config.PETS[petName]
	if not info then
		return
	end
	bannerId += 1
	local id = bannerId
	banner.Text = ("🎉 %s hatched a %s! (%s)"):format(playerName, petName, Config.chanceText(petName))
	banner.TextColor3 = info.Color
	banner.Visible = true
	task.delay(5, function()
		if bannerId == id then
			banner.Visible = false
		end
	end)
end)

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
	-- grass patches and tufts follow the floor color (darker/lighter shades)
	local floorColor = Config.areaColor(data.Rebirths)
	for _, patch in ipairs(CollectionService:GetTagged("FloorPatch")) do
		local shade = patch:GetAttribute("Shade") or 0
		patch.Color = floorColor:Lerp(if shade < 0 then Color3.new(0, 0, 0) else Color3.new(1, 1, 1), math.abs(shade))
	end

	-- show a lock on eggs we haven't unlocked yet
	local eggArea = workspace:FindFirstChild("EggArea")
	local eggs = eggArea and eggArea:FindFirstChild("Eggs")
	if eggs then
		for _, egg in ipairs(eggs:GetChildren()) do
			local lock = egg:FindFirstChild("Lock", true)
			local cost = egg:FindFirstChild("Cost", true)
			local required = egg:GetAttribute("RequiredRebirths")
			if lock and required then
				local locked = data.Rebirths < required
				lock.Visible = locked
				-- the plaque shows the price once it's unlocked
				if cost then
					cost.Visible = not locked
				end
			end
		end
	end

	boardButton.Visible = (data.Upgrades.Hoverboard or 0) > 0
end

State.Changed.Event:Connect(updateWorld)
CollectionService:GetInstanceAddedSignal("FloorPatch"):Connect(updateWorld)
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
