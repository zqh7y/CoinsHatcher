-- When you walk up to an egg, a glowing popup floats above it showing the
-- pets inside, their chances (with your Luck upgrade), mutation chances and
-- Hatch 1 / Hatch 3 / Auto buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)
local Hatch = require(script.Parent.Hatch)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer

local EggPreview = {}

local SHOW_DISTANCE = 16

-- The popup is a BillboardGui in PlayerGui (so its buttons can be clicked),
-- attached above whichever egg you're standing at.
local board = Instance.new("BillboardGui")
board.Name = "EggPopup"
board.Size = UDim2.fromOffset(640, 350)
board.SizeOffset = Vector2.new(0, 0.5) -- bottom edge sits at the anchor point
board.StudsOffsetWorldSpace = Vector3.new(0, 9.5, 0)
board.AlwaysOnTop = true
board.LightInfluence = 0
board.ResetOnSpawn = false
board.Enabled = false
board.Parent = player:WaitForChild("PlayerGui")

local popup = Instance.new("Frame")
popup.Size = UDim2.fromScale(1, 1)
popup.BackgroundColor3 = Color3.new(1, 1, 1)
popup.Parent = board
Ui.corner(popup, 26)
local popupStroke = Ui.stroke(popup, Color3.new(1, 1, 1), 4)
local popupGradient = Instance.new("UIGradient")
popupGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 110, 255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 80, 210)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 110, 200)),
})
popupGradient.Rotation = 35
popupGradient.Parent = popup
local popupScale = Instance.new("UIScale")
popupScale.Parent = popup

-- little sparkles in the corners
local corners = {}
for i, pos in ipairs({ UDim2.fromOffset(-6, -6), UDim2.new(1, 6, 0, -6), UDim2.new(0, -6, 1, 6), UDim2.new(1, 6, 1, 6) }) do
	corners[i] = Ui.label(popup, {
		Text = "✨",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(34, 34),
		TextStrokeTransparency = 1,
		ZIndex = 5,
	})
end

local title = Ui.label(popup, {
	Size = UDim2.new(0.62, 0, 0, 38),
	Position = UDim2.fromOffset(16, 10),
	TextXAlignment = Enum.TextXAlignment.Left,
})

local function chip(parent, color, props)
	local c = Ui.label(parent, props)
	c.BackgroundTransparency = 0
	c.BackgroundColor3 = color
	Ui.corner(c, 0.5)
	Ui.stroke(c, Color3.new(1, 1, 1), 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = c
	return c
end

local priceChip = chip(popup, Color3.fromRGB(255, 180, 40), {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 12),
	Size = UDim2.fromOffset(200, 34),
})

local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.Size = UDim2.new(1, -24, 0, 160)
row.Position = UDim2.fromOffset(12, 56)
row.Parent = popup
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(112, 158)
grid.CellPadding = UDim2.fromOffset(10, 0)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = row

-- mutation chips
local mutationRow = Instance.new("Frame")
mutationRow.BackgroundTransparency = 1
mutationRow.Size = UDim2.new(1, -24, 0, 30)
mutationRow.Position = UDim2.fromOffset(12, 224)
mutationRow.Parent = popup
local mutationLayout = Instance.new("UIListLayout")
mutationLayout.FillDirection = Enum.FillDirection.Horizontal
mutationLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
mutationLayout.Padding = UDim.new(0, 10)
mutationLayout.Parent = mutationRow
local mutationChips = {}
for i, mutation in ipairs(Config.MUTATIONS) do
	mutationChips[i] = chip(mutationRow, mutation.Color:Lerp(Color3.fromRGB(60, 30, 120), 0.45), {
		Size = UDim2.fromOffset(170, 30),
		LayoutOrder = i,
	})
end

-- buttons
local buttonRow = Instance.new("Frame")
buttonRow.BackgroundTransparency = 1
buttonRow.Size = UDim2.new(1, -24, 0, 62)
buttonRow.Position = UDim2.new(0, 12, 1, -74)
buttonRow.Parent = popup
local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buttonLayout.Padding = UDim.new(0, 12)
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonRow

local hatchOne = Ui.button(buttonRow, "🥚 Hatch 1  [E]", Ui.COLORS.Green, { Size = UDim2.fromOffset(180, 56), LayoutOrder = 1 })
local hatchThree = Ui.button(buttonRow, "🥚🥚🥚 Hatch 3", Color3.fromRGB(70, 160, 250), { Size = UDim2.fromOffset(190, 56), LayoutOrder = 2 })
local autoButton = Ui.button(buttonRow, "🔁 Auto", Color3.fromRGB(150, 140, 170), { Size = UDim2.fromOffset(170, 56), LayoutOrder = 3 })

local shownEgg = nil -- egg index currently shown
local auto = false
local autoCount = 1 -- auto hatches 1 or 3 at a time (whichever you pressed last)
local lastRequest = 0

local function setAuto(on)
	auto = on
	Hatch.fast = on
	autoButton.Text = if on then "⏹ Stop Auto" else "🔁 Auto"
	autoButton.BackgroundColor3 = if on then Ui.COLORS.Red else Color3.fromRGB(150, 140, 170)
end

-- Checks coins and space before asking the server, so auto stops nicely.
local function canHatch(count)
	local data = State.Data
	if not data or not shownEgg then
		return false
	end
	if data.Rebirths < Config.eggRequiredRebirths(shownEgg) then
		Ui.toast("🔒 Rebirth " .. Config.eggRequiredRebirths(shownEgg) .. " needed to open this egg!", Ui.COLORS.Red)
		return false
	end
	if #data.Pets + count > Config.maxPets(data) then
		Ui.toast("🎒 Your pet inventory is full! Delete some pets.", Ui.COLORS.Red)
		return false
	end
	local cost = Config.eggCost(shownEgg) * count
	if (player:GetAttribute("Coins") or 0) < cost then
		Ui.toast("💰 You need " .. Config.formatNumber(cost) .. " coins!", Ui.COLORS.Red)
		return false
	end
	return true
end

local function requestHatch(count)
	if Hatch.busy() or os.clock() - lastRequest < 0.9 then
		return
	end
	if not canHatch(count) then
		setAuto(false)
		return
	end
	lastRequest = os.clock()
	remotes.Hatch:FireServer(shownEgg, count)
end

hatchOne.Activated:Connect(function()
	autoCount = 1
	requestHatch(1)
end)
hatchThree.Activated:Connect(function()
	autoCount = 3
	requestHatch(3)
end)
autoButton.Activated:Connect(function()
	setAuto(not auto)
end)

local eggModels = {} -- [eggIndex] = model

local function show(eggIndex)
	shownEgg = eggIndex
	Ui.clear(row)
	if not eggIndex then
		board.Enabled = false
		setAuto(false)
		return
	end

	local model = eggModels[eggIndex]
	-- attach to the pedestal (not the bobbing egg) so the popup stays still
	board.Adornee = model and (model:FindFirstChild("Top") or model:FindFirstChild("Egg"))

	local data = State.Data
	local egg = Config.EGGS[eggIndex]
	local required = Config.eggRequiredRebirths(eggIndex)
	local locked = data and data.Rebirths < required
	title.Text = "🥚 " .. egg.Name
	if locked then
		priceChip.Text = "🔒 Rebirth " .. required
		priceChip.BackgroundColor3 = Ui.COLORS.Red
	else
		priceChip.Text = "💰 " .. Config.formatNumber(Config.eggCost(eggIndex))
		priceChip.BackgroundColor3 = Color3.fromRGB(255, 180, 40)
	end
	popupStroke.Color = egg.Color:Lerp(Color3.new(1, 1, 1), 0.5)

	for i, entry in ipairs(Config.mutationChances(data)) do
		mutationChips[i].Text = ("%s %s  %s"):format(entry.Mutation.Icon, entry.Mutation.Name, Ui.percent(entry.Chance))
	end

	for order, entry in ipairs(Config.eggChances(eggIndex, data)) do
		local known = data and data.Index[entry.Pet]
		local info = Config.PETS[entry.Pet]
		Cards.pet(row, entry.Pet, {
			-- huge pets stay a mystery until you find one
			Silhouette = info.Rarity == "Huge" and not known,
			Detail = Ui.percent(entry.Chance) .. " · ⚔️" .. Config.formatNumber(info.Power),
			LayoutOrder = order,
		})
	end

	if not board.Enabled then
		board.Enabled = true
		popupScale.Scale = 0.6
		TweenService:Create(popupScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

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
		if eggIndex and model:IsA("Model") then
			eggModels[eggIndex] = model
			local dist = (model:GetPivot().Position - root.Position).Magnitude
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

-- slowly shimmer the popup and spin the corner sparkles
RunService.RenderStepped:Connect(function()
	if not board.Enabled then
		return
	end
	local t = os.clock()
	popupGradient.Rotation = 35 + math.sin(t * 0.8) * 20
	for i, sparkle in ipairs(corners) do
		sparkle.Rotation = (t * 60 + i * 90) % 360
	end
end)

-- luck or rebirths changed: refresh the chances
State.Changed.Event:Connect(function()
	if shownEgg then
		show(shownEgg)
	end
end)

return EggPreview
