-- The index: a collection book of every pet. Ones you haven't hatched yet
-- show as black silhouettes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local Index = {}

local panel = Ui.panel("Index", nil, UDim2.fromOffset(700, 520), { Color3.fromRGB(255, 100, 150) })

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.fromScale(1, 1)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 8
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = panel.Content

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local function render()
	Ui.clear(list)
	local data = State.Data
	if not data then
		return
	end

	local found, total = 0, 0
	for eggIndex, egg in ipairs(Config.EGGS) do
		local pets = table.clone(egg.Pets)
		table.insert(pets, egg.Huge)

		local eggFound = 0
		for _, petName in ipairs(pets) do
			if data.Index[petName] then
				eggFound += 1
			end
		end
		found += eggFound
		total += #pets

		Ui.label(list, {
			Text = ("🥚 %s  (%d/%d)"):format(egg.Name, eggFound, #pets),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, -12, 0, 32),
			LayoutOrder = eggIndex * 2 - 1,
		})

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -12, 0, 160)
		row.BackgroundTransparency = 1
		row.LayoutOrder = eggIndex * 2
		row.Parent = list
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(122, 156)
		grid.CellPadding = UDim2.fromOffset(8, 0)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = row

		for order, petName in ipairs(pets) do
			local info = Config.PETS[petName]
			local known = data.Index[petName] == true
			Cards.pet(row, petName, {
				Silhouette = not known,
				Detail = if known then info.Rarity else "Not found yet",
				LayoutOrder = order,
			})
		end
	end

	panel.Title.Text = ("Index  ·  %d/%d found"):format(found, total)
end

panel.OnOpen.Event:Connect(render)
State.Changed.Event:Connect(function()
	if panel.isOpen() then
		render()
	end
end)

Index.toggle = panel.toggle

return Index
