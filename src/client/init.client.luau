-- Client entry point: the coin/diamond counters, the buttons on the left, the
-- rebirth reminder, and keeping the world in sync with our data. Each menu
-- lives in its own module.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local State = require(script.State)
local Ui = require(script.Ui)
local Icons = require(script.Icons)
local Inventory = require(script.Inventory)
local Index = require(script.Index)
local Rebirth = require(script.Rebirth)
local Hatch = require(script.Hatch)
local Gifts = require(script.Gifts)
local Fx = require(script.Fx)
local Transition = require(script.Transition)
require(script.Starter)
require(script.Portals)
require(script.AreaUpgrades)
require(script.Shop)
require(script.EggPreview)
require(script.Breakables)
require(script.Boosts)
require(script.EggArea)
require(script.WorldFx)

local player = Players.LocalPlayer
local EGG_CENTER = Vector3.new(0, 0, 1000) -- same as World.EGG_CENTER on the server

-- Coin + diamond counters (top left) ------------------------------------------
-- Sleek white pills with a glossy icon badge, a rolling number and a live
-- "+X/s" income rate. A shine sweeps across them now and then.

local hud = Instance.new("Frame")
hud.Position = UDim2.fromOffset(14, 60)
hud.Size = UDim2.fromOffset(230, 110)
hud.BackgroundTransparency = 1
hud.Parent = Ui.gui

local shines = {}

local function counter(drawIcon, color, y)
	local box = Instance.new("Frame")
	box.Size = UDim2.fromOffset(230, 48)
	box.Position = UDim2.fromOffset(0, y)
	box.BackgroundColor3 = Ui.COLORS.Panel
	box.Parent = hud
	Ui.corner(box, 0.5)
	local stroke = Ui.stroke(box, Ui.COLORS.Line, 1.5)

	-- a tinted band that sweeps across the pill now and then (under the text)
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55)
	overlay.ZIndex = 1
	overlay.Parent = box
	Ui.corner(overlay, 0.5)
	local shine = Instance.new("UIGradient")
	shine.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	shine.Rotation = 20
	shine.Offset = Vector2.new(-1, 0)
	shine.Parent = overlay
	table.insert(shines, shine)

	local badge = Instance.new("Frame")
	badge.Position = UDim2.fromOffset(5, 5)
	badge.Size = UDim2.fromOffset(38, 38)
	badge.BackgroundColor3 = color
	badge.ZIndex = 2
	badge.Parent = box
	Ui.corner(badge, 0.5)
	Ui.gradient(badge, color:Lerp(Color3.new(1, 1, 1), 0.3), color:Lerp(Color3.new(0, 0, 0), 0.15), 135)
	local iconHolder = Instance.new("Frame")
	iconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	iconHolder.Position = UDim2.fromScale(0.5, 0.5)
	iconHolder.Size = UDim2.fromScale(0.62, 0.62)
	iconHolder.BackgroundTransparency = 1
	iconHolder.ZIndex = 2
	iconHolder.Parent = badge
	drawIcon(iconHolder, Color3.new(1, 1, 1))

	local value = Ui.label(box, {
		Text = "0",
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -120, 0, 24),
		Position = UDim2.fromOffset(52, 12),
		ZIndex = 2,
	})
	local rate = Ui.label(box, {
		Text = "",
		Font = Ui.FONT_BODY,
		TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.15),
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(70, 16),
		Position = UDim2.new(1, -14, 0, 16),
		ZIndex = 2,
	})
	return value, box, rate, stroke
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

-- Tracks gains over the last few seconds to show "+X/s".
local function incomeRate(attribute, rateLabel, stroke, color)
	local gains = {} -- { time, amount }
	local last = player:GetAttribute(attribute) or 0
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local now = player:GetAttribute(attribute) or 0
		if now > last then
			table.insert(gains, { os.clock(), now - last })
			-- a quick glow on the border when you earn
			stroke.Color = color
			stroke.Thickness = 2.5
			TweenService:Create(stroke, TweenInfo.new(0.5), { Color = Ui.COLORS.Line, Thickness = 1.5 }):Play()
		end
		last = now
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local cutoff = os.clock() - 5
			local total = 0
			for i = #gains, 1, -1 do
				if gains[i][1] < cutoff then
					table.remove(gains, i)
				else
					total += gains[i][2]
				end
			end
			rateLabel.Text = if total > 0 then "+" .. Config.formatNumber(total / 5) .. "/s" else ""
		end
	end)
end

local coinText, coinBox, coinRate, coinStroke = counter(Icons.coin, Ui.COLORS.Gold, 0)
local diamondText, diamondBox, diamondRate, diamondStroke = counter(Icons.gem, Ui.COLORS.Gem, 56)
Fx.targets.Coins = coinBox
Fx.targets.Diamonds = diamondBox

local rollCoins = rollingNumber(coinText, function()
	return player:GetAttribute("Coins") or 0
end)
local rollDiamonds = rollingNumber(diamondText, function()
	return player:GetAttribute("Diamonds") or 0
end)
player:GetAttributeChangedSignal("Coins"):Connect(rollCoins)
player:GetAttributeChangedSignal("Diamonds"):Connect(rollDiamonds)
incomeRate("Coins", coinRate, coinStroke, Ui.COLORS.Gold)
incomeRate("Diamonds", diamondRate, diamondStroke, Ui.COLORS.Gem)

-- the shine sweeps across both pills every few seconds
task.spawn(function()
	while true do
		task.wait(4)
		for _, shine in ipairs(shines) do
			shine.Offset = Vector2.new(-1, 0)
			TweenService:Create(shine, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Offset = Vector2.new(1, 0) }):Play()
		end
	end
end)

-- Rebirth reminder: a glowing button under the counters when you can rebirth --

local reminder = Instance.new("TextButton")
reminder.Position = UDim2.fromOffset(14, 176)
reminder.Size = UDim2.fromOffset(230, 44)
reminder.BackgroundColor3 = Color3.new(1, 1, 1)
reminder.Text = ""
reminder.AutoButtonColor = true
reminder.Visible = false
reminder.Parent = Ui.gui
Ui.corner(reminder, 0.5)
Ui.gradient(reminder, Ui.COLORS.Accent2, Ui.COLORS.Accent, 0)
local reminderIcon = Instance.new("Frame")
reminderIcon.Position = UDim2.fromOffset(10, 7)
reminderIcon.Size = UDim2.fromOffset(30, 30)
reminderIcon.BackgroundTransparency = 1
reminderIcon.Parent = reminder
Icons.rebirth(reminderIcon, Color3.new(1, 1, 1))
Ui.label(reminder, {
	Text = "Rebirth ready!",
	TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(48, 11),
	Size = UDim2.new(1, -60, 0, 22),
})
Ui.bounce(reminder)
local reminderScale = Instance.new("UIScale")
reminderScale.Parent = reminderIcon
reminder.Activated:Connect(Rebirth.toggle)

local remindedAt = -1 -- the rebirth level we last announced, so the toast shows once
local function updateReminder()
	local data = State.Data
	local ready = data ~= nil
		and data.Rebirths < Config.MAX_REBIRTHS
		and (player:GetAttribute("Coins") or 0) >= Config.rebirthCost(data.Rebirths)
	reminder.Visible = ready
	if ready and remindedAt ~= data.Rebirths then
		remindedAt = data.Rebirths
		Ui.toast("You have enough coins to rebirth! Tap the Rebirth button.", Ui.COLORS.Accent2)
	end
end
player:GetAttributeChangedSignal("Coins"):Connect(updateReminder)
State.Changed.Event:Connect(updateReminder)
-- the rebirth icon spins while the reminder shows
RunService.RenderStepped:Connect(function()
	if reminder.Visible then
		reminderIcon.Rotation = (os.clock() * 90) % 360
		reminderScale.Scale = 1 + math.abs(math.sin(os.clock() * 3)) * 0.08
	end
end)

-- Combo counter (top middle): shows while you keep breaking things -------------

local combo = Instance.new("Frame")
combo.AnchorPoint = Vector2.new(0.5, 0)
combo.Position = UDim2.new(0.5, 0, 0, 12)
combo.Size = UDim2.fromOffset(250, 60)
combo.BackgroundColor3 = Ui.COLORS.Panel
combo.Visible = false
combo.Parent = Ui.gui
Ui.corner(combo, 16)
Ui.stroke(combo, Ui.COLORS.Line, 1.5)
local comboText = Ui.label(combo, {
	Position = UDim2.fromOffset(0, 6),
	Size = UDim2.new(1, 0, 0, 28),
	TextColor3 = Color3.fromRGB(255, 120, 60),
})
local comboBar = Instance.new("Frame")
comboBar.Position = UDim2.new(0, 16, 1, -16)
comboBar.Size = UDim2.new(1, -32, 0, 6)
comboBar.BackgroundColor3 = Ui.COLORS.Soft
comboBar.Parent = combo
Ui.corner(comboBar, 0.5)
local comboFill = Instance.new("Frame")
comboFill.Size = UDim2.fromScale(0, 1)
comboFill.BackgroundColor3 = Color3.new(1, 1, 1)
comboFill.Parent = comboBar
Ui.corner(comboFill, 0.5)
Ui.gradient(comboFill, Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 70, 70), 0)
local comboScale = Instance.new("UIScale")
comboScale.Parent = combo

player:GetAttributeChangedSignal("Combo"):Connect(function()
	local count = player:GetAttribute("Combo") or 0
	combo.Visible = count >= 3
	if count < 3 then
		return
	end
	comboText.Text = "🔥 Combo x" .. count
	-- the bar fills toward the next free boost
	local progress = (count % Config.COMBO_STEP) / Config.COMBO_STEP
	comboFill.Size = UDim2.fromScale(if progress == 0 then 1 else progress, 1)
	comboScale.Scale = 1.12
	TweenService:Create(comboScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end)

-- Buttons (left side): white tiles with modern icons -------------------------------

local side = Instance.new("Frame")
side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 14, 0.62, 0)
side.Size = UDim2.fromOffset(150, 290)
side.BackgroundTransparency = 1
side.Parent = Ui.gui

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(66, 88)
grid.CellPadding = UDim2.fromOffset(12, 6)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = side

local function sideButton(drawIcon, caption, accent)
	local cell = Instance.new("Frame")
	cell.Name = caption
	cell.BackgroundTransparency = 1
	cell.Parent = side

	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(66, 66)
	b.BackgroundColor3 = Ui.COLORS.Panel
	b.Text = ""
	b.AutoButtonColor = true
	b.Parent = cell
	Ui.corner(b, 18)
	local stroke = Ui.stroke(b, Ui.COLORS.Line, 1.5)

	local holder = Instance.new("Frame")
	holder.Name = "IconHolder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(0.56, 0.56)
	holder.BackgroundTransparency = 1
	holder.Parent = b
	drawIcon(holder, accent)

	local label = Ui.label(cell, {
		Name = "Caption",
		Text = caption,
		Font = Ui.FONT_BODY,
		TextColor3 = Ui.COLORS.White,
		TextStrokeTransparency = 0.6,
		TextStrokeColor3 = Color3.fromRGB(20, 20, 30),
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 0, 16),
	})

	-- the border lights up in the button's color on hover
	b.MouseEnter:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Color = accent, Thickness = 2.5 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.15), { Color = Ui.COLORS.Line, Thickness = 1.5 }):Play()
	end)
	Ui.bounce(b)
	return b, holder, label, cell
end

local function atEggs()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - EGG_CENTER).Magnitude < 150
end

local EGG_COLOR = Color3.fromRGB(255, 160, 60)
local HOME_COLOR = Color3.fromRGB(40, 190, 120)

-- one teleport button: goes to the eggs from home, and home from the eggs
local teleport, teleportIcon, teleportLabel, teleportCell = sideButton(Icons.egg, "Eggs", EGG_COLOR)
teleportCell.LayoutOrder = 1
teleport.Activated:Connect(function()
	Transition.go(if atEggs() then "Main" else "Eggs")
end)

local pets, _, _, petsCell = sideButton(Icons.paw, "Pets", Ui.COLORS.Accent)
petsCell.LayoutOrder = 2
pets.Activated:Connect(Inventory.toggle)

local index, _, _, indexCell = sideButton(Icons.book, "Index", Color3.fromRGB(255, 100, 150))
indexCell.LayoutOrder = 3
index.Activated:Connect(Index.toggle)

local rebirth, _, _, rebirthCell = sideButton(Icons.rebirth, "Rebirth", Ui.COLORS.Accent2)
rebirthCell.LayoutOrder = 4
rebirth.Activated:Connect(Rebirth.toggle)

local gifts, _, _, giftsCell = sideButton(Icons.gift, "Gifts", Ui.COLORS.Red)
giftsCell.LayoutOrder = 5
gifts.Activated:Connect(Gifts.toggle)
Gifts.attach(gifts)

-- the teleport button shows where it will take you
task.spawn(function()
	local showingEggs = nil
	while true do
		local here = atEggs()
		if here ~= showingEggs then
			showingEggs = here
			Ui.clear(teleportIcon)
			if here then
				Icons.home(teleportIcon, HOME_COLOR)
			else
				Icons.egg(teleportIcon, EGG_COLOR)
			end
			teleportLabel.Text = if here then "Home" else "Eggs"
		end
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
local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 146)
banner.Size = UDim2.fromOffset(640, 46)
banner.BackgroundColor3 = Ui.COLORS.Panel
banner.Visible = false
banner.ZIndex = 25
banner.Parent = Ui.gui
Ui.corner(banner, 0.5)
local bannerStroke = Ui.stroke(banner, Ui.COLORS.Gold, 2)
local bannerText = Ui.label(banner, {
	Position = UDim2.fromOffset(20, 11),
	Size = UDim2.new(1, -40, 0, 24),
	ZIndex = 26,
})
local bannerId = 0
remotes.Announce.OnClientEvent:Connect(function(playerName, petName)
	local info = Config.PETS[petName]
	if not info then
		return
	end
	bannerId += 1
	local id = bannerId
	bannerText.Text = ("🎉 %s hatched a %s! (%s)"):format(playerName, petName, Config.chanceText(petName))
	bannerStroke.Color = info.Color
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
		coinZone.Color = Config.areaColor(data.Rebirths):Lerp(Color3.new(1, 1, 1), 0.2)
	end
	-- grass patches and tufts follow the floor color (darker/lighter shades)
	local floorColor = Config.areaColor(data.Rebirths)
	for _, patch in ipairs(CollectionService:GetTagged("FloorPatch")) do
		local shade = patch:GetAttribute("Shade") or 0
		patch.Color = floorColor:Lerp(if shade < 0 then Color3.new(0, 0, 0) else Color3.new(1, 1, 1), math.abs(shade))
	end
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

