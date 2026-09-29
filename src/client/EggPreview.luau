-- When you walk up to an egg, a small popup floats on top of it: the pets
-- inside in a 3-wide grid with the chance to get each one under it (with your
-- luck), and three buttons that show the price (tap a pet to auto-delete it
-- whenever you hatch it):
--   E = buy 1 egg, F = buy more (3, up to 8 with the Hatch Amount upgrade),
--   T = auto hatch (on/off)
-- The keys work while the popup is open; the buttons can be tapped too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Viewport = require(script.Parent.Viewport)
local Hatch = require(script.Parent.Hatch)
local EggArea = require(script.Parent.EggArea)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local EggPreview = {}

local SHOW_DISTANCE = 14
local CELL = Vector2.new(84, 94)
local GAP = 6
local WIDTH = CELL.X * 3 + GAP * 2 + 24

-- The popup is a BillboardGui in PlayerGui (so its buttons can be clicked),
-- attached on top of whichever egg you're standing at.
local board = Instance.new("BillboardGui")
board.Name = "EggPopup"
board.Size = UDim2.fromOffset(WIDTH, 300)
board.SizeOffset = Vector2.new(0, 0.5) -- bottom edge sits at the anchor point
board.AlwaysOnTop = true
board.Active = true -- without this, clicks on its buttons are ignored
board.LightInfluence = 0
board.ResetOnSpawn = false
board.Enabled = false
board.Parent = player:WaitForChild("PlayerGui")

local popup = Instance.new("Frame")
popup.Size = UDim2.fromScale(1, 1)
popup.BackgroundColor3 = Ui.COLORS.Panel
popup.Parent = board
Ui.corner(popup, 18)
-- the border takes the egg's color, with a slow shimmer
local popupStroke = Ui.stroke(popup, Color3.new(1, 1, 1), 3)
local popupGradient = Instance.new("UIGradient")
popupGradient.Parent = popupStroke
local popupScale = Instance.new("UIScale")
popupScale.Parent = popup

local title = Ui.label(popup, {
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -160, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Left,
})
Ui.label(popup, {
	Text = "tap a pet to auto-delete",
	Font = Ui.FONT_BODY,
	TextColor3 = Ui.COLORS.SubText,
	TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 13),
	Size = UDim2.fromOffset(130, 14),
})

local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.fromOffset(12, 38)
grid.Size = UDim2.new(1, -24, 0, CELL.Y * 2 + GAP)
grid.Parent = popup
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
layout.CellPadding = UDim2.fromOffset(GAP, GAP)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

-- the egg's huge gets its own wide banner under the grid: a bigger pet, a big
-- HUGE tag and its chance
local HUGE_H = 104
local hugeRow = Instance.new("Frame")
hugeRow.BackgroundColor3 = Color3.fromRGB(255, 236, 249)
hugeRow.Size = UDim2.new(1, -24, 0, HUGE_H)
hugeRow.Visible = false
hugeRow.Parent = popup
Ui.corner(hugeRow, 14)
local hugeStroke = Ui.stroke(hugeRow, Color3.new(1, 1, 1), 3)
local hugeShimmer = Instance.new("UIGradient")
hugeShimmer.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 200)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 110, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 200)),
})
hugeShimmer.Parent = hugeStroke
local hugeView = Instance.new("Frame")
hugeView.BackgroundTransparency = 1
hugeView.Position = UDim2.fromOffset(6, 4)
hugeView.Size = UDim2.fromOffset(HUGE_H - 8, HUGE_H - 8)
hugeView.Parent = hugeRow
local hugeTag = Ui.label(hugeRow, {
	Text = "HUGE",
	TextColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0,
	BackgroundColor3 = Color3.fromRGB(245, 70, 185),
	Position = UDim2.fromOffset(HUGE_H + 4, 12),
	Size = UDim2.fromOffset(84, 26),
})
Ui.corner(hugeTag, 0.5)
local hugeTagPad = Instance.new("UIPadding")
hugeTagPad.PaddingTop = UDim.new(0, 4)
hugeTagPad.PaddingBottom = UDim.new(0, 4)
hugeTagPad.Parent = hugeTag
local hugeName = Ui.label(hugeRow, {
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(HUGE_H + 4, 42),
	Size = UDim2.new(1, -HUGE_H - 12, 0, 24),
})
local hugeChance = Ui.label(hugeRow, {
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(220, 50, 160),
	Position = UDim2.fromOffset(HUGE_H + 4, 70),
	Size = UDim2.new(1, -HUGE_H - 12, 0, 22),
})

-- the three buttons: a key letter badge, then what it does and the price
local buttonRow = Instance.new("Frame")
buttonRow.BackgroundTransparency = 1
buttonRow.AnchorPoint = Vector2.new(0, 1)
buttonRow.Position = UDim2.new(0, 12, 1, -10)
buttonRow.Size = UDim2.new(1, -24, 0, 46)
buttonRow.Parent = popup
local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.Padding = UDim.new(0, 6)
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonRow

local AUTO_OFF = Color3.fromRGB(150, 140, 170)

local function keyButton(order, key, color)
	local button = Ui.button(buttonRow, "", color, {
		Size = UDim2.new(1 / 3, -4, 1, 0),
		LayoutOrder = order,
	})
	local pad = button:FindFirstChildOfClass("UIPadding")
	if pad then
		pad:Destroy()
	end
	local badge = Ui.label(button, {
		Text = key,
		TextColor3 = color,
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(22, 22),
	})
	Ui.corner(badge, 6)
	local badgePad = Instance.new("UIPadding")
	badgePad.PaddingTop = UDim.new(0, 3)
	badgePad.PaddingBottom = UDim.new(0, 3)
	badgePad.Parent = badge
	local top = Ui.label(button, {
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(33, 5),
		Size = UDim2.new(1, -37, 0, 18),
	})
	local bottom = Ui.label(button, {
		Font = Ui.FONT_BODY,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(33, 24),
		Size = UDim2.new(1, -37, 0, 15),
	})
	return { Button = button, Badge = badge, Top = top, Bottom = bottom }
end

local buyOne = keyButton(1, "E", Ui.COLORS.Green)
local buyThree = keyButton(2, "F", Color3.fromRGB(70, 160, 250))
local autoButton = keyButton(3, "T", AUTO_OFF)
buyOne.Top.Text = "Buy 1"
autoButton.Top.Text = "Auto"

local shownEgg = nil -- egg index currently shown
local auto = false
local autoCount = 1 -- auto hatches 1 or several at a time (whichever you bought last)
local lastRequest = 0

local function setAuto(on)
	auto = on
	Hatch.fast = on
	autoButton.Top.Text = if on then "Stop" else "Auto"
	autoButton.Bottom.Text = if on then "hatching x" .. autoCount else "keep hatching"
	Ui.setButtonColor(autoButton.Button, if on then Ui.COLORS.Red else AUTO_OFF)
	autoButton.Badge.TextColor3 = if on then Ui.COLORS.Red else AUTO_OFF
	autoButton.Top.TextColor3 = Color3.new(1, 1, 1)
	autoButton.Bottom.TextColor3 = Color3.new(1, 1, 1)
end
setAuto(false)

-- Checks coins and space before asking the server, so auto stops nicely.
local function canHatch(count)
	local data = State.Data
	if not data or not shownEgg then
		return false
	end
	-- only stop when there's no room at all and nothing from this egg gets
	-- auto-deleted (the server rolls first and counts only the pets you keep)
	if #data.Pets >= Config.maxPets(data) then
		local anyAuto = false
		for _, petName in ipairs(Config.EGGS[shownEgg].Pets) do
			if data.AutoDelete and data.AutoDelete[petName] then
				anyAuto = true
			end
		end
		if not anyAuto then
			Ui.toast("🎒 Your pet inventory is full! Delete some pets.", Ui.COLORS.Red)
			return false
		end
	end
	local cost = Config.eggPrice(data, shownEgg) * count
	if (player:GetAttribute("Coins") or 0) < cost then
		Ui.toast("💰 You need " .. Config.formatNumber(cost) .. " coins!", Ui.COLORS.Red)
		return false
	end
	return true
end

local function requestHatch(count)
	local speed = Config.totalHatchSpeed(State.Data)
	if not shownEgg or Hatch.busy() or os.clock() - lastRequest < 0.9 / speed then
		return
	end
	if not canHatch(count) then
		setAuto(false)
		return
	end
	lastRequest = os.clock()
	remotes.Hatch:FireServer(shownEgg, count)
end

local function press(buttonInfo)
	local scale = buttonInfo.Button:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

local function buy(count)
	autoCount = count
	press(if count == 1 then buyOne else buyThree)
	requestHatch(count)
end

local function toggleAuto()
	press(autoButton)
	setAuto(not auto)
end

buyOne.Button.Activated:Connect(function()
	buy(1)
end)
buyThree.Button.Activated:Connect(function()
	buy(Config.totalHatchAmount(State.Data))
end)
autoButton.Button.Activated:Connect(toggleAuto)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not shownEgg then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		buy(1)
	elseif input.KeyCode == Enum.KeyCode.F then
		buy(Config.totalHatchAmount(State.Data))
	elseif input.KeyCode == Enum.KeyCode.T then
		toggleAuto()
	end
end)

local eggModels = {} -- [eggIndex] = model
local stopSpins = {} -- stops the spinning pet previews when the grid is rebuilt

-- One pet tile: the pet, and its chance under it in the rarity's color.
-- Pets that can be picked for auto-delete (never Mythical or Huge ones).
local AUTO_DELETABLE = { Common = true, Uncommon = true, Rare = true, Legendary = true }
local busyToggle = false

-- One pet tile: the pet, and its chance under it in the rarity's color.
-- Tap it to auto-delete that pet when you hatch it (red with a trash can).
local function petTile(entry, order, known, marked)
	local info = Config.PETS[entry.Pet]
	local rarity = info.Rarity
	local color = info.Color
	local canDelete = AUTO_DELETABLE[rarity] == true

	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = if marked then Color3.fromRGB(255, 225, 228) else color:Lerp(Color3.new(1, 1, 1), 0.85)
	tile.LayoutOrder = order
	tile.Parent = grid
	Ui.corner(tile, 12)
	Ui.stroke(
		tile,
		if marked then Ui.COLORS.Red else color:Lerp(Color3.new(1, 1, 1), 0.3),
		if marked or rarity == "Mythical" or rarity == "Huge" then 2.5 else 1.5
	)

	local view = Instance.new("Frame")
	view.BackgroundTransparency = 1
	view.Position = UDim2.fromOffset(4, 2)
	view.Size = UDim2.new(1, -8, 0, CELL.Y - 26)
	view.Parent = tile
	-- huge pets stay a mystery until you find one
	local vp, model = Viewport.pet(view, entry.Pet, rarity == "Huge" and not known)
	table.insert(stopSpins, Viewport.spin(model, 1))
	if marked then
		vp.ImageTransparency = 0.55
	end

	Ui.label(tile, {
		Text = if marked then "auto-delete" else Config.chanceLabel(entry.Chance),
		TextColor3 = if marked then Ui.COLORS.Red else color:Lerp(Color3.new(0, 0, 0), 0.25),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -8, 0, 18),
	})
	if marked then
		local badge = Ui.label(tile, {
			Text = "🗑",
			BackgroundTransparency = 0,
			BackgroundColor3 = Ui.COLORS.Red,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(22, 22),
		})
		Ui.corner(badge, 0.5)
	end

	-- an invisible button over the whole tile catches the tap (so the 3D
	-- preview inside can never swallow it)
	local hit = Instance.new("TextButton")
	hit.Name = "Tap"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 10
	hit.Parent = tile
	hit.Activated:Connect(function()
		if not canDelete then
			Ui.toast("Mythical and Huge pets can't be auto-deleted", Ui.COLORS.Red)
			return
		end
		if busyToggle then
			return
		end
		busyToggle = true
		local ok = remotes.SetAutoDelete:InvokeServer(entry.Pet, not marked)
		busyToggle = false
		if ok then
			Ui.toast(
				if marked then entry.Pet .. " will be kept again" else entry.Pet .. " will be auto-deleted",
				if marked then Ui.COLORS.Green else Ui.COLORS.Red
			)
		end
	end)
end

local function show(eggIndex)
	if shownEgg and shownEgg ~= eggIndex then
		EggArea.setLabelVisible(shownEgg, true)
	end
	shownEgg = eggIndex
	for _, stop in ipairs(stopSpins) do
		stop()
	end
	table.clear(stopSpins)
	Ui.clear(grid)
	if not eggIndex then
		board.Enabled = false
		setAuto(false)
		return
	end
	EggArea.setLabelVisible(eggIndex, false)

	local model = eggModels[eggIndex]
	local top = model and model:FindFirstChild("Top")
	local shell = model and model:FindFirstChild("Egg")
	-- attach to the pedestal (not the bobbing egg) so the popup stays still
	board.Adornee = top or shell
	board.StudsOffsetWorldSpace = Vector3.new(0, if shell then shell.Size.Y * 1.2 + 0.6 else 8, 0)

	local data = State.Data
	local egg = Config.EGGS[eggIndex]
	title.Text = egg.Name
	popupGradient.Color = ColorSequence.new(egg.Color, Ui.COLORS.Accent2)

	local price = Config.eggPrice(data, eggIndex)
	buyOne.Bottom.Text = "💰 " .. Config.formatNumber(price)
	local amount = Config.totalHatchAmount(data)
	buyThree.Top.Text = "Buy " .. amount
	buyThree.Bottom.Text = "💰 " .. Config.formatNumber(price * amount)
	setAuto(auto)

	local chances = Config.eggChances(eggIndex, data)
	local huge = nil
	local count = 0
	for order, entry in ipairs(chances) do
		if Config.PETS[entry.Pet].Rarity == "Huge" then
			huge = entry
		else
			count += 1
			petTile(entry, order, data and data.Index[entry.Pet], data and data.AutoDelete and data.AutoDelete[entry.Pet] == true)
		end
	end
	local rows = math.ceil(count / 3)
	local gridBottom = 38 + rows * CELL.Y + (rows - 1) * GAP

	-- the huge banner
	for _, child in ipairs(hugeView:GetChildren()) do
		child:Destroy()
	end
	hugeRow.Visible = huge ~= nil
	local extra = 0
	if huge then
		local known = data and data.Index[huge.Pet]
		local _, model = Viewport.pet(hugeView, huge.Pet, not known)
		table.insert(stopSpins, Viewport.spin(model, 1))
		hugeName.Text = if known then huge.Pet else "Mystery Huge"
		hugeChance.Text = Config.chanceLabel(huge.Chance)
		hugeRow.Position = UDim2.fromOffset(12, gridBottom + GAP + 2)
		extra = HUGE_H + GAP + 2
	end
	board.Size = UDim2.fromOffset(WIDTH, gridBottom + extra + 10 + 46 + 10)

	if not board.Enabled then
		board.Enabled = true
		popupScale.Scale = 0.6
		TweenService:Create(popupScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- The closest unlocked egg within reach (locked eggs have no popup).
local function nearestEgg()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local eggArea = workspace:FindFirstChild("EggArea")
	local eggs = eggArea and eggArea:FindFirstChild("Eggs")
	if not root or not eggs then
		return nil
	end
	local best, bestDist = nil, SHOW_DISTANCE
	for _, model in ipairs(eggs:GetChildren()) do
		local eggIndex = model:GetAttribute("EggIndex")
		local top = model:FindFirstChild("Top")
		if eggIndex and top and not EggArea.isLocked(eggIndex) then
			eggModels[eggIndex] = model
			local offset = top.Position - root.Position
			local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if dist < bestDist then
				best, bestDist = eggIndex, dist
			end
		end
	end
	return best
end

task.spawn(function()
	while true do
		task.wait(0.2)
		local eggIndex = nearestEgg()
		if eggIndex ~= shownEgg then
			show(eggIndex)
		end
		if auto and shownEgg then
			requestHatch(autoCount)
		end
	end
end)

-- the border shimmer slowly spins around
RunService.RenderStepped:Connect(function()
	if board.Enabled then
		popupGradient.Rotation = (os.clock() * 40) % 360
		hugeShimmer.Rotation = (os.clock() * 90) % 360
	end
end)

-- luck, coins or rebirths changed: refresh the chances and prices
State.Changed.Event:Connect(function()
	if shownEgg then
		show(shownEgg)
	end
end)

return EggPreview
