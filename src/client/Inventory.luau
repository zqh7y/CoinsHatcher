-- The pets menu: huge pets first in their own row of big tiles, then a clean
-- grid of square pet icons, 4 per row. Copies of the same pet are stacked
-- into one icon with how many you have ("x20"); equipped pets and huges get
-- their own icons. Tap a pet to equip or unequip it. Filter tabs, Equip Best, and a delete mode (tap pets
-- to pick them, then delete).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ui = require(script.Parent.Ui)
local State = require(script.Parent.State)
local Cards = require(script.Parent.Cards)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Inventory = {}

local panel = Ui.panel("Pets", nil, UDim2.fromOffset(660, 600), { Ui.COLORS.Accent })

-- small stats line under the title
local stats = Ui.label(panel.Frame, {
	Font = Ui.FONT_BODY,
	TextColor3 = Ui.COLORS.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(120, 24),
	Size = UDim2.new(1, -200, 0, 18),
})

-- Tabs + actions ----------------------------------------------------------------

local TABS = {
	{ "All", nil },
	{ "Equipped", "Equipped" },
	{ "Common", "Common" },
	{ "Uncommon", "Uncommon" },
	{ "Rare", "Rare" },
	{ "Legendary", "Legendary" },
	{ "Huge", "Huge" },
	{ "Mutated", "Mutated" },
}

local tabBar = Instance.new("ScrollingFrame")
tabBar.BackgroundTransparency = 1
tabBar.BorderSizePixel = 0
tabBar.Size = UDim2.new(1, -250, 0, 36)
tabBar.ScrollBarThickness = 0
tabBar.ScrollingDirection = Enum.ScrollingDirection.X
tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
tabBar.CanvasSize = UDim2.new()
tabBar.Parent = panel.Content
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 16)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Parent = tabBar

local actions = Instance.new("Frame")
actions.BackgroundTransparency = 1
actions.AnchorPoint = Vector2.new(1, 0)
actions.Position = UDim2.new(1, 0, 0, 0)
actions.Size = UDim2.fromOffset(240, 36)
actions.Parent = panel.Content
local actionLayout = Instance.new("UIListLayout")
actionLayout.FillDirection = Enum.FillDirection.Horizontal
actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
actionLayout.Padding = UDim.new(0, 8)
actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionLayout.Parent = actions

local equipBest = Ui.button(actions, "Equip Best", Ui.COLORS.Accent, { Size = UDim2.fromOffset(110, 36), LayoutOrder = 1 })
local deleteMode = Ui.button(actions, "Delete", Ui.COLORS.Soft, { Size = UDim2.fromOffset(80, 36), LayoutOrder = 2 })
local deleteConfirm = Ui.button(actions, "Delete 0", Ui.COLORS.Red, { Size = UDim2.fromOffset(100, 36), LayoutOrder = 3, Visible = false })

local listHolder = Instance.new("Frame")
listHolder.BackgroundTransparency = 1
listHolder.Position = UDim2.fromOffset(0, 48)
listHolder.Size = UDim2.new(1, 0, 1, -48)
listHolder.Parent = panel.Content
-- one scrolling list: a grid of big huge tiles on top, the normal grid under it
local scroller = Instance.new("ScrollingFrame")
scroller.Size = UDim2.fromScale(1, 1)
scroller.BackgroundTransparency = 1
scroller.BorderSizePixel = 0
scroller.ScrollBarThickness = 5
scroller.ScrollBarImageColor3 = Ui.COLORS.Disabled
scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroller.CanvasSize = UDim2.new()
scroller.Parent = listHolder
local scrollLayout = Instance.new("UIListLayout")
scrollLayout.Padding = UDim.new(0, 12)
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Parent = scroller
local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingTop = UDim.new(0, 4)
scrollPad.PaddingBottom = UDim.new(0, 8)
scrollPad.Parent = scroller

local function section(order, cell)
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = scroller
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cell
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = frame
	return frame
end
local hugeList = section(1, UDim2.fromOffset(292, 230)) -- huges: two big tiles per row
local list = section(2, UDim2.fromOffset(140, 140))

local filter = nil -- current tab's filter
local deleting = false
local selected = {} -- [petIndex] = true while picking pets to delete
local tabButtons = {}

local render

local function countSelected()
	local n = 0
	for _ in pairs(selected) do
		n += 1
	end
	return n
end

local function setDeleting(on)
	deleting = on
	selected = {}
	deleteMode.Text = if on then "Cancel" else "Delete"
	deleteConfirm.Visible = on
	deleteConfirm.Text = "Delete 0"
	equipBest.Visible = not on
	render()
end

-- minimal text tabs: the active one is dark with an accent underline
for order, tab in ipairs(TABS) do
	local button = Instance.new("TextButton")
	button.AutomaticSize = Enum.AutomaticSize.X
	button.Size = UDim2.fromOffset(0, 30)
	button.BackgroundTransparency = 1
	button.Text = tab[1]
	button.Font = Ui.FONT
	button.TextSize = 15
	button.TextColor3 = Ui.COLORS.Text
	button.LayoutOrder = order
	button.Parent = tabBar

	local underline = Instance.new("Frame")
	underline.AnchorPoint = Vector2.new(0.5, 1)
	underline.Position = UDim2.fromScale(0.5, 1)
	underline.Size = UDim2.new(1, 0, 0, 3)
	underline.BackgroundColor3 = Ui.COLORS.Accent
	underline.BorderSizePixel = 0
	underline.Parent = button
	Ui.corner(underline, 0.5)

	button.Activated:Connect(function()
		filter = tab[2]
		render()
	end)
	tabButtons[order] = { Button = button, Underline = underline, Filter = tab[2] }
end

local function matches(info, equipped)
	if filter == nil then
		return true
	elseif filter == "Equipped" then
		return equipped
	elseif filter == "Mutated" then
		return info.Mutation ~= nil
	end
	return info.Rarity == filter
end

render = function()
	Ui.clear(list)
	Ui.clear(hugeList)
	local data = State.Data
	if not data then
		return
	end

	for _, tab in ipairs(tabButtons) do
		local active = tab.Filter == filter
		tab.Button.TextColor3 = if active then Ui.COLORS.Text else Ui.COLORS.SubText
		tab.Underline.Visible = active
	end

	local teamPower = 0
	for _, index in ipairs(data.Equipped) do
		local info = Config.PETS[data.Pets[index] or ""]
		if info then
			teamPower += info.Power
		end
	end
	stats.Text = ("%d/%d pets  ·  %d/%d equipped  ·  ⚔ %s team power"):format(
		#data.Pets,
		Config.maxPets(data),
		#data.Equipped,
		Config.totalSlots(data),
		Config.formatNumber(teamPower * Config.totalDamage(data))
	)

	-- One tile per equipped pet and per huge; every other kind of pet is
	-- stacked into one tile with how many you have ("x20").
	-- tiles = { { Name, Indexes, Equipped } }
	local tiles = {}
	local stacks = {} -- [pet name] = tile
	for index, petName in ipairs(data.Pets) do
		local info = Config.PETS[petName]
		local equipped = table.find(data.Equipped, index) ~= nil
		if info and matches(info, equipped) then
			if equipped or info.Rarity == "Huge" then
				table.insert(tiles, { Name = petName, Indexes = { index }, Equipped = equipped })
			elseif stacks[petName] then
				table.insert(stacks[petName].Indexes, index)
			else
				stacks[petName] = { Name = petName, Indexes = { index }, Equipped = false }
				table.insert(tiles, stacks[petName])
			end
		end
	end
	-- equipped first, then strongest first
	table.sort(tiles, function(a, b)
		if a.Equipped ~= b.Equipped then
			return a.Equipped
		end
		local pa, pb = Config.PETS[a.Name].Power, Config.PETS[b.Name].Power
		if pa ~= pb then
			return pa > pb
		end
		return a.Name < b.Name
	end)

	if #tiles == 0 then
		Ui.label(list, { Text = "No pets here yet", TextColor3 = Ui.COLORS.SubText, LayoutOrder = 1 })
	end
	hugeList.Visible = false

	for rank, tile in ipairs(tiles) do
		local petName = tile.Name
		local info = Config.PETS[petName]
		local count = #tile.Indexes
		-- a stack counts as picked when all of it is picked
		local picked = true
		for _, index in ipairs(tile.Indexes) do
			if not selected[index] then
				picked = false
			end
		end

		-- tap the pet itself: equip/unequip (or pick it in delete mode)
		local huge = info.Rarity == "Huge"
		if huge then
			hugeList.Visible = true
		end
		local card = Cards.pet(if huge then hugeList else list, petName, {
			Compact = true,
			Button = true,
			Detail = "⚔ " .. Config.formatNumber(info.Power),
			LayoutOrder = rank,
			Equipped = tile.Equipped,
			Picked = picked,
		})
		-- how many of this pet you have
		if count > 1 then
			local amount = Ui.label(card, {
				Text = "x" .. count,
				TextColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0,
				BackgroundColor3 = Ui.COLORS.Accent,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -5, 0, if picked then 30 else 5), -- under the ✕ when picked
				Size = UDim2.fromOffset(42, 22),
				ZIndex = 6,
			})
			Ui.corner(amount, 0.5)
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 3)
			pad.PaddingBottom = UDim.new(0, 3)
			pad.Parent = amount
		end
		card.Activated:Connect(function()
			if deleting then
				if tile.Equipped then
					Ui.toast("Equipped pets can't be deleted", Ui.COLORS.Red)
				else
					-- a stack is picked (or unpicked) all at once
					for _, index in ipairs(tile.Indexes) do
						selected[index] = if picked then nil else true
					end
					deleteConfirm.Text = "Delete " .. countSelected()
					render()
				end
				return
			end
			-- a stack equips one of its pets; an equipped pet unequips
			local ok, message = remotes.SetEquipped:InvokeServer(tile.Indexes[1], not tile.Equipped)
			if not ok and message then
				Ui.toast(message, Ui.COLORS.Red)
			end
		end)
	end
end

equipBest.Activated:Connect(function()
	local ok, message = remotes.EquipBest:InvokeServer()
	if message then
		Ui.toast(message, if ok then Ui.COLORS.Green else Ui.COLORS.Red)
	end
end)

deleteMode.Activated:Connect(function()
	setDeleting(not deleting)
end)

deleteConfirm.Activated:Connect(function()
	local indexes = {}
	for index in pairs(selected) do
		table.insert(indexes, index)
	end
	if #indexes == 0 then
		Ui.toast("Tap pets to pick which ones to delete", Ui.COLORS.Accent)
		return
	end
	local ok, message = remotes.DeletePets:InvokeServer(indexes)
	if message then
		Ui.toast(message, if ok then Ui.COLORS.Green else Ui.COLORS.Red)
	end
	setDeleting(false)
end)

panel.OnOpen.Event:Connect(function()
	if deleting then
		setDeleting(false)
	else
		render()
	end
end)
State.Changed.Event:Connect(function()
	if panel.isOpen() then
		-- pet numbers shift after deleting, so drop any picks
		selected = {}
		deleteConfirm.Text = "Delete 0"
		render()
	end
end)

Inventory.toggle = panel.toggle

return Inventory
