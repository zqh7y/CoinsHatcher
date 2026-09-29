-- When you walk up to an egg, a popup shows the pets inside, their chances
-- (including your Luck upgrade), mutation chances, and Hatch 1 / Hatch 3 /
-- Auto buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local popup = Instance.new("Frame")
popup.AnchorPoint = Vector2.new(0.5, 1)
popup.Position = UDim2.new(0.5, 0, 1, -16)
popup.Size = UDim2.fromOffset(640, 340)
popup.BackgroundColor3 = Ui.COLORS.Panel
popup.Visible = false
popup.Parent = Ui.gui
Ui.corner(popup, 22)
Ui.stroke(popup, Ui.COLORS.Outline, 5)
local popupScale = Instance.new("UIScale")
popupScale.Parent = popup

local title = Ui.label(popup, {
	Size = UDim2.new(1, -20, 0, 34),
	Position = UDim2.fromOffset(10, 8),
})
local mutationLine = Ui.label(popup, {
	Size = UDim2.new(1, -20, 0, 22),
	Position = UDim2.fromOffset(10, 44),
	TextColor3 = Color3.fromRGB(235, 225, 255),
})

local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.Size = UDim2.new(1, -20, 0, 180)
row.Position = UDim2.fromOffset(10, 72)
row.Parent = popup
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(116, 176)
grid.CellPadding = UDim2.fromOffset(8, 0)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = row

-- buttons
local buttonRow = Instance.new("Frame")
buttonRow.BackgroundTransparency = 1
buttonRow.Size = UDim2.new(1, -20, 0, 60)
buttonRow.Position = UDim2.new(0, 10, 1, -70)
buttonRow.Parent = popup
local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.Padding = UDim.new(0, 12)
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonRow

local hatchOne = Ui.button(buttonRow, "🥚 Hatch 1", Ui.COLORS.Green, { Size = UDim2.fromOffset(170, 56), LayoutOrder = 1 })
local hatchThree = Ui.button(buttonRow, "🥚🥚🥚 Hatch 3", Color3.fromRGB(80, 160, 240), { Size = UDim2.fromOffset(190, 56), LayoutOrder = 2 })
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
	if #data.Pets + count > Config.MAX_PETS then
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

local function show(eggIndex)
	shownEgg = eggIndex
	Ui.clear(row)
	if not eggIndex then
		popup.Visible = false
		setAuto(false)
		return
	end

	local data = State.Data
	local egg = Config.EGGS[eggIndex]
	local required = Config.eggRequiredRebirths(eggIndex)
	local locked = data and data.Rebirths < required
	title.Text = ("🥚 %s   ·   💰 %s each%s"):format(
		egg.Name,
		Config.formatNumber(Config.eggCost(eggIndex)),
		if locked then "   ·   🔒 Rebirth " .. required else ""
	)

	local mutations = {}
	for _, entry in ipairs(Config.mutationChances(data and data.Upgrades)) do
		table.insert(mutations, ("%s %s %s"):format(entry.Mutation.Icon, entry.Mutation.Name, Ui.percent(entry.Chance)))
	end
	mutationLine.Text = "Mutations:  " .. table.concat(mutations, "   ")

	for order, entry in ipairs(Config.eggChances(eggIndex, data and data.Upgrades)) do
		local known = data and data.Index[entry.Pet]
		local info = Config.PETS[entry.Pet]
		Cards.pet(row, entry.Pet, {
			-- huge pets stay a mystery until you find one
			Silhouette = info.Rarity == "Huge" and not known,
			Detail = Ui.percent(entry.Chance) .. "  ·  ⚔️" .. Config.formatNumber(info.Power),
			LayoutOrder = order,
		})
	end

	if not popup.Visible then
		popup.Visible = true
		popupScale.Scale = 0.7
		TweenService:Create(popupScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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

-- luck or rebirths changed: refresh the chances
State.Changed.Event:Connect(function()
	if shownEgg then
		show(shownEgg)
	end
end)

return EggPreview
