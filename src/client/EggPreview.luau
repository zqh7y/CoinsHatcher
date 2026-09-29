-- When you walk up to an egg, a popup shows the pets inside and their chances
-- (including your Luck upgrade).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local player = Players.LocalPlayer

local EggPreview = {}

local SHOW_DISTANCE = 16

local popup = Instance.new("Frame")
popup.AnchorPoint = Vector2.new(0.5, 1)
popup.Position = UDim2.new(0.5, 0, 1, -20)
popup.Size = UDim2.fromOffset(640, 250)
popup.BackgroundColor3 = Ui.COLORS.Panel
popup.Visible = false
popup.Parent = Ui.gui
Ui.corner(popup, 22)
Ui.stroke(popup, Ui.COLORS.Outline, 5)
local popupScale = Instance.new("UIScale")
popupScale.Parent = popup

local title = Ui.label(popup, {
	Size = UDim2.new(1, -20, 0, 36),
	Position = UDim2.fromOffset(10, 8),
})

local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.Size = UDim2.new(1, -20, 0, 190)
row.Position = UDim2.fromOffset(10, 50)
row.Parent = popup
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(116, 180)
grid.CellPadding = UDim2.fromOffset(8, 0)
grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = row

local shownEgg = nil -- egg index currently shown

local function show(eggIndex)
	shownEgg = eggIndex
	Ui.clear(row)
	if not eggIndex then
		popup.Visible = false
		return
	end

	local data = State.Data
	local egg = Config.EGGS[eggIndex]
	local required = Config.eggRequiredRebirths(eggIndex)
	local locked = data and data.Rebirths < required
	title.Text = ("🥚 %s   ·   💰 %s%s"):format(
		egg.Name,
		Config.formatNumber(Config.eggCost(eggIndex)),
		if locked then "   ·   🔒 Rebirth " .. required else "   ·   Press E to hatch!"
	)

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
	end
end)

-- luck or rebirths changed: refresh the chances
State.Changed.Event:Connect(function()
	if shownEgg then
		show(shownEgg)
	end
end)

return EggPreview
