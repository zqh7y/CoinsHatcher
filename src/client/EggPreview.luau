-- When you walk up to an egg, a small popup floats on top of it: the pets
-- inside in a 3-wide grid with the chance to get each one under it (with your
-- luck), and three buttons that show the price:
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
	Size = UDim2.new(1, -24, 0, 24),
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
	if #data.Pets + count > Config.maxPets(data) then
		Ui.toast("🎒 Your pet inventory is full! Delete some pets.", Ui.COLORS.Red)
		return false
	end
	local cost = Config.eggPrice(data, shownEgg) * count
	if (player:GetAttribute("Coins") or 0) < cost then
		Ui.toast("💰 You need " .. Config.formatNumber(cost) .. " coins!", Ui.COLORS.Red)
		return false
	end
	return true
end

local function requestHatch(count)
	local speed = Config.hatchSpeed(State.Data and State.Data.Upgrades)
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
	buy(Config.hatchAmount(State.Data and State.Data.Upgrades))
end)
autoButton.Button.Activated:Connect(toggleAuto)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not shownEgg then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		buy(1)
	elseif input.KeyCode == Enum.KeyCode.F then
		buy(Config.hatchAmount(State.Data and State.Data.Upgrades))
	elseif input.KeyCode == Enum.KeyCode.T then
		toggleAuto()
	end
end)

local eggModels = {} -- [eggIndex] = model
local stopSpins = {} -- stops the spinning pet previews when the grid is rebuilt

-- One pet tile: the pet, and its chance under it in the rarity's color.
local function petTile(entry, order, known)
	local info = Config.PETS[entry.Pet]
	local rarity = info.Rarity
	local color = info.Color

	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.85)
	tile.LayoutOrder = order
	tile.Parent = grid
	Ui.corner(tile, 12)
	Ui.stroke(tile, color:Lerp(Color3.new(1, 1, 1), 0.3), if rarity == "Mythical" or rarity == "Huge" then 2.5 else 1.5)

	local view = Instance.new("Frame")
	view.BackgroundTransparency = 1
	view.Position = UDim2.fromOffset(4, 2)
	view.Size = UDim2.new(1, -8, 0, CELL.Y - 26)
	view.Parent = tile
	-- huge pets stay a mystery until you find one
	local _, model = Viewport.pet(view, entry.Pet, rarity == "Huge" and not known)
	table.insert(stopSpins, Viewport.spin(model, 1))

	Ui.label(tile, {
		Text = Config.chanceLabel(entry.Chance),
		TextColor3 = color:Lerp(Color3.new(0, 0, 0), 0.25),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -8, 0, 18),
	})
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
	local amount = Config.hatchAmount(data and data.Upgrades)
	buyThree.Top.Text = "Buy " .. amount
	buyThree.Bottom.Text = "💰 " .. Config.formatNumber(price * amount)
	setAuto(auto)

	local chances = Config.eggChances(eggIndex, data)
	for order, entry in ipairs(chances) do
		petTile(entry, order, data and data.Index[entry.Pet])
	end
	local rows = math.ceil(#chances / 3)
	board.Size = UDim2.fromOffset(WIDTH, 38 + rows * CELL.Y + (rows - 1) * GAP + 10 + 46 + 10)

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
	end
end)

-- luck, coins or rebirths changed: refresh the chances and prices
State.Changed.Event:Connect(function()
	if shownEgg then
		show(shownEgg)
	end
end)

return EggPreview
